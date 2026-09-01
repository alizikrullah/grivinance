import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/categories/category_form_screen.dart';
import '../../presentation/screens/categories/category_list_screen.dart';
import '../../presentation/screens/home_shell.dart';
import '../../presentation/screens/transactions/transaction_detail_screen.dart';
import '../../presentation/screens/transactions/transaction_form_screen.dart';
import '../../presentation/screens/wallets/wallet_form_screen.dart';
import '../../presentation/screens/wallets/wallet_list_screen.dart';
import '../../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';

  static const String wallets = '/wallets';
  static const String walletNew = '/wallets/new';
  static String walletEdit(String id) => '/wallets/$id/edit';

  static const String categories = '/categories';
  static const String categoryNew = '/categories/new';
  static String categoryEdit(String id) => '/categories/$id/edit';

  static const String transactionNew = '/transactions/new';
  static String transactionDetail(String id) => '/transactions/$id';
  static String transactionEdit(String id) => '/transactions/$id/edit';
}

/// Tab yang lagi aktif di HomeShell. Dipisah jadi provider supaya layar lain
/// (misal tombol "Semua" di dashboard) bisa pindah tab tanpa push layar kedua.
final homeTabProvider = StateProvider<int>((ref) => 0);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: ref.watch(authRouterNotifierProvider),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;

      // Masih nanya /me ke server. Tahan di splash, jangan tebak-tebakan.
      if (auth.isLoading) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final loggedIn = auth.value != null;
      final onAuthScreen =
          location == AppRoutes.login || location == AppRoutes.register;

      if (!loggedIn) return onAuthScreen ? null : AppRoutes.login;
      if (onAuthScreen || location == AppRoutes.splash) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const _SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeShell()),

      GoRoute(path: AppRoutes.wallets, builder: (_, _) => const WalletListScreen()),
      GoRoute(path: AppRoutes.walletNew, builder: (_, _) => const WalletFormScreen()),
      GoRoute(
        path: '/wallets/:id/edit',
        builder: (_, state) => WalletFormScreen(walletId: state.pathParameters['id']),
      ),

      GoRoute(path: AppRoutes.categories, builder: (_, _) => const CategoryListScreen()),
      GoRoute(
        path: AppRoutes.categoryNew,
        builder: (_, _) => const CategoryFormScreen(),
      ),
      GoRoute(
        path: '/categories/:id/edit',
        builder: (_, state) => CategoryFormScreen(categoryId: state.pathParameters['id']),
      ),

      GoRoute(
        path: AppRoutes.transactionNew,
        builder: (_, _) => const TransactionFormScreen(),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        builder: (_, state) =>
            TransactionFormScreen(transactionId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (_, state) =>
            TransactionDetailScreen(transactionId: state.pathParameters['id']!),
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
