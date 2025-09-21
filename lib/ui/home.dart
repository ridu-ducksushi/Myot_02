import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petcare/features/labs/placeholder.dart';
import 'package:petcare/features/pets/pets_screen.dart';
import 'package:petcare/features/pets/pet_detail_screen.dart';
import 'package:petcare/features/records/records_screen.dart';
import 'package:petcare/features/settings/placeholder.dart';
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
    // 현재 경로에 따라 탭 인덱스 결정
    final location = GoRouterState.of(context).matchedLocation;
    final petsState = ref.watch(petsProvider);
    
    if (location.startsWith('/pets/')) {
      // 펫 상세 화면과 하위 경로 처리
      final parts = location.split('/');
      if (parts.length >= 3) {
        _currentPetId = parts[2]; // 현재 펫 ID 저장
      }
      
      if (location.endsWith('/records')) {
        _currentIndex = 1; // Records 탭
      } else if (location.endsWith('/health')) {
        _currentIndex = 2; // Health 탭
      } else {
        _currentIndex = 0; // 기본 펫 상세 화면
      }
    } else if (location == '/records') {
      _currentIndex = 1;
    } else if (location == '/health') {
      _currentIndex = 2;
    } else if (location == '/settings') {
      _currentIndex = 3;
      // Settings 화면에서도 현재 펫 ID를 유지 (이미 설정된 경우)
      // 만약 _currentPetId가 null이면, 첫 번째 펫을 기본값으로 설정
      if (_currentPetId == null && petsState.pets.isNotEmpty) {
        _currentPetId = petsState.pets.first.id;
      }
    } else {
      _currentIndex = 0; // 기본값은 펫 탭
      // 메인 화면에서는 펫 ID 초기화
      _currentPetId = null;
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          
          // 현재 경로가 펫 상세 화면인지 확인
          final location = GoRouterState.of(context).matchedLocation;
          final isPetDetail = location.startsWith('/pets/') && location.contains('/');
          
          if (isPetDetail) {
            // 펫 상세 화면에서 하단 탭 클릭 시 해당 펫의 개별 화면으로 이동
            final petId = location.split('/')[2]; // /pets/{petId}/... 에서 petId 추출
            switch (index) {
              case 0:
                context.go('/pets/$petId'); // 해당 펫의 상세 페이지로 돌아가기
                break;
              case 1:
                context.go('/pets/$petId/records');
                break;
              case 2:
                context.go('/pets/$petId/health');
                break;
              case 3:
                context.go('/settings');
                break;
            }
          } else {
            // 일반 탭 네비게이션
            switch (index) {
              case 0:
                // Settings에서 Pets 탭 클릭 시, 현재 선택된 펫이 있다면 해당 펫으로 이동
                if (location == '/settings' && _currentPetId != null) {
                  context.go('/pets/$_currentPetId');
                } else {
                  context.go('/');
                }
                break;
              case 1:
                context.go('/records');
                break;
              case 2:
                context.go('/health');
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
      ),
    );
  }
}
