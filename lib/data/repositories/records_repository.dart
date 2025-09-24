import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petcare/data/models/record.dart';
import 'package:petcare/data/local/database.dart';

/// Repository for record data management
class RecordsRepository {
  RecordsRepository({
    required this.supabase,
    required this.localDb,
  });

  final SupabaseClient supabase;
  final LocalDatabase localDb;

  Map<String, dynamic> _toSupabaseRow(Record record) {
    return {
      // Do NOT send id; let Supabase generate
      'pet_id': record.petId,
      'type': record.type,
      'title': record.title,
      'content': record.content,
      'value': record.value,
      'at': record.at.toIso8601String(),
      'files': record.files,
    }..removeWhere((k, v) => v == null);
  }

  bool _isValidUUID(String str) {
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);
    return uuidRegex.hasMatch(str);
  }

  Record _fromSupabaseRow(Map<String, dynamic> row) {
    return Record(
      id: row['id'] as String,
      petId: (row['pet_id'] as String),
      type: row['type'] as String,
      title: row['title'] as String? ?? '',
      content: row['content'] as String?,
      value: row['value'] as Map<String, dynamic>?,
      at: DateTime.tryParse(row['at'] as String? ?? '') ?? DateTime.now(),
      files: (row['files'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Get all records for a pet
  Future<List<Record>> getRecordsForPet(String petId) async {
    try {
      // Try to fetch from Supabase first
      final user = supabase.auth.currentUser;
      final response = await supabase
          .from('records')
          .select()
          .eq('pet_id', petId)
          .order('at', ascending: false);

      final records = (response as List)
          .map((row) => _fromSupabaseRow(row as Map<String, dynamic>))
          .toList();

      // Cache locally
      for (final record in records) {
        await localDb.saveRecord(record);
      }

      if (user == null) {
        return records;
      }

      return records.where((record) => record.petId == petId).toList();
    } catch (e) {
      print('Failed to fetch records from Supabase: $e');
      // Fallback to local database
      return await localDb.getRecordsForPet(petId);
    }
  }

  /// Get all records
  Future<List<Record>> getAllRecords() async {
    try {
      // Try to fetch from Supabase first
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Get records for user's pets
      final response = await supabase
          .from('records')
          .select('''
              *,
              pets!inner(owner_id)
            ''')
          .eq('pets.owner_id', user.id)
          .order('at', ascending: false);

        final records = (response as List)
            .map((row) => _fromSupabaseRow(row as Map<String, dynamic>))
            .toList();

        // Cache locally
        for (final record in records) {
          await localDb.saveRecord(record);
        }

        return records;
      }
    } catch (e) {
      print('Failed to fetch records from Supabase: $e');
    }

    // Fallback to local database (사용자 기준 필터링)
    final all = await localDb.getAllRecords();
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return all.where((r) => false).toList();
    // 로컬에는 ownerId가 없으므로, 현재는 전체 레코드 중 서버에서 동기화된 항목만 남도록 서버 우선으로 로드하도록 유도
    return all; // 최소 변경: 필요 시 Record 모델에 ownerId 추가 후 강제 필터링
  }

  /// Get today's records
  Future<List<Record>> getTodaysRecords() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('records')
            .select('''
              *,
              pets!inner(owner_id)
            ''')
            .eq('pets.owner_id', user.id)
            .gte('at', startOfDay.toIso8601String())
            .lt('at', endOfDay.toIso8601String())
            .order('at', ascending: false);

        return (response as List)
            .map((row) => _fromSupabaseRow(row as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Failed to fetch today\'s records from Supabase: $e');
    }

    // Fallback to filtering local records
    final allRecords = await localDb.getAllRecords();
    return allRecords.where((record) {
      return record.at.isAfter(startOfDay) && record.at.isBefore(endOfDay);
    }).toList();
  }

  /// Create a new record
  Future<Record> createRecord(Record record) async {
    try {
      // If petId is not a UUID (likely local only), save locally only
      if (!_isValidUUID(record.petId)) {
        print('⚠️ PetId is not a UUID, saving locally only: ${record.petId}');
        await localDb.saveRecord(record);
        return record;
      }
      
      final insertRow = _toSupabaseRow(record);
      final response = await supabase
          .from('records')
          .insert(insertRow)
          .select()
          .single();

      final savedRecord = _fromSupabaseRow(response as Map<String, dynamic>);
      
      // Cache locally
      await localDb.saveRecord(savedRecord);
      
      return savedRecord;
    } catch (e) {
      print('Failed to create record in Supabase: $e');
      // Save locally anyway
      await localDb.saveRecord(record);
      return record;
    }
  }

  /// Update an existing record
  Future<Record> updateRecord(Record record) async {
    try {
      // If petId is not a UUID (likely local only), save locally only
      if (!_isValidUUID(record.petId)) {
        print('⚠️ PetId is not a UUID, updating locally only: ${record.petId}');
        await localDb.saveRecord(record);
        return record;
      }
      
      final updateRow = _toSupabaseRow(record);
      final response = await supabase
          .from('records')
          .update(updateRow)
          .eq('id', record.id)
          .select()
          .single();

      final updatedRecord = _fromSupabaseRow(response as Map<String, dynamic>);
      
      // Update locally
      await localDb.saveRecord(updatedRecord);
      
      return updatedRecord;
    } catch (e) {
      print('Failed to update record in Supabase: $e');
      // Update locally anyway
      await localDb.saveRecord(record);
      return record;
    }
  }

  /// Delete a record
  Future<void> deleteRecord(String id) async {
    try {
      // Delete from Supabase
      await supabase
          .from('records')
          .delete()
          .eq('id', id);

      // Delete locally
      await localDb.deleteRecord(id);
    } catch (e) {
      print('Failed to delete record from Supabase: $e');
      // Delete locally anyway
      await localDb.deleteRecord(id);
    }
  }

  /// Get records by type
  Future<List<Record>> getRecordsByType(String type) async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('records')
            .select('''
              *,
              pets!inner(owner_id)
            ''')
            .eq('pets.owner_id', user.id)
            .eq('type', type)
            .order('at', ascending: false);

        return (response as List)
            .map((row) => _fromSupabaseRow(row as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Failed to fetch records by type from Supabase: $e');
    }

    // Fallback to filtering local records
    final allRecords = await localDb.getAllRecords();
    return allRecords.where((record) => record.type == type).toList();
  }

  /// Sync local changes to Supabase
  Future<void> syncToCloud() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // TODO: Implement conflict resolution and sync logic
      print('Syncing records to cloud...');
    } catch (e) {
      print('Failed to sync records to cloud: $e');
    }
  }
}

/// Provider for records repository
final recordsRepositoryProvider = Provider<RecordsRepository>((ref) {
  return RecordsRepository(
    supabase: Supabase.instance.client,
    localDb: LocalDatabase.instance,
  );
});
