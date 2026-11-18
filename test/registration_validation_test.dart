import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/services/database_service.dart';
import 'package:inventory_manager/core/services/auth_service.dart';
import 'package:inventory_manager/core/db/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppDatabase.forceInMemory = true;

  group('Registration Validation & Non-Destructive Error Handling Tests', () {
    late DatabaseService db;
    late AuthService auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppDatabase.forceInMemory = true;
      db = DatabaseService();
      db.resetForTest();
      await db.ensureInitialized();
      auth = AuthService();
    });

    test('Registration fails fast for short business name ("g") without touching local database', () async {
      expect(
        () async => await auth.signUp(
          'testowner@example.com',
          'Password123!',
          'testowner',
          'Test Owner',
          'g', // Short business name (< 2 chars)
        ),
        throwsA(predicate((e) => e.toString().contains('Business name must be at least 2 characters.'))),
      );

      // Verify no user record was persisted in SQLite
      final cachedUser = await db.getCachedUser();
      expect(cachedUser, isNull);

      final usersInDb = await db.query('users');
      expect(usersInDb, isEmpty);

      // Verify no active user session
      expect(auth.user, isNull);
    });

    test('Registration rejects a username that already exists locally (case-insensitive)', () async {
      await db.saveUserRecord({
        'uid': 'dup-user-1',
        'username': 'TakenName',
        'email': 'taken@example.com',
        'roles': ['admin'],
        'shopId': 'shop-1',
        'isActive': true,
      });

      expect(
        () async => await auth.signUp(
          'newowner@example.com',
          'Password123!',
          'takenname',
          'New Owner',
          'New Shop',
        ),
        throwsA(predicate((e) => e.toString().contains('already taken'))),
      );

      // The conflicting account must remain untouched and no second user added.
      final users = await db.query('users');
      expect(users.length, 1);
      expect(users.first['username'], 'TakenName');
    });

    test('HTTP 422 error detail parsing extracts clean validation message', () {
      const raw422Body = 'HTTP 422: {"detail": [{"type": "string_too_short", "loc": ["body", "business_name"], "msg": "String should have at least 2 characters", "input": "g", "ctx": {"min_length": 2}}]}';
      
      final parsed = auth.parseHttpErrorDetailForTesting(raw422Body);
      expect(parsed, equals('Business name must be at least 2 characters.'));
    });

    test('HTTP 409 error detail parsing extracts conflict message', () {
      const raw409Body = 'HTTP 409: {"detail": "Email already registered"}';
      
      final parsed = auth.parseHttpErrorDetailForTesting(raw409Body);
      expect(parsed, equals('Email already registered'));
    });
  });
}
