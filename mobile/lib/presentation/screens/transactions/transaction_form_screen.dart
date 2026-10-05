import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/common/grivi_async_view.dart';
import '../../widgets/common/grivi_button.dart';
import '../../widgets/common/grivi_error_banner.dart';
import '../../widgets/common/grivi_icon_badge.dart';
import '../../widgets/common/grivi_motion.dart';
import '../../widgets/common/grivi_text_field.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.transactionId,
    this.initialType,
    this.initialWalletId,
  });

  final String? transactionId;
  final TxType? initialType;
  final String? initialWalletId;

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _feeController = TextEditingController();
  final _noteController = TextEditingController();

  late TxType _type = widget.initialType ?? TxType.expense;
  late String? _walletId = widget.initialWalletId;
  String? _toWalletId;
  String? _categoryId;
  DateTime _date = DateTime.now();

  bool _loading = false;
  String? _error;
  bool _prefilled = false;

  bool get _isEdit => widget.transactionId != null;
  bool get _isTransfer => _type == TxType.transfer;

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _prefill(TransactionModel tx) {
    if (_prefilled) return;
    _prefilled = true;
    _type = tx.type;
    _walletId = tx.walletId;
    _toWalletId = tx.toWalletId;
    _categoryId = tx.categoryId;
    _date = tx.date.toLocal();
    _amountController.text = CurrencyFormatter.formatInput(tx.amount);
    _feeController.text = CurrencyFormatter.formatInput(tx.fee ?? 0);
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

  String? _missingChoice() {
    if (_walletId == null) return _isTransfer ? 'Wallet asal wajib dipilih' : 'Wallet wajib dipilih';
    if (_isTransfer) {
      if (_toWalletId == null) return 'Wallet tujuan wajib dipilih';
      if (_toWalletId == _walletId) return 'Wallet asal dan tujuan tidak boleh sama';
    } else if (_categoryId == null) {
      return 'Kategori wajib dipilih';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final missing = _missingChoice();
    if (missing != null) {
      setState(() => _error = missing);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final input = TransactionInput(
      type: _type,
      walletId: _walletId!,
      toWalletId: _isTransfer ? _toWalletId : null,
      categoryId: _isTransfer ? null : _categoryId,
      amount: CurrencyFormatter.parseInput(_amountController.text),
      fee: _isTransfer ? CurrencyFormatter.parseInput(_feeController.text) : null,
      date: _date,
      note: _noteController.text,
    );

    try {
      final notifier = ref.read(transactionsProvider.notifier);
      if (_isEdit) {
        await notifier.edit(widget.transactionId!, input);
      } else {
        await notifier.create(input);
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
    // Prefill DULU, baru ambil daftar kategori. Kebalikannya bikin daftar
    // diambil pakai tipe default (pengeluaran), dan kategori asli transaksi
    // pemasukan langsung dianggap nggak valid lalu dikosongkan (BUG-7).
    if (_isEdit) {
      final detail = ref.watch(transactionDetailProvider(widget.transactionId!));
      final tx = detail.valueOrNull;
      if (tx == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Edit transaksi')),
          body: GriviAsyncView<TransactionModel>(
            value: detail,
            onRetry: () => ref.invalidate(transactionDetailProvider(widget.transactionId!)),
            builder: (_) => const SizedBox.shrink(),
          ),
        );
      }
      _prefill(tx);
    }

    final wallets = ref.watch(walletsProvider).valueOrNull ?? const <WalletModel>[];
    final categoriesState = ref.watch(categoriesProvider);
    final categories = ref.watch(categoriesByTypeProvider(_type));

    // Wallet pertama dipilih otomatis supaya user nggak perlu satu tap ekstra.
    if (_walletId == null && wallets.isNotEmpty) _walletId = wallets.first.id;

    // Kategori cuma direset kalau daftarnya sudah selesai dimuat dan memang
    // nggak cocok — daftar yang masih kosong karena loading bukan alasan.
    if (categoriesState.hasValue &&
        _categoryId != null &&
        !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    final accent = switch (_type) {
      TxType.expense => AppColors.expense,
      TxType.income => AppColors.income,
      TxType.transfer => AppColors.transfer,
    };

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit transaksi' : 'Transaksi baru')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _TypeSelector(
                selected: _type,
                onChanged: (type) => setState(() {
                  _type = type;
                  _categoryId = null;
                  _error = null;
                }),
              ),
              const SizedBox(height: 16),
              _AmountField(controller: _amountController, color: accent, autofocus: !_isEdit),
              const SizedBox(height: 20),
              if (wallets.isEmpty)
                const Text(
                  'Belum ada wallet. Tambah wallet dulu di menu Akun.',
                  style: TextStyle(color: AppColors.warning, fontSize: 13),
                )
              else if (_isTransfer) ...[
                if (wallets.length < 2)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Transfer butuh minimal 2 wallet.',
                      style: TextStyle(color: AppColors.warning, fontSize: 13),
                    ),
                  ),
                const _FieldLabel('Dari wallet'),
                const SizedBox(height: 8),
                _WalletChips(
                  wallets: wallets,
                  selectedId: _walletId,
                  onSelected: (id) => setState(() {
                    _walletId = id;
                    if (_toWalletId == id) _toWalletId = null;
                  }),
                ),
                const SizedBox(height: 18),
                const _FieldLabel('Ke wallet'),
                const SizedBox(height: 8),
                _WalletChips(
                  wallets: wallets.where((w) => w.id != _walletId).toList(),
                  selectedId: _toWalletId,
                  onSelected: (id) => setState(() => _toWalletId = id),
                ),
                const SizedBox(height: 18),
                GriviTextField(
                  controller: _feeController,
                  label: 'Biaya admin (opsional)',
                  hint: '0',
                  icon: Icons.receipt_long_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RupiahInputFormatter()],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Dicatat sebagai pengeluaran "Biaya Admin" dari wallet asal.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ] else ...[
                const _FieldLabel('Wallet'),
                const SizedBox(height: 8),
                _WalletChips(
                  wallets: wallets,
                  selectedId: _walletId,
                  onSelected: (id) => setState(() => _walletId = id),
                ),
                const SizedBox(height: 18),
                const _FieldLabel('Kategori'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in categories)
                      _SelectChip(
                        label: category.name,
                        iconName: category.icon,
                        color: hexToColor(category.color),
                        selected: _categoryId == category.id,
                        onTap: () => setState(() => _categoryId = category.id),
                      ),
                    _AddChip(onTap: () => context.push(AppRoutes.categoryNew)),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const _FieldLabel('Tanggal'),
              const SizedBox(height: 8),
              GriviPressable(
                onTap: _pickDate,
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
                      Expanded(
                        child: Text(
                          '${DateFormatter.full(_date)} · ${DateFormatter.time(_date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

/// Tiga pilihan tipe dengan warnanya masing-masing.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final TxType selected;
  final ValueChanged<TxType> onChanged;

  static Color _colorOf(TxType type) => switch (type) {
    TxType.expense => AppColors.expense,
    TxType.income => AppColors.income,
    TxType.transfer => AppColors.transfer,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final type in TxType.values)
            Expanded(
              child: GriviPressable(
                onTap: () => onChanged(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: type == selected ? _colorOf(type) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    type.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: type == selected
                          ? GriviIconBadge.inkFor(_colorOf(type))
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Nominal besar di tengah, berpemisah ribuan selagi diketik.
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.color, required this.autofocus});

  final TextEditingController controller;
  final Color color;

  /// Transaksi baru langsung siap diketik; waktu edit, keyboard nggak perlu muncul.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Jumlah', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          TextFormField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color),
            cursorColor: color,
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color),
              hintText: '0',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
            validator: (value) => CurrencyFormatter.parseInput(value ?? '') <= 0
                ? 'Jumlah harus lebih dari 0'
                : null,
          ),
        ],
      ),
    );
  }
}

class _WalletChips extends StatelessWidget {
  const _WalletChips({
    required this.wallets,
    required this.selectedId,
    required this.onSelected,
  });

  final List<WalletModel> wallets;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final wallet in wallets)
          _SelectChip(
            label: wallet.name,
            iconName: wallet.icon,
            color: hexToColor(wallet.color),
            selected: selectedId == wallet.id,
            onTap: () => onSelected(wallet.id),
          ),
      ],
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
    required this.iconName,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String iconName;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GriviPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GriviIconBadge(name: iconName, color: color, size: 22, radius: 7),
            const SizedBox(width: 8),
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

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GriviPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceVariant, width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: AppColors.primary),
            SizedBox(width: 6),
            Text('Kategori baru', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
