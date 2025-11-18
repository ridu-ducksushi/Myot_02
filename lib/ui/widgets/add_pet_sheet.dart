import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/widgets/profile_image_picker.dart';
import 'package:petcare/ui/widgets/app_record_calendar.dart';
import 'package:petcare/utils/app_constants.dart';

class AddPetSheet extends ConsumerStatefulWidget {
  const AddPetSheet({super.key});

  @override
  ConsumerState<AddPetSheet> createState() => _AddPetSheetState();
}

class _AddPetSheetState extends ConsumerState<AddPetSheet> {
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

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

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
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomSafe = mediaQuery.padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset + bottomSafe),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
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
                  SizedBox(height: AppConstants.defaultPadding),

                  // Title
                  Text(
                    'pets.add_new'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: AppConstants.defaultPadding * 1.5),

                  // Form fields
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // Profile Image Picker
                        Center(
                          child: ProfileImagePicker(
                            imagePath: _selectedImage?.path,
                            selectedDefaultIcon: _selectedDefaultIcon,
                            selectedBgColor: _selectedBgColor,
                            species: _selectedSpecies,
                            onImageSelected: (image) {
                              if (image == null) {
                                return;
                              }
                              setState(() {
                                _selectedImage = image;
                                _selectedDefaultIcon = null;
                                _selectedBgColor = null;
                              });
                            },
                            onDefaultIconSelected: (iconName, bgColor) {
                              setState(() {
                                _selectedDefaultIcon = iconName;
                                _selectedBgColor = bgColor;
                                _selectedImage = null;
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
                        SizedBox(height: AppConstants.defaultPadding * 1.5),
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
                        SizedBox(height: AppConstants.defaultPadding),

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
                        SizedBox(height: AppConstants.defaultPadding),

                        AppTextField(
                          controller: _breedController,
                          labelText: 'pets.breed'.tr(),
                          prefixIcon: const Icon(Icons.info_outline),
                        ),
                        SizedBox(height: AppConstants.defaultPadding),

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
                        SizedBox(height: AppConstants.defaultPadding),

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
                        SizedBox(height: AppConstants.defaultPadding),

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
                        SizedBox(height: AppConstants.defaultPadding),

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
                        SizedBox(height: AppConstants.defaultPadding),

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
                  SizedBox(height: AppConstants.defaultPadding * 1.5),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('common.cancel'.tr()),
                        ),
                      ),
                      SizedBox(width: AppConstants.defaultPadding),
                      Expanded(
                        child: FilledButton(
                          onPressed: _savePet,
                          child: Text('common.save'.tr()),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: bottomSafe + AppConstants.addPetButtonBottomOffset,
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
    final now = DateTime.now();
    final initial = _birthDate ?? now.subtract(const Duration(days: 365));
    final first = now.subtract(const Duration(days: 365 * 30));

    final picked = await showRecordCalendarDialog(
      context: context,
      initialDate: _dateOnly(initial),
      firstDay: _dateOnly(first),
      lastDay: _dateOnly(now),
      markedDates: {
        if (_birthDate != null) _dateOnly(_birthDate!),
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _birthDate = _dateOnly(picked);
      });
    }
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) return;

    final String? avatarUrl = _selectedImage?.path;

    final sexForDb = _selectedSex != null
        ? AppConstants.sexMapping[_selectedSex]
        : null;

    final pet = Pet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: Supabase.instance.client.auth.currentUser?.id ?? 'guest',
      name: _nameController.text.trim(),
      species: _selectedSpecies,
      breed: _breedController.text.trim().isEmpty
          ? null
          : _breedController.text.trim(),
      sex: sexForDb,
      neutered: _isNeutered,
      birthDate: _birthDate,
      weightKg: _weightController.text.isEmpty
          ? null
          : double.tryParse(_weightController.text),
      avatarUrl: avatarUrl,
      defaultIcon: _selectedDefaultIcon,
      profileBgColor: _selectedBgColor,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.read(petsProvider.notifier).addPet(pet);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

