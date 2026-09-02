import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/common/grivi_button.dart';
import '../../widgets/common/grivi_error_banner.dart';
import '../../widgets/common/grivi_pickers.dart';
import '../../widgets/common/grivi_text_field.dart';

class WalletFormScreen extends ConsumerStatefulWidget {
  const WalletFormScreen({super.key, this.walletId});

  /// null = tambah baru.
  final String? walletId;

  @override
  ConsumerState<WalletFormScreen> createState() => _WalletFormScreenState();
}

class _WalletFormScreenState extends ConsumerState<WalletFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  WalletType _type = WalletType.eWallet;
  String _icon = 'account_balance_wallet';
  String _color = '#10B981';

  bool _loading = false;
  bool _deleting = false;
  String? _error;
  bool _prefilled = false;

  bool get _isEdit => widget.walletId != null;

  /// Saldo awal cuma bisa disunting selama wallet belum punya transaksi.
  /// Begitu ada transaksi, balance = saldo awal + jumlah transaksi, dan dua
  /// komponen itu tidak disimpan terpisah. Backend menolak dengan 409 juga.
  bool _canEditBalance = true;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  /// Isi form dari data yang sudah ada di provider, sekali saja.
  void _prefill(WalletModel wallet) {
    if (_prefilled) return;
    _prefilled = true;
    _nameController.text = wallet.name;
    _type = wallet.type;
    _icon = wallet.icon;
    _color = wallet.color;
    _canEditBalance = wallet.canEditBalance;
    if (_canEditBalance) {
      _balanceController.text = wallet.balance.toStringAsFixed(0);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifier = ref.read(walletsProvider.notifier);
      if (_isEdit) {
        await notifier.edit(
          id: widget.walletId!,
          name: _nameController.text.trim(),
          type: _type,
          icon: _icon,
          color: _color,
          balance: _canEditBalance
              ? CurrencyFormatter.parseInput(_balanceController.text)
              : null,
        );
      } else {
        await notifier.create(
          name: _nameController.text.trim(),
          type: _type,
          icon: _icon,
          color: _color,
          balance: CurrencyFormatter.parseInput(_balanceController.text),
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus wallet?'),
        content: const Text(
          'Semua transaksi di wallet ini ikut terhapus permanen dan tidak bisa '
          'dikembalikan.',
        ),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await ref.read(walletsProvider.notifier).delete(widget.walletId!);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      final wallets = ref.watch(walletsProvider).value ?? const <WalletModel>[];
      final existing = wallets.where((w) => w.id == widget.walletId).firstOrNull;
      if (existing != null) _prefill(existing);
    }

    final showBalanceField = !_isEdit || _canEditBalance;

    final color = hexToColor(_color);
    final busy = _loading || _deleting;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit wallet' : 'Tambah wallet'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline, color: AppColors.expense),
              onPressed: busy ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              GriviTextField(
                controller: _nameController,
                label: 'Nama wallet',
                hint: 'GoPay, BCA, Dompet',
                icon: Icons.badge_outlined,
                validator: (value) =>
                    (value?.trim() ?? '').isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 18),
              const Text(
                'Tipe',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<WalletType>(
                segments: WalletType.values
                    .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                    .toList(),
                selected: {_type},
                onSelectionChanged: (value) => setState(() => _type = value.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppColors.surfaceVariant,
                  foregroundColor: AppColors.textSecondary,
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: const Color(0xFF04231A),
                  side: BorderSide.none,
                ),
              ),
              if (showBalanceField) ...[
                const SizedBox(height: 18),
                GriviTextField(
                  controller: _balanceController,
                  label: 'Saldo awal',
                  hint: '0',
                  icon: Icons.savings_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ] else ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 17, color: AppColors.textMuted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Saldo awal terkunci karena wallet ini sudah punya '
                          'transaksi. Hapus semua transaksinya kalau mau '
                          'mengubahnya lagi.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              IconPickerField(
                selected: _icon,
                color: color,
                groups: [
                  IconGroup('BANK', AppLogos.bankValues),
                  IconGroup('E-WALLET', AppLogos.eWalletValues),
                  IconGroup('IKON', AppIcons.forWallet),
                ],
                onChanged: (value) => setState(() => _icon = value),
              ),
              const SizedBox(height: 18),
              ColorPickerField(
                selected: _color,
                onChanged: (value) => setState(() => _color = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                GriviErrorBanner(message: _error!),
              ],
              const SizedBox(height: 26),
              GriviButton(
                label: _isEdit ? 'Simpan perubahan' : 'Tambah wallet',
                loading: busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
