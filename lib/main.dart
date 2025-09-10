import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:petcare/app/notifications.dart';
// import 'firebase_options.dart'; // TODO: Run flutterfire configure
import 'package:petcare/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // TODO(setup): Uncomment after flutterfire configure
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  // Initialize FCM (non-breaking if Firebase not configured)
  await initNotifications();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
      path: 'assets/i18n',
      fallbackLocale: const Locale('ko'),
      child: const ProviderScope(child: PetCareApp()),
    ),
  );
}

class PetCareApp extends StatelessWidget {
  const PetCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PetCare',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: router,
    );
  }
}