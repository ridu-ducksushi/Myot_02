import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:petcare/features/auth/login_screen.dart';
import 'package:petcare/features/auth/signup_screen.dart';
import 'package:petcare/features/settings/placeholder.dart';
import 'package:petcare/features/pets/pet_detail_screen.dart';
import 'package:petcare/ui/home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

// This listenable will notify the router when the auth state changes.
final _authChangeNotifier = GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange);

final router = GoRouter(
  initialLocation: '/login',
  // Listen to auth state changes and rebuild the router when they occur.
  refreshListenable: _authChangeNotifier,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'pets/:petId',
          builder: (context, state) => PetDetailScreen(
            petId: state.pathParameters['petId']!,
          ),
          routes: [
            GoRoute(
              path: 'records',
              builder: (context, state) => const SettingsPlaceholder(), // TODO: Pet Records Screen
            ),
            GoRoute(
              path: 'reminders',
              builder: (context, state) => const SettingsPlaceholder(), // TODO: Pet Reminders Screen
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPlaceholder(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = Supabase.instance.client.auth.currentSession != null;
    final bool onAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

    // If the user is not logged in and not on an auth route, redirect to login.
    if (!loggedIn && !onAuthRoute) {
      return '/login';
    }

    // If the user is logged in and on an auth route, redirect to home.
    if (loggedIn && onAuthRoute) {
      return '/';
    }

    // No redirect needed.
    return null;
  },
);

// A simple class to convert a Stream to a Listenable for GoRouter.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
