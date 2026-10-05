import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/gamification_model.dart';
import '../../../providers/gamification_provider.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_card.dart';
import '../../widgets/common/grivi_motion.dart';
import '../../widgets/gamification/gamification_widgets.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gamificationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lencana')),
      body: GriviAsyncView<GamificationState>(
        value: state,
        onRetry: () => ref.invalidate(gamificationProvider),
        builder: (game) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverToBoxAdapter(
                child: GriviFadeIn(
                  child: GriviCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LevelProgress(state: game),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _Stat(label: 'Total XP', value: '${game.xp}'),
                            _Stat(
                              label: 'Lencana',
                              value: '${game.unlockedCount}/${game.achievements.length}',
                            ),
                            _Stat(label: 'Streak terpanjang', value: '${game.longestStreak} hari'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemCount: game.achievements.length,
                itemBuilder: (context, index) => GriviFadeIn(
                  index: index + 1,
                  child: AchievementTile(achievement: game.achievements[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
        ],
      ),
    );
  }
}
