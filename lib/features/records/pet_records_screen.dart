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
            label: 'Food',
            onTap: () => _addRecord(context, pet, 'food_meal'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.cookie,
            label: 'Snack',
            onTap: () => _addRecord(context, pet, 'food_snack'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.water_drop,
            label: 'Water',
            onTap: () => _addRecord(context, pet, 'food_water'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.local_hospital,
            label: 'Med',
            onTap: () => _addRecord(context, pet, 'health_med'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.medication,
            label: 'Supplement',
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
            label: 'Play',
            onTap: () => _addRecord(context, pet, 'activity_play'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.explore_outlined,
            label: 'Explore',
            onTap: () => _addRecord(context, pet, 'activity_explore'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.directions_walk,
            label: 'Outing',
            onTap: () => _addRecord(context, pet, 'activity_outing'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.hotel_outlined,
            label: 'Rest',
            onTap: () => _addRecord(context, pet, 'activity_rest'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.more_horiz,
            label: 'etc',
            onTap: () => _addRecord(context, pet, 'activity_other'),
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
            label: 'Urine',
            onTap: () => _addRecord(context, pet, 'poop_urine'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.pets,
            label: 'Feces',
            onTap: () => _addRecord(context, pet, 'poop_feces'),
          ),
          const SizedBox(width: 16),
          _buildSubMenuItem(
            icon: Icons.more_horiz,
            label: 'etc',
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

    Widget recordsView = _Time24Table(records: records);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // 날짜 선택 헤더 (Health 탭과 동일한 스타일)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('기록 날짜: ', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 4),
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: recordsView),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "record-chart",
            tooltip: 'records.type.chart'.tr(),
            onPressed: () {
              context.go('/pets/${pet!.id}/records-chart?name=${Uri.encodeComponent(pet!.name)}');
            },
            child: const Icon(Icons.bar_chart),
          ),
          const SizedBox(height: 12),
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
                  });
                },
                child: const Icon(Icons.cleaning_services),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "record-health",
            tooltip: 'records.type.health'.tr(),
            onPressed: () {
              setState(() {
                _isFoodMenuVisible = false;
                _isActivityMenuVisible = false;
                _isPoopMenuVisible = false;
              });
              _addRecord(context, pet, 'health');
            },
            child: const Icon(Icons.favorite),
          ),
        ],
      ),
    );
  }

  void _addRecord(BuildContext context, Pet pet, String type) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController noteController = TextEditingController();
        TimeOfDay selectedTime = TimeOfDay.now();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('${'records.add_new'.tr()}: $type'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(hintText: 'records.content'.tr()),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.access_time),
                        onPressed: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null && picked != selectedTime) {
                            setState(() {
                              selectedTime = picked;
                            });
                          }
                        },
                      ),
                      Text('Time: ${selectedTime.format(context)}'),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('common.cancel'.tr()),
                  onPressed: () {
                    Navigator.of(context).pop();
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
}

class _Time24Table extends StatelessWidget {
  const _Time24Table({required this.records});

  final List<Record> records;

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
          return Expanded(
            child: Row(
              children: [
                // Left time label cell
                Container(
                  width: 64,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: outline),
                      bottom: bottomLine,
                    ),
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onSurfaceVariant,
                          fontWeight: FontWeight.w600,
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
                        : ListView(
                            children: recordsForHour.map((record) {
                              return Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Text('${record.title}: ${record.content}'),
                              );
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

  String _labelForRow(int index) {
    if (index == 0) return '12:00';
    if (index == 23) return '24:00';
    final int hour = index;
    final String two = hour.toString().padLeft(2, '0');
    return '$two:00';
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
                        record.title,
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