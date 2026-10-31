import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_week/backend/local_backend.dart';
import 'package:my_week/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = await LocalBackend.create();
  });

  testWidgets('empty form shows both validation messages', (tester) async {
    await tester.pumpWidget(MyWeekApp(backend: backend));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('At least 6 characters'), findsOneWidget);
  });

  testWidgets('create account → samples → delete → undo → log out', (
    tester,
  ) async {
    await tester.pumpWidget(MyWeekApp(backend: backend));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'aline@gmail.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret1',
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // The week screen with the sample data and computed values.
    expect(find.text('My Week'), findsOneWidget);
    expect(find.text('11h'), findsOneWidget); // total of the samples
    expect(find.text('1 clash in your week'), findsOneWidget);
    expect(find.text('Algorithms'), findsOneWidget);

    // Long-press → confirm → gone, and the clash disappears.
    await tester.longPress(find.text('Databases'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Databases'), findsNothing);
    expect(find.text('1 clash in your week'), findsNothing);
    expect(find.text('9h 30m'), findsOneWidget);

    // Undo writes it back.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Databases'), findsOneWidget);
    expect(find.text('11h'), findsOneWidget);

    // Log out → back to the login screen.
    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('wrong password shows a clear message', (tester) async {
    await backend.auth.createAccount(email: 'a@b.co', password: 'secret1');
    await backend.auth.signOut();

    await tester.pumpWidget(MyWeekApp(backend: backend));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.co',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'nottheone',
    );
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong email or password.'), findsOneWidget);
  });
}
