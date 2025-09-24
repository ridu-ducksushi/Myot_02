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

  Map<String, dynamic> _toSupabaseRow(Pet pet, String ownerId) {
    return {
      // Do NOT send id: let Supabase generate UUID
      'owner_id': ownerId,
      'name': pet.name,
      'species': pet.species,
      'breed': pet.breed,
      'sex': pet.sex,
      'neutered': pet.neutered,
      'birth_date': pet.birthDate?.toIso8601String(),
      'blood_type': pet.bloodType,
      'weight_kg': pet.weightKg,
      'avatar_url': pet.avatarUrl,
      'note': pet.note,
      // created_at/updated_at are defaulted by DB triggers if set; omit to avoid format mismatches
    }..removeWhere((k, v) => v == null);
  }

  Pet _fromSupabaseRow(Map<String, dynamic> row) {
    return Pet(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      name: row['name'] as String,
      species: row['species'] as String,
      breed: row['breed'] as String?,
      sex: row['sex'] as String?,
      neutered: row['neutered'] as bool?,
      birthDate: row['birth_date'] != null ? DateTime.tryParse(row['birth_date'] as String) : null,
      bloodType: row['blood_type'] as String?,
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      avatarUrl: row['avatar_url'] as String?,
      note: row['note'] as String?,
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((row['updated_at'] as String?) ?? '') ?? DateTime.now(),
    );
  }

  /// Get all pets for the current user
  Future<List<Pet>> getAllPets() async {
    try {
      // Try to fetch from Supabase first
      final user = supabase.auth.currentUser;
      print('🔍 getAllPets - 현재 사용자: ${user?.email ?? 'null'}');
      
      if (user != null) {
        try {
          final response = await supabase
              .from('pets')
              .select()
              .eq('owner_id', user.id)
              .order('created_at', ascending: false);

          final pets = (response as List)
              .map((row) => _fromSupabaseRow(row as Map<String, dynamic>))
              .toList();

          print('✅ Supabase에서 ${pets.length}개 펫 로드');

          // Cache locally
          for (final pet in pets) {
            await localDb.savePet(pet);
          }

          final localPets = await localDb.getAllPets();
          final filteredPets = localPets.where((pet) {
            if (pet.ownerId == user.id) return true;
            if (pet.ownerId == 'local-user') return true;
            return false;
          }).toList();
          
          print('✅ 총 ${filteredPets.length}개 펫 반환 (Supabase: ${pets.length}, 로컬: ${localPets.length})');
          return filteredPets;
        } catch (e) {
          print('❌ Supabase에서 펫 로드 실패: $e');
        }
      }
    } catch (e) {
      print('❌ getAllPets 전체 오류: $e');
    }

    // Fallback to local database
    print('🔄 로컬 데이터베이스에서 로드');
    final localPets = await localDb.getAllPets();
    final userId = supabase.auth.currentUser?.id;
    final filtered = localPets.where((pet) {
      if (userId == null) {
        return pet.ownerId == 'local-user';
      }
      return pet.ownerId == userId || pet.ownerId == 'local-user';
    }).toList();
    print('📱 로컬에서 ${filtered.length}개 펫 로드 (필터링 적용)');
    return filtered;
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

      final pet = _fromSupabaseRow(response as Map<String, dynamic>);
      
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
      print('🔍 현재 사용자: ${user?.email ?? 'null'} (ID: ${user?.id ?? 'null'})');
      
      if (user != null) {
        // Build row for Supabase
        final insertRow = _toSupabaseRow(pet, user.id);
        final response = await supabase
            .from('pets')
            .insert(insertRow)
            .select()
            .single();

        final savedPet = _fromSupabaseRow(response as Map<String, dynamic>);
        
        // Cache locally
        await localDb.savePet(savedPet);
        
        print('✅ Supabase에 펫 저장 성공: ${savedPet.name} (ID: ${savedPet.id})');
        return savedPet;
      } else {
        // 로그인하지 않은 경우 로컬에만 저장
        print('⚠️ 사용자가 로그인하지 않음 - 로컬 저장');
        await localDb.savePet(pet);
        print('📱 로컬에만 펫 저장: ${pet.name}');
        return pet;
      }
    } catch (e) {
      // Supabase 오류 시 로컬에만 저장
      print('❌ Supabase 저장 실패 상세: $e');
      print('🔄 로컬 저장으로 대체');
      await localDb.savePet(pet);
      return pet;
    }
  }

  /// Update an existing pet
  Future<Pet> updatePet(Pet pet) async {
    try {
      // Update in Supabase
      final userId = supabase.auth.currentUser?.id;
      final updateRow = userId != null ? _toSupabaseRow(pet, userId) : _toSupabaseRow(pet, pet.ownerId);
      final response = await supabase
          .from('pets')
          .update(updateRow)
          .eq('id', pet.id)
          .select()
          .single();

      final updatedPet = _fromSupabaseRow(response as Map<String, dynamic>);
      
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
