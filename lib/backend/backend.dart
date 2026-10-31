import '../models/course.dart';

/// The rest of the app only knows these interfaces. Whether the data lives on
/// this device (LocalBackend) or in Firebase (FirebaseBackend) is decided once,
/// at startup, in select_backend.dart.
abstract class Backend {
  /// Shown to the user, e.g. "Cloud (Firebase)".
  String get label;

  /// True when data is synced to a server.
  bool get isCloud;

  AuthService get auth;

  /// The courses of one user: users/{uid}/courses.
  CourseRepository coursesFor(String uid);
}

class AppUser {
  const AppUser({required this.uid, this.email});
  final String uid;
  final String? email;
}

/// Thrown by every AuthService. [code] uses Firebase's codes
/// (email-already-in-use, invalid-credential, weak-password, ...),
/// so the login screen handles both backends the same way.
class AuthException implements Exception {
  const AuthException(this.code);
  final String code;

  @override
  String toString() => 'AuthException($code)';
}

abstract class AuthService {
  /// The current user now, and again every time someone logs in or out.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<void> signIn({required String email, required String password});

  /// Creates the account and logs the user in.
  Future<void> createAccount({required String email, required String password});

  Future<void> signOut();
}

abstract class CourseRepository {
  /// All courses, ordered by start time, now and after every change.
  Stream<List<Course>> watchCourses();

  Future<void> add(Course course);

  /// Saves changes to an existing course (uses [Course.id]).
  Future<void> update(Course course);

  Future<void> delete(String id);

  /// Writes a deleted course back with its old id (undo).
  Future<void> restore(Course course);

  /// Writes several courses at once: all of them, or none.
  Future<void> addAll(List<Course> courses);
}
