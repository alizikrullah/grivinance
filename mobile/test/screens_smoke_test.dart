import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grivinance/core/router/app_router.dart';
import 'package:grivinance/data/models/category_model.dart';
import 'package:grivinance/data/services/api_service.dart';
import 'package:grivinance/data/services/storage_service.dart';
import 'package:grivinance/providers/auth_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Merender semua layar dengan data palsu, tanpa jaringan. Gagal kalau ada
/// error layout (overflow, lebar tak terbatas) atau exception saat build —
/// kelas bug yang nggak ketangkap `flutter analyze`.

class _MemoryStorage extends StorageService {
  _MemoryStorage({this.signedIn = true});

  final bool signedIn;

  @override
  Future<String?> readAccessToken() async => signedIn ? 'token' : null;
  @override
  Future<String?> readRefreshToken() async => 'refresh';
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<bool> readHideBalance() async => false;
  @override
  Future<void> saveHideBalance(bool hide) async {}
}

Map<String, Object?> _ref(String id, String name, String icon, String color) =>
    {'id': id, 'name': name, 'icon': icon, 'color': color};

Map<String, Object?> _tx(
  String id,
  String type, {
  String amount = '25000.00',
  String? categoryId = 'c1',
  String? toWalletId,
  String? fee,
  String? feeForId,
}) => {
  'id': id,
  'walletId': 'w1',
  'categoryId': categoryId,
  'toWalletId': toWalletId,
  'feeForId': feeForId,
  'type': type,
  'amount': amount,
  'fee': fee,
  'note': id == 't1' ? 'Kopi susu gula aren yang namanya panjang sekali' : null,
  'date': '2026-10-05T03:00:00.000Z',
  'wallet': _ref('w1', 'BCA Utama', 'logo:bca', '#3B82F6'),
  'toWallet': toWalletId == null ? null : _ref('w2', 'DANA', 'logo:dana', '#0EA5E9'),
  'category': categoryId == null ? null : _ref(categoryId, 'Makan', 'restaurant', '#F97316'),
};

final _transactions = [
  _tx('t1', 'expense'),
  _tx('t2', 'income', amount: '7500000.00', categoryId: 'c2'),
  _tx('t3', 'transfer', categoryId: null, toWalletId: 'w2', fee: '2500.00'),
  _tx('t4', 'expense', amount: '2500.00', categoryId: 'cat_biaya_admin', feeForId: 't3'),
];

final _periodSummary = {
  'totalIncome': '7500000.00',
  'totalExpense': '1275000.00',
  'byCategory': [
    {..._ref('c1', 'Makan', 'restaurant', '#F97316'), 'categoryId': 'c1', 'type': 'expense', 'total': '1250000.00'},
    {..._ref('cat_biaya_admin', 'Biaya Admin', 'receipt_long', '#78716C'), 'categoryId': 'cat_biaya_admin', 'type': 'expense', 'total': '25000.00'},
    {..._ref('c2', 'Gaji', 'work', '#10B981'), 'categoryId': 'c2', 'type': 'income', 'total': '7500000.00'},
  ],
};

final Map<String, Object?> _gamification = {
  'xp': 230,
  'level': 3,
  'title': 'Pemula Hemat',
  'levelXp': 30,
  'nextLevelXp': 100,
  'streak': {'current': 5, 'longest': 9, 'recordedToday': true},
  'missions': [
    {'key': 'expense_1', 'title': 'Catat 1 pengeluaran', 'xp': 10, 'done': true, 'claimed': false, 'progress': 1, 'target': 1},
    {'key': 'records_3', 'title': 'Catat 3 transaksi', 'xp': 20, 'done': false, 'claimed': false, 'progress': 2, 'target': 3},
    {'key': 'streak_3', 'title': 'Jaga streak 3 hari', 'xp': 15, 'done': true, 'claimed': true, 'progress': 3, 'target': 3},
    {'key': 'under_budget', 'title': 'Kemarin di bawah jatah', 'xp': 30, 'done': false, 'claimed': false, 'progress': 0, 'target': 1, 'spent': '80000.00', 'limit': '66666.67'},
  ],
  'achievements': [
    {'key': 'first_tx', 'title': 'Langkah Pertama', 'description': 'Catat transaksi pertama', 'icon': 'flag', 'xp': 50, 'target': 1, 'progress': 1, 'unlocked': true, 'unlockedAt': '2026-10-01T00:00:00.000Z'},
    {'key': 'tx_100', 'title': 'Rajin Nyatet', 'description': 'Catat 100 transaksi', 'icon': 'edit_note', 'xp': 50, 'target': 100, 'progress': 37, 'unlocked': false, 'unlockedAt': null},
  ],
  'newlyUnlocked': ['first_tx'],
};

Object? _route(RequestOptions options, {required bool empty}) {
  final path = options.path;
  if (empty) {
    if (path == '/api/wallets' || path == '/api/categories') return [];
    if (path == '/api/transactions') {
      return {
        'items': [],
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 0},
      };
    }
    if (path == '/api/summary/daily' || path == '/api/summary/monthly') {
      return {'totalIncome': '0.00', 'totalExpense': '0.00', 'byCategory': []};
    }
    if (path == '/api/budgets') {
      return {'year': 2026, 'month': 10, 'totalBudget': '0.00', 'totalSpent': '0.00', 'remaining': '0.00', 'items': []};
    }
    if (path == '/api/gamification') {
      return {
        ..._gamification,
        'xp': 0,
        'level': 1,
        'levelXp': 0,
        'streak': {'current': 0, 'longest': 0, 'recordedToday': false},
        'newlyUnlocked': [],
      };
    }
  }
  if (path == '/api/auth/me') {
    return {
      'id': 'u1',
      'email': 'tes@grivinance.local',
      'name': 'Tester Panjang Sekali Namanya',
      'nickname': 'Tes',
      'phone': '081234567890',
      'birthDate': '1999-04-17',
      'createdAt': '2026-09-01T00:00:00.000Z',
      'avatarUpdatedAt': null,
    };
  }
  if (path == '/api/wallets') {
    return [
      {'id': 'w1', 'name': 'BCA Utama', 'type': 'bank', 'balance': '12500000.00', 'icon': 'logo:bca', 'color': '#3B82F6', 'transactionCount': 3},
      {'id': 'w2', 'name': 'DANA', 'type': 'e_wallet', 'balance': '-20000.00', 'icon': 'logo:dana', 'color': '#0EA5E9', 'transactionCount': 0},
    ];
  }
  if (path == '/api/categories') {
    return [
      {..._ref('c1', 'Makan', 'restaurant', '#F97316'), 'type': 'expense', 'userId': null, 'transactionCount': 4},
      {..._ref('c2', 'Gaji', 'work', '#10B981'), 'type': 'income', 'userId': null, 'transactionCount': 1},
      {..._ref('c3', 'Kopi', 'coffee', '#A855F7'), 'type': 'expense', 'userId': 'u1', 'transactionCount': 2},
    ];
  }
  if (path == '/api/transactions') {
    return {
      'items': _transactions,
      'pagination': {'page': 1, 'limit': 20, 'total': 4, 'totalPages': 1},
    };
  }
  if (path.startsWith('/api/transactions/')) {
    final id = path.split('/').last;
    return _transactions.firstWhere((t) => t['id'] == id);
  }
  if (path == '/api/summary/daily' || path == '/api/summary/monthly') return _periodSummary;
  if (path == '/api/summary/yearly') {
    return {
      'year': 2026,
      'totalIncome': '7500000.00',
      'totalExpense': '1275000.00',
      'months': [
        for (var m = 1; m <= 12; m++)
          {'month': m, 'income': m == 10 ? '7500000.00' : '0.00', 'expense': m == 10 ? '1275000.00' : '0.00'},
      ],
    };
  }
  if (path == '/api/budgets') {
    return {
      'year': 2026,
      'month': 10,
      'totalBudget': '1500000.00',
      'totalSpent': '1275000.00',
      'remaining': '225000.00',
      'items': [
        {'categoryId': 'c1', 'name': 'Makan', 'icon': 'restaurant', 'color': '#F97316', 'amount': '1000000.00', 'spent': '1250000.00', 'remaining': '-250000.00'},
        {'categoryId': 'cat_biaya_admin', 'name': 'Biaya Admin', 'icon': 'receipt_long', 'color': '#78716C', 'amount': '500000.00', 'spent': '25000.00', 'remaining': '475000.00'},
      ],
    };
  }
  if (path == '/api/gamification') return _gamification;
  return null;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.empty = false});

  final bool empty;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = _route(options, empty: empty);
    final body = data == null
        ? {'success': false, 'message': 'Tidak ada', 'errors': []}
        : {'success': true, 'message': 'ok', 'data': data};
    return ResponseBody.fromString(
      jsonEncode(body),
      data == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Pasang app dengan API palsu di layar seukuran HP (±392 x 850 dp).
Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  bool signedIn = true,
  bool empty = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  final storage = _MemoryStorage(signedIn: signedIn);
  final api = ApiService(storage)..dio.httpClientAdapter = _FakeAdapter(empty: empty);
  final container = ProviderContainer(
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
      apiServiceProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: ThemeData.dark(useMaterial3: true),
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('semua layar ke-render tanpa error layout', (tester) async {
    final container = await _pumpApp(tester);

    // Beranda + perayaan lencana baru (newlyUnlocked).
    expect(find.text('Hai, Tes! 👋'), findsOneWidget);
    expect(find.text('Lencana baru!'), findsOneWidget);
    await tester.tap(find.text('Mantap'));
    await tester.pumpAndSettle();
    expect(find.text('Misi harian'), findsOneWidget);

    // Scroll Beranda sampai bawah supaya semua section ikut dibangun.
    await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
    await tester.pumpAndSettle();

    for (final tab in [1, 2, 3, 0]) {
      container.read(homeTabProvider.notifier).state = tab;
      await tester.pumpAndSettle();
    }

    final router = container.read(routerProvider);
    final routes = [
      AppRoutes.wallets,
      AppRoutes.walletDetail('w1'),
      AppRoutes.walletEdit('w1'),
      AppRoutes.walletNew,
      AppRoutes.categories,
      AppRoutes.categoryEdit('c3'),
      AppRoutes.budgets,
      AppRoutes.achievements,
      AppRoutes.profile,
      AppRoutes.transactionNew,
      AppRoutes.newTransaction(type: TxType.transfer, walletId: 'w1'),
      AppRoutes.transactionDetail('t1'),
      AppRoutes.transactionDetail('t3'),
      AppRoutes.transactionDetail('t4'),
      AppRoutes.transactionEdit('t2'),
      AppRoutes.transactionEdit('t3'),
    ];
    for (final route in routes) {
      router.push(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      router.pop();
      await tester.pumpAndSettle();
    }

    // Tab Grafik: ketiga sub-tab.
    container.read(homeTabProvider.notifier).state = 2;
    await tester.pumpAndSettle();
    for (final label in ['Bulanan', 'Tahunan', 'Harian']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('akun baru tanpa data: state kosong nggak meluber', (tester) async {
    final container = await _pumpApp(tester, empty: true);

    // Chip pakai Text.rich dengan ikon di depan, jadi cocokkan sebagian teksnya.
    expect(find.textContaining('Mulai streak'), findsOneWidget);
    expect(find.text('Lencana baru!'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada wallet'), findsOneWidget);

    final router = container.read(routerProvider);
    for (final route in [
      AppRoutes.transactionNew,
      AppRoutes.budgets,
      AppRoutes.wallets,
      AppRoutes.newTransaction(type: TxType.transfer),
    ]) {
      router.push(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      router.pop();
      await tester.pumpAndSettle();
    }

    for (final tab in [1, 2, 3]) {
      container.read(homeTabProvider.notifier).state = tab;
      await tester.pumpAndSettle();
    }
  });

  testWidgets('belum login: layar login (dengan pesan sesi) dan register', (tester) async {
    final container = await _pumpApp(tester, signedIn: false);

    container.read(sessionNoticeProvider.notifier).state = 'Sesi kamu berakhir, silakan masuk lagi';
    await tester.pumpAndSettle();
    expect(find.textContaining('Sesi kamu berakhir'), findsOneWidget);

    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    expect(find.text('Buat akun'), findsOneWidget);
  });
}
