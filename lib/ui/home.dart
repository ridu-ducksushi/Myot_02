import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  void initState() {
    super.initState();
    _loadLastSelectedPetId();
  }

  Future<void> _loadLastSelectedPetId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('last_selected_pet_id');
      if (mounted && saved != null && saved.isNotEmpty) {
        setState(() => _currentPetId = saved);
      }
    } catch (_) {}
  }

  Future<void> _saveLastSelectedPetId(String petId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_selected_pet_id', petId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final petsState = ref.watch(petsProvider);
    
    // 펫 상세 화면과 설정 화면에서 하단 탭 표시
    final isPetDetailRoute = location.startsWith('/pets/') && location.split('/').length >= 3;
    final isSettingsRoute = location == '/settings' || location.startsWith('/settings');
    final shouldShowBottomNav = isPetDetailRoute || isSettingsRoute;
    
    if (shouldShowBottomNav) {
      // 펫 ID 추출
      if (isPetDetailRoute) {
        final parts = location.split('/');
        if (parts.length >= 3) {
          _currentPetId = parts[2];
          _saveLastSelectedPetId(_currentPetId!);
        }
      } else if (_currentPetId == null) {
        // 설정 화면에서 재구성된 경우 마지막 선택 펫 복원 → 없으면 첫 번째 펫
        // _loadLastSelectedPetId() 비동기 복원을 기다리는 동안 일시 폴백
        if (petsState.pets.isNotEmpty) {
          _currentPetId = petsState.pets.first.id;
        }
      }
      
      // 탭 인덱스 결정
      if (location.endsWith('/records')) {
        _currentIndex = 1;
      } else if (location.endsWith('/health')) {
        _currentIndex = 2;
      } else if (isSettingsRoute) {
        _currentIndex = 3;
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
                _saveLastSelectedPetId(_currentPetId!);
                context.go('/pets/$_currentPetId');
                break;
              case 1:
                _saveLastSelectedPetId(_currentPetId!);
                context.go('/pets/$_currentPetId/records');
                break;
              case 2:
                _saveLastSelectedPetId(_currentPetId!);
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
