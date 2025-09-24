import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petcare/data/local/database.dart';
import 'package:petcare/data/models/record.dart';
import 'package:petcare/data/repositories/records_repository.dart';

/// State class for records list
class RecordsState {
  const RecordsState({
    this.records = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Record> records;
  final bool isLoading;
  final String? error;

  RecordsState copyWith({
    List<Record>? records,
    bool? isLoading,
    String? error,
  }) {
    return RecordsState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Records provider notifier
class RecordsNotifier extends StateNotifier<RecordsState> {
  RecordsNotifier(this._repository) : super(const RecordsState());

  final RecordsRepository _repository;

  /// Load all records
  Future<void> loadRecords([String? petId]) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final records = petId != null
          ? await _repository.getRecordsForPet(petId)
          : await _repository.getAllRecords();
      
      state = state.copyWith(
        records: records,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Add a new record
  Future<void> addRecord(Record record) async {
    final oldRecords = state.records;
    final updatedRecords = [record, ...oldRecords];
    state = state.copyWith(records: updatedRecords); // Optimistic update

    try {
      final savedRecord = await _repository.createRecord(record);
      // Update with the saved record (which has server-generated ID)
      final finalRecords = [savedRecord, ...oldRecords];
      state = state.copyWith(records: finalRecords);
    } catch (e) {
      state = state.copyWith(records: oldRecords, error: e.toString()); // Revert on error
    }
  }

  /// Update an existing record
  Future<void> updateRecord(Record updatedRecord) async {
    final oldRecords = state.records;
    final updatedRecords = state.records.map((record) {
      return record.id == updatedRecord.id ? updatedRecord : record;
    }).toList();
    state = state.copyWith(records: updatedRecords); // Optimistic update
    
    try {
      final savedRecord = await _repository.updateRecord(updatedRecord);
      final finalRecords = state.records.map((record) {
        return record.id == savedRecord.id ? savedRecord : record;
      }).toList();
      state = state.copyWith(records: finalRecords);
    } catch (e) {
      state = state.copyWith(records: oldRecords, error: e.toString()); // Revert
    }
  }

  /// Delete a record
  Future<void> deleteRecord(String recordId) async {
    final oldRecords = state.records;
    final updatedRecords = state.records.where((record) => record.id != recordId).toList();
    state = state.copyWith(records: updatedRecords); // Optimistic update

    try {
      await _repository.deleteRecord(recordId);
    } catch (e) {
      state = state.copyWith(records: oldRecords, error: e.toString()); // Revert
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Records provider
final recordsProvider = StateNotifierProvider<RecordsNotifier, RecordsState>((ref) {
  return RecordsNotifier(ref.read(recordsRepositoryProvider));
});

/// Records for specific pet provider
final recordsForPetProvider = Provider.family<List<Record>, String>((ref, petId) {
  final recordsState = ref.watch(recordsProvider);
  return recordsState.records.where((record) => record.petId == petId).toList();
});

/// Today's records provider
final todaysRecordsProvider = Provider<List<Record>>((ref) {
  final recordsState = ref.watch(recordsProvider);
  final today = DateTime.now();
  
  return recordsState.records.where((record) {
    final recordDate = record.at;
    return recordDate.year == today.year &&
           recordDate.month == today.month &&
           recordDate.day == today.day;
  }).toList();
});

/// Weekly records provider
final weeklyRecordsProvider = Provider<List<Record>>((ref) {
  final recordsState = ref.watch(recordsProvider);
  final today = DateTime.now();
  final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 6));

  return recordsState.records.where((record) {
    final recordDate = record.at;
    return recordDate.isAfter(startOfWeek) && recordDate.isBefore(endOfWeek.add(const Duration(days: 1)));
  }).toList();
});

/// Monthly records provider
final monthlyRecordsProvider = Provider<List<Record>>((ref) {
  final recordsState = ref.watch(recordsProvider);
  final today = DateTime.now();

  return recordsState.records.where((record) {
    final recordDate = record.at;
    return recordDate.year == today.year && recordDate.month == today.month;
  }).toList();
});

/// Yearly records provider
final yearlyRecordsProvider = Provider<List<Record>>((ref) {
  final recordsState = ref.watch(recordsProvider);
  final today = DateTime.now();

  return recordsState.records.where((record) {
    final recordDate = record.at;
    return recordDate.year == today.year;
  }).toList();
});

/// Records count provider
final recordsCountProvider = Provider<int>((ref) {
  final recordsState = ref.watch(recordsProvider);
  return recordsState.records.length;
});

/// Records by type provider
final recordsByTypeProvider = Provider.family<List<Record>, String>((ref, type) {
  final recordsState = ref.watch(recordsProvider);
  return recordsState.records.where((record) => record.type == type).toList();
});
