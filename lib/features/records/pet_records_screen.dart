import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/core/providers/records_provider.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/theme/app_colors.dart';

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
  @override
  void initState() {
    super.initState();
    // Load records for this specific pet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordsProvider.notifier).loadRecords(widget.petId);
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Text('${pet.name} - ${'records.title'.tr()}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pets/${widget.petId}'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: const [
            Expanded(child: _Time24Table()),
          ],
        ),
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.restaurant),
            label: 'records.type.food'.tr(),
            onTap: () => _addRecord(context, pet, 'food'),
          ),
          SpeedDialChild(
            child: const Icon(Icons.sports_tennis),
            label: 'records.type.play'.tr(),
            onTap: () => _addRecord(context, pet, 'play'),
          ),
          SpeedDialChild(
            child: const Icon(Icons.cleaning_services),
            label: 'records.type.poop'.tr(),
            onTap: () => _addRecord(context, pet, 'poop'),
          ),
          SpeedDialChild(
            child: const Icon(Icons.favorite),
            label: 'records.type.health'.tr(),
            onTap: () => _addRecord(context, pet, 'health'),
          ),
        ],
      ),
    );
  }

  void _addRecord(BuildContext context, Pet pet, String type) {
    // TODO: Navigate to add record with pre-selected pet
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Add record for ${pet.name} - Coming Soon')),
    );
  }
}

class _Time24Table extends StatelessWidget {
  const _Time24Table();

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

  final dynamic record;
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final typeColor = AppColors.getRecordTypeColor(record.type);

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
            if (record.content != null && record.content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record.content,
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
