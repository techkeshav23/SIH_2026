import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/market/market_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/product/product_detail_screen.dart';
import '../features/studio/create_product_screen.dart';

GoRouter buildRouter(Api api) {
  return GoRouter(
    initialLocation: api.isLoggedIn ? '/home' : '/login',
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/create', builder: (c, s) => const CreateProductScreen()),
      GoRoute(path: '/market', builder: (c, s) => const MarketScreen()),
      GoRoute(path: '/orders', builder: (c, s) => const OrdersScreen()),
      GoRoute(
        path: '/product/:id',
        builder: (c, s) => ProductDetailScreen(productId: s.pathParameters['id']!),
      ),
    ],
  );
}
