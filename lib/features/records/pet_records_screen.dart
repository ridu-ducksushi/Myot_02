import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/core/providers/records_provider.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/data/models/record.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/theme/app_colors.dart';

import 'package:petcare/features/records/records_chart_screen.dart';

// 전역 헬퍼 함수들
IconData getIconForType(String type) {
  switch (type) {
    case 'food_meal': return Icons.dinner_dining;
    case 'food_snack': return Icons.cookie;
    case 'food_water': return Icons.water_drop;
    case 'health_med': return Icons.medical_services;
    case 'health_supplement': return Icons.medication;
    case 'health_vaccine': return Icons.vaccines;
    case 'health_visit': return Icons.local_hospital;
    case 'health_weight': return Icons.more_horiz;
    case 'activity_play': return Icons.gamepad_outlined;
    case 'activity_explore': return Icons.explore_outlined;
    case 'activity_outing': return Icons.directions_walk;
    case 'activity_rest': return Icons.hotel_outlined;
    case 'activity_other': return Icons.more_horiz;
    case 'poop_urine': return Icons.opacity;
    case 'poop_feces': return Icons.pets;
    case 'poop_other': return Icons.more_horiz;
    default: return Icons.add_circle_outline;
  }
}

String getLabelForType(String type) {
  switch (type) {
    case 'food_meal': return '사료';
    case 'food_snack': return '간식';
    case 'food_water': return '음수';
    case 'health_med': return '약';
    case 'health_supplement': return '보조제';
    case 'health_vaccine': return '백신';
    case 'health_visit': return '병원';
    case 'health_weight': return '건강:기타';
    case 'activity_play': return '놀이';
    case 'activity_explore': return '탐색';
    case 'activity_outing': return '산책';
    case 'activity_rest': return '휴식';
    case 'activity_other': return '활동:기타';
    case 'poop_urine': return '소변';
    case 'poop_feces': return '대변';
    case 'poop_other': return '배변:기타';
    default: return type;
  }
}

class PetRecordsScreen extends ConsumerStatefulWidget {
  const PetRecordsScreen({
    super.key,
    required this.petId,
  });

  final String petId;

  @override
  ConsumerState<PetRecordsScreen> createState() => _PetRecordsScreenState();
}

class _PetRecordsScreenState extends ConsumerState<PetRecordsScreen> {
  bool _isFoodMenuVisible = false;
  bool _isActivityMenuVisible = false;
  bool _isPoopMenuVisible = false;
  bool _isHealthMenuVisible = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Load records for this specific pet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordsProvider.notifier).loadRecords(widget.petId);
    });
  }

  Widget _buildSubMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodSubMenu(Pet pet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSubMenuItem(
            icon: Icons.dinner_dining,
            label: '사료',
            onTap: () => _addRecord(context, pet, 'food_meal'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.cookie,
            label: '간식',
            onTap: () => _addRecord(context, pet, 'food_snack'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.water_drop,
            label: '음수',
            onTap: () => _addRecord(context, pet, 'food_water'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.local_hospital,
            label: '투약',
            onTap: () => _addRecord(context, pet, 'health_med'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.medication,
            label: '보조제',
            onTap: () => _addRecord(context, pet, 'health_supplement'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySubMenu(Pet pet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSubMenuItem(
            icon: Icons.gamepad_outlined,
            label: '놀이',
            onTap: () => _addRecord(context, pet, 'activity_play'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.explore_outlined,
            label: '탐색',
            onTap: () => _addRecord(context, pet, 'activity_explore'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.directions_walk,
            label: '산책',
            onTap: () => _addRecord(context, pet, 'activity_outing'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.hotel_outlined,
            label: '휴식',
            onTap: () => _addRecord(context, pet, 'activity_rest'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.more_horiz,
            label: '기타',
            onTap: () => _addRecord(context, pet, 'activity_other'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthSubMenu(Pet pet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSubMenuItem(
            icon: Icons.medical_services,
            label: '약',
            onTap: () => _addRecord(context, pet, 'health_med'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.vaccines,
            label: '백신',
            onTap: () => _addRecord(context, pet, 'health_vaccine'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.local_hospital,
            label: '병원',
            onTap: () => _addRecord(context, pet, 'health_visit'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.more_horiz,
            label: '기타',
            onTap: () => _addRecord(context, pet, 'health_weight'),
          ),
        ],
      ),
    );
  }

  Widget _buildPoopSubMenu(Pet pet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSubMenuItem(
            icon: Icons.opacity,
            label: '소변',
            onTap: () => _addRecord(context, pet, 'poop_urine'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.pets,
            label: '대변',
            onTap: () => _addRecord(context, pet, 'poop_feces'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.more_horiz,
            label: '기타',
            onTap: () => _addRecord(context, pet, 'poop_other'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(petByIdProvider(widget.petId));
    // 선택된 날짜에 해당하는 레코드만 필터링
    final List<Record> allRecords = ref.watch(recordsForPetProvider(widget.petId));
    final List<Record> records = allRecords.where((record) {
      final recordDate = record.at;
      return recordDate.year == _selectedDate.year &&
             recordDate.month == _selectedDate.month &&
             recordDate.day == _selectedDate.day;
    }).toList();

    if (pet == null) {
      return Scaffold(
        body: SafeArea(
          child: AppEmptyState(
            icon: Icons.pets,
            title: 'pets.not_found'.tr(),
            message: 'pets.not_found_message'.tr(),
          ),
        ),
      );
    }

    Widget recordsView = _Time24Table(
      records: records,
      onRecordTap: (record) => _showRecordEditDialog(context, record, pet),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // 날짜 선택 헤더 with 네비게이션 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 이전 날짜 버튼
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.chevron_left,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  
                  // 날짜 표시 및 선택 + 차트 아이콘 (중앙 정렬)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('yyyy-MM-dd').format(_selectedDate),
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 차트 아이콘 (Health 화면과 동일한 스타일)
                      InkWell(
                        onTap: () {
                          context.go('/pets/${widget.petId}/records-chart?name=${Uri.encodeComponent(pet.name)}');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.bar_chart,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // 다음 날짜 버튼
                  InkWell(
                    onTap: () {
                      final tomorrow = _selectedDate.add(const Duration(days: 1));
                      if (tomorrow.isBefore(DateTime.now().add(const Duration(days: 1)))) {
                        setState(() {
                          _selectedDate = tomorrow;
                        });
                      }
                    },
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
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: recordsView,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isFoodMenuVisible)
                _buildFoodSubMenu(pet),
              if (_isFoodMenuVisible)
                const SizedBox(width: 12),
              FloatingActionButton(
                heroTag: "record-food",
                tooltip: 'records.type.food'.tr(),
                onPressed: () {
                  setState(() {
                    _isFoodMenuVisible = !_isFoodMenuVisible;
                    _isActivityMenuVisible = false;
                    _isPoopMenuVisible = false;
                    _isHealthMenuVisible = false;
                  });
                },
                child: const Icon(Icons.restaurant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isActivityMenuVisible)
                _buildActivitySubMenu(pet),
              if (_isActivityMenuVisible)
                const SizedBox(width: 12),
              FloatingActionButton(
                heroTag: "record-play",
                tooltip: 'records.type.play'.tr(),
                onPressed: () {
                  setState(() {
                    _isActivityMenuVisible = !_isActivityMenuVisible;
                    _isFoodMenuVisible = false;
                    _isPoopMenuVisible = false;
                    _isHealthMenuVisible = false;
                  });
                },
                child: const Icon(Icons.sports_tennis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isPoopMenuVisible)
                _buildPoopSubMenu(pet),
              if (_isPoopMenuVisible)
                const SizedBox(width: 12),
              FloatingActionButton(
                heroTag: "record-poop",
                tooltip: 'records.type.poop'.tr(),
                onPressed: () {
                  setState(() {
                    _isPoopMenuVisible = !_isPoopMenuVisible;
                    _isFoodMenuVisible = false;
                    _isActivityMenuVisible = false;
                    _isHealthMenuVisible = false;
                  });
                },
                child: const Icon(Icons.cleaning_services),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isHealthMenuVisible)
                _buildHealthSubMenu(pet),
              if (_isHealthMenuVisible)
                const SizedBox(width: 12),
              FloatingActionButton(
                heroTag: "record-health",
                tooltip: 'records.type.health'.tr(),
                onPressed: () {
                  setState(() {
                    _isHealthMenuVisible = !_isHealthMenuVisible;
                    _isFoodMenuVisible = false;
                    _isActivityMenuVisible = false;
                    _isPoopMenuVisible = false;
                  });
                },
                child: const Icon(Icons.favorite),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _closeAllSubMenus() {
    setState(() {
      _isFoodMenuVisible = false;
      _isActivityMenuVisible = false;
      _isPoopMenuVisible = false;
      _isHealthMenuVisible = false;
    });
  }

  void _addRecord(BuildContext context, Pet pet, String type) {
    final TextEditingController noteController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Row(
                children: [
                  Icon(getIconForType(type), color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('records.add_new'.tr()),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(hintText: 'records.content'.tr()),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                            if (picked != null) {
                              setState(() {
                                selectedTime = picked;
                              });
                            }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Time: ${selectedTime.format(context)}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('common.cancel'.tr()),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _closeAllSubMenus();
                  },
                ),
                Consumer(
                  builder: (context, ref, child) {
                    return TextButton(
                      child: Text('common.save'.tr()),
                      onPressed: () {
                        final now = DateTime.now();
                        final recordAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, selectedTime.hour, selectedTime.minute);
                        final newRecord = Record(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          petId: pet.id,
                          type: type,
                          title: type, // Using type as title for now
                          content: noteController.text,
                          at: recordAt,
                          createdAt: now,
                          updatedAt: now,
                        );
                        ref.read(recordsProvider.notifier).addRecord(newRecord);
                        Navigator.of(context).pop();
                        _closeAllSubMenus();
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordEditDialog(BuildContext context, Record record, Pet pet) {
    final TextEditingController contentController = TextEditingController(text: record.content ?? '');
    DateTime selectedDate = record.at;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(record.at);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text('기록 편집'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 항목명 (읽기 전용)
                      Text(
                        '항목명',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(getIconForType(record.type), size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            getLabelForType(record.type),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 날짜
                    Text(
                      '날짜',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = DateTime(picked.year, picked.month, picked.day, selectedTime.hour, selectedTime.minute);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 시간
                    Text(
                      '시간',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                            selectedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, picked.hour, picked.minute);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(selectedTime.format(context)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 메모
                    Text(
                      '메모',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '메모를 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                // 삭제 버튼
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDeleteConfirmDialog(context, record);
                  },
                  icon: Icon(Icons.delete, color: Colors.red),
                  label: Text('삭제', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 16),
                // 취소 버튼
                TextButton(
                  child: Text('취소'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _closeAllSubMenus();
                  },
                ),
                // 저장 버튼
                Consumer(
                  builder: (context, ref, child) {
                    return TextButton(
                      child: Text('저장'),
                      onPressed: () {
                        final updatedRecord = record.copyWith(
                          content: contentController.text,
                          at: selectedDate,
                          updatedAt: DateTime.now(),
                        );
                        ref.read(recordsProvider.notifier).updateRecord(updatedRecord);
                        Navigator.of(context).pop();
                        _closeAllSubMenus();
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Record record) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text('기록 삭제'),
          content: SizedBox(
            width: double.maxFinite,
            child: Text('이 기록을 삭제하시겠습니까?\n"${getLabelForType(record.type)}"'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
                _closeAllSubMenus();
              },
            ),
            Consumer(
              builder: (context, ref, child) {
                return TextButton(
                  child: Text('삭제', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    ref.read(recordsProvider.notifier).deleteRecord(record.id);
                    Navigator.of(context).pop();
                    _closeAllSubMenus();
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _Time24Table extends StatelessWidget {
  const _Time24Table({required this.records, required this.onRecordTap});

  final List<Record> records;
  final Function(Record) onRecordTap;

  @override
  Widget build(BuildContext context) {
    final Color outline = Theme.of(context).colorScheme.outlineVariant;
    final Color surface = Theme.of(context).colorScheme.surface;
    final Color onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outline),
      ),
      child: Column(
        children: List.generate(24, (i) {
          final recordsForHour = records.where((r) => r.at.hour == i).toList();
          final String label = _labelForRow(i);
          final BorderSide bottomLine = i == 23 ? BorderSide.none : BorderSide(color: outline);
           return SizedBox(
             height: 32, // 행 높이를 32로 변경
             child: Row(
              children: [
                // Left time label cell
                Container(
                  width: 45, // 시간 라벨 영역의 고정 너비를 45px로 줄임
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    border: Border(
                      right: BorderSide(color: outline),
                      bottom: bottomLine,
                    ),
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                // Right content cell
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: bottomLine,
                      ),
                    ),
                    child: recordsForHour.isEmpty
                        ? null
                        : Row(
                            children: recordsForHour.map((record) {
                              return _buildRecordButton(context, record, recordsForHour.length);
                            }).toList(),
                          ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRecordButton(BuildContext context, Record record, int totalRecords) {
    final typeColor = AppColors.getRecordTypeColor(record.type);
    
    // 총 기록 개수에 따라 버튼 크기 조정 (1개면 전체 너비, 2개면 각각 50%, 3개면 각각 33% 등)
    final double flexValue = 1.0 / totalRecords;
    
    return Expanded(
      flex: (flexValue * 100).round(), // flex는 정수여야 하므로 100을 곱해서 반올림
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: InkWell(
          onTap: () => onRecordTap(record),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // 타임라인 행 높이 32px에 맞춰 패딩 조정
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: typeColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getRecordIcon(record.type),
                  size: 18,
                  color: typeColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${getLabelForType(record.type)}${record.content != null && record.content!.isNotEmpty ? ': ${record.content}' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: typeColor,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getRecordIcon(String type) {
    switch (type.toLowerCase()) {
      case 'food_meal': return Icons.restaurant;
      case 'food_snack': return Icons.cookie;
      case 'food_water': return Icons.water_drop;
      case 'health_med': case 'food_med': return Icons.medical_services;
      case 'health_supplement': case 'food_supplement': return Icons.medication;
      case 'activity_play': return Icons.sports_tennis;
      case 'activity_explore': return Icons.explore_outlined;
      case 'activity_outing': return Icons.directions_walk;
      case 'activity_rest': return Icons.hotel_outlined;
      case 'activity_other': return Icons.more_horiz;
      case 'poop_urine': return Icons.opacity;
      case 'poop_feces': return Icons.pets;
      case 'poop_other': return Icons.more_horiz;
      case 'health': return Icons.favorite;
      default: return Icons.note;
    }
  }

  String _labelForRow(int index) {
    if (index == 0) return '12';
    if (index == 23) return '23';
    final int hour = index;
    return hour.toString();
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.pet,
  });

  final Record record;
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final typeColor = AppColors.getRecordTypeColor(record.type);
    final content = record.content;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getRecordIcon(record.type),
                    color: typeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getLabelForType(record.type),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy - HH:mm').format(record.at),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record.type.toUpperCase(),
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (content != null && content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getRecordIcon(String type) {
    switch (type.toLowerCase()) {
      case 'meal': return Icons.restaurant;
      case 'snack': return Icons.cookie;
      case 'med': case 'medicine': return Icons.medical_services;
      case 'vaccine': return Icons.vaccines;
      case 'visit': return Icons.local_hospital;
      case 'weight': return Icons.monitor_weight;
      case 'litter': return Icons.cleaning_services;
      case 'play': return Icons.sports_tennis;
      case 'groom': return Icons.content_cut;
      default: return Icons.note;
    }
  }
}