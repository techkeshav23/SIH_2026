import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/studio/create_product_screen.dart';

GoRouter buildRouter(Api api) {
  return GoRouter(
    initialLocation: api.isLoggedIn ? '/home' : '/login',
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(
        path: '/create',
        builder: (c, s) => const CreateProductScreen(),
      ),
    ],
  );
}
