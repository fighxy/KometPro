import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final vault = <String, String>{};

  setUp(() {
    vault.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
          final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
          final key = args['key'] as String?;
          switch (call.method) {
            case 'write':
              vault[key!] = args['value'] as String;
              return null;
            case 'read':
              return vault[key];
            case 'delete':
              vault.remove(key);
              return null;
            case 'readAll':
              return Map<String, String>.from(vault);
            default:
              return null;
          }
        });
  });

  test('the active account goes to the head of the order', () async {
    await TokenStorage.setActiveAccount(11);
    await TokenStorage.setActiveAccount(22);
    await TokenStorage.setActiveAccount(33);

    expect(await TokenStorage.recentAccountIds(), [33, 22, 11]);
    expect(await TokenStorage.getActiveAccountId(), 33);
  });

  test('switching back moves an account without duplicating it', () async {
    await TokenStorage.setActiveAccount(11);
    await TokenStorage.setActiveAccount(22);
    await TokenStorage.setActiveAccount(11);

    expect(await TokenStorage.recentAccountIds(), [11, 22]);
  });

  test('the previous profile is the entry behind the active one', () async {
    await TokenStorage.setActiveAccount(11);
    await TokenStorage.setActiveAccount(22);

    final order = await TokenStorage.recentAccountIds();
    expect(order.first, await TokenStorage.getActiveAccountId());
    expect(order[1], 11);
  });

  test(
    'deleting the active account leaves the next one to fall back to',
    () async {
      await TokenStorage.saveToken('token-11', 11);
      await TokenStorage.saveToken('token-22', 22);
      await TokenStorage.setActiveAccount(11);
      await TokenStorage.setActiveAccount(22);

      await TokenStorage.deleteAccount(22);

      expect(await TokenStorage.recentAccountIds(), [11]);
      expect(await TokenStorage.getActiveAccountId(), isNull);
      expect(await TokenStorage.readToken(22), isNull);
      expect(await TokenStorage.readToken(11), 'token-11');
    },
  );

  test('deleting an idle account keeps the active pointer', () async {
    await TokenStorage.saveToken('token-11', 11);
    await TokenStorage.saveToken('token-22', 22);
    await TokenStorage.setActiveAccount(11);
    await TokenStorage.setActiveAccount(22);

    await TokenStorage.deleteAccount(11);

    expect(await TokenStorage.recentAccountIds(), [22]);
    expect(await TokenStorage.getActiveAccountId(), 22);
  });
}
