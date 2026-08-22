import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../features/auth/login_screen.dart';
import '../features/buyer/buyer_home_screen.dart';
import '../features/buyer/buyer_product_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/home/home_screen.dart';
import '../features/market/market_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/product/product_detail_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/studio/create_product_screen.dart';

GoRouter buildRouter(Api api) {
  final start = !api.isLoggedIn ? '/login' : (api.isBuyer ? '/buyer/home' : '/home');
  return GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/create', builder: (c, s) => const CreateProductScreen()),
      GoRoute(path: '/market', builder: (c, s) => const MarketScreen()),
      GoRoute(path: '/orders', builder: (c, s) => const OrdersScreen()),
      GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/buyer/home', builder: (c, s) => const BuyerHomeScreen()),
      GoRoute(
        path: '/buyer/product',
        builder: (c, s) => BuyerProductScreen(product: s.extra as Product),
      ),
      GoRoute(
        path: '/order-detail',
        builder: (c, s) => OrderDetailScreen(order: s.extra as Order),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (c, s) => ProductDetailScreen(productId: s.pathParameters['id']!),
      ),
    ],
  );
}
