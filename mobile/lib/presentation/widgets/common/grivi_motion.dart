import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';

/// Apa pun yang bisa diketuk: mengecil sedikit waktu ditekan + getar halus.
/// Ini yang bikin app terasa "hidup" — dipakai kartu, tile, chip, tombol nav.
class GriviPressable extends StatefulWidget {
  const GriviPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  @override
  State<GriviPressable> createState() => _GriviPressableState();
}

class _GriviPressableState extends State<GriviPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Muncul pelan dari bawah, bertahap sesuai [index]. Cuma beberapa elemen
/// pertama yang dianimasikan — di daftar panjang, animasi tiap baris yang
/// di-scroll malah bikin pusing.
class GriviFadeIn extends StatelessWidget {
  const GriviFadeIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const int _maxAnimated = 10;

  @override
  Widget build(BuildContext context) {
    if (index > _maxAnimated) return child;

    final start = (index * 0.06).clamp(0.0, 0.5);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
    );
  }
}

/// Nominal yang menghitung naik ke angka barunya, alih-alih langsung berganti.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney({
    super.key,
    required this.value,
    this.style,
    this.hidden = false,
    this.compact = false,
  });

  final double value;
  final TextStyle? style;

  /// Mode "sembunyikan saldo".
  final bool hidden;

  /// "1,3 jt" alih-alih "Rp 1.250.000" — buat kartu kecil.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (hidden) return Text('Rp ••••••', style: style, maxLines: 1);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        compact ? 'Rp ${CurrencyFormatter.compact(v)}' : CurrencyFormatter.formatSigned(v),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Bar progres yang mengisi dengan animasi. Lewat 100% tetap penuh — warnanya
/// yang memberi tahu (pemanggil yang memilih warna).
class GriviProgressBar extends StatelessWidget {
  const GriviProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.primary,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        color: AppColors.surfaceVariant,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => FractionallySizedBox(
            widthFactor: t,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: radius),
            ),
          ),
        ),
      ),
    );
  }
}
