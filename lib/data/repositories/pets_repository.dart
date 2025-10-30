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
    final Map<String, dynamic> row = {
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
      'default_icon': pet.defaultIcon,
      'profile_bg_color': pet.profileBgColor,
      'note': pet.note,
      'supplies_food': pet.suppliesFood,
      'supplies_supplement': pet.suppliesSupplement,
      'supplies_snack': pet.suppliesSnack,
      'supplies_litter': pet.suppliesLitter,
      'supplies_last_updated': pet.suppliesLastUpdated?.toIso8601String(),
      // created_at/updated_at are defaulted by DB triggers if set; omit to avoid format mismatches
    };
    
    // avatarUrl/defaultIcon/profileBgColor/note 는 명시적으로 null 허용 (삭제/초기화 반영)
    // 나머지 필드만 null 제거
    row.removeWhere((k, v) => v == null && k != 'avatar_url' && k != 'default_icon' && k != 'profile_bg_color' && k != 'note');
    
    return row;
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
      defaultIcon: row['default_icon'] as String?,
      profileBgColor: row['profile_bg_color'] as String?,
      note: row['note'] as String?,
      suppliesFood: row['supplies_food'] as String?,
      suppliesSupplement: row['supplies_supplement'] as String?,
      suppliesSnack: row['supplies_snack'] as String?,
      suppliesLitter: row['supplies_litter'] as String?,
      suppliesLastUpdated: row['supplies_last_updated'] != null ? DateTime.tryParse(row['supplies_last_updated'] as String) : null,
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((row['updated_at'] as String?) ?? '') ?? DateTime.now(),
    );
  }

  Future<void> _ensureUserExists() async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) return;
    try {
      await supabase.from('users').upsert({
        'id': authUser.id,
        'email': authUser.email,
        'display_name': authUser.userMetadata?['name'] ?? authUser.email,
      });
    } catch (_) {
      // Ignore if exists or RLS prevents; FK will reveal issues otherwise
    }
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

          // Debug: dump all pet scopes/keys before migration
          await localDb.debugDumpAllPetScopes();

          // 자동 마이그레이션: 로컬에 guest/local-user 소유 펫이 있으면 현재 사용자로 승격 후 클라우드 업로드
          await _migrateLocalGuestPets(user.id);

          final localPets = await localDb.getAllPets();
          print('🧭 로컬 전체 펫 목록 (${localPets.length}) → ' + localPets.map((p) => '[${p.ownerId}] ${p.name}').take(10).join(', '));
          final filteredPets = localPets.where((pet) {
            if (pet.ownerId == user.id) return true;
            // 마이그레이션 직후 반영 지연 대비: 임시로 local-user/guest도 포함
            if (pet.ownerId == 'local-user') return true;
            if (pet.ownerId == 'guest') return true;
            return false;
          }).toList();
          print('🧭 필터 후 펫 목록 (${filteredPets.length}) → ' + filteredPets.map((p) => '[${p.ownerId}] ${p.name}').take(10).join(', '));
          
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

  /// 로컬의 guest/local-user 펫을 현재 사용자 소유로 승격하고 Supabase에 업로드
  Future<void> _migrateLocalGuestPets(String currentUserId) async {
    try {
      // 게스트/로컬유저 스코프에 저장된 펫을 직접 읽어와서 마이그레이션
      print('🔎 스코프 점검 시작 (guest/local-user)');
      final guestPets = await localDb.getAllPetsForScope('guest');
      final localUserPets = await localDb.getAllPetsForScope('local-user');
      print('📦 guest 스코프: ${guestPets.length}개 → ' + guestPets.map((p) => p.name).take(10).join(', '));
      print('📦 local-user 스코프: ${localUserPets.length}개 → ' + localUserPets.map((p) => p.name).take(10).join(', '));
      final needsMigration = [...guestPets, ...localUserPets];
      if (needsMigration.isEmpty) {
        print('ℹ️ 마이그레이션 대상 없음');
        return;
      }

      print('🔄 자동 마이그레이션 시작: 대상 ${needsMigration.length}개');

      for (final pet in needsMigration) {
        try {
          // 현재 사용자 소유로 변경
          final migratedPet = pet.copyWith(
            ownerId: currentUserId,
            updatedAt: DateTime.now(),
          );

          print('⬆️ 업로드 시도: ${pet.name} (oldOwner=${pet.ownerId}) → newOwner=$currentUserId');
          // Supabase에 업로드 (id는 DB에서 생성) → 응답으로 받은 id로 로컬 업데이트
          final insertRow = _toSupabaseRow(migratedPet, currentUserId);
          final response = await supabase
              .from('pets')
              .insert(insertRow)
              .select()
              .single();

          final savedPet = _fromSupabaseRow(response as Map<String, dynamic>);

          // 로컬 저장소에 새 ID로 저장 (이전 guest/local-user 항목 대체)
          await localDb.savePet(savedPet);

          print('✅ 마이그레이션 완료: ${savedPet.name} (신규 ID: ${savedPet.id})');
        } catch (e) {
          print('❌ 펫 마이그레이션 실패: ${pet.name} - $e');
          // 실패 시에도 다른 항목 진행
        }
      }

      // 마이그레이션 완료 후, 이전 스코프 데이터 정리
      await localDb.removeScopedKeyFor('pets', 'guest');
      await localDb.removeScopedKeyFor('pets', 'local-user');
      print('🧹 스코프 정리 완료 (guest/local-user)');
    } catch (e) {
      print('❌ 자동 마이그레이션 전체 실패: $e');
    }
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
        await _ensureUserExists();
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
