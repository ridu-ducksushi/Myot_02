import 'package:petcare/data/models/pet.dart';
import 'package:petcare/data/models/record.dart';
import 'package:petcare/data/models/reminder.dart';

/// Local database service using in-memory storage
class LocalDatabase {
  static LocalDatabase? _instance;
  static LocalDatabase get instance => _instance!;
  
  // In-memory storage
  final List<Pet> _pets = [];
  final List<Record> _records = [];
  final List<Reminder> _reminders = [];
  
  LocalDatabase._();
  
  /// Initialize the database
  static Future<void> initialize() async {
    _instance = LocalDatabase._();
    await _instance!._init();
  }
  
  Future<void> _init() async {
    // No initialization needed for in-memory storage
  }
  
  /// Close the database
  Future<void> close() async {
    // No cleanup needed for in-memory storage
  }
  
  /// Clear all data (for testing/reset)
  Future<void> clearAll() async {
    _pets.clear();
    _records.clear();
    _reminders.clear();
  }
  
  // Pet operations
  Future<List<Pet>> getAllPets() async {
    return List.from(_pets);
  }
  
  Future<Pet?> getPetById(String id) async {
    try {
      return _pets.firstWhere((pet) => pet.id == id);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> savePet(Pet pet) async {
    final index = _pets.indexWhere((p) => p.id == pet.id);
    if (index >= 0) {
      _pets[index] = pet;
    } else {
      _pets.add(pet);
    }
  }
  
  Future<void> deletePet(String id) async {
    _pets.removeWhere((pet) => pet.id == id);
  }
  
  // Record operations
  Future<List<Record>> getAllRecords() async {
    return List.from(_records);
  }
  
  Future<List<Record>> getRecordsForPet(String petId) async {
    return _records.where((record) => record.petId == petId).toList();
  }
  
  Future<void> saveRecord(Record record) async {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      _records[index] = record;
    } else {
      _records.add(record);
    }
  }
  
  Future<void> deleteRecord(String id) async {
    _records.removeWhere((record) => record.id == id);
  }
  
  // Reminder operations
  Future<List<Reminder>> getAllReminders() async {
    return List.from(_reminders);
  }
  
  Future<List<Reminder>> getRemindersForPet(String petId) async {
    return _reminders.where((reminder) => reminder.petId == petId).toList();
  }
  
  Future<void> saveReminder(Reminder reminder) async {
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index >= 0) {
      _reminders[index] = reminder;
    } else {
      _reminders.add(reminder);
    }
  }
  
  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((reminder) => reminder.id == id);
  }
}
