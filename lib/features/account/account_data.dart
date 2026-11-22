import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../data/session.dart';

/// كل المجموعات اللي التطبيق بيخزنها للمستخدم (لازم تتحدث مع أي قسم جديد)
const userCollections = [
  'tasks',
  'habits',
  'transactions',
  'journal',
  'prayers',
  'quran',
  'money',
  'family',
];

/// مفاتيح التخزين المحلي (وضع الضيف)
bool _isLocalDataKey(String k) =>
    k.startsWith('local_') || k.startsWith('store/');

/// تصدير كل بيانات المستخدم كملف JSON ومشاركته (حق من حقوق المستخدم ومطلوب لـ Play)
Future<void> exportMyData(WidgetRef ref) async {
  final session = ref.read(sessionProvider);
  final data = <String, dynamic>{
    'app': 'hayati',
    'exportedAt': DateTime.now().toIso8601String(),
  };
  if (session is UserSession) {
    final user = FirebaseFirestore.instance
        .collection('users')
        .doc(session.uid);
    data['account'] = {
      'uid': session.uid,
      'email': session.email,
      'name': session.name,
    };
    for (final c in userCollections) {
      final snap = await user.collection(c).get();
      data[c] = {for (final d in snap.docs) d.id: d.data()};
    }
  } else {
    final prefs = ref.read(sharedPrefsProvider);
    for (final k in prefs.getKeys().where(_isLocalDataKey)) {
      final v = prefs.get(k);
      data[k] = v is String ? _tryDecode(v) : v;
    }
  }
  final bytes = Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
  );
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/json')],
      fileNameOverrides: ['hayati-data.json'],
      subject: 'بياناتي من حياتي',
    ),
  );
}

Object? _tryDecode(String v) {
  try {
    return jsonDecode(v);
  } catch (_) {
    return v;
  }
}

/// حذف الحساب وكل البيانات نهائيًا
Future<void> deleteMyAccount(WidgetRef ref) async {
  final session = ref.read(sessionProvider);
  if (session is UserSession) {
    await FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
        .httpsCallable('deleteMyAccount')
        .call<Map<String, dynamic>>();
  } else {
    final prefs = ref.read(sharedPrefsProvider);
    for (final k in prefs.getKeys().where(_isLocalDataKey).toList()) {
      await prefs.remove(k);
    }
  }
  await ref.read(sessionProvider.notifier).signOut();
}
