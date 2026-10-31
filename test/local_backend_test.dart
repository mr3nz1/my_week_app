import 'package:flutter_test/flutter_test.dart';
import 'package:my_week/backend/backend.dart';
import 'package:my_week/backend/local_backend.dart';
import 'package:my_week/models/course.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = await LocalBackend.create();
  });

  group('auth', () {
    test('create account, log out, log in again', () async {
      final auth = backend.auth;
      expect(auth.currentUser, isNull);

      await auth.createAccount(email: 'Aline@Gmail.com ', password: 'secret1');
      final uid = auth.currentUser!.uid;
      expect(auth.currentUser!.email, 'aline@gmail.com');

      await auth.signOut();
      expect(auth.currentUser, isNull);

      await auth.signIn(email: 'aline@gmail.com', password: 'secret1');
      expect(auth.currentUser!.uid, uid);
    });

    test('errors use Firebase codes', () async {
      final auth = backend.auth;
      await expectLater(
        auth.createAccount(email: 'a@b.co', password: '123'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'weak-password'),
        ),
      );

      await auth.createAccount(email: 'a@b.co', password: 'secret1');
      await expectLater(
        auth.createAccount(email: 'a@b.co', password: 'secret1'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'email-already-in-use',
          ),
        ),
      );

      await auth.signOut();
      await expectLater(
        auth.signIn(email: 'a@b.co', password: 'wrong!!'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'invalid-credential',
          ),
        ),
      );
    });

    test('the session survives an app restart', () async {
      await backend.auth.createAccount(email: 'a@b.co', password: 'secret1');
      final uid = backend.auth.currentUser!.uid;

      final restarted = await LocalBackend.create();
      expect(restarted.auth.currentUser?.uid, uid);
    });

    test(
      'authStateChanges gives the current user, then every change',
      () async {
        final events = <String?>[];
        final sub = backend.auth.authStateChanges().listen(
          (u) => events.add(u?.email),
        );
        await pumpEventQueue();
        await backend.auth.createAccount(email: 'a@b.co', password: 'secret1');
        await backend.auth.signOut();
        await pumpEventQueue();
        expect(events, [null, 'a@b.co', null]);
        await sub.cancel();
      },
    );
  });

  group('courses', () {
    const course = Course(name: 'Algorithms', day: 2, start: 600, end: 720);

    test('add, update, delete and undo, all seen live', () async {
      final repo = backend.coursesFor('user1');
      final seen = <List<Course>>[];
      final sub = repo.watchCourses().listen(seen.add);
      await pumpEventQueue();

      await repo.add(course);
      await pumpEventQueue();
      final saved = seen.last.single;
      expect(saved.id, isNotEmpty);
      expect(saved.name, 'Algorithms');

      await repo.update(saved.copyWith(name: 'Algorithms II'));
      await pumpEventQueue();
      expect(seen.last.single.name, 'Algorithms II');

      final before = seen.last.single;
      await repo.delete(before.id);
      await pumpEventQueue();
      expect(seen.last, isEmpty);

      await repo.restore(before);
      await pumpEventQueue();
      expect(seen.last.single, before);

      expect(seen.first, isEmpty); // the empty state came first
      await sub.cancel();
    });

    test('ordered by start time', () async {
      final repo = backend.coursesFor('user1');
      await repo.addAll(const [
        Course(name: 'late', day: 1, start: 900, end: 960),
        Course(name: 'early', day: 3, start: 480, end: 540),
      ]);
      final list = await repo.watchCourses().first;
      expect(list.map((c) => c.name), ['early', 'late']);
    });

    test('each user only sees their own courses', () async {
      await backend.coursesFor('user1').add(course);
      expect(
        await backend.coursesFor('user1').watchCourses().first,
        hasLength(1),
      );
      expect(await backend.coursesFor('user2').watchCourses().first, isEmpty);
    });
  });
}
