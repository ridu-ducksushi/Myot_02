import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/data/services/image_service.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/widgets/profile_image_picker.dart';
import 'package:petcare/ui/widgets/add_pet_sheet.dart';
import 'package:petcare/ui/theme/app_colors.dart';
import 'package:petcare/data/local/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare/utils/app_constants.dart';

class PetsScreen extends ConsumerStatefulWidget {
  const PetsScreen({super.key});

  @override
  ConsumerState<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends ConsumerState<PetsScreen> {
  @override
  void initState() {
    super.initState();
    // Load pets when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(petsProvider.notifier).loadPets();
      ref.read(lastUserIdProvider.notifier).state = Supabase.instance.client.auth.currentUser?.id;
    });

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final newUserId = data.session?.user.id;
      final lastUserId = ref.read(lastUserIdProvider);
      if (newUserId != lastUserId) {
        ref.read(lastUserIdProvider.notifier).state = newUserId;
        ref.read(petsProvider.notifier).loadPets();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final petsState = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppCustomAppBar(
        title: Text('pets.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPetDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await LocalDatabase.instance.clearAll();
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(petsProvider.notifier).loadPets(),
        child: _buildBody(context, petsState),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPetDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PetsState state) {
    if (state.isLoading && state.pets.isEmpty) {
      return const Center(
        child: AppLoadingIndicator(message: 'Loading pets...'),
      );
    }

    if (state.error != null) {
      return AppErrorState(
        message: state.error!,
        onRetry: () => ref.read(petsProvider.notifier).loadPets(),
      );
    }

    if (state.pets.isEmpty) {
      return AppEmptyState(
        icon: Icons.pets,
        title: 'pets.empty_title'.tr(),
        message: 'pets.empty_message'.tr(),
        action: ElevatedButton.icon(
          onPressed: () => _showAddPetDialog(context),
          icon: const Icon(Icons.add),
          label: Text('pets.add_first'.tr()),
        ),
      );
    }

    Future<List<Pet>> _reorderedPets() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final preferredId = prefs.getString('last_selected_pet_id');
        if (preferredId == null || preferredId.isEmpty) return state.pets;
        final list = List<Pet>.from(state.pets);
        final idx = list.indexWhere((p) => p.id == preferredId);
        if (idx > 0) {
          final selected = list.removeAt(idx);
          list.insert(0, selected);
        }
        return list;
      } catch (_) {
        return state.pets;
      }
    }

    return FutureBuilder<List<Pet>>(
      future: _reorderedPets(),
      builder: (context, snapshot) {
        final pets = snapshot.data ?? state.pets;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80), // Space for FAB
          itemCount: pets.length,
          itemBuilder: (context, index) {
            final pet = pets[index];
            return _PetCard(pet: pet);
          },
        );
      },
    );
  }

  void _showAddPetDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddPetSheet(),
    );
  }
}

class _DismissiblePetCard extends StatelessWidget {
  const _DismissiblePetCard({
    required this.pet,
    required this.onDelete,
  });

  final Pet pet;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('pet_${pet.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // 스와이프로 삭제 확인 다이얼로그 표시
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('pets.delete_confirm_title'.tr()),
            content: Text('pets.delete_confirm_message'.tr(args: [pet.name])),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text('common.delete'.tr()),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        onDelete();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.onError,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              'common.delete'.tr(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onError,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: _PetCard(pet: pet),
    );
  }
}

class _PetCard extends ConsumerWidget {
  const _PetCard({required this.pet});

  final Pet pet;


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final age = _calculateAge(pet.birthDate);
    final speciesColor = AppColors.getSpeciesColor(pet.species);

    return AppCard(
      onTap: () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_selected_pet_id', pet.id);
        } catch (_) {}
        _showPetDetails(context, pet);
      },
      onLongPress: () => _showPetOptions(context, ref, pet),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Pet Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                children: [
                  // 배경색 레이어 (기본 아이콘이 선택된 경우에만)
                  if (pet.defaultIcon != null && pet.profileBgColor != null)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/profile_bg/${pet.profileBgColor}.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: speciesColor.withOpacity(0.1),
                              child: Icon(
                                Icons.pets,
                                color: speciesColor,
                                size: 30,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // 아이콘 레이어
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pet.defaultIcon != null && pet.profileBgColor != null 
                          ? Colors.transparent 
                          : speciesColor.withOpacity(0.1),
                    ),
                    child: ClipOval(
                      child: pet.defaultIcon != null
                          ? _buildDefaultIcon(context, pet.defaultIcon, speciesColor, species: pet.species)
                          : pet.avatarUrl != null
                              ? Image.file(
                                  File(pet.avatarUrl!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildDefaultIcon(context, pet.defaultIcon, speciesColor, species: pet.species),
                                )
                              : _buildDefaultIcon(context, pet.defaultIcon, speciesColor, species: pet.species),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Pet Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pet.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      PetSpeciesChip(species: pet.species),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (pet.breed != null) ...[
                    Text(
                      pet.breed!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      if (age != null) ...[
                        Icon(
                          Icons.cake,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          age,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (pet.weightKg != null) ...[
                        Icon(
                          Icons.monitor_weight,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${pet.weightKg}kg',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Arrow
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;
    
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    
    if (years > 0) {
      return '$years years';
    } else if (months > 0) {
      return '$months months';
    } else {
      final days = difference.inDays;
      return '$days days';
    }
  }

         void _showPetDetails(BuildContext context, Pet pet) {
           context.push('/pets/${pet.id}');
         }

         void _editPet(BuildContext context, WidgetRef ref, Pet pet) {
           showModalBottomSheet<void>(
             context: context,
             isScrollControlled: true,
             builder: (context) => _EditPetSheet(pet: pet),
           );
         }

  void _showPetOptions(BuildContext context, WidgetRef ref, Pet pet) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Pet Info Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.getSpeciesColor(pet.species).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.getSpeciesColor(pet.species).withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.pets,
                      color: AppColors.getSpeciesColor(pet.species),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        Text(
                          pet.species,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Options
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text('common.edit'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _editPet(context, ref, pet);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'common.delete'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('pets.delete_confirm_title'.tr()),
                    content: Text('pets.delete_confirm_message'.tr(args: [pet.name])),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('common.cancel'.tr()),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: Text('common.delete'.tr()),
                      ),
                    ],
                  ),
                );

                if (shouldDelete == true) {
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
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(BuildContext context, String? defaultIcon, Color backgroundColor, {String? species}) {
    if (defaultIcon != null) {
      // Supabase Storage에서 이미지 URL 가져오기
      final imageUrl = ImageService.getDefaultIconUrl(species ?? 'cat', defaultIcon);
      if (imageUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Image.asset(
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
    
    return Icon(Icons.pets, color: backgroundColor, size: 30);
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
        return const Color(0xFFCD853F); // 페루색
      case 'cat1':
        return const Color(0xFF696969); // 회색
      case 'cat2':
        return const Color(0xFFA9A9A9); // 어두운 회색
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
  
  String _selectedSpecies = AppConstants.petSpecies.first;
  String? _selectedSex;
  bool? _isNeutered;
  DateTime? _birthDate;
  File? _selectedImage;
  String? _selectedDefaultIcon;
  String? _selectedBgColor;
  
  final List<String> _species = AppConstants.petSpecies;
  
  final List<String> _sexOptions = AppConstants.sexOptions;

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
    // DB 값 -> 표시값 변환
    _selectedSex = AppConstants.sexMapping.entries
        .firstWhere(
          (entry) => entry.value == pet.sex,
          orElse: () => const MapEntry('', ''),
        )
        .key;
    if (_selectedSex?.isEmpty ?? true) {
      _selectedSex = pet.sex; // 매핑되지 않은 경우 원본 값 사용
    }
    _isNeutered = pet.neutered;
    _birthDate = pet.birthDate;
    _selectedDefaultIcon = pet.defaultIcon;
    _selectedBgColor = pet.profileBgColor;
    
    // Load existing image if available
    if (pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty) {
      try {
        _selectedImage = File(pet.avatarUrl!);
      } catch (e) {
        print('❌ 기존 이미지 로드 실패: $e');
      }
    }
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
                
                // Profile Image Picker
                Center(
                  child: ProfileImagePicker(
                    imagePath: _selectedImage?.path,
                    selectedDefaultIcon: _selectedDefaultIcon,
                    selectedBgColor: _selectedBgColor,
                    species: _selectedSpecies, // 동물 종류 전달
                    onImageSelected: (image) {
                      if (image == null) {
                        return;
                      }
                      setState(() {
                        _selectedImage = image;
                        _selectedDefaultIcon = null; // 이미지 선택 시 기본 아이콘 제거
                        _selectedBgColor = null;
                      });
                    },
                    onDefaultIconSelected: (iconName, bgColor) {
                      setState(() {
                        _selectedDefaultIcon = iconName;
                        _selectedBgColor = bgColor;
                        _selectedImage = null; // 기본 아이콘 선택 시 이미지 제거
                      });
                    },
                    onClearSelection: () async {
                      setState(() {
                        _selectedImage = null;
                        _selectedDefaultIcon = null;
                        _selectedBgColor = null;
                      });
                    },
                    size: 120,
                  ),
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
    
    // _selectedImage는 이미 ProfileImagePicker에서 저장된 파일이므로 경로만 사용
    final String? avatarUrl = _selectedImage?.path ?? widget.pet.avatarUrl;
    
    // 성별 변환 (표시값 -> DB 값)
    final sexForDb = _selectedSex != null 
        ? AppConstants.sexMapping[_selectedSex] 
        : null;
    
    final updatedPet = widget.pet.copyWith(
      name: _nameController.text.trim(),
      species: _selectedSpecies,
      breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
      sex: sexForDb,
      neutered: _isNeutered,
      birthDate: _birthDate,
      weightKg: _weightController.text.isEmpty ? null : double.tryParse(_weightController.text),
      avatarUrl: avatarUrl,
      defaultIcon: _selectedDefaultIcon,
      profileBgColor: _selectedBgColor,
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
