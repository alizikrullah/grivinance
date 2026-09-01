import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common/grivi_bottom_nav.dart';
import 'account/account_screen.dart';
import 'charts/chart_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'transactions/transaction_list_screen.dart';

/// Empat tab utama ditahan di IndexedStack supaya scroll position dan state
/// tiap tab nggak ke-reset waktu pindah. Form dan detail di-push di atasnya.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const List<Widget> _tabs = [
    DashboardScreen(),
    TransactionListScreen(),
    ChartScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: GriviBottomNav(
        index: index,
        onChanged: (i) => ref.read(homeTabProvider.notifier).state = i,
      ),
      // Tab grafik nggak perlu tombol tambah, dan FAB-nya nutupin legend.
      floatingActionButton: index == 2
          ? null
          : FloatingActionButton(
              onPressed: () => context.push(AppRoutes.transactionNew),
              backgroundColor: AppColors.primary,
              foregroundColor: const Color(0xFF04231A),
              child: const Icon(Icons.add),
            ),
    );
  }
}
