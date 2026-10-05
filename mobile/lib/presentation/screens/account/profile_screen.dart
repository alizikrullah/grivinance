import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/common/grivi_avatar.dart';
import '../../widgets/common/grivi_button.dart';
import '../../widgets/common/grivi_card.dart';
import '../../widgets/common/grivi_error_banner.dart';
import '../../widgets/common/grivi_icon_badge.dart';
import '../../widgets/common/grivi_motion.dart';
import '../../widgets/common/grivi_text_field.dart';

/// Batas server untuk foto profil. HP mengecilkan fotonya dulu, jadi angka
/// ini cuma pengaman kalau kompresinya nggak jalan.
const int _maxAvatarBytes = 1024 * 1024;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _birthDate;

  bool _prefilled = false;
  bool _saving = false;
  bool _photoBusy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _prefill(UserModel user) {
    if (_prefilled) return;
    _prefilled = true;
    _nameController.text = user.name;
    _nicknameController.text = user.nickname ?? '';
    _phoneController.text = user.phone ?? '';
    _birthDate = user.birthDate;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).updateProfile(
        name: _nameController.text.trim(),
        nickname: _nicknameController.text.trim(),
        phone: _phoneController.text.trim(),
        birthDate: _birthDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil disimpan')));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Tanggal lahir',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  /// Jenis gambar dari byte awalnya — server juga memeriksa dengan cara yang sama.
  static String? _mimeOf(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) {
      return 'image/png';
    }
    if (bytes.length > 12 && String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    // Dikecilkan di HP: avatar cuma tampil maksimal ~100 px, jadi 512 px
    // dengan kualitas 80 udah lebih dari cukup dan ukurannya ±50–150 KB.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final mime = _mimeOf(bytes);
    if (mime == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Format foto harus JPEG, PNG, atau WebP')));
      return;
    }
    if (bytes.length > _maxAvatarBytes) {
      messenger.showSnackBar(const SnackBar(content: Text('Foto terlalu besar, maksimal 1 MB')));
      return;
    }

    setState(() => _photoBusy = true);
    try {
      await ref.read(authProvider.notifier).uploadAvatar(bytes, mime);
      messenger.showSnackBar(const SnackBar(content: Text('Foto profil diperbarui')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal upload foto: $e')));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _deletePhoto() async {
    setState(() => _photoBusy = true);
    try {
      await ref.read(authProvider.notifier).deleteAvatar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _photoMenu(bool hasAvatar) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.of(sheet).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () {
                Navigator.of(sheet).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.expense),
                title: const Text('Hapus foto', style: TextStyle(color: AppColors.expense)),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _deletePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openSheet(Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user != null) _prefill(user);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profil')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Center(
                child: Stack(
                  children: [
                    GriviAvatar(size: 104, onTap: () => _photoMenu(user?.hasAvatar ?? false)),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GriviPressable(
                        onTap: () => _photoMenu(user?.hasAvatar ?? false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 3),
                          ),
                          child: _photoBusy
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_camera, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              GriviTextField(
                controller: _nameController,
                label: 'Nama lengkap',
                icon: Icons.badge_outlined,
                validator: (value) =>
                    (value?.trim() ?? '').isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              GriviTextField(
                controller: _nicknameController,
                label: 'Nama panggilan (opsional)',
                hint: 'Dipakai di sapaan Beranda',
                icon: Icons.waving_hand_outlined,
                validator: (value) =>
                    (value?.trim().length ?? 0) > 30 ? 'Maksimal 30 karakter' : null,
              ),
              const SizedBox(height: 14),
              GriviTextField(
                controller: _phoneController,
                label: 'Nomor HP (opsional)',
                hint: '0812xxxxxxxx',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
                validator: (value) {
                  final digits = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
                  if (digits.isEmpty) return null;
                  return RegExp(r'^\+?\d{8,15}$').hasMatch(digits)
                      ? null
                      : 'Nomor HP 8-15 digit, boleh diawali +';
                },
              ),
              const SizedBox(height: 14),
              GriviPressable(
                onTap: _pickBirthDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cake_outlined, size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _birthDate == null
                              ? 'Tanggal lahir (opsional)'
                              : DateFormatter.full(_birthDate!),
                          style: TextStyle(
                            color: _birthDate == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_birthDate != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _birthDate = null),
                        )
                      else
                        const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                GriviErrorBanner(message: _error!),
              ],
              const SizedBox(height: 22),
              GriviButton(label: 'Simpan profil', loading: _saving, onPressed: _save),
              const SizedBox(height: 28),
              const Text(
                'Keamanan',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _SecurityTile(
                icon: Icons.alternate_email,
                title: 'Ganti email',
                subtitle: user?.email ?? '',
                onTap: () => _openSheet(_ChangeEmailSheet(currentEmail: user?.email ?? '')),
              ),
              const SizedBox(height: 10),
              _SecurityTile(
                icon: Icons.lock_outline,
                title: 'Ganti password',
                subtitle: 'Perangkat lain otomatis keluar',
                onTap: () => _openSheet(const _ChangePasswordSheet()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GriviCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: 16,
      child: Row(
        children: [
          GriviIconBadge.material(icon, color: AppColors.transfer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Dasar dua sheet keamanan: judul, isi form, error, tombol simpan.
class _SheetForm extends StatelessWidget {
  const _SheetForm({
    required this.formKey,
    required this.title,
    required this.fields,
    required this.error,
    required this.loading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final List<Widget> fields;
  final String? error;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              for (final field in fields) ...[field, const SizedBox(height: 12)],
              if (error != null) ...[GriviErrorBanner(message: error!), const SizedBox(height: 12)],
              const SizedBox(height: 4),
              GriviButton(label: 'Simpan', loading: loading, onPressed: onSubmit),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeEmailSheet extends ConsumerStatefulWidget {
  const _ChangeEmailSheet({required this.currentEmail});

  final String currentEmail;

  @override
  ConsumerState<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<_ChangeEmailSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.currentEmail);
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).changeEmail(
        email: _emailController.text.trim(),
        currentPassword: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email diperbarui')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetForm(
      formKey: _formKey,
      title: 'Ganti email',
      error: _error,
      loading: _loading,
      onSubmit: _submit,
      fields: [
        GriviTextField(
          controller: _emailController,
          label: 'Email baru',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            final v = value?.trim() ?? '';
            if (!v.contains('@') || !v.contains('.')) return 'Format email tidak valid';
            return null;
          },
        ),
        GriviTextField(
          controller: _passwordController,
          label: 'Password saat ini',
          icon: Icons.lock_outline,
          obscure: true,
          validator: (value) => (value ?? '').isEmpty ? 'Password wajib diisi' : null,
        ),
      ],
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password diganti. Perangkat lain otomatis keluar.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetForm(
      formKey: _formKey,
      title: 'Ganti password',
      error: _error,
      loading: _loading,
      onSubmit: _submit,
      fields: [
        GriviTextField(
          controller: _currentController,
          label: 'Password saat ini',
          icon: Icons.lock_outline,
          obscure: true,
          validator: (value) => (value ?? '').isEmpty ? 'Password wajib diisi' : null,
        ),
        GriviTextField(
          controller: _newController,
          label: 'Password baru',
          hint: 'Minimal 8 karakter',
          icon: Icons.lock_reset,
          obscure: true,
          validator: (value) => (value ?? '').length < 8 ? 'Password minimal 8 karakter' : null,
        ),
        GriviTextField(
          controller: _confirmController,
          label: 'Ulangi password baru',
          icon: Icons.lock_reset,
          obscure: true,
          validator: (value) => value != _newController.text ? 'Password tidak sama' : null,
        ),
      ],
    );
  }
}
