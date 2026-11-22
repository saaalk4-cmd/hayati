import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';

/// حالة المستخدم داخل التطبيق
sealed class Session {
  const Session();
}

class SessionLoading extends Session {
  const SessionLoading();
}

class SignedOut extends Session {
  const SignedOut();
}

/// وضع الضيف: البيانات على الجهاز فقط، والمساعد غير متاح
class GuestSession extends Session {
  const GuestSession();
}

class UserSession extends Session {
  const UserSession({required this.uid, this.name, this.email, this.photoUrl});
  final String uid;
  final String? name;
  final String? email;
  final String? photoUrl;
}

final firebaseReadyProvider = Provider<bool>((ref) => false);
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

const _guestKey = 'guest_mode';

class SessionController extends Notifier<Session> {
  StreamSubscription<User?>? _sub;
  bool _googleInitialized = false;

  bool get _firebase => ref.read(firebaseReadyProvider);
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  Session build() {
    ref.onDispose(() => _sub?.cancel());
    if (_prefs.getBool(_guestKey) ?? false) return const GuestSession();
    if (!_firebase) return const SignedOut();
    _sub = FirebaseAuth.instance.authStateChanges().listen(_onUser);
    final current = FirebaseAuth.instance.currentUser;
    return current == null ? const SessionLoading() : _fromUser(current);
  }

  void _onUser(User? user) {
    if (state is GuestSession) return;
    state = user == null ? const SignedOut() : _fromUser(user);
  }

  Session _fromUser(User u) => UserSession(
    uid: u.uid,
    name: u.displayName,
    email: u.email,
    photoUrl: u.photoURL,
  );

  Future<void> continueAsGuest() async {
    await _prefs.setBool(_guestKey, true);
    state = const GuestSession();
  }

  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await google.initialize(serverClientId: AppConfig.googleServerClientId);
      _googleInitialized = true;
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signInWithEmail(String email, String password) => FirebaseAuth
      .instance
      .signInWithEmailAndPassword(email: email, password: password);

  Future<void> registerWithEmail(
    String name,
    String email,
    String password,
  ) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(name);
    await cred.user?.reload();
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) state = _fromUser(u);
  }

  Future<void> resetPassword(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email);

  Future<void> signOut() async {
    await _prefs.remove(_guestKey);
    if (_firebase) {
      if (_googleInitialized) await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
    }
    state = const SignedOut();
  }
}

final sessionProvider = NotifierProvider<SessionController, Session>(
  SessionController.new,
);

/// ترجمة أخطاء تسجيل الدخول لرسائل عربية مفهومة
String authErrorMessage(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد أو كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'البريد ده مسجّل قبل كده، جرّب تسجيل الدخول';
      case 'weak-password':
        return 'كلمة المرور ضعيفة، استخدم 6 حروف أو أكتر';
      case 'network-request-failed':
        return 'مفيش اتصال بالإنترنت';
      case 'too-many-requests':
        return 'محاولات كتير، استنى شوية وجرّب تاني';
    }
    return e.message ?? 'حصل خطأ، جرّب تاني';
  }
  if (e is GoogleSignInException) {
    if (e.code == GoogleSignInExceptionCode.canceled) return 'تم الإلغاء';
    return 'تعذّر تسجيل الدخول بجوجل';
  }
  return 'حصل خطأ، جرّب تاني';
}
