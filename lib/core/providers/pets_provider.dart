import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petcare/data/models/pet.dart';

/// State class for pets list
class PetsState {
  const PetsState({
    this.pets = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Pet> pets;
  final bool isLoading;
  final String? error;

  PetsState copyWith({
    List<Pet>? pets,
    bool? isLoading,
    String? error,
  }) {
    return PetsState(
      pets: pets ?? this.pets,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Pets provider notifier
class PetsNotifier extends StateNotifier<PetsState> {
  PetsNotifier() : super(const PetsState());

  /// Load all pets
  Future<void> loadPets() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data loading from repository
      await Future.delayed(const Duration(seconds: 1)); // Simulating API call
      
      // Mock data for now
      final mockPets = [
        Pet(
          id: '1',
          ownerId: 'user1',
          name: 'Buddy',
          species: 'Dog',
          breed: 'Golden Retriever',
          sex: 'Male',
          neutered: true,
          birthDate: DateTime(2020, 5, 15),
          weightKg: 25.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Pet(
          id: '2',
          ownerId: 'user1',
          name: 'Whiskers',
          species: 'Cat',
          breed: 'Persian',
          sex: 'Female',
          neutered: true,
          birthDate: DateTime(2019, 8, 20),
          weightKg: 4.2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      
      state = state.copyWith(
        pets: mockPets,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Add a new pet
  Future<void> addPet(Pet pet) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data saving to repository
      await Future.delayed(const Duration(milliseconds: 500));
      
      final updatedPets = [...state.pets, pet];
      state = state.copyWith(
        pets: updatedPets,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Update an existing pet
  Future<void> updatePet(Pet updatedPet) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data updating in repository
      await Future.delayed(const Duration(milliseconds: 500));
      
      final updatedPets = state.pets.map((pet) {
        return pet.id == updatedPet.id ? updatedPet : pet;
      }).toList();
      
      state = state.copyWith(
        pets: updatedPets,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Delete a pet
  Future<void> deletePet(String petId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data deletion from repository
      await Future.delayed(const Duration(milliseconds: 500));
      
      final updatedPets = state.pets.where((pet) => pet.id != petId).toList();
      state = state.copyWith(
        pets: updatedPets,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Get pet by ID
  Pet? getPetById(String petId) {
    try {
      return state.pets.firstWhere((pet) => pet.id == petId);
    } catch (e) {
      return null;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Pets provider
final petsProvider = StateNotifierProvider<PetsNotifier, PetsState>((ref) {
  return PetsNotifier();
});

/// Selected pet provider
final selectedPetProvider = StateProvider<Pet?>((ref) => null);

/// Pet by ID provider
final petByIdProvider = Provider.family<Pet?, String>((ref, petId) {
  final petsState = ref.watch(petsProvider);
  return petsState.pets.where((pet) => pet.id == petId).firstOrNull;
});

/// Pets count provider
final petsCountProvider = Provider<int>((ref) {
  final petsState = ref.watch(petsProvider);
  return petsState.pets.length;
});
