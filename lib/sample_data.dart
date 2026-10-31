import 'models/course.dart';

/// Written once for every new account. Monday has a clash on purpose,
/// so the clash warning can be seen straight away.
const sampleCourses = [
  Course(name: 'Mobile Programming', day: 1, start: 8 * 60, end: 10 * 60),
  Course(name: 'Databases', day: 1, start: 9 * 60 + 30, end: 11 * 60),
  Course(name: 'Algorithms', day: 2, start: 10 * 60, end: 12 * 60),
  Course(name: 'Mobile Programming lab', day: 3, start: 14 * 60, end: 17 * 60),
  Course(name: 'English', day: 4, start: 8 * 60, end: 9 * 60),
  Course(name: 'Project meeting', day: 5, start: 13 * 60, end: 14 * 60 + 30),
];
