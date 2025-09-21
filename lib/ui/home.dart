import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petcare/core/providers/pets_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  String? _currentPetId;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final petsState = ref.watch(petsProvider);
    
    // 펫 상세 화면에서만 하단 탭 표시
    final shouldShowBottomNav = location.startsWith('/pets/') && location.split('/').length >= 3;
    
    if (shouldShowBottomNav) {
      // 펫 ID 추출
      final parts = location.split('/');
      if (parts.length >= 3) {
        _currentPetId = parts[2];
      }
      
      // 탭 인덱스 결정
      if (location.endsWith('/records')) {
        _currentIndex = 1;
      } else if (location.endsWith('/health')) {
        _currentIndex = 2;
      } else {
        _currentIndex = 0;
      }
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: shouldShowBottomNav ? BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          
          if (_currentPetId != null) {
            switch (index) {
              case 0:
                context.go('/pets/$_currentPetId');
                break;
              case 1:
                context.go('/pets/$_currentPetId/records');
                break;
              case 2:
                context.go('/pets/$_currentPetId/health');
                break;
              case 3:
                context.go('/settings');
                break;
            }
          }
        },
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
      ) : null,
    );
  }
}
