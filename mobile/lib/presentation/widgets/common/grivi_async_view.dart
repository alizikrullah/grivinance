import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'grivi_button.dart';

/// Satu tempat buat tiga keadaan yang dipunyai semua layar: loading, error,
/// dan kosong. Tanpa ini tiap layar nulis ulang tiga cabang yang sama.
class GriviAsyncView<T> extends StatelessWidget {
  const GriviAsyncView({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.isEmpty,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Belum ada data',
    this.emptyMessage,
    this.emptyAction,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => GriviErrorView(message: '$error', onRetry: onRetry),
      data: (data) {
        if (isEmpty?.call(data) ?? false) {
          return GriviEmptyView(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
            action: emptyAction,
          );
        }
        return builder(data);
      },
    );
  }
}

class GriviErrorView extends StatelessWidget {
  const GriviErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: GriviButton(
                label: 'Coba lagi',
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GriviEmptyView extends StatelessWidget {
  const GriviEmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
