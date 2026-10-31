import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import 'backend.dart';

/// Works with no server at all: accounts and courses are kept on this device
/// with shared_preferences. Each account still only sees its own courses.
class LocalBackend implements Backend {
  LocalBackend._(this._prefs) : auth = LocalAuthService(_prefs);

  static Future<LocalBackend> create() async =>
      LocalBackend._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  final Map<String, LocalCourseRepository> _repos = {};

  @override
  final LocalAuthService auth;

  @override
  String get label => 'On this device';

  @override
  bool get isCloud => false;

  @override
  CourseRepository coursesFor(String uid) =>
      _repos[uid] ??= LocalCourseRepository(_prefs, uid);
}

final _random = Random.secure();

/// A stream that gives [current] as soon as someone listens, then every value
/// of [changes]. Like Firebase's streams: the value now, then each change.
Stream<T> _startWithThen<T>(T Function() current, Stream<T> changes) {
  late final StreamController<T> controller;
  StreamSubscription<T>? sub;
  controller = StreamController<T>(
    onListen: () {
      controller.add(current());
      sub = changes.listen(controller.add, onError: controller.addError);
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () => sub?.cancel(),
  );
  return controller.stream;
}

String _newId([int length = 20]) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(
    length,
    (_) => chars[_random.nextInt(chars.length)],
  ).join();
}

class LocalAuthService implements AuthService {
  LocalAuthService(this._prefs) {
    final uid = _prefs.getString(_sessionKey);
    if (uid != null) {
      final entry = _accounts().entries.where((e) => e.value['uid'] == uid);
      if (entry.isNotEmpty) {
        _current = AppUser(uid: uid, email: entry.first.key);
      }
    }
  }

  static const _accountsKey = 'local_accounts';
  static const _sessionKey = 'local_session_uid';

  final SharedPreferences _prefs;
  final _changes = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() =>
      _startWithThen(() => _current, _changes.stream.map((u) => u));

  /// email -> {uid, salt, hash}
  Map<String, Map<String, dynamic>> _accounts() {
    final raw = _prefs.getString(_accountsKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as Map<String, dynamic>),
    );
  }

  String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  Future<void> _setCurrent(AppUser? user) async {
    _current = user;
    if (user == null) {
      await _prefs.remove(_sessionKey);
    } else {
      await _prefs.setString(_sessionKey, user.uid);
    }
    _changes.add(user);
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    if (password.length < 6) throw const AuthException('weak-password');
    final accounts = _accounts();
    if (accounts.containsKey(key)) {
      throw const AuthException('email-already-in-use');
    }
    final salt = _newId(16);
    final uid = _newId(28);
    accounts[key] = {'uid': uid, 'salt': salt, 'hash': _hash(password, salt)};
    await _prefs.setString(_accountsKey, jsonEncode(accounts));
    await _setCurrent(AppUser(uid: uid, email: key));
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final key = email.trim().toLowerCase();
    final account = _accounts()[key];
    if (account == null ||
        account['hash'] != _hash(password, account['salt'] as String)) {
      throw const AuthException('invalid-credential');
    }
    await _setCurrent(AppUser(uid: account['uid'] as String, email: key));
  }

  @override
  Future<void> signOut() => _setCurrent(null);
}

class LocalCourseRepository implements CourseRepository {
  LocalCourseRepository(this._prefs, String uid) : _key = 'courses_$uid';

  final SharedPreferences _prefs;
  final String _key;
  final _changes = StreamController<void>.broadcast();

  List<Course> _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map((m) => Course.fromMap(m['id'] as String, m))
        .toList();
    return list..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<void> _save(List<Course> courses) async {
    await _prefs.setString(
      _key,
      jsonEncode([
        for (final c in courses) {'id': c.id, ...c.toMap()},
      ]),
    );
    _changes.add(null);
  }

  @override
  Stream<List<Course>> watchCourses() =>
      _startWithThen(_load, _changes.stream.map((_) => _load()));

  @override
  Future<void> add(Course course) =>
      _save([..._load(), course.copyWith(id: _newId())]);

  @override
  Future<void> addAll(List<Course> courses) =>
      _save([..._load(), for (final c in courses) c.copyWith(id: _newId())]);

  @override
  Future<void> update(Course course) {
    final courses = _load();
    final i = courses.indexWhere((c) => c.id == course.id);
    if (i == -1) throw StateError('No course with id ${course.id}');
    courses[i] = course;
    return _save(courses);
  }

  @override
  Future<void> delete(String id) =>
      _save(_load()..removeWhere((c) => c.id == id));

  @override
  Future<void> restore(Course course) =>
      _save([..._load()..removeWhere((c) => c.id == course.id), course]);
}
