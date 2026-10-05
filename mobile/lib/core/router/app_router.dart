import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/category_model.dart';
import '../../presentation/screens/account/achievements_screen.dart';
import '../../presentation/screens/account/profile_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/budgets/budget_screen.dart';
import '../../presentation/screens/categories/category_form_screen.dart';
import '../../presentation/screens/categories/category_list_screen.dart';
import '../../presentation/screens/home_shell.dart';
import '../../presentation/screens/transactions/transaction_detail_screen.dart';
import '../../presentation/screens/transactions/transaction_form_screen.dart';
import '../../presentation/screens/wallets/wallet_detail_screen.dart';
import '../../presentation/screens/wallets/wallet_form_screen.dart';
import '../../presentation/screens/wallets/wallet_list_screen.dart';
import '../../presentation/widgets/common/grivi_button.dart';
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
  static String walletDetail(String id) => '/wallets/$id';
  static String walletEdit(String id) => '/wallets/$id/edit';

  static const String categories = '/categories';
  static const String categoryNew = '/categories/new';
  static String categoryEdit(String id) => '/categories/$id/edit';

  static const String budgets = '/budgets';
  static const String achievements = '/achievements';
  static const String profile = '/profile';

  static const String transactionNew = '/transactions/new';
  static String transactionDetail(String id) => '/transactions/$id';
  static String transactionEdit(String id) => '/transactions/$id/edit';

  /// Form transaksi baru, opsional langsung di tipe/wallet tertentu
  /// (misal "Transfer dari wallet ini" di detail wallet).
  static String newTransaction({TxType? type, String? walletId}) {
    final query = {'type': ?type?.apiValue, 'walletId': ?walletId};
    // Map kosong bikin Uri menempelkan "?" telanjang di ujung path.
    return Uri(path: transactionNew, queryParameters: query.isEmpty ? null : query).toString();
  }
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

      // Masih nanya /me ke server, atau server nggak kejangkau waktu cold
      // start. Tahan di splash — dia yang nampilin tombol coba lagi.
      if (auth.isLoading || auth.hasError) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final loggedIn = auth.valueOrNull != null;
      final onAuthScreen = location == AppRoutes.login || location == AppRoutes.register;

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
      GoRoute(
        path: '/wallets/:id',
        builder: (_, state) => WalletDetailScreen(walletId: state.pathParameters['id']!),
      ),

      GoRoute(path: AppRoutes.categories, builder: (_, _) => const CategoryListScreen()),
      GoRoute(path: AppRoutes.categoryNew, builder: (_, _) => const CategoryFormScreen()),
      GoRoute(
        path: '/categories/:id/edit',
        builder: (_, state) => CategoryFormScreen(categoryId: state.pathParameters['id']),
      ),

      GoRoute(path: AppRoutes.budgets, builder: (_, _) => const BudgetScreen()),
      GoRoute(path: AppRoutes.achievements, builder: (_, _) => const AchievementsScreen()),
      GoRoute(path: AppRoutes.profile, builder: (_, _) => const ProfileScreen()),

      GoRoute(
        path: AppRoutes.transactionNew,
        builder: (_, state) => TransactionFormScreen(
          initialType: state.uri.queryParameters['type'] == null
              ? null
              : TxType.fromApi(state.uri.queryParameters['type']!),
          initialWalletId: state.uri.queryParameters['walletId'],
        ),
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

class _SplashScreen extends ConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: auth.hasError
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'Tidak bisa terhubung',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Cek koneksi internet kamu. Sesi kamu tetap aman, '
                      'nggak perlu login ulang.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: 180,
                      child: GriviButton(
                        label: 'Coba lagi',
                        icon: Icons.refresh,
                        onPressed: () => ref.read(authProvider.notifier).retry(),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
