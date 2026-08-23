import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalasetu/data/api.dart';
import 'package:kalasetu/data/cart.dart';
import 'package:kalasetu/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('logout()', () {
    test('clears the session but KEEPS device DPDP consent', () async {
      SharedPreferences.setMockInitialValues({
        'token': 'a',
        'refresh_token': 'r',
        'role': 'buyer',
        'demo': false,
        'consent_version': kConsentVersion, // user already agreed on this device
      });
      final api = Api();
      await api.loadToken();
      expect(api.isLoggedIn, isTrue);
      expect(api.consentGiven, isTrue);

      await api.logout();

      // session gone...
      expect(api.isLoggedIn, isFalse);
      expect(api.role, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
      expect(prefs.getString('role'), isNull);

      // ...but consent survives, so re-login won't re-trigger the DPDP gate.
      expect(prefs.getString('consent_version'), kConsentVersion);
      expect(api.consentGiven, isTrue);
    });
  });

  group('cart isolation across accounts', () {
    Product p(String id) =>
        Product(id: id, userId: 'u', titleEn: 'T$id', status: 'listed', finalPrice: 100);

    test('invalidating cartProvider empties the cart (logout leak fix)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      c.read(cartProvider.notifier).add(p('1'));
      c.read(cartProvider.notifier).add(p('2'), qty: 3);
      expect(c.read(cartCountProvider), 4);

      // what the logout handlers now do:
      c.invalidate(cartProvider);

      expect(c.read(cartProvider), isEmpty);
      expect(c.read(cartCountProvider), 0);
    });
  });
}
