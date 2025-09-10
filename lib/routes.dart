import 'package:go_router/go_router.dart';
import 'package:petcare/features/settings/placeholder.dart';
import 'package:petcare/ui/home.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPlaceholder(),
    ),
  ],
);
