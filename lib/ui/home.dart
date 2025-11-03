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

  // In-memory route history for tab navigation
  final List<String> _routeHistory = <String>[];
  String? _currentTrackedLocation;

  @override
  void initState() {
    super.initState();
    _loadLastSelectedPetId();
  }

  void _recordRouteIfChanged(String newLocation) {
    // Track only main app routes (tabs and pet detail)
    final isTrackable = newLocation == '/settings' || newLocation == '/' || newLocation.startsWith('/pets/');
    if (!isTrackable) {
      _currentTrackedLocation = newLocation;
      return;
    }

    if (_currentTrackedLocation == null) {
      _currentTrackedLocation = newLocation;
      return;
    }

    if (_currentTrackedLocation != newLocation) {
      // Push previous trackable location into history as a back target
      if (_routeHistory.isEmpty || _routeHistory.last != _currentTrackedLocation) {
        _routeHistory.add(_currentTrackedLocation!);
        if (_routeHistory.length > 30) {
          _routeHistory.removeAt(0);
        }
      }
      _currentTrackedLocation = newLocation;
    }
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

  Future<void> _saveLastRoute(String route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_route', route);
    } catch (_) {}
  }

  Future<bool> _onWillPop() async {
    // Pop to last recorded tab route if present
    if (_routeHistory.isNotEmpty) {
      final target = _routeHistory.removeLast();
      context.go(target);
      return false;
    }

    // If on settings and no history, go to a safe pet route or root
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/settings' || location.startsWith('/settings')) {
      try {
        String? petId = _currentPetId;
        if (petId == null || petId.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          petId = prefs.getString('last_selected_pet_id');
        }
        if (petId != null && petId.isNotEmpty) {
          context.go('/pets/$petId');
        } else {
          context.go('/');
        }
        return false;
      } catch (_) {
        context.go('/');
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final petsState = ref.watch(petsProvider);

    // Record route transitions globally
    _recordRouteIfChanged(location);
    
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
      ),
    );
  }
}
