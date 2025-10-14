import 'package:petcare/data/models/pet_supplies.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PetSuppliesRepository {
  final SupabaseClient _client;

  PetSuppliesRepository(this._client);

  bool _isEmptySuppliesRow(Map<String, dynamic> row) {
    bool _isEmpty(dynamic v) => v == null || (v is String && v.trim().isEmpty);
    return _isEmpty(row['dry_food']) &&
        _isEmpty(row['wet_food']) &&
        _isEmpty(row['supplement']) &&
        _isEmpty(row['snack']) &&
        _isEmpty(row['litter']);
  }

  // 특정 날짜의 물품 기록 조회
  Future<PetSupplies?> getSuppliesByDate(String petId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('pet_supplies')
          .select()
          .eq('pet_id', petId)
          .gte('recorded_at', startOfDay.toIso8601String())
          .lt('recorded_at', endOfDay.toIso8601String())
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      if (_isEmptySuppliesRow(response)) return null;

      return PetSupplies.fromJson(_fromSupabaseRow(response));
    } catch (e) {
      print('❌ Error getting supplies by date: $e');
      return null;
    }
  }

  // 특정 펫의 모든 물품 기록 날짜 조회
  Future<List<DateTime>> getSuppliesRecordDates(String petId) async {
    try {
      final response = await _client
          .from('pet_supplies')
          .select('recorded_at,dry_food,wet_food,supplement,snack,litter')
          .eq('pet_id', petId)
          .order('recorded_at', ascending: false);

      final filtered = (response as List)
          .where((row) => !_isEmptySuppliesRow(row as Map<String, dynamic>))
          .map((row) => DateTime.parse(row['recorded_at'] as String))
          .map((dt) => DateTime(dt.year, dt.month, dt.day))
          .toSet()
          .toList();

      return filtered;
    } catch (e) {
      print('❌ Error getting supplies record dates: $e');
      return [];
    }
  }

  // 물품 기록 저장/업데이트
  Future<PetSupplies> saveSupplies(PetSupplies supplies) async {
    try {
      final data = _toSupabaseRow(supplies);

      // 같은 날짜의 기록이 있는지 확인
      final existing = await getSuppliesByDate(supplies.petId, supplies.recordedAt);

      bool isAllEmpty = [
        supplies.dryFood,
        supplies.wetFood,
        supplies.supplement,
        supplies.snack,
        supplies.litter,
      ].every((v) => v == null || (v?.trim().isEmpty ?? true));

      if (existing != null) {
        if (isAllEmpty) {
          // 모든 값이 비어있으면 해당 날짜 레코드 삭제
          await _client.from('pet_supplies').delete().eq('id', existing.id);
          // 삭제 후에도 상위 로직이 날짜 목록을 재조회하여 UI 갱신하도록 빈 값 그대로 반환
          return supplies;
        }
        // 업데이트
        final response = await _client
            .from('pet_supplies')
            .update(data)
            .eq('id', existing.id)
            .select()
            .single();

        return PetSupplies.fromJson(_fromSupabaseRow(response));
      } else {
        // 새로 생성: 단, 모두 비어있으면 생성하지 않음
        if (isAllEmpty) {
          return supplies;
        }
        final response = await _client
            .from('pet_supplies')
            .insert(data)
            .select()
            .single();

        return PetSupplies.fromJson(_fromSupabaseRow(response));
      }
    } catch (e) {
      print('❌ Error saving supplies: $e');
      rethrow;
    }
  }

  // 물품 기록 삭제
  Future<void> deleteSupplies(String id) async {
    try {
      await _client
          .from('pet_supplies')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('❌ Error deleting supplies: $e');
      rethrow;
    }
  }

  // Supabase snake_case → Flutter camelCase 변환
  Map<String, dynamic> _fromSupabaseRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'petId': row['pet_id'],
      'dryFood': row['dry_food'],
      'wetFood': row['wet_food'],
      'supplement': row['supplement'],
      'snack': row['snack'],
      'litter': row['litter'],
      'recordedAt': row['recorded_at'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    };
  }

  // Flutter camelCase → Supabase snake_case 변환
  Map<String, dynamic> _toSupabaseRow(PetSupplies supplies) {
    return {
      'id': supplies.id,
      'pet_id': supplies.petId,
      'dry_food': supplies.dryFood,
      'wet_food': supplies.wetFood,
      'supplement': supplies.supplement,
      'snack': supplies.snack,
      'litter': supplies.litter,
      'recorded_at': supplies.recordedAt.toIso8601String(),
      'created_at': supplies.createdAt.toIso8601String(),
      'updated_at': supplies.updatedAt.toIso8601String(),
    };
  }
}

