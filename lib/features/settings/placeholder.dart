import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/data/local/database.dart';
import 'package:petcare/data/services/image_service.dart';
import 'package:petcare/features/pets/pets_screen.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
// import 'package:petcare/ui/widgets/banner_ad_widget.dart'; // AdMob 승인 전까지 비활성화
import 'package:petcare/ui/theme/app_colors.dart';
import 'package:petcare/data/models/pet.dart';

class SettingsPlaceholder extends ConsumerStatefulWidget {
  const SettingsPlaceholder({super.key});

  @override
  ConsumerState<SettingsPlaceholder> createState() => _SettingsPlaceholderState();
}

class _SettingsPlaceholderState extends ConsumerState<SettingsPlaceholder> {
  @override
  void initState() {
    super.initState();
    // Supabase 인증 상태 변화를 감지
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      // 캐시는 사용자 스코프 키로 분리되어 있으므로 전역 삭제하지 않음
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그아웃 완료.')));
      }
      // The GoRouter redirect will handle navigation to the login screen.
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e')),
        );
      }
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'ridusoft@gmail.com',
        query: 'subject=Myot 문의&body=안녕하세요, Myot 앱에 대해 문의드립니다.',
      );
      
      print('이메일 URI: $emailUri');
      
      // canLaunchUrl 체크를 건너뛰고 직접 실행 시도
      final bool launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      
      if (launched) {
        print('이메일 앱이 성공적으로 실행되었습니다.');
      } else {
        print('이메일 앱 실행 실패, 클립보드에 복사합니다.');
        await Clipboard.setData(const ClipboardData(text: 'ridusoft@gmail.com'));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이메일 주소가 클립보드에 복사되었습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('이메일 발송 오류: $e');
      // 오류 발생 시에도 클립보드에 복사
      await Clipboard.setData(const ClipboardData(text: 'ridusoft@gmail.com'));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이메일 주소가 클립보드에 복사되었습니다. 오류: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteRequest(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 삭제'),
        content: const Text(
          '이 작업은 되돌릴 수 없습니다.\n\n'
          '• 서버에 저장된 모든 데이터(펫, 기록, 리마인더)가 삭제됩니다.\n'
          '• 인증 계정도 삭제되어 재로그인이 불가합니다.\n'
          '• 로컬 캐시 데이터도 정리됩니다.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('완전 삭제'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _performHardDelete(context);
    }
  }

  Future<void> _performHardDelete(BuildContext context) async {
    if (!context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (context.mounted) Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }

      print('🔄 계정 삭제 시작: ${user.id}');

      // Ensure fresh session (older emulators may have skew causing token invalidation)
      try {
        print('🔄 세션 새로고침 시도...');
        await Supabase.instance.client.auth.refreshSession();
        print('✅ 세션 새로고침 성공');
      } catch (e) {
        print('⚠️ 세션 새로고침 실패 (무시하고 진행): $e');
      }

      // Invoke Edge Function with JWT to delete server-side data and auth user
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;
      if (token == null) {
        if (context.mounted) Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('세션이 만료되었습니다. 다시 로그인 후 시도해주세요.')),
          );
        }
        return;
      }

      print('🔑 JWT 토큰 획득 완료: ${token.substring(0, 20)}...');

      Future<dynamic> _call() async {
        print('📞 Edge Function 호출 중...');
        final result = await Supabase.instance.client.functions.invoke(
          'delete-account',
          body: const {},
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        print('📞 Edge Function 응답: ${result.data}');
        return result;
      }

      dynamic response;
      try {
        response = await _call().timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            print('⏱️ Edge Function 타임아웃 (20초)');
            throw TimeoutException('서버 응답 시간 초과');
          },
        );
      } on TimeoutException catch (e) {
        print('⏱️ 첫 시도 타임아웃, 재시도 중...');
        // One-time retry for slow/older emulators or flaky network
        response = await _call().timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            print('⏱️ Edge Function 재시도 타임아웃 (20초)');
            throw TimeoutException('서버 응답 시간 초과 (재시도 실패)');
          },
        );
      }

      print('📊 Edge Function 응답 타입: ${response.runtimeType}');
      print('📊 Edge Function 응답 데이터: ${response.data}');

      // Check response
      final data = response.data;
      final isSuccess = data is Map && data['ok'] == true;

      if (!isSuccess) {
        final errorDetail = data is Map 
            ? (data['error']?.toString() ?? data.toString())
            : data?.toString() ?? '알 수 없는 오류';
        print('❌ Edge Function 실패: $errorDetail');
        throw Exception('서버 삭제 실패: $errorDetail');
      }

      print('✅ 서버 데이터 삭제 완료');

      // Clear local scoped caches
      print('🗑️ 로컬 캐시 삭제 중...');
      await LocalDatabase.instance.clearAll();
      print('✅ 로컬 캐시 삭제 완료');

      // Delete all locally saved images
      print('🗑️ 로컬 이미지 삭제 중...');
      await ImageService.deleteAllSavedImages();
      print('✅ 로컬 이미지 삭제 완료');

      // Sign out locally (session becomes invalid anyway after auth deletion)
      print('🚪 로그아웃 중...');
      await Supabase.instance.client.auth.signOut();
      print('✅ 로그아웃 완료');
      print('✅ 계정 삭제 완료');

      // Navigation will happen automatically via auth redirect (GoRouter)
      // No need to manually pop or navigate
    } catch (e, stackTrace) {
      print('❌ 계정 삭제 오류: $e');
      print('❌ 스택 트레이스: $stackTrace');

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 중 오류가 발생했습니다.\n오류: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '문의',
              onPressed: () => _sendEmail(context),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showDeletePetDialog(BuildContext context, WidgetRef ref, Pet pet) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('pets.delete_confirm_title'.tr()),
        content: Text('pets.delete_confirm_message'.tr(args: [pet.name])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await ref.read(petsProvider.notifier).deletePet(pet.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('pets.delete_success'.tr(args: [pet.name])),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('pets.delete_error'.tr(args: [pet.name])),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final petsState = ref.watch(petsProvider);
    final currentLocation = GoRouterState.of(context).matchedLocation;
    
    // 현재 선택된 펫 ID 추출
    String? currentPetId;
    if (currentLocation.startsWith('/pets/')) {
      final parts = currentLocation.split('/');
      if (parts.length >= 3) {
        currentPetId = parts[2];
      }
    }
    
    final currentPet = currentPetId != null 
        ? petsState.pets.where((pet) => pet.id == currentPetId).firstOrNull
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('tabs.settings'.tr()),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      ),
      body: ListView(
        children: [
          // 사용자 프로필 섹션
          _buildUserProfileSection(context),
          
          const SizedBox(height: 2),
          
          // 펫 정보 섹션 (통합)
          SectionHeader(title: '펫 정보'),
          
          // 가로 스크롤 가능한 펫 카드들
          SizedBox(
            height: 240, // 카드 높이
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: petsState.pets.length + 1, // 펫들 + 새 펫 추가 카드
              itemBuilder: (context, index) {
                if (index < petsState.pets.length) {
                  // 기존 펫 카드
                  final pet = petsState.pets[index];
                  return Container(
                    width: 200, // 카드 너비
                    child: _buildHorizontalPetCard(context, ref, pet),
                  );
                } else {
                  // 새 펫 추가 카드
                  return Container(
                    width: 200,
                    child: _buildAddPetCard(context),
                  );
                }
              },
            ),
          ),
          
          const SizedBox(height: 2),
          
          // 문의하기 섹션
          SectionHeader(title: 'contact.title'.tr()),
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.email, color: AppColors.primary),
              title: Text('ridusoft@gmail.com'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _sendEmail(context),
            ),
          ),
          
          const SizedBox(height: 2),
          
          // 계정 설정 섹션
          SectionHeader(title: '계정 설정'),
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: Text('로그아웃'),
              subtitle: Text('세션을 종료하고 로그인 화면으로 돌아갑니다.'),
              onTap: () => _signOut(context),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.error),
              title: const Text('계정 삭제'),
              subtitle: const Text('계정 및 모든 데이터가 영구 삭제됩니다.'),
              onTap: () => _confirmDeleteRequest(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _EditProfileSheet(),
    );
  }

  Widget _buildUserProfileSection(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Unknown';
    final displayName = user?.userMetadata?['display_name'] as String? ?? 
                      user?.userMetadata?['full_name'] as String? ?? 
                      email.split('@').first;
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // 사용자 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '내 프로필',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 편집 아이콘
              IconButton(
                onPressed: () => _showEditProfileDialog(context),
                icon: Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalPetCard(BuildContext context, WidgetRef ref, pet) {
    final speciesColor = AppColors.getSpeciesColor(pet.species);
    
    return AppCard(
      onTap: () => context.go('/pets/${pet.id}'),
      onLongPress: () => _showDeletePetDialog(context, ref, pet),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 펫 아바타
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: speciesColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: speciesColor.withOpacity(0.3), width: 2),
              ),
              child: pet.defaultIcon != null
                  ? _buildDefaultIcon(context, pet.defaultIcon, speciesColor, species: pet.species, bgColor: pet.profileBgColor)
                  : pet.avatarUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.file(
                            File(pet.avatarUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildDefaultIcon(context, pet.defaultIcon, speciesColor, species: pet.species, bgColor: pet.profileBgColor),
                          ),
                        )
                      : _buildDefaultIcon(context, pet.defaultIcon, speciesColor, species: pet.species, bgColor: pet.profileBgColor),
            ),
            const SizedBox(height: 12),
            
            // 펫 이름
            Text(
              pet.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            
            // 펫 종류
            Transform.scale(
              scale: 0.8,
              child: PetSpeciesChip(species: pet.species),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPetCard(BuildContext context) {
    return AppCard(
      onTap: () => _showAddPetDialog(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 추가 아이콘
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            
            // 추가 텍스트
            Text(
              '새 펫 추가',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPetDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddPetSheet(),
    );
  }

  Widget _buildDefaultIcon(BuildContext context, String? defaultIcon, Color fallbackColor, {String? species, String? bgColor}) {
    if (defaultIcon != null) {
      // Supabase Storage에서 이미지 URL 가져오기
      final imageUrl = ImageService.getDefaultIconUrl(species ?? 'cat', defaultIcon);
      if (imageUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
              // 배경색
              if (bgColor != null)
                Image.asset(
                  'assets/images/profile_bg/$bgColor.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              // 아이콘
              Image.asset(
                imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Assets 이미지 로드 실패 시 기존 아이콘으로 폴백
                  final iconData = _getDefaultIconData(defaultIcon);
                  final color = _getDefaultIconColor(defaultIcon);
                  return Icon(
                    iconData,
                    size: 30,
                    color: color,
                  );
                },
              ),
            ],
          ),
        );
      }
      
      // 폴백: 기존 아이콘 방식
      final iconData = _getDefaultIconData(defaultIcon);
      final color = _getDefaultIconColor(defaultIcon);
      
      return Icon(
        iconData,
        size: 30,
        color: color,
      );
    }
    
    return Icon(Icons.pets, color: fallbackColor, size: 30);
  }

  // 기본 아이콘 데이터 매핑
  IconData _getDefaultIconData(String iconName) {
    switch (iconName) {
      case 'dog1':
        return Icons.pets;
      case 'dog2':
        return Icons.pets_outlined;
      case 'cat1':
        return Icons.cruelty_free;
      case 'cat2':
        return Icons.cruelty_free_outlined;
      case 'rabbit':
        return Icons.cruelty_free;
      case 'bird':
        return Icons.flight;
      case 'fish':
        return Icons.water_drop;
      case 'hamster':
        return Icons.circle;
      case 'turtle':
        return Icons.circle_outlined;
      case 'heart':
        return Icons.favorite;
      default:
        return Icons.pets;
    }
  }

  // 기본 아이콘 색상 매핑
  Color _getDefaultIconColor(String iconName) {
    switch (iconName) {
      case 'dog1':
        return const Color(0xFF8B4513); // 갈색
      case 'dog2':
        return const Color(0xFF9370DB); // 보라색
      case 'cat1':
        return const Color(0xFF808080); // 회색
      case 'cat2':
        return const Color(0xFF2F4F4F); // 어두운 회색
      case 'rabbit':
        return const Color(0xFFFFB6C1); // 연분홍
      case 'bird':
        return const Color(0xFF87CEEB); // 하늘색
      case 'fish':
        return const Color(0xFF4169E1); // 로얄블루
      case 'hamster':
        return const Color(0xFFDEB887); // 버프색
      case 'turtle':
        return const Color(0xFF9ACD32); // 옐로우그린
      case 'heart':
        return const Color(0xFFFF69B4); // 핫핑크
      default:
        return const Color(0xFF666666);
    }
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  void _loadCurrentProfile() {
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = user?.userMetadata?['display_name'] as String? ?? 
                      user?.userMetadata?['full_name'] as String? ?? 
                      '';
    
    _displayNameController.text = displayName;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final displayName = _displayNameController.text.trim();
      
      print('🔧 프로필 업데이트 시도: displayName=$displayName');

      // 사용자 메타데이터 업데이트 (닉네임만)
      final metadata = <String, dynamic>{
        'display_name': displayName,
      };

      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: metadata),
      );

      print('✅ 프로필 업데이트 응답: ${response.user?.userMetadata}');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 업데이트되었습니다.')),
        );
      }
    } catch (e) {
      print('❌ 프로필 업데이트 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 업데이트 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.8,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    '프로필 편집',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  
                  // Display Name
                  AppTextField(
                    controller: _displayNameController,
                    labelText: '닉네임',
                    prefixIcon: const Icon(Icons.person),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return '닉네임을 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  
                  const Spacer(),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : _updateProfile,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('저장'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddPetSheet extends ConsumerStatefulWidget {
  const _AddPetSheet();

  @override
  ConsumerState<_AddPetSheet> createState() => _AddPetSheetState();
}

class _AddPetSheetState extends ConsumerState<_AddPetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _noteController = TextEditingController();
  
  String _selectedSpecies = 'Dog';
  String? _selectedSex;
  bool? _isNeutered;
  DateTime? _birthDate;
  
  final List<String> _species = [
    'Dog', 'Cat', 'Other'
  ];
  
  final List<String> _sexOptions = ['남아', '여아'];

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    'pets.add_new'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  
                  // Form fields
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        AppTextField(
                          controller: _nameController,
                          labelText: 'pets.name'.tr(),
                          prefixIcon: const Icon(Icons.pets),
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'pets.name_required'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          value: _selectedSpecies,
                          decoration: InputDecoration(
                            labelText: 'pets.species'.tr(),
                            prefixIcon: const Icon(Icons.category),
                          ),
                          items: _species.map((species) {
                            return DropdownMenuItem(
                              value: species,
                              child: Text(species),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSpecies = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _breedController,
                          labelText: 'pets.breed'.tr(),
                          prefixIcon: const Icon(Icons.info_outline),
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          value: _selectedSex,
                          decoration: InputDecoration(
                            labelText: 'pets.sex'.tr(),
                            prefixIcon: const Icon(Icons.wc),
                          ),
                          items: _sexOptions.map((sex) {
                            return DropdownMenuItem(
                              value: sex,
                              child: Text(sex),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSex = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        CheckboxListTile(
                          title: Text('pets.neutered'.tr()),
                          subtitle: Text('pets.neutered_description'.tr()),
                          value: _isNeutered ?? false,
                          onChanged: (value) {
                            setState(() {
                              _isNeutered = value;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _weightController,
                          labelText: 'pets.weight_kg'.tr(),
                          prefixIcon: const Icon(Icons.monitor_weight),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isNotEmpty == true) {
                              final weight = double.tryParse(value!);
                              if (weight == null || weight <= 0) {
                                return 'pets.weight_invalid'.tr();
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        ListTile(
                          leading: const Icon(Icons.cake),
                          title: Text('pets.birth_date'.tr()),
                          subtitle: Text(
                            _birthDate != null
                                ? DateFormat.yMMMd().format(_birthDate!)
                                : 'pets.select_birth_date'.tr(),
                          ),
                          onTap: _selectBirthDate,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _noteController,
                          labelText: 'pets.notes'.tr(),
                          prefixIcon: const Icon(Icons.note),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  
                  // Buttons
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('common.cancel'.tr()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _savePet,
                          child: Text('common.save'.tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _birthDate = date;
      });
    }
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) return;
    
    // 남아/여아를 Male/Female로 변환 (DB 저장용)
    String? sexForDb = _selectedSex;
    if (_selectedSex == '남아') sexForDb = 'Male';
    if (_selectedSex == '여아') sexForDb = 'Female';
    
    final pet = Pet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: '', // Will be set by repository
      name: _nameController.text.trim(),
      species: _selectedSpecies,
      breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
      sex: sexForDb,
      neutered: _isNeutered,
      birthDate: _birthDate,
      weightKg: _weightController.text.isEmpty ? null : double.tryParse(_weightController.text),
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await ref.read(petsProvider.notifier).addPet(pet);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

}

