import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/data/models/pet.dart';
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

    return Container(
      margin: const EdgeInsets.all(16),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Image Picker
              ProfileImagePicker(
                imagePath: pet.avatarUrl,
                selectedDefaultIcon: pet.defaultIcon,
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
                onDefaultIconSelected: (iconName) async {
                  // 기본 아이콘 선택 시 펫 업데이트
                  final updatedPet = pet.copyWith(
                    defaultIcon: iconName,
                    avatarUrl: null, // 기본 아이콘 선택 시 이미지 제거
                    updatedAt: DateTime.now(),
                  );
                  
                  try {
                    await ref.read(petsProvider.notifier).updatePet(updatedPet);
                    
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

  Widget _buildPetSupplies(BuildContext context, Pet pet) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      // TODO: 이전 기록 보기
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이전 기록이 없습니다')),
                      );
                    },
                  ),
                  Flexible(
                    child: Text(
                      pet.suppliesLastUpdated != null
                          ? DateFormat('yyyy년 MM월 dd일').format(pet.suppliesLastUpdated!)
                          : '기록 없음',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: pet.suppliesLastUpdated != null
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editSupplies(context, pet),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          // TODO: 다음 기록 보기
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('다음 기록이 없습니다')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSupplyItem(
                context,
                icon: Icons.restaurant,
                label: '사료',
                value: pet.suppliesFood,
              ),
              const SizedBox(height: 12),
              _buildSupplyItem(
                context,
                icon: Icons.medication,
                label: '영양제',
                value: pet.suppliesSupplement,
              ),
              const SizedBox(height: 12),
              _buildSupplyItem(
                context,
                icon: Icons.cookie,
                label: '간식',
                value: pet.suppliesSnack,
              ),
              const SizedBox(height: 12),
              _buildSupplyItem(
                context,
                icon: Icons.cleaning_services,
                label: '모래',
                value: pet.suppliesLitter,
              ),
            ],
          ),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value ?? '미등록',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
                      color: value != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
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
    
    if (years > 0) {
      return '$years ${years == 1 ? 'year' : 'years'}';
    } else if (months > 0) {
      return '$months ${months == 1 ? 'month' : 'months'}';
    } else {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
  }

  void _editSupplies(BuildContext context, Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditSuppliesSheet(pet: pet),
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

class _EditSuppliesSheet extends ConsumerStatefulWidget {
  const _EditSuppliesSheet({required this.pet});

  final Pet pet;

  @override
  ConsumerState<_EditSuppliesSheet> createState() => _EditSuppliesSheetState();
}

class _EditSuppliesSheetState extends ConsumerState<_EditSuppliesSheet> {
  final _formKey = GlobalKey<FormState>();
  final _foodController = TextEditingController();
  final _supplementController = TextEditingController();
  final _snackController = TextEditingController();
  final _litterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final pet = widget.pet;
    _foodController.text = pet.suppliesFood ?? '';
    _supplementController.text = pet.suppliesSupplement ?? '';
    _snackController.text = pet.suppliesSnack ?? '';
    _litterController.text = pet.suppliesLitter ?? '';
  }

  @override
  void dispose() {
    _foodController.dispose();
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
        initialChildSize: 0.7,
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
                    '물품 기록 수정',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  
                  // Form fields
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        AppTextField(
                          controller: _foodController,
                          labelText: '사료',
                          prefixIcon: const Icon(Icons.restaurant),
                          hintText: '예: 로얄캐닌 3kg',
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _supplementController,
                          labelText: '영양제',
                          prefixIcon: const Icon(Icons.medication),
                          hintText: '예: 종합 비타민',
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _snackController,
                          labelText: '간식',
                          prefixIcon: const Icon(Icons.cookie),
                          hintText: '예: 츄르 30개입',
                        ),
                        const SizedBox(height: 16),
                        
                        AppTextField(
                          controller: _litterController,
                          labelText: '모래',
                          prefixIcon: const Icon(Icons.cleaning_services),
                          hintText: '예: 두부 모래 5L',
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateSupplies() async {
    if (!_formKey.currentState!.validate()) return;
    
    final updatedPet = widget.pet.copyWith(
      suppliesFood: _foodController.text.trim().isEmpty ? null : _foodController.text.trim(),
      suppliesSupplement: _supplementController.text.trim().isEmpty ? null : _supplementController.text.trim(),
      suppliesSnack: _snackController.text.trim().isEmpty ? null : _snackController.text.trim(),
      suppliesLitter: _litterController.text.trim().isEmpty ? null : _litterController.text.trim(),
      suppliesLastUpdated: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    try {
      await ref.read(petsProvider.notifier).updatePet(updatedPet);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('물품 기록이 업데이트되었습니다'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('물품 기록 업데이트에 실패했습니다'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
