import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grivinance/data/models/category_model.dart';
import 'package:grivinance/data/models/transaction_model.dart';
import 'package:grivinance/data/models/wallet_model.dart';
import 'package:grivinance/data/repositories/auth_repository.dart';
import 'package:grivinance/data/repositories/budget_repository.dart';
import 'package:grivinance/data/repositories/category_repository.dart';
import 'package:grivinance/data/repositories/gamification_repository.dart';
import 'package:grivinance/data/repositories/summary_repository.dart';
import 'package:grivinance/data/repositories/transaction_repository.dart';
import 'package:grivinance/data/repositories/wallet_repository.dart';
import 'package:grivinance/data/services/api_service.dart';
import 'package:grivinance/data/services/storage_service.dart';

/// Secure storage butuh platform channel yang nggak ada di test, jadi
/// token disimpan di memori saja.
class _MemoryStorage extends StorageService {
  String? _access;
  String? _refresh;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
  }

  @override
  Future<void> saveAccessToken(String accessToken) async => _access = accessToken;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

void main() {
  // flutter_test memasang HttpClient tiruan yang menolak semua request.
  // Tanpa baris ini, tiap panggilan jaringan balik 400.
  setUpAll(() => HttpOverrides.global = null);

  final storage = _MemoryStorage();
  final api = ApiService(storage);
  final auth = AuthRepository(api, storage);
  final wallets = WalletRepository(api);
  final categories = CategoryRepository(api);
  final transactions = TransactionRepository(api);
  final summary = SummaryRepository(api);
  final budgets = BudgetRepository(api);
  final gamification = GamificationRepository(api);

  final email = 'flutter.${DateTime.now().millisecondsSinceEpoch}@grivinance.local';
  const password = 'rahasia123';

  late String walletId;
  late String secondWalletId;
  late String categoryId;
  late String transactionId;

  test('register lalu /me balik user yang sama', () async {
    final registered = await auth.register(
      name: 'Flutter Test',
      email: email,
      password: password,
    );
    expect(registered.user.email, email);
    expect(registered.accessToken, isNotEmpty);

    final me = await auth.me();
    expect(me.email, email);
  });

  test('kategori preset ke-parse, isPreset kebaca dari userId null', () async {
    final list = await categories.list();
    expect(list.length, 17);
    expect(list.every((c) => c.isPreset), isTrue);
    expect(list.any((c) => c.type == TxType.income), isTrue);
    expect(list.any((c) => c.name == 'Biaya Admin'), isTrue);
  });

  test('wallet dibuat dengan saldo awal, balance ke-parse jadi double', () async {
    final wallet = await wallets.create(
      name: 'Test Wallet',
      type: WalletType.bank,
      icon: 'account_balance',
      color: '#3B82F6',
      balance: 100000,
    );
    walletId = wallet.id;
    expect(wallet.balance, 100000.0);
    expect(wallet.type, WalletType.bank);
  });

  test('saldo awal bisa diubah selama wallet belum ada transaksi', () async {
    final updated = await wallets.update(
      id: walletId,
      name: 'Test Wallet',
      type: WalletType.bank,
      icon: 'account_balance',
      color: '#3B82F6',
      balance: 250000,
    );
    expect(updated.balance, 250000.0);
    expect(updated.canEditBalance, isTrue);

    // dikembalikan supaya perhitungan test berikutnya tetap sama
    await wallets.update(
      id: walletId,
      name: 'Test Wallet',
      type: WalletType.bank,
      icon: 'account_balance',
      color: '#3B82F6',
      balance: 100000,
    );
  });

  test('kategori custom dibuat dengan isPreset false', () async {
    final category = await categories.create(
      name: 'Test Kategori',
      type: TxType.expense,
      icon: 'coffee',
      color: '#A855F7',
    );
    categoryId = category.id;
    expect(category.isPreset, isFalse);
    expect(category.canChangeType, isTrue);
  });

  test('transaksi expense mengurangi saldo; jamnya balik sama persis (BUG-2)', () async {
    // 01:00 waktu HP (WIB) = 18:00 UTC hari sebelumnya — persis jendela yang
    // dulu diam-diam geser 7 jam karena tanggal dikirim tanpa offset.
    final localDate = DateTime(2026, 9, 1, 1, 0);
    final tx = await transactions.create(
      TransactionInput(
        type: TxType.expense,
        walletId: walletId,
        categoryId: categoryId,
        amount: 25000,
        date: localDate,
        note: 'dini hari WIB',
      ),
    );
    transactionId = tx.id;
    expect(tx.amount, 25000.0);
    expect(tx.isIncome, isFalse);
    expect(tx.category?.name, 'Test Kategori');
    expect(tx.date.toLocal(), localDate);

    final list = await wallets.list();
    final updated = list.firstWhere((w) => w.id == walletId);
    expect(updated.balance, 75000.0);
  });

  test('list transaksi bawa relasi wallet dan kategori', () async {
    final page = await transactions.list(filter: TransactionFilter(walletId: walletId));
    expect(page.total, 1);
    expect(page.items.first.wallet.name, 'Test Wallet');
    expect(page.items.first.category?.icon, 'coffee');
  });

  test('summary harian pakai batas WIB, bukan UTC', () async {
    // Transaksi dicatat 01:00 WIB 1 September.
    final onDay = await summary.daily(DateTime(2026, 9, 1));
    expect(onDay.totalExpense, 25000.0);

    final dayBefore = await summary.daily(DateTime(2026, 8, 31));
    expect(dayBefore.totalExpense, 0.0);
  });

  test('summary tahunan balik 12 bulan', () async {
    final yearly = await summary.yearly(2026);
    expect(yearly.months.length, 12);
    expect(yearly.months[8].month, 9);
    expect(yearly.months[8].expense, 25000.0);
  });

  test('transfer + biaya admin: saldo dua wallet, biaya jadi pengeluaran', () async {
    final second = await wallets.create(
      name: 'Dompet Kedua',
      type: WalletType.eWallet,
      icon: 'logo:dana',
      color: '#10B981',
      balance: 0,
    );
    secondWalletId = second.id;

    final transfer = await transactions.create(
      TransactionInput(
        type: TxType.transfer,
        walletId: walletId,
        toWalletId: secondWalletId,
        amount: 20000,
        fee: 2500,
        date: DateTime(2026, 9, 2, 10, 0),
      ),
    );
    expect(transfer.isTransfer, isTrue);
    expect(transfer.category, isNull);
    expect(transfer.toWallet?.name, 'Dompet Kedua');
    expect(transfer.fee, 2500.0);

    final list = await wallets.list();
    expect(list.firstWhere((w) => w.id == walletId).balance, 52500.0);
    expect(list.firstWhere((w) => w.id == secondWalletId).balance, 20000.0);

    final day = await summary.daily(DateTime(2026, 9, 2));
    expect(day.totalExpense, 2500.0, reason: 'transfer nggak dihitung, biaya admin dihitung');

    await transactions.delete(transfer.id);
    final after = await wallets.list();
    expect(after.firstWhere((w) => w.id == walletId).balance, 75000.0);
  });

  test('budget per kategori ke-parse dengan terpakai bulan itu', () async {
    await budgets.set(categoryId, 100000);
    final month = await budgets.month(2026, 9);
    expect(month.totalBudget, 100000.0);
    expect(month.items.single.spent, 25000.0);
    expect(month.remaining, 75000.0);
  });

  test('gamifikasi ke-parse; misi yang belum selesai ditolak server', () async {
    final state = await gamification.state();
    expect(state.level, greaterThanOrEqualTo(1));
    expect(state.missions, isNotEmpty);
    expect(state.achievements.length, 9);
    expect(state.unlockedCount, greaterThanOrEqualTo(1)); // transaksi pertama

    await expectLater(
      gamification.claim('records_3'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 422)),
    );
  });

  test('profil & foto: simpan, baca balik, hapus', () async {
    final updated = await auth.updateProfile(
      name: 'Flutter Test',
      nickname: 'Flut',
      phone: '081234567890',
      birthDate: DateTime(2000, 1, 31),
    );
    expect(updated.greetingName, 'Flut');
    expect(updated.birthDate, DateTime(2000, 1, 31));

    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 7, 7, 7]);
    await auth.uploadAvatar(png, 'image/png');
    expect(await auth.avatar(), png);
    expect((await auth.me()).hasAvatar, isTrue);

    await auth.deleteAvatar();
    expect(await auth.avatar(), isNull);
  });

  test('hapus transaksi mengembalikan saldo', () async {
    await transactions.delete(transactionId);
    final list = await wallets.list();
    final updated = list.firstWhere((w) => w.id == walletId);
    expect(updated.balance, 100000.0);
  });

  test('error API jadi ApiException dengan pesan dari server', () async {
    await expectLater(
      auth.login(email: email, password: 'salahbanget'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Email atau password salah'),
        ),
      ),
    );
  });

  tearDownAll(() async {
    // Wallet dihapus supaya transaksi sisa ikut hilang, baru kategorinya bisa lepas.
    try {
      await wallets.delete(walletId);
      await wallets.delete(secondWalletId);
      await categories.delete(categoryId);
    } catch (_) {
      // Bersih-bersih gagal bukan alasan test dianggap gagal.
    }
  });
}
