import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/core/providers/records_provider.dart';
import 'package:petcare/core/providers/reminders_provider.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/data/services/image_service.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/widgets/profile_image_picker.dart';
import 'package:petcare/features/labs/weight_chart_screen.dart';
import 'package:petcare/ui/theme/app_colors.dart';

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
  File? _selectedImage;
  String? _selectedDefaultIcon;

  @override
  void initState() {
    super.initState();
    // Load related data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordsProvider.notifier).loadRecords(widget.petId);
      ref.read(remindersProvider.notifier).loadReminders(widget.petId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(petByIdProvider(widget.petId));
    final petRecords = ref.watch(recordsForPetProvider(widget.petId));
    final petReminders = ref.watch(remindersForPetProvider(widget.petId));

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
        title: Text(pet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editPet(context, pet),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Pet Header
            _buildPetHeader(context, pet),
            
            // Quick Stats
            _buildQuickStats(context, petRecords, petReminders),
            
            // Recent Records
            _buildRecentRecords(context, petRecords),
            
            // Upcoming Reminders
            _buildUpcomingReminders(context, petReminders),
            
            const SizedBox(height: 100), // Bottom padding for navigation bar
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRecord(context, pet),
        icon: const Icon(Icons.add),
        label: Text('records.add'.tr()),
      ),
    );
  }

  Widget _buildPetHeader(BuildContext context, Pet pet) {
    final speciesColor = AppColors.getSpeciesColor(pet.species);
    final age = _calculateAge(pet.birthDate);

    return Container(
      margin: const EdgeInsets.all(16),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Image Picker
              ProfileImagePicker(
                imagePath: _selectedImage?.path ?? pet.avatarUrl,
                selectedDefaultIcon: _selectedDefaultIcon ?? pet.defaultIcon,
                onImageSelected: (image) async {
                  if (image != null) {
                    // 이미지 저장 및 펫 업데이트
                    final avatarUrl = await ImageService.saveImageToAppDirectory(image);
                    final updatedPet = pet.copyWith(
                      avatarUrl: avatarUrl,
                      defaultIcon: null, // 이미지 선택 시 기본 아이콘 제거
                      updatedAt: DateTime.now(),
                    );
                    
                    try {
                      await ref.read(petsProvider.notifier).updatePet(updatedPet);
                      setState(() {
                        _selectedImage = image;
                        _selectedDefaultIcon = null;
                      });
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('pets.image_updated'.tr(args: [pet.name])),
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
                      setState(() {
                        _selectedImage = null;
                        _selectedDefaultIcon = 'dog1'; // 상태 업데이트
                      });

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
                onDefaultIconSelected: (iconName) async {
                  // 기본 아이콘 선택 시 펫 업데이트
                  final updatedPet = pet.copyWith(
                    defaultIcon: iconName,
                    avatarUrl: null, // 기본 아이콘 선택 시 이미지 제거
                    updatedAt: DateTime.now(),
                  );
                  
                  try {
                    await ref.read(petsProvider.notifier).updatePet(updatedPet);
                    setState(() {
                      _selectedDefaultIcon = iconName;
                      _selectedImage = null;
                    });
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('기본 아이콘이 설정되었습니다'),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('기본 아이콘 설정에 실패했습니다'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                },
                size: 120,
                showEditIcon: true,
              ),
              const SizedBox(height: 16),
              
              // Basic Info
              Text(
                pet.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PetSpeciesChip(species: pet.species),
                  if (pet.breed != null) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(pet.breed!),
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Details Grid
              Row(
                children: [
                  if (age != null)
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.cake,
                        label: 'pets.age'.tr(),
                        value: age,
                      ),
                    ),
                  if (pet.weightKg != null)
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.monitor_weight,
                        label: 'pets.weight'.tr(),
                        value: '${pet.weightKg}kg',
                        onTap: () => _showWeightChart(context, pet),
                      ),
                    ),
                  if (pet.sex != null)
                    Expanded(
                      child: _InfoCard(
                        icon: pet.sex!.toLowerCase() == 'male' ? Icons.male : Icons.female,
                        label: 'pets.sex'.tr(),
                        value: pet.sex!,
                      ),
                    ),
                ],
              ),
              
              if (pet.note != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pet.note!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, List<dynamic> records, List<dynamic> reminders) {
    final todayRecords = records.where((r) {
      final today = DateTime.now();
      final recordDate = r.at as DateTime;
      return recordDate.day == today.day &&
             recordDate.month == today.month &&
             recordDate.year == today.year;
    }).length;

    final upcomingReminders = reminders.where((r) {
      final reminder = r as dynamic;
      return !reminder.done && reminder.scheduledAt.isAfter(DateTime.now());
    }).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.today,
              label: 'records.today'.tr(),
              value: todayRecords.toString(),
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.notifications_active,
              label: 'reminders.upcoming'.tr(),
              value: upcomingReminders.toString(),
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.list_alt,
              label: 'records.total'.tr(),
              value: records.length.toString(),
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRecords(BuildContext context, List<dynamic> records) {
    final recentRecords = records.take(3).toList();

    return Column(
      children: [
        SectionHeader(
          title: 'records.recent'.tr(),
          action: TextButton(
            onPressed: () => context.push('/pets/${widget.petId}/records'),
            child: Text('common.see_all'.tr()),
          ),
        ),
        if (recentRecords.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'records.no_recent'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          ...recentRecords.map((record) => _RecordListItem(record: record)),
      ],
    );
  }

  Widget _buildUpcomingReminders(BuildContext context, List<dynamic> reminders) {
    final upcomingReminders = reminders.where((r) {
      final reminder = r as dynamic;
      return !reminder.done && reminder.scheduledAt.isAfter(DateTime.now());
    }).take(3).toList();

    return Column(
      children: [
        SectionHeader(
          title: 'reminders.upcoming'.tr(),
          action: TextButton(
            onPressed: () => context.push('/pets/${widget.petId}/health'),
            child: Text('common.see_all'.tr()),
          ),
        ),
        if (upcomingReminders.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'reminders.no_upcoming'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          ...upcomingReminders.map((reminder) => _ReminderListItem(reminder: reminder)),
      ],
    );
  }

  String? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;
    
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    
    if (years > 0) {
      return '$years ${years == 1 ? 'year' : 'years'}';
    } else if (months > 0) {
      return '$months ${months == 1 ? 'month' : 'months'}';
    } else {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
  }

  void _editPet(BuildContext context, Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditPetSheet(pet: pet),
    );
  }

  void _addRecord(BuildContext context, Pet pet) {
    // TODO: Navigate to add record with pre-selected pet
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Add record for ${pet.name} - Coming Soon')),
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
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordListItem extends StatelessWidget {
  const _RecordListItem({required this.record});

  final dynamic record;

  @override
  Widget build(BuildContext context) {
    final typeColor = AppColors.getRecordTypeColor(record.type);

    return AppCard(
      child: ListTile(
        leading: Container(
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
        title: Text(record.title),
        subtitle: Text(DateFormat('MMM dd, HH:mm').format(record.at)),
        trailing: RecordTypeChip(type: record.type, size: ChipSize.small),
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

class _ReminderListItem extends StatelessWidget {
  const _ReminderListItem({required this.reminder});

  final dynamic reminder;

  @override
  Widget build(BuildContext context) {
    final isOverdue = reminder.scheduledAt.isBefore(DateTime.now());
    final color = isOverdue ? AppColors.error : AppColors.warning;

    return AppCard(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isOverdue ? Icons.warning : Icons.schedule,
            color: color,
            size: 20,
          ),
        ),
        title: Text(reminder.title),
        subtitle: Text(DateFormat('MMM dd, HH:mm').format(reminder.scheduledAt)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isOverdue ? 'reminders.overdue'.tr() : 'reminders.upcoming'.tr(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
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
    'Dog', 'Cat', 'Bird', 'Fish', 'Rabbit', 'Hamster', 'Reptile', 'Other'
  ];
  
  final List<String> _sexOptions = ['Male', 'Female'];

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
    _selectedSex = pet.sex;
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
    
    final updatedPet = widget.pet.copyWith(
      name: _nameController.text.trim(),
      species: _selectedSpecies,
      breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
      sex: _selectedSex,
      neutered: _isNeutered,
      birthDate: _birthDate,
      weightKg: _weightController.text.isEmpty ? null : double.tryParse(_weightController.text),
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      updatedAt: DateTime.now(),
    );
    
    try {
      await ref.read(petsProvider.notifier).updatePet(updatedPet);
      
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
