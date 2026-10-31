import 'course.dart';

/// Everything computed from the saved courses. Never stored: it is rebuilt
/// every time the list arrives, so it can never disagree with the data.
class WeekStats {
  WeekStats(List<Course> courses)
    : courses = [...courses]
        ..sort((a, b) {
          final byDay = a.day.compareTo(b.day);
          return byDay != 0 ? byDay : a.start.compareTo(b.start);
        });

  /// Sorted by day, then start time.
  final List<Course> courses;

  /// Courses grouped by day (1 = Monday), each list ordered by start time.
  late final Map<int, List<Course>> byDay = () {
    final map = <int, List<Course>>{};
    for (final c in courses) {
      (map[c.day] ??= []).add(c);
    }
    return map;
  }();

  /// Days that have at least one course, Monday first.
  List<int> get activeDays => byDay.keys.toList()..sort();

  int minutesOn(int day) =>
      (byDay[day] ?? const []).fold(0, (total, c) => total + c.minutes);

  int get totalMinutes => courses.fold(0, (total, c) => total + c.minutes);

  /// The day with the most scheduled time, or null if the week is empty.
  int? get busiestDay {
    int? best;
    for (final day in activeDays) {
      if (best == null || minutesOn(day) > minutesOn(best)) best = day;
    }
    return best;
  }

  /// Every pair of courses that overlap on the same day.
  late final List<(Course, Course)> clashes = () {
    final result = <(Course, Course)>[];
    for (final dayCourses in byDay.values) {
      for (var i = 0; i < dayCourses.length; i++) {
        for (var j = i + 1; j < dayCourses.length; j++) {
          if (dayCourses[i].overlaps(dayCourses[j])) {
            result.add((dayCourses[i], dayCourses[j]));
          }
        }
      }
    }
    return result;
  }();

  /// The other courses [course] overlaps with (works for unsaved courses too).
  List<Course> clashesWith(Course course) => courses
      .where((c) => c.id != course.id || course.id.isEmpty)
      .where((c) => c.overlaps(course))
      .toList();
}
