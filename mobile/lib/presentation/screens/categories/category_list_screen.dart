import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/category_model.dart';
import '../../../providers/category_provider.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_card.dart';
import '../../widgets/common/grivi_icon_badge.dart';
import '../../widgets/common/grivi_motion.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kategori'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(text: 'Pengeluaran'),
              Tab(text: 'Pemasukan'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.categoryNew),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          icon: const Icon(Icons.add),
          label: const Text('Tambah'),
        ),
        body: GriviAsyncView<List<CategoryModel>>(
          value: categories,
          onRetry: () => ref.invalidate(categoriesProvider),
          builder: (data) => TabBarView(
            children: [
              _CategoryTab(items: data.where((c) => c.type == TxType.expense).toList()),
              _CategoryTab(items: data.where((c) => c.type == TxType.income).toList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({required this.items});

  final List<CategoryModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const GriviEmptyView(
        icon: Icons.category_outlined,
        title: 'Belum ada kategori',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final category = items[index];
        final color = hexToColor(category.color);

        return GriviFadeIn(
          index: index,
          child: GriviCard(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            // Preset global nggak bisa diedit siapa pun, jadi jangan dibikin
            // keliatan bisa diklik.
            onTap: category.isPreset
                ? null
                : () => context.push(AppRoutes.categoryEdit(category.id)),
            child: Row(
                children: [
                  GriviIconBadge(name: category.icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          category.transactionCount == 0
                              ? 'Belum dipakai'
                              : 'Dipakai di ${category.transactionCount} transaksi',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (category.isPreset)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Bawaan',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
            ),
          ),
        );
      },
    );
  }
}
