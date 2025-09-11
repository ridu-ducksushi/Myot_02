import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petcare/data/models/reminder.dart';
import 'package:petcare/data/local/database.dart';

/// Repository for reminder data management
class RemindersRepository {
  RemindersRepository({
    required this.supabase,
    required this.localDb,
  });

  final SupabaseClient supabase;
  final LocalDatabase localDb;

  /// Get all reminders for a pet
  Future<List<Reminder>> getRemindersForPet(String petId) async {
    try {
      // Try to fetch from Supabase first
      final response = await supabase
          .from('reminders')
          .select()
          .eq('pet_id', petId)
          .order('scheduled_at', ascending: true);

      final reminders = (response as List)
          .map((json) => Reminder.fromJson(json))
          .toList();

      // Cache locally
      for (final reminder in reminders) {
        await localDb.saveReminder(reminder);
      }

      return reminders;
    } catch (e) {
      print('Failed to fetch reminders from Supabase: $e');
      // Fallback to local database
      return await localDb.getRemindersForPet(petId);
    }
  }

  /// Get all reminders
  Future<List<Reminder>> getAllReminders() async {
    try {
      // Try to fetch from Supabase first
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Get reminders for user's pets
        final response = await supabase
            .from('reminders')
            .select('''
              *,
              pets!inner(owner_id)
            ''')
            .eq('pets.owner_id', user.id)
            .order('scheduled_at', ascending: true);

        final reminders = (response as List)
            .map((json) => Reminder.fromJson(json))
            .toList();

        // Cache locally
        for (final reminder in reminders) {
          await localDb.saveReminder(reminder);
        }

        return reminders;
      }
    } catch (e) {
      print('Failed to fetch reminders from Supabase: $e');
    }

    // Fallback to local database
    return await localDb.getAllReminders();
  }

  /// Get upcoming reminders (next 7 days)
  Future<List<Reminder>> getUpcomingReminders() async {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('reminders')
            .select('''
              *,
              pets!inner(owner_id)
            ''')
            .eq('pets.owner_id', user.id)
            .eq('done', false)
            .gte('scheduled_at', now.toIso8601String())
            .lte('scheduled_at', sevenDaysFromNow.toIso8601String())
            .order('scheduled_at', ascending: true);

        return (response as List)
            .map((json) => Reminder.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Failed to fetch upcoming reminders from Supabase: $e');
    }

    // Fallback to filtering local reminders
    final allReminders = await localDb.getAllReminders();
    return allReminders.where((reminder) {
      return !reminder.done && 
             reminder.scheduledAt.isAfter(now) && 
             reminder.scheduledAt.isBefore(sevenDaysFromNow);
    }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  /// Get overdue reminders
  Future<List<Reminder>> getOverdueReminders() async {
    final now = DateTime.now();

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('reminders')
            .select('''
              *,
              pets!inner(owner_id)
            ''')
            .eq('pets.owner_id', user.id)
            .eq('done', false)
            .lt('scheduled_at', now.toIso8601String())
            .order('scheduled_at', ascending: true);

        return (response as List)
            .map((json) => Reminder.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Failed to fetch overdue reminders from Supabase: $e');
    }

    // Fallback to filtering local reminders
    final allReminders = await localDb.getAllReminders();
    return allReminders.where((reminder) {
      return !reminder.done && reminder.scheduledAt.isBefore(now);
    }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  /// Create a new reminder
  Future<Reminder> createReminder(Reminder reminder) async {
    try {
      // Save to Supabase
      final response = await supabase
          .from('reminders')
          .insert(reminder.toJson())
          .select()
          .single();

      final savedReminder = Reminder.fromJson(response);
      
      // Cache locally
      await localDb.saveReminder(savedReminder);
      
      return savedReminder;
    } catch (e) {
      print('Failed to create reminder in Supabase: $e');
      // Save locally anyway
      await localDb.saveReminder(reminder);
      return reminder;
    }
  }

  /// Update an existing reminder
  Future<Reminder> updateReminder(Reminder reminder) async {
    try {
      // Update in Supabase
      final response = await supabase
          .from('reminders')
          .update(reminder.toJson())
          .eq('id', reminder.id)
          .select()
          .single();

      final updatedReminder = Reminder.fromJson(response);
      
      // Update locally
      await localDb.saveReminder(updatedReminder);
      
      return updatedReminder;
    } catch (e) {
      print('Failed to update reminder in Supabase: $e');
      // Update locally anyway
      await localDb.saveReminder(reminder);
      return reminder;
    }
  }

  /// Mark reminder as done
  Future<Reminder> markReminderDone(String id) async {
    try {
      // Update in Supabase
      final response = await supabase
          .from('reminders')
          .update({'done': true})
          .eq('id', id)
          .select()
          .single();

      final updatedReminder = Reminder.fromJson(response);
      
      // Update locally
      await localDb.saveReminder(updatedReminder);
      
      return updatedReminder;
    } catch (e) {
      print('Failed to mark reminder as done in Supabase: $e');
      
      // Get current reminder and mark as done locally
      final currentReminder = await localDb.getAllReminders();
      final reminder = currentReminder.firstWhere((r) => r.id == id);
      final updatedReminder = reminder.copyWith(done: true);
      await localDb.saveReminder(updatedReminder);
      
      return updatedReminder;
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String id) async {
    try {
      // Delete from Supabase
      await supabase
          .from('reminders')
          .delete()
          .eq('id', id);

      // Delete locally
      await localDb.deleteReminder(id);
    } catch (e) {
      print('Failed to delete reminder from Supabase: $e');
      // Delete locally anyway
      await localDb.deleteReminder(id);
    }
  }

  /// Sync local changes to Supabase
  Future<void> syncToCloud() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // TODO: Implement conflict resolution and sync logic
      print('Syncing reminders to cloud...');
    } catch (e) {
      print('Failed to sync reminders to cloud: $e');
    }
  }
}

/// Provider for reminders repository
final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepository(
    supabase: Supabase.instance.client,
    localDb: LocalDatabase.instance,
  );
});
