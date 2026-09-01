import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/common/grivi_button.dart';
import '../../widgets/common/grivi_error_banner.dart';
import '../../widgets/common/grivi_text_field.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transactionId});

  final String? transactionId;

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TxType _type = TxType.expense;
  String? _walletId;
  String? _categoryId;
  DateTime _date = DateTime.now();

  bool _loading = false;
  String? _error;
  bool _prefilled = false;

  bool get _isEdit => widget.transactionId != null;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _prefill(TransactionModel tx) {
    if (_prefilled) return;
    _prefilled = true;
    _type = tx.type;
    _walletId = tx.walletId;
    _categoryId = tx.categoryId;
    _date = tx.date.toLocal();
    _amountController.text = tx.amount.toStringAsFixed(0);
    _noteController.text = tx.note ?? '';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );

    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? _date.hour,
        time?.minute ?? _date.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_walletId == null) {
      setState(() => _error = 'Wallet wajib dipilih');
      return;
    }
    if (_categoryId == null) {
      setState(() => _error = 'Kategori wajib dipilih');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifier = ref.read(transactionsProvider.notifier);
      final amount = CurrencyFormatter.parseInput(_amountController.text);

      if (_isEdit) {
        await notifier.edit(
          id: widget.transactionId!,
          walletId: _walletId!,
          categoryId: _categoryId!,
          type: _type,
          amount: amount,
          date: _date,
          note: _noteController.text,
        );
      } else {
        await notifier.create(
          walletId: _walletId!,
          categoryId: _categoryId!,
          type: _type,
          amount: amount,
          date: _date,
          note: _noteController.text,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider).value ?? const <WalletModel>[];
    final categories = ref.watch(categoriesByTypeProvider(_type));

    if (_isEdit) {
      final detail = ref.watch(transactionDetailProvider(widget.transactionId!));
      final tx = detail.value;
      if (tx != null) _prefill(tx);
    }

    // Wallet pertama dipilih otomatis supaya user nggak perlu satu tap ekstra.
    if (_walletId == null && wallets.isNotEmpty) {
      _walletId = wallets.first.id;
    }
    // Kategori direset kalau tipenya nggak cocok lagi — backend nolak (422)
    // kalau kategori expense dipakai di transaksi income.
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit transaksi' : 'Transaksi baru')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SegmentedButton<TxType>(
                segments: TxType.values
                    .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                    .toList(),
                selected: {_type},
                onSelectionChanged: (value) => setState(() {
                  _type = value.first;
                  _categoryId = null;
                }),
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppColors.surfaceVariant,
                  foregroundColor: AppColors.textSecondary,
                  selectedBackgroundColor: _type == TxType.income
                      ? AppColors.income
                      : AppColors.expense,
                  selectedForegroundColor: Colors.white,
                  side: BorderSide.none,
                ),
              ),
              const SizedBox(height: 20),
              GriviTextField(
                controller: _amountController,
                label: 'Jumlah',
                hint: '0',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final amount = CurrencyFormatter.parseInput(value ?? '');
                  if (amount <= 0) return 'Jumlah harus lebih dari 0';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _FieldLabel('Wallet'),
              const SizedBox(height: 8),
              if (wallets.isEmpty)
                const Text(
                  'Belum ada wallet. Tambah wallet dulu di menu Akun.',
                  style: TextStyle(color: AppColors.warning, fontSize: 13),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: wallets
                      .map(
                        (wallet) => _SelectChip(
                          label: wallet.name,
                          icon: AppIcons.resolve(wallet.icon),
                          color: hexToColor(wallet.color),
                          selected: _walletId == wallet.id,
                          onTap: () => setState(() => _walletId = wallet.id),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 18),
              _FieldLabel('Kategori'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map(
                      (category) => _SelectChip(
                        label: category.name,
                        icon: AppIcons.resolve(category.icon),
                        color: hexToColor(category.color),
                        selected: _categoryId == category.id,
                        onTap: () => setState(() => _categoryId = category.id),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              _FieldLabel('Tanggal'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 12),
                      Text('${DateFormatter.full(_date)} · ${DateFormatter.time(_date)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GriviTextField(
                controller: _noteController,
                label: 'Catatan (opsional)',
                icon: Icons.notes,
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                GriviErrorBanner(message: _error!),
              ],
              const SizedBox(height: 26),
              GriviButton(
                label: _isEdit ? 'Simpan perubahan' : 'Simpan transaksi',
                loading: _loading,
                onPressed: wallets.isEmpty ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: selected ? color : AppColors.textMuted),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
