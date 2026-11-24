import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// مجموعة محلية لوضع الضيف: خريطة {id: map} محفوظة كـ JSON في SharedPreferences،
/// ومعاها stream بيتحدث مع كل تغيير. بتشيل التكرار من كل الـ repositories المحلية.
class LocalJsonCollection<T> {
  LocalJsonCollection({
    required this.prefs,
    required this.key,
    required this.fromMap,
    required this.toMap,
  });

  final SharedPreferences prefs;
  final String key;
  final T Function(String id, Map<String, dynamic> map) fromMap;
  final Map<String, dynamic> Function(T item) toMap;

  static final _changes = StreamController<String>.broadcast();

  /// بعد ما بيانات اتكتبت من برّه (زرار في إشعار): نخلّي الشاشات تقرا من جديد
  static void refreshAll(Iterable<String> keys) => keys.forEach(_changes.add);

  Map<String, T> read() {
    final raw = prefs.getString(key);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in m.entries)
        e.key: fromMap(e.key, (e.value as Map).cast<String, dynamic>()),
    };
  }

  Future<void> write(Map<String, T> items) async {
    await prefs.setString(
      key,
      jsonEncode({for (final e in items.entries) e.key: toMap(e.value)}),
    );
    _changes.add(key);
  }

  /// كل العناصر، ومع كل تغيير بتطلع النسخة الجديدة
  Stream<Map<String, T>> watch() async* {
    yield read();
    yield* _changes.stream.where((k) => k == key).map((_) => read());
  }
}
