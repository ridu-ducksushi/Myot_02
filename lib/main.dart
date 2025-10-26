import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:petcare/data/services/admob_service.dart'; // AdMob 승인 전까지 비활성화

// import 'package:petcare/app/notifications.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
import 'package:petcare/routes.dart';
import 'package:petcare/ui/theme/app_theme.dart';
import 'package:petcare/app/bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize Firebase (임시 비활성화)
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://uvbyxqdkxyhlbntvzyuo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2Ynl4cWRreHlobGJudHZ6eXVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTczNDIxNDMsImV4cCI6MjA3MjkxODE0M30.ftMFqFomXgaxR3FaynZyNxViH1eREMBLSc0rseanaxM',
  );
  print('✅ 실제 Supabase 연결 완료');

  // Initialize app services
  await AppBootstrap.initialize();

  // Initialize AdMob (AdMob 승인 전까지 비활성화)
  // await AdMobService.initialize();

  // Initialize FCM (임시 비활성화)
  // await initNotifications();

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
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: 1.0, // 시스템 폰트 크기 변경 무시하고 고정
      ),
      child: MaterialApp.router(
        title: 'PetCare',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        routerConfig: router,
      ),
    );
  }
}