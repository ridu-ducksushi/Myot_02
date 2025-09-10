// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:petcare/main.dart';

void main() {
  testWidgets('PetCare app starts', (WidgetTester tester) async {
    await EasyLocalization.ensureInitialized();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
        path: 'assets/i18n',
        fallbackLocale: const Locale('ko'),
        child: const ProviderScope(child: PetCareApp()),
      ),
    );

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify that we can find some basic UI elements
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}