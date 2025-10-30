import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/data/models/pet_supplies.dart';
import 'package:petcare/data/repositories/pet_supplies_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/widgets/profile_image_picker.dart';
import 'package:petcare/features/labs/weight_chart_screen.dart';
import 'package:petcare/ui/theme/app_colors.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PetDetailScreen extends ConsumerStatefulWidget {
  const PetDetailScreen({
    super.key,
    required this.petId,
  });

  final String petId;

  @override
  ConsumerState<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends ConsumerState<PetDetailScreen> {
  late DateTime _currentSuppliesDate;
  Set<DateTime> _suppliesRecordDates = {};
  PetSupplies? _currentSupplies;
  bool _isInitialized = false;
  late PetSuppliesRepository _suppliesRepository;

  @override
  void initState() {
    super.initState();
    // Repository 초기화는 build에서 수행
  }

  void _initialize(Pet pet) {
    if (_isInitialized) return;
    
    // Repository 초기화
    _suppliesRepository = PetSuppliesRepository(
      Supabase.instance.client,
    );
    
    // 오늘 날짜로 초기화 후, 저장된 선택 날짜가 있으면 복원
    _currentSuppliesDate = DateTime.now();
    _loadSelectedDate(pet.id);
    _loadSuppliesRecordDates();
    _loadCurrentSupplies();
    _isInitialized = true;
  }

  Future<void> _loadSelectedDate(String petId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString('selected_date_$petId');
      if (iso != null && iso.isNotEmpty) {
        final parts = iso.split('-');
        if (parts.length == 3) {
          _currentSuppliesDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _saveSelectedDate(String petId, DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await prefs.setString('selected_date_$petId', iso);
    } catch (_) {}
  }

  Future<void> _loadSuppliesRecordDates() async {
    try {
      final dates = await _suppliesRepository.getSuppliesRecordDates(widget.petId);
      if (mounted) {
        setState(() {
          _suppliesRecordDates = dates.toSet();
        });
      }
    } catch (e) {
      print('❌ Error loading supplies record dates: $e');
    }
  }

  Future<void> _loadCurrentSupplies() async {
    try {
      final supplies = await _suppliesRepository.getSuppliesByDate(
        widget.petId,
        _currentSuppliesDate,
      );
      if (mounted) {
        setState(() {
          _currentSupplies = supplies;
        });
      }
    } catch (e) {
      print('❌ Error loading current supplies: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(petByIdProvider(widget.petId));

    if (pet == null) {
      return Scaffold(
        appBar: AppBar(title: Text('pets.not_found'.tr())),
        body: AppEmptyState(
          icon: Icons.pets,
          title: 'pets.not_found'.tr(),
          message: 'pets.not_found_message'.tr(),
        ),
      );
    }

    // 펫 데이터가 로드되면 초기화
    _initialize(pet);

    return Scaffold(
      appBar: AppBar(
        title: Text('pets.profile'.tr()),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.95),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 프로필 → 펫 카드 목록으로 일관되게 이동
            context.go('/');
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Pet Header
            _buildPetHeader(context, pet),
            
            // Pet Supplies
            _buildPetSupplies(context, pet),
            
            const SizedBox(height: 100), // Bottom padding for navigation bar
          ],
        ),
      ),
    );
  }

  Widget _buildPetHeader(BuildContext context, Pet pet) {
    final speciesColor = AppColors.getSpeciesColor(pet.species);
    final age = _calculateAge(pet.birthDate);

    return InkWell(
      onTap: () => _editPet(context, pet),
      borderRadius: BorderRadius.circular(0),
      child: AppCard(
        borderRadius: BorderRadius.zero,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 왼쪽: 프로필 이미지와 편집 아이콘 + 종족/품종
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {}, // 빈 핸들러로 상위 InkWell 이벤트 차단
                      child: ProfileImagePicker(
                    imagePath: pet.avatarUrl,
                    selectedDefaultIcon: pet.defaultIcon,
                    selectedBgColor: pet.profileBgColor,
                    species: pet.species, // 동물 종류 전달
                    onImageSelected: (image) async {
                      if (image != null) {
                        // ProfileImagePicker에서 이미 저장된 파일을 받음
                        final updatedPet = pet.copyWith(
                          avatarUrl: image.path, // 이미 저장된 경로를 사용
                          defaultIcon: null, // 이미지 선택 시 기본 아이콘 제거
                          updatedAt: DateTime.now(),
                        );
                        
                        try {
                          await ref.read(petsProvider.notifier).updatePet(updatedPet);
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('pets.image_updated'.tr()),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('pets.image_update_error'.tr(args: [pet.name])),
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      } else {
                        // 이미지 삭제 및 기본 아이콘으로 설정
                        final updatedPet = pet.copyWith(
                          avatarUrl: null,
                          defaultIcon: 'dog1', // 기본 아이콘 설정
                          updatedAt: DateTime.now(),
                        );

                        try {
                          await ref.read(petsProvider.notifier).updatePet(updatedPet);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('프로필 이미지가 기본 아이콘으로 변경되었습니다.'),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('이미지 삭제에 실패했습니다.'),
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      }
                    },
                    onDefaultIconSelected: (iconName, bgColor) async {
                      // 기본 아이콘과 배경색을 함께 업데이트
                      final updatedPet = pet.copyWith(
                        defaultIcon: iconName,
                        profileBgColor: bgColor,
                        avatarUrl: null, // 기본 아이콘 선택 시 이미지 제거
                        updatedAt: DateTime.now(),
                      );
                      
                      try {
                        await ref.read(petsProvider.notifier).updatePet(updatedPet);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('프로필이 설정되었습니다'),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('프로필 설정에 실패했습니다'),
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
                    size: 136.5,
                    showEditIcon: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 종족과 품종
                    Column(
                      children: [
                        Transform.scale(
                          scale: 0.85,
                          child: PetSpeciesChip(species: pet.species),
                        ),
                        // 디버그: 품종 정보 로그
                        Builder(builder: (context) {
                          print('🔍 품종 정보: breed="${pet.breed}", isNull=${pet.breed == null}, isEmpty=${pet.breed?.isEmpty ?? true}');
                          return const SizedBox.shrink();
                        }),
                        if (pet.breed != null && pet.breed!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Transform.scale(
                            scale: 0.85,
                            child: Chip(
                              label: Text(pet.breed!),
                              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(width: 12),
                
                // 오른쪽: 펫 정보들
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름
                      Text(
                        pet.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 상세 정보들
                      Column(
                        children: [
                          if (age != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _InfoCard(
                                icon: Icons.cake,
                                label: 'pets.age'.tr(),
                                value: age,
                              ),
                            ),
                          if (pet.weightKg != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: InkWell(
                                  onTap: () => _editPet(context, pet),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.monitor_weight,
                                        size: 18,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${pet.weightKg}kg',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _showWeightChart(context, pet),
                                              child: Icon(
                                                Icons.bar_chart,
                                                size: 18,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (pet.sex != null)
                            _InfoCard(
                              icon: pet.sex!.toLowerCase() == 'male' || pet.sex == '남아' ? Icons.male : Icons.female,
                              label: 'pets.sex'.tr(),
                              value: _getSexWithNeuteredText(pet),
                            ),
                        ],
                      ),
                      
                      // 메모 섹션 (기록이 없어도 영역 유지)
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pet.note ?? '',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
        ),
        ),
      ),
    );
  }

  Widget _buildPetSupplies(BuildContext context, Pet pet) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: AppCard(
        borderRadius: BorderRadius.zero,
        margin: EdgeInsets.zero,
        elevation: 0,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 헤더 영역 (배경색 추가)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: const BoxConstraints(minHeight: 30),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 좌측 화살표 - 이전 기록으로 이동
                    InkWell(
                      onTap: () => _moveToPreviousSuppliesRecord(pet),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.chevron_left,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    
                    // 중앙 영역 - 날짜 + 달력 아이콘
                    InkWell(
                      onTap: () => _showSuppliesCalendarDialog(pet),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('yyyy년 MM월 dd일').format(_currentSuppliesDate),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    
                    // 우측 화살표 - 다음 기록 또는 오늘 날짜로 이동
                    InkWell(
                      onTap: () => _moveToNextSuppliesRecord(pet),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 물품 목록 영역
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // 날짜별 기록 표시 안내
              if (_currentSupplies == null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '선택한 날짜의 기록이 없습니다',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              InkWell(
                onTap: () => _editSupplies(context, pet),
                borderRadius: BorderRadius.circular(8),
                child: _buildSupplyItem(
                  context,
                  icon: Icons.restaurant,
                  label: '건사료',
                  value: _currentSupplies?.dryFood,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _editSupplies(context, pet),
                borderRadius: BorderRadius.circular(8),
                child: _buildSupplyItem(
                  context,
                  icon: Icons.rice_bowl,
                  label: '습식사료',
                  value: _currentSupplies?.wetFood,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _editSupplies(context, pet),
                borderRadius: BorderRadius.circular(8),
                child: _buildSupplyItem(
                  context,
                  icon: Icons.medication,
                  label: '영양제',
                  value: _currentSupplies?.supplement,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _editSupplies(context, pet),
                borderRadius: BorderRadius.circular(8),
                child: _buildSupplyItem(
                  context,
                  icon: Icons.cookie,
                  label: '간식',
                  value: _currentSupplies?.snack,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _editSupplies(context, pet),
                borderRadius: BorderRadius.circular(8),
                child: _buildSupplyItem(
                  context,
                  icon: Icons.cleaning_services,
                  label: '모래',
                  value: _currentSupplies?.litter,
                ),
              ),
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }

  Widget _buildSupplyItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value ?? 'supplies.add_placeholder'.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: value != null ? FontWeight.bold : FontWeight.normal,
                      color: value != null
                          ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;
    
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    
    // 생년월일 형식: yyyy.mm.dd
    final birthDateStr = '${birthDate.year}.${birthDate.month.toString().padLeft(2, '0')}.${birthDate.day.toString().padLeft(2, '0')}';
    
    // 나이 형식: yy년 mm개월
    final ageStr = '${years}년 ${months}개월';
    
    // 줄바꿈으로 생년월일과 나이를 분리 표기
    return '$birthDateStr\n($ageStr)';
  }

  String _getSexWithNeuteredText(Pet pet) {
    // 성별 텍스트
    String sexText = pet.sex == 'Male' ? '남아' : (pet.sex == 'Female' ? '여아' : pet.sex ?? '');
    
    // 중성화 여부 텍스트
    String neuteredText = '';
    if (pet.neutered == true) {
      neuteredText = ' / 중성화 완료';
    } else if (pet.neutered == false) {
      neuteredText = ' / 중성화 미완료';
    }
    
    return sexText + neuteredText;
  }

  void _editSupplies(BuildContext context, Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditSuppliesSheet(
        pet: pet, 
        selectedDate: _currentSuppliesDate,
        existingSupplies: _currentSupplies,
        onSaved: (savedSupplies, dates) {
          // 부모 상태 즉시 업데이트
          setState(() {
            _currentSupplies = savedSupplies;
            _currentSuppliesDate = savedSupplies.recordedAt;
            _suppliesRecordDates = dates.toSet();
          });
        },
      ),
    );
  }

  void _editPet(BuildContext context, Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditPetSheet(pet: pet),
    );
  }

  void _showWeightChart(BuildContext context, Pet pet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightChartScreen(
          petId: pet.id,
          petName: pet.name,
        ),
      ),
    );
  }

  // 이전 기록으로 이동
  void _moveToPreviousSuppliesRecord(Pet pet) {
    // 현재 날짜보다 이전 날짜 중 가장 최근 날짜 찾기
    final previousDates = _suppliesRecordDates
        .where((date) => date.isBefore(_currentSuppliesDate))
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (previousDates.isNotEmpty) {
      setState(() {
        _currentSuppliesDate = previousDates.first;
      });
      _saveSelectedDate(pet.id, _currentSuppliesDate);
      _loadCurrentSupplies();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이전 기록이 없습니다')),
      );
    }
  }

  // 다음 기록 또는 오늘 날짜로 이동
  void _moveToNextSuppliesRecord(Pet pet) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 현재 날짜보다 이후 날짜 중 가장 오래된 날짜 찾기
    final nextDates = _suppliesRecordDates
        .where((date) => date.isAfter(_currentSuppliesDate))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    if (nextDates.isNotEmpty) {
      setState(() {
        _currentSuppliesDate = nextDates.first;
      });
      _saveSelectedDate(pet.id, _currentSuppliesDate);
      _loadCurrentSupplies();
    } else if (!isSameDay(_currentSuppliesDate, today)) {
      // 다음 기록이 없으면 오늘로 이동
      setState(() {
        _currentSuppliesDate = today;
      });
      _saveSelectedDate(pet.id, _currentSuppliesDate);
      _loadCurrentSupplies();
    } else {
      // 이미 오늘 날짜인 경우
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 최신 기록입니다')),
      );
    }
  }

  // 달력 팝업 표시
  Future<void> _showSuppliesCalendarDialog(Pet pet) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '날짜 선택',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TableCalendar(
                firstDay: DateTime(2000),
                lastDay: DateTime.now(),
                focusedDay: _currentSuppliesDate,
                selectedDayPredicate: (day) => isSameDay(_currentSuppliesDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _currentSuppliesDate = selectedDay;
                  });
                  _saveSelectedDate(pet.id, _currentSuppliesDate);
                  _loadCurrentSupplies();
                  Navigator.of(context).pop();
                },
                calendarFormat: CalendarFormat.month,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    // 기록이 있는 날짜에 점 표시
                    if (_suppliesRecordDates.any((date) => isSameDay(date, day))) {
                      return Container(
                        margin: const EdgeInsets.all(4),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPetSheet extends ConsumerStatefulWidget {
  const _EditPetSheet({required this.pet});

  final Pet pet;

  @override
  ConsumerState<_EditPetSheet> createState() => _EditPetSheetState();
}

class _EditPetSheetState extends ConsumerState<_EditPetSheet> {
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
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final pet = widget.pet;
    _nameController.text = pet.name;
    _breedController.text = pet.breed ?? '';
    _weightController.text = pet.weightKg?.toString() ?? '';
    _noteController.text = pet.note ?? '';
    
    _selectedSpecies = pet.species;
    // Male/Female을 남아/여아로 변환
    _selectedSex = pet.sex == 'Male' ? '남아' : (pet.sex == 'Female' ? '여아' : pet.sex);
    _isNeutered = pet.neutered;
    _birthDate = pet.birthDate;
  }

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
                    'pets.edit_title'.tr(),
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
                          onPressed: _updatePet,
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

  Future<void> _updatePet() async {
    if (!_formKey.currentState!.validate()) return;
    
    // 남아/여아를 Male/Female로 변환 (DB 저장용)
    String? sexForDb = _selectedSex;
    if (_selectedSex == '남아') sexForDb = 'Male';
    if (_selectedSex == '여아') sexForDb = 'Female';
    
    final breedValue = _breedController.text.trim();
    print('🔍 품종 저장 디버그: 원본="${_breedController.text}", trim="${breedValue}", isEmpty=${breedValue.isEmpty}');
    
    final updatedPet = widget.pet.copyWith(
      name: _nameController.text.trim(),
      species: _selectedSpecies,
      breed: breedValue.isEmpty ? null : breedValue,
      sex: sexForDb,
      neutered: _isNeutered,
      birthDate: _birthDate,
      weightKg: _weightController.text.isEmpty ? null : double.tryParse(_weightController.text),
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      updatedAt: DateTime.now(),
    );
    
    try {
      await ref.read(petsProvider.notifier).updatePet(updatedPet);
      
      // Update weight in health tab's basic info if weight was changed
      if (updatedPet.weightKg != null && updatedPet.weightKg != widget.pet.weightKg) {
        try {
          final uid = Supabase.instance.client.auth.currentUser?.id;
          if (uid != null) {
            final today = DateTime.now();
            final dateKey = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
            
            // Get current lab data for today
            final currentRes = await Supabase.instance.client
                .from('labs')
                .select('items')
                .eq('user_id', uid)
                .eq('pet_id', widget.pet.id)
                .eq('date', dateKey)
                .eq('panel', 'BloodTest')
                .maybeSingle();

            Map<String, dynamic> currentItems = {};
            if (currentRes != null) {
              currentItems = Map<String, dynamic>.from(currentRes['items'] ?? {});
            }

            // Update weight in lab data
            currentItems['체중'] = {
              'value': updatedPet.weightKg.toString(),
              'unit': 'kg',
              'reference': '',
            };

            // Save to Supabase
            await Supabase.instance.client
                .from('labs')
                .upsert({
                  'user_id': uid,
                  'pet_id': widget.pet.id,
                  'date': dateKey,
                  'panel': 'BloodTest',
                  'items': currentItems,
                });
          }
        } catch (e) {
          print('⚠️ Failed to update weight in health tab: $e');
        }
      }
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pets.edit_success'.tr(args: [updatedPet.name])),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pets.edit_error'.tr(args: [widget.pet.name])),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _EditSuppliesSheet extends ConsumerStatefulWidget {
  const _EditSuppliesSheet({
    required this.pet,
    required this.selectedDate,
    this.existingSupplies,
    required this.onSaved,
  });

  final Pet pet;
  final DateTime selectedDate;
  final PetSupplies? existingSupplies;
  final Function(PetSupplies, List<DateTime>) onSaved;

  @override
  ConsumerState<_EditSuppliesSheet> createState() => _EditSuppliesSheetState();
}

class _EditSuppliesSheetState extends ConsumerState<_EditSuppliesSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dryFoodController = TextEditingController();
  final _wetFoodController = TextEditingController();
  final _supplementController = TextEditingController();
  final _snackController = TextEditingController();
  final _litterController = TextEditingController();
  late PetSuppliesRepository _suppliesRepository;

  @override
  void initState() {
    super.initState();
    _suppliesRepository = PetSuppliesRepository(
      Supabase.instance.client,
    );
    _initializeForm();
  }

  void _initializeForm() {
    final existingSupplies = widget.existingSupplies;
    
    if (existingSupplies != null) {
      // 기존 기록이 있는 경우 데이터 사용
      _dryFoodController.text = existingSupplies.dryFood ?? '';
      _wetFoodController.text = existingSupplies.wetFood ?? '';
      _supplementController.text = existingSupplies.supplement ?? '';
      _snackController.text = existingSupplies.snack ?? '';
      _litterController.text = existingSupplies.litter ?? '';
    } else {
      // 새로운 기록인 경우 빈 값으로 초기화
      _dryFoodController.text = '';
      _wetFoodController.text = '';
      _supplementController.text = '';
      _snackController.text = '';
      _litterController.text = '';
    }
  }

  @override
  void dispose() {
    _dryFoodController.dispose();
    _wetFoodController.dispose();
    _supplementController.dispose();
    _snackController.dispose();
    _litterController.dispose();
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
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                    'supplies.daily_record'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  // 선택된 날짜 표시
                  Text(
                    DateFormat('yyyy년 MM월 dd일').format(widget.selectedDate),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Form fields
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        AppTextField(
                          controller: _dryFoodController,
                          labelText: 'supplies.dry_food'.tr(),
                          prefixIcon: const Icon(Icons.restaurant),
                          hintText: 'supplies.dry_food_hint'.tr(),
                        ),
                        const SizedBox(height: 16),

                        AppTextField(
                          controller: _wetFoodController,
                          labelText: 'supplies.wet_food'.tr(),
                          prefixIcon: const Icon(Icons.rice_bowl),
                          hintText: 'supplies.wet_food_hint'.tr(),
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _supplementController,
                          labelText: 'supplies.supplement'.tr(),
                          prefixIcon: const Icon(Icons.medication),
                          hintText: 'supplies.supplement_hint'.tr(),
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _snackController,
                          labelText: 'supplies.snack'.tr(),
                          prefixIcon: const Icon(Icons.cookie),
                          hintText: 'supplies.snack_hint'.tr(),
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _litterController,
                          labelText: 'supplies.litter'.tr(),
                          prefixIcon: const Icon(Icons.cleaning_services),
                          hintText: 'supplies.litter_hint'.tr(),
                        ),
                      ],
                    ),
                  ),
                  
                  // Buttons
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _updateSupplies,
                          child: const Text('저장'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateSupplies() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final now = DateTime.now();
      final supplies = PetSupplies(
        id: widget.existingSupplies?.id ?? const Uuid().v4(),
        petId: widget.pet.id,
        dryFood: _dryFoodController.text.trim().isEmpty ? null : _dryFoodController.text.trim(),
        wetFood: _wetFoodController.text.trim().isEmpty ? null : _wetFoodController.text.trim(),
        supplement: _supplementController.text.trim().isEmpty ? null : _supplementController.text.trim(),
        snack: _snackController.text.trim().isEmpty ? null : _snackController.text.trim(),
        litter: _litterController.text.trim().isEmpty ? null : _litterController.text.trim(),
        recordedAt: widget.selectedDate,
        createdAt: widget.existingSupplies?.createdAt ?? now,
        updatedAt: now,
      );
      
      print('🔄 저장 시작: ${supplies.dryFood}, ${supplies.wetFood}, ${supplies.supplement}, ${supplies.snack}, ${supplies.litter}');
      final savedSupplies = await _suppliesRepository.saveSupplies(supplies);
      print('✅ 저장 완료: ${savedSupplies?.dryFood}, ${savedSupplies?.wetFood}, ${savedSupplies?.supplement}');
      
      if (!mounted) {
        print('❌ Widget disposed');
        return;
      }
      
      // 날짜 목록 로드
      final dates = await _suppliesRepository.getSuppliesRecordDates(widget.pet.id);
      print('📅 날짜 목록 로드: ${dates.length}개');
      
      // 콜백을 통해 부모에게 알림
      if (savedSupplies != null) {
        print('📝 콜백 호출: ${savedSupplies.dryFood}');
        widget.onSaved(savedSupplies, dates);
      }
      
      // 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('물품 기록이 저장되었습니다'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('물품 기록 저장에 실패했습니다'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

