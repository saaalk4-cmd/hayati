import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/session.dart';
import '../../data/user_store.dart';
import 'account_data.dart';

/// المجموعات اللي في وضع الضيف بتتحفظ كـ «خريطة كاملة» في مفتاح واحد
const _localCollectionKeys = {
  'tasks': 'local_tasks',
  'habits': 'local_habits',
  'transactions': 'local_transactions',
  'journal': 'local_journal',
};

typedef BackupDoc = ({String collection, String id, Map<String, dynamic> data});

/// بيحوّل ملف التصدير (من حساب أو من وضع الضيف) لقايمة مستندات موحّدة
List<BackupDoc> parseBackup(String jsonText) {
  final root = jsonDecode(jsonText);
  if (root is! Map || root['app'] != 'hayati') {
    throw const FormatException('الملف ده مش نسخة احتياطية من «حياتي»');
  }
  final docs = <BackupDoc>[];
  // شكل الحساب: {tasks: {id: {...}}, prayers: {day: {...}}, ...}
  for (final c in userCollections) {
    final m = root[c];
    if (m is Map) {
      for (final e in m.entries) {
        if (e.value is Map) {
          docs.add((
            collection: c,
            id: '${e.key}',
            data: (e.value as Map).cast<String, dynamic>(),
          ));
        }
      }
    }
  }
  // شكل وضع الضيف: {local_tasks: {...}, 'store/prayers/2026-11-23': {...}}
  for (final e in _localCollectionKeys.entries) {
    final m = root[e.value];
    if (m is Map) {
      for (final item in m.entries) {
        if (item.value is Map) {
          docs.add((
            collection: e.key,
            id: '${item.key}',
            data: (item.value as Map).cast<String, dynamic>(),
          ));
        }
      }
    }
  }
  for (final e in root.entries) {
    final k = '${e.key}';
    if (!k.startsWith('store/') || e.value is! Map) continue;
    final parts = k.split('/');
    if (parts.length == 3) {
      docs.add((
        collection: parts[1],
        id: parts[2],
        data: (e.value as Map).cast<String, dynamic>(),
      ));
    }
  }
  return docs;
}

/// بيكتب المستندات في الحساب أو على الجهاز (بيدمج مع الموجود ومش بيمسح حاجة)
Future<int> applyBackup(
  List<BackupDoc> docs,
  Session session,
  SharedPreferences prefs,
) async {
  if (session is UserSession) {
    final user = FirebaseFirestore.instance
        .collection('users')
        .doc(session.uid);
    var batch = FirebaseFirestore.instance.batch();
    var ops = 0;
    for (final d in docs) {
      batch.set(
        user.collection(d.collection).doc(d.id),
        d.data,
        SetOptions(merge: true),
      );
      if (++ops >= 400) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    return docs.length;
  }
  final store = LocalUserStore(prefs);
  final grouped = <String, Map<String, dynamic>>{};
  for (final d in docs) {
    final key = _localCollectionKeys[d.collection];
    if (key != null) {
      grouped.putIfAbsent(key, () {
        final raw = prefs.getString(key);
        return raw == null
            ? <String, dynamic>{}
            : (jsonDecode(raw) as Map).cast<String, dynamic>();
      })[d.id] = d.data;
    } else {
      await store.merge(d.collection, d.id, d.data);
    }
  }
  for (final e in grouped.entries) {
    await prefs.setString(e.key, jsonEncode(e.value));
  }
  return docs.length;
}

/// يختار ملف ويسترجع منه. بيرجّع عدد العناصر أو null لو المستخدم لغى.
Future<int?> pickAndRestore(WidgetRef ref) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (files.isEmpty) return null;
  final text = utf8.decode(await files.first.readAsBytes());
  final docs = parseBackup(text);
  return applyBackup(
    docs,
    ref.read(sessionProvider),
    ref.read(sharedPrefsProvider),
  );
}
