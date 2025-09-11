import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:petcare/features/labs/placeholder.dart';
import 'package:petcare/features/pets/pets_screen.dart';
import 'package:petcare/features/records/records_screen.dart';
import 'package:petcare/features/settings/placeholder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    PetsScreen(),
    RecordsScreen(), 
    LabsPlaceholder(),
    SettingsPlaceholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.pets),
            label: 'tabs.profile'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.list_alt),
            label: 'tabs.records'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite),
            label: 'tabs.health'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: 'tabs.settings'.tr(),
          ),
        ],
      ),
    );
  }
}
