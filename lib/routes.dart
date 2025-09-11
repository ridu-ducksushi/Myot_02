import 'package:go_router/go_router.dart';
import 'package:petcare/features/settings/placeholder.dart';
import 'package:petcare/features/pets/pet_detail_screen.dart';
import 'package:petcare/ui/home.dart';

final router = GoRouter(
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
  ],
);
