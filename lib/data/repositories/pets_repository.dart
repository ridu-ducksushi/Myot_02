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
      print('🔍 getAllPets - 현재 사용자: ${user?.email ?? 'null'}');
      
      if (user != null) {
        try {
          final response = await supabase
              .from('pets')
              .select()
              .eq('owner_id', user.id)
              .order('created_at', ascending: false);

          final pets = (response as List)
              .map((json) => Pet.fromJson(json as Map<String, dynamic>))
              .toList();

          print('✅ Supabase에서 ${pets.length}개 펫 로드');

          // Cache locally
          for (final pet in pets) {
            await localDb.savePet(pet);
          }

          // 로컬 데이터와 합치기
          final localPets = await localDb.getAllPets();
          final allPets = [...pets];
          
          // 로컬에만 있는 펫들 추가 (중복 제거)
          for (final localPet in localPets) {
            if (!allPets.any((p) => p.id == localPet.id)) {
              allPets.add(localPet);
            }
          }
          
          print('✅ 총 ${allPets.length}개 펫 반환 (Supabase: ${pets.length}, 로컬: ${localPets.length})');
          return allPets;
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
    print('📱 로컬에서 ${localPets.length}개 펫 로드');
    return localPets;
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
      print('🔍 현재 사용자: ${user?.email ?? 'null'} (ID: ${user?.id ?? 'null'})');
      
      if (user != null) {
        // Create pet with user ID
        final petWithOwner = pet.copyWith(ownerId: user.id);
        
        // Save to Supabase (avatarUrl 제거)
        final petJson = petWithOwner.toJson();
        petJson.remove('avatarUrl'); // Supabase 테이블에 없는 컬럼 제거
        
        final response = await supabase
            .from('pets')
            .insert(petJson)
            .select()
            .single();

        final savedPet = Pet.fromJson(response as Map<String, dynamic>);
        
        // Cache locally
        await localDb.savePet(savedPet);
        
        print('✅ Supabase에 펫 저장 성공: ${savedPet.name} (ID: ${savedPet.id})');
        return savedPet;
      } else {
        // 로그인하지 않은 경우 로컬에만 저장
        print('⚠️ 사용자가 로그인하지 않음 - 로컬 저장');
        final localPet = pet.copyWith(ownerId: 'local-user');
        await localDb.savePet(localPet);
        print('📱 로컬에만 펫 저장: ${localPet.name}');
        return localPet;
      }
    } catch (e) {
      // Supabase 오류 시 로컬에만 저장
      print('❌ Supabase 저장 실패 상세: $e');
      print('🔄 로컬 저장으로 대체');
      final localPet = pet.copyWith(ownerId: 'local-user');
      await localDb.savePet(localPet);
      return localPet;
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
