import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petcare/data/models/reminder.dart';

/// State class for reminders list
class RemindersState {
  const RemindersState({
    this.reminders = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Reminder> reminders;
  final bool isLoading;
  final String? error;

  RemindersState copyWith({
    List<Reminder>? reminders,
    bool? isLoading,
    String? error,
  }) {
    return RemindersState(
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Reminders provider notifier
class RemindersNotifier extends StateNotifier<RemindersState> {
  RemindersNotifier() : super(const RemindersState());

  /// Load all reminders
  Future<void> loadReminders([String? petId]) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data loading from repository
      await Future<void>.delayed(const Duration(seconds: 1));
      
      // Mock data for now
      final mockReminders = [
        Reminder(
          id: '1',
          petId: '1',
          type: 'vaccine',
          title: 'Annual Vaccination',
          note: 'DHPP vaccine due',
          scheduledAt: DateTime.now().add(const Duration(days: 7)),
          createdAt: DateTime.now(),
        ),
        Reminder(
          id: '2',
          petId: '1',
          type: 'medicine',
          title: 'Heartworm Prevention',
          note: 'Monthly heartworm medication',
          scheduledAt: DateTime.now().add(const Duration(days: 3)),
          repeatRule: 'monthly',
          createdAt: DateTime.now(),
        ),
        Reminder(
          id: '3',
          petId: '2',
          type: 'grooming',
          title: 'Nail Trim',
          note: 'Trim claws',
          scheduledAt: DateTime.now().add(const Duration(days: 14)),
          createdAt: DateTime.now(),
        ),
      ];
      
      // Filter by pet if petId is provided
      final filteredReminders = petId != null
          ? mockReminders.where((reminder) => reminder.petId == petId).toList()
          : mockReminders;
      
      state = state.copyWith(
        reminders: filteredReminders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Add a new reminder
  Future<void> addReminder(Reminder reminder) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data saving to repository
      await Future<void>.delayed(const Duration(milliseconds: 500));
      
      final updatedReminders = [...state.reminders, reminder];
      state = state.copyWith(
        reminders: updatedReminders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Update an existing reminder
  Future<void> updateReminder(Reminder updatedReminder) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data updating in repository
      await Future<void>.delayed(const Duration(milliseconds: 500));
      
      final updatedReminders = state.reminders.map((reminder) {
        return reminder.id == updatedReminder.id ? updatedReminder : reminder;
      }).toList();
      
      state = state.copyWith(
        reminders: updatedReminders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Mark reminder as done
  Future<void> markReminderDone(String reminderId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data updating in repository
      await Future<void>.delayed(const Duration(milliseconds: 500));
      
      final updatedReminders = state.reminders.map((reminder) {
        if (reminder.id == reminderId) {
          return reminder.copyWith(done: true);
        }
        return reminder;
      }).toList();
      
      state = state.copyWith(
        reminders: updatedReminders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement actual data deletion from repository
      await Future<void>.delayed(const Duration(milliseconds: 500));
      
      final updatedReminders = state.reminders.where((reminder) => reminder.id != reminderId).toList();
      state = state.copyWith(
        reminders: updatedReminders,
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

/// Reminders provider
final remindersProvider = StateNotifierProvider<RemindersNotifier, RemindersState>((ref) {
  return RemindersNotifier();
});

/// Reminders for specific pet provider
final remindersForPetProvider = Provider.family<List<Reminder>, String>((ref, petId) {
  final remindersState = ref.watch(remindersProvider);
  return remindersState.reminders.where((reminder) => reminder.petId == petId).toList();
});

/// Upcoming reminders provider (next 7 days)
final upcomingRemindersProvider = Provider<List<Reminder>>((ref) {
  final remindersState = ref.watch(remindersProvider);
  final now = DateTime.now();
  final sevenDaysFromNow = now.add(const Duration(days: 7));
  
  return remindersState.reminders.where((reminder) {
    return !reminder.done && 
           reminder.scheduledAt.isAfter(now) && 
           reminder.scheduledAt.isBefore(sevenDaysFromNow);
  }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
});

/// Overdue reminders provider
final overdueRemindersProvider = Provider<List<Reminder>>((ref) {
  final remindersState = ref.watch(remindersProvider);
  final now = DateTime.now();
  
  return remindersState.reminders.where((reminder) {
    return !reminder.done && reminder.scheduledAt.isBefore(now);
  }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
});

/// Today's reminders provider
final todaysRemindersProvider = Provider<List<Reminder>>((ref) {
  final remindersState = ref.watch(remindersProvider);
  final today = DateTime.now();
  
  return remindersState.reminders.where((reminder) {
    final reminderDate = reminder.scheduledAt;
    return reminderDate.year == today.year &&
           reminderDate.month == today.month &&
           reminderDate.day == today.day;
  }).toList();
});

/// Reminders count provider
final remindersCountProvider = Provider<int>((ref) {
  final remindersState = ref.watch(remindersProvider);
  return remindersState.reminders.length;
});
