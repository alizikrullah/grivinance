import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/gamification_model.dart';
import '../../providers/gamification_provider.dart';
import '../widgets/common/grivi_bottom_nav.dart';
import '../widgets/gamification/gamification_widgets.dart';
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

    // Lencana baru dan naik level dirayakan di sini, satu tempat untuk semua
    // tab — lencana bisa kebuka dari mana saja (catat transaksi, atur budget).
    ref.listen<AsyncValue<GamificationState>>(gamificationProvider, (previous, next) {
      final state = next.valueOrNull;
      // Waktu disegarkan, provider sempat membawa data lama; jangan rayakan dua kali.
      if (next.isLoading || state == null || identical(previous?.valueOrNull, state)) return;

      showUnlockCelebration(context, state.freshAchievements);

      final before = previous?.valueOrNull?.level;
      if (before != null && state.level > before) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Naik ke Lv. ${state.level} — ${state.title}!')),
        );
      }
    });

    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: GriviBottomNav(
        index: index,
        onChanged: (i) => ref.read(homeTabProvider.notifier).state = i,
        onAdd: () => context.push(AppRoutes.transactionNew),
      ),
    );
  }
}
