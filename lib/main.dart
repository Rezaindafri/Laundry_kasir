import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/network/dio_client.dart';
import 'core/widgets/request_failure_listener.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const LaundryApp(),
    ),
  );
}

class LaundryApp extends ConsumerWidget {
  const LaundryApp({super.key});

  static final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: _messengerKey,
      routerConfig: router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.black,
          systemNavigationBarContrastEnforced: false,
        ),
        child: RequestFailureListener(
          events: DioClient().requestFailureEvents,
          messengerKey: _messengerKey,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
