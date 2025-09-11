import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/data/local/database.dart';

/// Repository for pet data management
class PetsRepository {
  PetsRepository({
    required this.supabase,
    required this.localDb,
  });

  final SupabaseClient supabase;
  final LocalDatabase localDb;

  /// Get all pets for the current user
  Future<List<Pet>> getAllPets() async {
    try {
      // Try to fetch from Supabase first
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('pets')
            .select()
            .eq('owner_id', user.id)
            .order('created_at', ascending: false);

        final pets = (response as List)
            .map((json) => Pet.fromJson(json as Map<String, dynamic>))
            .toList();

        // Cache locally
        for (final pet in pets) {
          await localDb.savePet(pet);
        }

        return pets;
      }
    } catch (e) {
      // If network fails, try local database
      print('Failed to fetch pets from Supabase: $e');
    }

    // Fallback to local database
    return await localDb.getAllPets();
  }

  /// Get pet by ID
  Future<Pet?> getPetById(String id) async {
    try {
      // Try Supabase first
      final response = await supabase
          .from('pets')
          .select()
          .eq('id', id)
          .single();

      final pet = Pet.fromJson(response as Map<String, dynamic>);
      
      // Cache locally
      await localDb.savePet(pet);
      
      return pet;
    } catch (e) {
      print('Failed to fetch pet from Supabase: $e');
      // Fallback to local database
      return await localDb.getPetById(id);
    }
  }

  /// Create a new pet
  Future<Pet> createPet(Pet pet) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create pet with user ID
      final petWithOwner = pet.copyWith(ownerId: user.id);
      
      // Save to Supabase
      final response = await supabase
          .from('pets')
          .insert(petWithOwner.toJson())
          .select()
          .single();

      final savedPet = Pet.fromJson(response as Map<String, dynamic>);
      
      // Cache locally
      await localDb.savePet(savedPet);
      
      return savedPet;
    } catch (e) {
      // If network fails, save locally and mark for sync
      print('Failed to create pet in Supabase: $e');
      await localDb.savePet(pet);
      return pet;
    }
  }

  /// Update an existing pet
  Future<Pet> updatePet(Pet pet) async {
    try {
      // Update in Supabase
      final response = await supabase
          .from('pets')
          .update(pet.toJson())
          .eq('id', pet.id)
          .select()
          .single();

      final updatedPet = Pet.fromJson(response as Map<String, dynamic>);
      
      // Update locally
      await localDb.savePet(updatedPet);
      
      return updatedPet;
    } catch (e) {
      print('Failed to update pet in Supabase: $e');
      // Update locally anyway
      await localDb.savePet(pet);
      return pet;
    }
  }

  /// Delete a pet
  Future<void> deletePet(String id) async {
    try {
      // Delete from Supabase
      await supabase
          .from('pets')
          .delete()
          .eq('id', id);

      // Delete locally
      await localDb.deletePet(id);
    } catch (e) {
      print('Failed to delete pet from Supabase: $e');
      // Delete locally anyway
      await localDb.deletePet(id);
    }
  }

  /// Sync local changes to Supabase
  Future<void> syncToCloud() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // TODO: Implement conflict resolution and sync logic
      // This would handle uploading local changes that couldn't be synced
      print('Syncing pets to cloud...');
    } catch (e) {
      print('Failed to sync pets to cloud: $e');
    }
  }
}

/// Provider for pets repository
final petsRepositoryProvider = Provider<PetsRepository>((ref) {
  return PetsRepository(
    supabase: Supabase.instance.client,
    localDb: LocalDatabase.instance,
  );
});
