import 'package:flutter_test/flutter_test.dart';
import 'package:my_week/models/course.dart';
import 'package:my_week/models/week_stats.dart';
import 'package:my_week/sample_data.dart';

Course c(String id, int day, int start, int end) =>
    Course(id: id, name: id, day: day, start: start, end: end);

void main() {
  test('formatting', () {
    expect(formatTime(510), '08:30');
    expect(formatDuration(90), '1h 30m');
    expect(formatDuration(120), '2h');
    expect(formatDuration(45), '45m');
  });

  test('hours per day and per week', () {
    final stats = WeekStats([
      c('a', 1, 480, 600), // Mon 2h
      c('b', 1, 660, 690), // Mon 30m
      c('c', 3, 600, 660), // Wed 1h
    ]);
    expect(stats.minutesOn(1), 150);
    expect(stats.minutesOn(2), 0);
    expect(stats.totalMinutes, 210);
    expect(stats.activeDays, [1, 3]);
    expect(stats.busiestDay, 1);
  });

  test('courses are grouped by day and sorted by start', () {
    final stats = WeekStats([c('late', 2, 900, 960), c('early', 2, 480, 540)]);
    expect(stats.byDay[2]!.map((x) => x.id), ['early', 'late']);
  });

  test('clashes: overlap on the same day only, touching is fine', () {
    final stats = WeekStats([
      c('a', 1, 480, 600),
      c('b', 1, 570, 660), // overlaps a
      c('c', 1, 660, 720), // starts exactly when b ends: no clash
      c('d', 2, 480, 600), // same time as a, other day: no clash
    ]);
    expect(stats.clashes.length, 1);
    expect(stats.clashes.single.$1.id, 'a');
    expect(stats.clashes.single.$2.id, 'b');
    expect(stats.clashesWith(stats.courses.first).map((x) => x.id), ['b']);
    // An unsaved course (empty id) is checked against everything.
    expect(stats.clashesWith(c('', 2, 500, 520)).map((x) => x.id), ['d']);
  });

  test('sample data has exactly one clash, on Monday', () {
    final stats = WeekStats([
      for (var i = 0; i < sampleCourses.length; i++)
        sampleCourses[i].copyWith(id: '$i'),
    ]);
    expect(stats.clashes.length, 1);
    expect(stats.clashes.single.$1.day, 1);
  });

  test('toMap / fromMap round trip', () {
    final course = c('x', 4, 510, 600);
    expect(Course.fromMap('x', course.toMap()), course);
  });
}
