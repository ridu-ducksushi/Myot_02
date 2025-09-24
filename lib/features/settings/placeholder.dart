import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/data/local/database.dart';
import 'package:petcare/features/pets/pets_screen.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/theme/app_colors.dart';
import 'package:petcare/data/models/pet.dart';

class SettingsPlaceholder extends ConsumerWidget {
  const SettingsPlaceholder({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
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
      ),
      body: ListView(
        children: [
          // 현재 선택된 펫 섹션
          if (currentPet != null) ...[
            SectionHeader(title: '현재 선택된 펫'),
            _buildCurrentPetCard(context, currentPet),
            const SizedBox(height: 16),
          ],
          
          // 등록된 모든 펫 섹션
          SectionHeader(title: '등록된 펫'),
          ...petsState.pets.map((pet) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildPetCard(context, ref, pet),
          )),
          
          const SizedBox(height: 16),
          
          // 펫 추가 섹션
          SectionHeader(title: '펫 관리'),
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.add),
              title: Text('새 펫 추가'),
              subtitle: Text('새로운 반려동물을 등록하세요'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAddPetDialog(context),
            ),
          ),
          
          const SizedBox(height: 24),
          
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
        ],
      ),
    );
  }

  Widget _buildCurrentPetCard(BuildContext context, pet) {
    final speciesColor = AppColors.getSpeciesColor(pet.species);
    
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
              child: pet.avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.file(
                        File(pet.avatarUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.pets, color: speciesColor, size: 30),
                      ),
                    )
                  : Icon(Icons.pets, color: speciesColor, size: 30),
            ),
            const SizedBox(width: 16),
            
            // 펫 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      PetSpeciesChip(species: pet.species),
                      if (pet.breed != null) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(pet.breed!),
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // 펫 상세 보기 버튼
            IconButton(
              onPressed: () => context.go('/pets/${pet.id}'),
              icon: const Icon(Icons.visibility),
              tooltip: '펫 상세 보기',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetCard(BuildContext context, WidgetRef ref, pet) {
    final speciesColor = AppColors.getSpeciesColor(pet.species);
    
    return AppCard(
      onTap: () => context.go('/pets/${pet.id}'),
      onLongPress: () => _showDeletePetDialog(context, ref, pet),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 펫 아바타
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: speciesColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: speciesColor.withOpacity(0.3), width: 2),
              ),
              child: pet.avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Image.file(
                        File(pet.avatarUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.pets, color: speciesColor, size: 25),
                      ),
                    )
                  : Icon(Icons.pets, color: speciesColor, size: 25),
            ),
            const SizedBox(width: 12),
            
            // 펫 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      PetSpeciesChip(species: pet.species),
                      if (pet.breed != null) ...[
                        const SizedBox(width: 6),
                        Chip(
                          label: Text(pet.breed!),
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          labelStyle: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // 펫 상세 보기 아이콘
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    'Dog', 'Cat', 'Bird', 'Fish', 'Rabbit', 'Hamster', 'Reptile', 'Other'
  ];
  
  final List<String> _sexOptions = ['Male', 'Female'];

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
    
    final pet = Pet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: '', // Will be set by repository
      name: _nameController.text.trim(),
      species: _selectedSpecies,
      breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
      sex: _selectedSex,
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

