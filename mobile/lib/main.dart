import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wajib sebelum DateFormat pakai locale 'id_ID', kalau nggak dia lempar
  // LocaleDataException waktu format tanggal pertama.
  await initializeDateFormatting('id_ID');
  runApp(const ProviderScope(child: GrivinanceApp()));
}

class GrivinanceApp extends ConsumerWidget {
  const GrivinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Grivinance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
