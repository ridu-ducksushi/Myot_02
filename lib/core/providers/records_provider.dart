import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petcare/data/models/record.dart';

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
  RecordsNotifier() : super(const RecordsState());

  /// Load all records
  Future<void> loadRecords([String? petId]) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data loading from repository
      await Future<void>.delayed(const Duration(seconds: 1));
      
      // Mock data for now
      final mockRecords = [
        Record(
          id: '1',
          petId: '1',
          type: 'meal',
          title: 'Morning Feed',
          content: 'Regular dry food, 1 cup',
          at: DateTime.now().subtract(const Duration(hours: 2)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Record(
          id: '2',
          petId: '1',
          type: 'walk',
          title: 'Morning Walk',
          content: '30 minutes in the park',
          at: DateTime.now().subtract(const Duration(hours: 1)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Record(
          id: '3',
          petId: '2',
          type: 'litter',
          title: 'Litter Box Clean',
          content: 'Changed litter box',
          at: DateTime.now().subtract(const Duration(minutes: 30)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      
      // Filter by pet if petId is provided
      final filteredRecords = petId != null
          ? mockRecords.where((record) => record.petId == petId).toList()
          : mockRecords;
      
      state = state.copyWith(
        records: filteredRecords,
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
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data saving to repository
      await Future<void>.delayed(const Duration(milliseconds: 500));
      
      final updatedRecords = [record, ...state.records];
      state = state.copyWith(
        records: updatedRecords,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Update an existing record
  Future<void> updateRecord(Record updatedRecord) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data updating in repository
      await Future<void>.delayed(const Duration(milliseconds: 500));
      
      final updatedRecords = state.records.map((record) {
        return record.id == updatedRecord.id ? updatedRecord : record;
      }).toList();
      
      state = state.copyWith(
        records: updatedRecords,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Delete a record
  Future<void> deleteRecord(String recordId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data deletion from repository
      await Future<void>.delayed(const Duration(milliseconds: 500));
      
      final updatedRecords = state.records.where((record) => record.id != recordId).toList();
      state = state.copyWith(
        records: updatedRecords,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Records provider
final recordsProvider = StateNotifierProvider<RecordsNotifier, RecordsState>((ref) {
  return RecordsNotifier();
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
