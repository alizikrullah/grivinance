import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/category_model.dart';
import '../../../providers/category_provider.dart';
import '../../widgets/common/grivi_button.dart';
import '../../widgets/common/grivi_error_banner.dart';
import '../../widgets/common/grivi_pickers.dart';
import '../../widgets/common/grivi_text_field.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.categoryId});

  final String? categoryId;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  TxType _type = TxType.expense;
  String _icon = 'more_horiz';
  String _color = '#F97316';

  bool _loading = false;
  bool _deleting = false;
  String? _error;
  bool _prefilled = false;

  bool get _isEdit => widget.categoryId != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _prefill(CategoryModel category) {
    if (_prefilled) return;
    _prefilled = true;
    _nameController.text = category.name;
    _type = category.type;
    _icon = category.icon;
    _color = category.color;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifier = ref.read(categoriesProvider.notifier);
      if (_isEdit) {
        await notifier.edit(
          id: widget.categoryId!,
          name: _nameController.text.trim(),
          type: _type,
          icon: _icon,
          color: _color,
        );
      } else {
        await notifier.create(
          name: _nameController.text.trim(),
          type: _type,
          icon: _icon,
          color: _color,
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
        title: const Text('Hapus kategori?'),
        content: const Text('Kategori yang masih dipakai transaksi tidak bisa dihapus.'),
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
      await ref.read(categoriesProvider.notifier).delete(widget.categoryId!);
      if (mounted) context.pop();
    } catch (e) {
      // Backend balikin 409 kalau kategorinya masih kepakai; tampilkan apa adanya.
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      final all = ref.watch(categoriesProvider).value ?? const <CategoryModel>[];
      final existing = all.where((c) => c.id == widget.categoryId).firstOrNull;
      if (existing != null) _prefill(existing);
    }

    final color = hexToColor(_color);
    final busy = _loading || _deleting;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit kategori' : 'Tambah kategori'),
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
                label: 'Nama kategori',
                hint: 'Kopi, Parkir, Bonus',
                icon: Icons.label_outline,
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
              SegmentedButton<TxType>(
                segments: TxType.values
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
              const SizedBox(height: 18),
              IconPickerField(
                selected: _icon,
                color: color,
                groups: [IconGroup('IKON', AppIcons.forCategory)],
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
                label: _isEdit ? 'Simpan perubahan' : 'Tambah kategori',
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
