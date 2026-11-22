import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/user_store.dart';

enum OccasionType { birthday, anniversary, other }

extension OccasionTypeAr on OccasionType {
  String get ar => const {
    OccasionType.birthday: 'عيد ميلاد',
    OccasionType.anniversary: 'ذكرى سنوية',
    OccasionType.other: 'مناسبة',
  }[this]!;
  String get emoji => const {
    OccasionType.birthday: '🎂',
    OccasionType.anniversary: '💍',
    OccasionType.other: '🎉',
  }[this]!;
}

/// مناسبة سنوية بتاريخ ميلادي
class Occasion {
  const Occasion({
    required this.id,
    required this.title,
    required this.type,
    required this.month,
    required this.day,
    this.year,
    this.remindDaysBefore = 1,
  });

  final String id;
  final String title;
  final OccasionType type;
  final int month;
  final int day;

  /// سنة البداية (لحساب العمر أو عدد السنين) — اختياري
  final int? year;
  final int remindDaysBefore;

  DateTime nextDate(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    var d = DateTime(today.year, month, day);
    if (d.isBefore(today)) d = DateTime(today.year + 1, month, day);
    return d;
  }

  int daysUntil(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    return nextDate(from).difference(today).inDays;
  }

  /// العمر/عدد السنين في المرة الجاية
  int? yearsAtNext(DateTime from) =>
      year == null ? null : nextDate(from).year - year!;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'type': type.name,
    'month': month,
    'day': day,
    'year': year,
    'remindDaysBefore': remindDaysBefore,
  };

  factory Occasion.fromMap(Map<String, dynamic> m) => Occasion(
    id: m['id'] as String,
    title: (m['title'] as String?) ?? '',
    type: OccasionType.values.firstWhere(
      (t) => t.name == m['type'],
      orElse: () => OccasionType.other,
    ),
    month: (m['month'] as num).toInt(),
    day: (m['day'] as num).toInt(),
    year: (m['year'] as num?)?.toInt(),
    remindDaysBefore: (m['remindDaysBefore'] as num?)?.toInt() ?? 1,
  );
}

/// شخص عايز تفضل على تواصل معاه (صلة الرحم)
class Person {
  const Person({
    required this.id,
    required this.name,
    this.relation = '',
    this.everyDays = 14,
    this.lastContact,
  });

  final String id;
  final String name;
  final String relation;

  /// كل كام يوم تحب تكلمه
  final int everyDays;
  final DateTime? lastContact;

  int daysSince(DateTime now) =>
      lastContact == null ? 9999 : now.difference(lastContact!).inDays;

  bool isDue(DateTime now) => daysSince(now) >= everyDays;

  Person contactedNow() => Person(
    id: id,
    name: name,
    relation: relation,
    everyDays: everyDays,
    lastContact: DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'relation': relation,
    'everyDays': everyDays,
    'lastContact': lastContact?.millisecondsSinceEpoch,
  };

  factory Person.fromMap(Map<String, dynamic> m) {
    final lc = m['lastContact'];
    return Person(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      relation: (m['relation'] as String?) ?? '',
      everyDays: (m['everyDays'] as num?)?.toInt() ?? 14,
      lastContact: lc is int ? DateTime.fromMillisecondsSinceEpoch(lc) : null,
    );
  }
}

/// users/{uid}/family/occasions => {items: [...]}
final occasionsProvider = StreamProvider<List<Occasion>>((ref) {
  return ref.watch(userStoreProvider).watch('family', 'occasions').map((d) {
    final items = (d?['items'] as List?) ?? const [];
    final list = items
        .map((e) => Occasion.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
    final now = DateTime.now();
    return list..sort((a, b) => a.daysUntil(now).compareTo(b.daysUntil(now)));
  });
});

/// users/{uid}/family/people => {items: [...]}
final peopleProvider = StreamProvider<List<Person>>((ref) {
  return ref.watch(userStoreProvider).watch('family', 'people').map((d) {
    final items = (d?['items'] as List?) ?? const [];
    final list = items
        .map((e) => Person.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
    final now = DateTime.now();
    return list..sort(
      (a, b) => (b.daysSince(now) - b.everyDays).compareTo(
        a.daysSince(now) - a.everyDays,
      ),
    );
  });
});

Future<void> saveOccasions(WidgetRef ref, List<Occasion> list) =>
    ref.read(userStoreProvider).merge('family', 'occasions', {
      'items': list.map((o) => o.toMap()).toList(),
    });

Future<void> savePeople(WidgetRef ref, List<Person> list) => ref
    .read(userStoreProvider)
    .merge('family', 'people', {'items': list.map((p) => p.toMap()).toList()});
