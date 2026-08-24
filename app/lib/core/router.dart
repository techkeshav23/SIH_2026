import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../features/auth/login_screen.dart';
import '../features/buyer/addresses_screen.dart';
import '../features/buyer/buyer_home_screen.dart';
import '../features/buyer/buyer_product_screen.dart';
import '../features/buyer/cart_screen.dart';
import '../features/buyer/storefront_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/home/home_screen.dart';
import '../features/legal/consent_screen.dart';
import '../features/legal/privacy_screen.dart';
import '../features/market/market_screen.dart';
import '../features/marketing/marketing_screen.dart';
import '../features/quotes/quotes_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/product/product_detail_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/studio/create_product_screen.dart';
import '../features/voice/kala_screen.dart';

/// Artisan-only sections. A signed-in buyer hitting these is bounced home.
const _artisanOnly = {'/home', '/products', '/create', '/market', '/orders', '/dashboard', '/marketing'};

/// Buyer-only sections (also matched by prefix, e.g. /buyer/product).
bool _isBuyerArea(String path) =>
    path.startsWith('/buyer') || path == '/cart' || path == '/addresses';

GoRouter buildRouter(Api api) {
  final start = !api.isLoggedIn ? '/login' : (api.isBuyer ? '/buyer/home' : '/home');
  return GoRouter(
    initialLocation: start,
    // Re-evaluate guards when the session is force-invalidated (401 -> logout).
    refreshListenable: api.authChanged,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final atLogin = path == '/login';

      // Not signed in -> only the login screen is reachable.
      if (!api.isLoggedIn) return atLogin ? null : '/login';

      // Signed in but on /login -> send to the right home.
      if (atLogin) return api.isBuyer ? '/buyer/home' : '/home';

      // DPDP consent gate: must accept before using the app (privacy page allowed).
      if (!api.consentGiven && path != '/consent' && path != '/privacy') {
        return '/consent';
      }
      // Already consented -> don't linger on the consent screen.
      if (api.consentGiven && path == '/consent') {
        return api.isBuyer ? '/buyer/home' : '/home';
      }

      // Role separation: keep buyers and artisans in their own areas.
      if (api.isBuyer && _artisanOnly.contains(path)) return '/buyer/home';
      if (!api.isBuyer && _isBuyerArea(path)) return '/home';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/consent', builder: (c, s) => const ConsentScreen()),
      GoRoute(path: '/privacy', builder: (c, s) => const PrivacyScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/products', builder: (c, s) => const ProductsScreen()),
      GoRoute(path: '/create', builder: (c, s) => const CreateProductScreen()),
      GoRoute(path: '/market', builder: (c, s) => const MarketScreen()),
      GoRoute(path: '/orders', builder: (c, s) => const OrdersScreen()),
      GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
      GoRoute(path: '/marketing', builder: (c, s) => const MarketingScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/cart', builder: (c, s) => const CartScreen()),
      GoRoute(path: '/addresses', builder: (c, s) => AddressesScreen(selectMode: s.extra == true)),
      GoRoute(
        path: '/storefront/:id',
        builder: (c, s) => StorefrontScreen(artisanId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/kala', builder: (c, s) => const KalaScreen()),
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: '/quotes', builder: (c, s) => const QuotesScreen()),
      GoRoute(path: '/buyer/home', builder: (c, s) => const BuyerHomeScreen()),
      GoRoute(
        path: '/buyer/product',
        // extra can be lost on process-death restoration -> guard the cast.
        builder: (c, s) {
          final p = s.extra;
          return p is Product ? BuyerProductScreen(product: p) : const BuyerHomeScreen();
        },
      ),
      GoRoute(
        path: '/order-detail',
        builder: (c, s) {
          final o = s.extra;
          if (o is Order) return OrderDetailScreen(order: o);
          return api.isBuyer ? const BuyerHomeScreen() : const OrdersScreen();
        },
      ),
      GoRoute(
        path: '/product/:id',
        builder: (c, s) => ProductDetailScreen(productId: s.pathParameters['id']!),
      ),
    ],
  );
}
