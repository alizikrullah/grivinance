import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/gamification_model.dart';
import '../../../providers/gamification_provider.dart';
import '../common/grivi_card.dart';
import '../common/grivi_icon_badge.dart';
import '../common/grivi_motion.dart';

/// Warna khas progres: emas buat XP, streak, dan lencana — beda dari hijau
/// (uang masuk) supaya nggak dibaca sebagai angka keuangan.
const Color _gold = AppColors.warning;

/// "Lv. 4 · Pencatat Rajin" di kartu saldo.
class LevelChip extends StatelessWidget {
  const LevelChip({super.key, required this.state, this.onTap, this.onDark = false});

  final GamificationState state;
  final VoidCallback? onTap;

  /// Di atas kartu hijau, tintanya gelap.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return GriviChip(
      icon: Icons.star_rounded,
      label: 'Lv. ${state.level} · ${state.title}',
      color: onDark ? AppColors.onPrimary : _gold,
      background: onDark ? AppColors.onPrimary.withValues(alpha: 0.12) : null,
      onTap: onTap,
    );
  }
}

/// Chip streak di header Beranda. Redup kalau hari ini belum mencatat.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.state});

  final GamificationState state;

  @override
  Widget build(BuildContext context) {
    final alive = state.recordedToday;
    return GriviChip(
      icon: Icons.local_fire_department,
      label: state.streak == 0 ? 'Mulai streak' : 'Streak ${state.streak} hari',
      color: alive ? _gold : AppColors.textSecondary,
    );
  }
}

/// Level, gelar, dan bar XP ke level berikutnya.
class LevelProgress extends StatelessWidget {
  const LevelProgress({super.key, required this.state});

  final GamificationState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Lv. ${state.level}',
              style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${state.levelXp}/${state.nextLevelXp} XP',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GriviProgressBar(value: state.levelRatio, color: _gold),
      ],
    );
  }
}

/// Kartu misi harian di Beranda: progres tiap misi + tombol klaim.
class MissionCard extends ConsumerStatefulWidget {
  const MissionCard({super.key, required this.state});

  final GamificationState state;

  @override
  ConsumerState<MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends ConsumerState<MissionCard> {
  String? _claiming;

  Future<void> _claim(Mission mission) async {
    setState(() => _claiming = mission.key);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(gamificationProvider.notifier).claim(mission.key);
      messenger.showSnackBar(SnackBar(content: Text('+${mission.xp} XP — ${mission.title}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return GriviCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: _gold, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Misi harian',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                ),
              ),
              if (state.claimableCount > 0)
                GriviChip(label: '${state.claimableCount} siap diklaim', color: _gold),
            ],
          ),
          const SizedBox(height: 6),
          for (final mission in state.missions)
            _MissionRow(
              mission: mission,
              busy: _claiming == mission.key,
              onClaim: _claiming == null ? () => _claim(mission) : null,
            ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission, required this.busy, required this.onClaim});

  final Mission mission;
  final bool busy;
  final VoidCallback? onClaim;

  String get _detail {
    if (mission.limit != null) {
      return 'Kemarin ${CurrencyFormatter.compact(mission.spent ?? 0)} '
          'dari jatah ${CurrencyFormatter.compact(mission.limit!)}';
    }
    return '${mission.progress}/${mission.target}';
  }

  @override
  Widget build(BuildContext context) {
    final ratio = mission.target == 0 ? 0.0 : mission.progress / mission.target;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            height: 34,
            width: 34,
            child: mission.done
                ? const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.check, size: 18, color: AppColors.onPrimary),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => CircularProgressIndicator(
                      value: t,
                      strokeWidth: 3.5,
                      color: _gold,
                      backgroundColor: AppColors.surfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: mission.claimed ? AppColors.textMuted : AppColors.textPrimary,
                    decoration: mission.claimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(_detail, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (mission.claimable)
            GriviPressable(
              onTap: onClaim,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(20)),
                child: busy
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                      )
                    : Text(
                        'Klaim +${mission.xp}',
                        style: const TextStyle(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
              ),
            )
          else
            Text(
              mission.claimed ? 'Diklaim' : '+${mission.xp} XP',
              style: TextStyle(
                color: mission.claimed ? AppColors.primary : AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
        ],
      ),
    );
  }
}

/// Satu lencana di galeri. Yang terkunci abu-abu dengan progres.
class AchievementTile extends StatelessWidget {
  const AchievementTile({super.key, required this.achievement, this.onTap});

  final Achievement achievement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;

    return GriviCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: unlocked ? _gold.withValues(alpha: 0.45) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.35,
            child: GriviIconBadge(
              name: achievement.icon,
              color: unlocked ? _gold : AppColors.textMuted,
              size: 44,
              radius: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            achievement.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: unlocked ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            achievement.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.3),
          ),
          const Spacer(),
          if (unlocked)
            Text(
              '+${achievement.xp} XP',
              style: const TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 12),
            )
          else ...[
            GriviProgressBar(value: achievement.ratio, color: _gold, height: 5),
            const SizedBox(height: 4),
            Text(
              '${achievement.progress}/${achievement.target}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Perayaan lencana baru: kartu yang melompat masuk.
Future<void> showUnlockCelebration(BuildContext context, List<Achievement> fresh) {
  if (fresh.isEmpty) return Future.value();
  final first = fresh.first;
  final more = fresh.length - 1;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 450),
    transitionBuilder: (context, animation, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
      child: FadeTransition(opacity: animation, child: child),
    ),
    pageBuilder: (context, _, _) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _gold.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GriviIconBadge(name: first.icon, color: _gold, size: 76, radius: 24),
              const SizedBox(height: 16),
              const Text(
                'Lencana baru!',
                style: TextStyle(color: _gold, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                first.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                first.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Text(
                more > 0 ? '+${first.xp} XP · dan $more lencana lain' : '+${first.xp} XP',
                style: const TextStyle(color: _gold, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Mantap'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
