import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/course.dart';
import 'backend.dart';

/// Firebase Authentication + Firestore. Data lives in users/{uid}/courses,
/// exactly where the security rules allow it.
class FirebaseBackend implements Backend {
  @override
  final FirebaseAuthService auth = FirebaseAuthService();

  @override
  String get label => 'Cloud (Firebase)';

  @override
  bool get isCloud => true;

  @override
  CourseRepository coursesFor(String uid) => FirestoreCourseRepository(
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('courses'),
  );
}

class FirebaseAuthService implements AuthService {
  final _auth = FirebaseAuth.instance;

  AppUser? _toAppUser(User? user) =>
      user == null ? null : AppUser(uid: user.uid, email: user.email);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAppUser);

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class FirestoreCourseRepository implements CourseRepository {
  FirestoreCourseRepository(this._courses);

  final CollectionReference<Map<String, dynamic>> _courses;

  @override
  Stream<List<Course>> watchCourses() => _courses
      .orderBy('start')
      .snapshots()
      .map((s) => s.docs.map((d) => Course.fromMap(d.id, d.data())).toList());

  @override
  Future<void> add(Course course) => _courses.add({
    ...course.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> addAll(List<Course> courses) {
    final batch = FirebaseFirestore.instance.batch();
    for (final c in courses) {
      batch.set(_courses.doc(), {
        ...c.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  @override
  Future<void> update(Course course) =>
      _courses.doc(course.id).update(course.toMap());

  @override
  Future<void> delete(String id) => _courses.doc(id).delete();

  @override
  Future<void> restore(Course course) => _courses.doc(course.id).set({
    ...course.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });
}
