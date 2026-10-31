/// One course in the week. Only the facts the user typed are stored:
/// hours per day, totals and clashes are always computed (see week_stats.dart).
class Course {
  const Course({
    this.id = '',
    required this.name,
    required this.day,
    required this.start,
    required this.end,
  });

  /// Document id. Empty for a course that has not been saved yet.
  final String id;
  final String name;

  /// 1 = Monday ... 7 = Sunday (same as DateTime.weekday).
  final int day;

  /// Minutes since midnight, e.g. 8:30 = 510.
  final int start;
  final int end;

  int get minutes => end - start;

  bool overlaps(Course other) =>
      day == other.day && start < other.end && other.start < end;

  Map<String, dynamic> toMap() => {
    'name': name,
    'day': day,
    'start': start,
    'end': end,
  };

  factory Course.fromMap(String id, Map<String, dynamic> data) => Course(
    id: id,
    name: data['name'] as String,
    day: (data['day'] as num).toInt(),
    start: (data['start'] as num).toInt(),
    end: (data['end'] as num).toInt(),
  );

  Course copyWith({String? id, String? name, int? day, int? start, int? end}) =>
      Course(
        id: id ?? this.id,
        name: name ?? this.name,
        day: day ?? this.day,
        start: start ?? this.start,
        end: end ?? this.end,
      );

  @override
  bool operator ==(Object other) =>
      other is Course &&
      other.id == id &&
      other.name == name &&
      other.day == day &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(id, name, day, start, end);

  @override
  String toString() =>
      'Course($name, ${dayNames[day - 1]} ${formatTime(start)}-${formatTime(end)})';
}

const dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// 510 -> "08:30"
String formatTime(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// 90 -> "1h 30m", 120 -> "2h", 45 -> "45m"
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}
