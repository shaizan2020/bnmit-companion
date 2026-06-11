import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bnmit_companion/core/theme.dart';
import 'package:bnmit_companion/core/router.dart';
import 'package:bnmit_companion/providers/theme_provider.dart';

import 'package:bnmit_companion/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notification service initialization failed: $e');
  }
  runApp(const ProviderScope(child: BNMITCompanionApp()));
}

class BNMITCompanionApp extends ConsumerWidget {
  const BNMITCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BNMIT Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
