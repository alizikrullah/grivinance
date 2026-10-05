import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import 'grivi_motion.dart';

/// Foto profil user yang login, atau huruf depan namanya kalau belum ada foto.
class GriviAvatar extends ConsumerWidget {
  const GriviAvatar({super.key, this.size = 44, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final photo = ref.watch(avatarProvider).valueOrNull;

    final avatar = Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      child: ClipOval(
        child: photo != null
            ? Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true)
            : Container(
                color: AppColors.primaryDark,
                alignment: Alignment.center,
                child: Text(
                  user?.initial ?? '?',
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );

    return GriviPressable(onTap: onTap, child: avatar);
  }
}
