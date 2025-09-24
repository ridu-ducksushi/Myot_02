import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/data/models/record.dart';
import 'package:petcare/data/models/reminder.dart';

/// Local database service using SharedPreferences for persistent storage
class LocalDatabase {
  static LocalDatabase? _instance;
  static LocalDatabase get instance => _instance!;
  
  SharedPreferences? _prefs;
  
  // Keys for SharedPreferences
  static const String _petsKey = 'pets';
  static const String _recordsKey = 'records';
  static const String _remindersKey = 'reminders';
  
  LocalDatabase._();

  String _userScopedKey(String baseKey) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return '${baseKey}_${userId ?? 'guest'}';
  }

  String? _getScopedString(String baseKey) {
    final prefs = _prefs;
    if (prefs == null) return null;

    final scopedKey = _userScopedKey(baseKey);
    final scopedValue = prefs.getString(scopedKey);
    if (scopedValue != null) {
      return scopedValue;
    }

    final legacyValue = prefs.getString(baseKey);
    if (legacyValue != null) {
      unawaited(prefs.setString(scopedKey, legacyValue));
      unawaited(prefs.remove(baseKey));
    }
    return legacyValue;
  }

  Future<void> _setScopedString(String baseKey, String value) async {
    final prefs = _prefs;
    if (prefs == null) return;

    final scopedKey = _userScopedKey(baseKey);
    await prefs.setString(scopedKey, value);
    if (prefs.containsKey(baseKey)) {
      await prefs.remove(baseKey);
    }
  }

  Future<void> _removeScopedKey(String baseKey) async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.remove(_userScopedKey(baseKey));
    if (prefs.containsKey(baseKey)) {
      await prefs.remove(baseKey);
    }
  }
  
  /// Initialize the database
  static Future<void> initialize() async {
    _instance = LocalDatabase._();
    await _instance!._init();
  }
  
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    print('✅ LocalDatabase 초기화 완료 (SharedPreferences 사용)');
  }
  
  /// Close the database
  Future<void> close() async {
    // No cleanup needed for SharedPreferences
  }
  
  /// Clear all data (for testing/reset)
  Future<void> clearAll() async {
    await _removeScopedKey(_petsKey);
    await _removeScopedKey(_recordsKey);
    await _removeScopedKey(_remindersKey);
    print('🗑️ 모든 로컬 데이터 삭제 완료');
  }
  
  // Pet operations
  Future<List<Pet>> getAllPets() async {
    try {
      final petsJson = _getScopedString(_petsKey);
      if (petsJson == null) return [];
      
      final List<dynamic> petsList = json.decode(petsJson);
      final pets = petsList.map((json) => Pet.fromJson(json as Map<String, dynamic>)).toList();
      print('📱 로컬에서 ${pets.length}개 펫 로드');
      return pets;
    } catch (e) {
      print('❌ 펫 데이터 로드 실패: $e');
      return [];
    }
  }
  
  Future<Pet?> getPetById(String id) async {
    try {
      final pets = await getAllPets();
      return pets.firstWhere((pet) => pet.id == id);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> savePet(Pet pet) async {
    try {
      final pets = await getAllPets();
      final index = pets.indexWhere((p) => p.id == pet.id);
      
      if (index >= 0) {
        pets[index] = pet;
        print('📝 펫 업데이트: ${pet.name}');
      } else {
        pets.add(pet);
        print('➕ 새 펫 추가: ${pet.name}');
      }
      
      final petsJson = json.encode(pets.map((p) => p.toJson()).toList());
      await _setScopedString(_petsKey, petsJson);
      print('💾 펫 데이터 저장 완료 (총 ${pets.length}개)');
    } catch (e) {
      print('❌ 펫 저장 실패: $e');
    }
  }
  
  Future<void> deletePet(String id) async {
    try {
      final pets = await getAllPets();
      final initialCount = pets.length;
      pets.removeWhere((pet) => pet.id == id);
      
      final petsJson = json.encode(pets.map((p) => p.toJson()).toList());
      await _setScopedString(_petsKey, petsJson);
      print('🗑️ 펫 삭제 완료 (${initialCount} → ${pets.length})');
    } catch (e) {
      print('❌ 펫 삭제 실패: $e');
    }
  }
  
  // Record operations
  Future<List<Record>> getAllRecords() async {
    try {
      final recordsJson = _getScopedString(_recordsKey);
      if (recordsJson == null) return [];
      
      final List<dynamic> recordsList = json.decode(recordsJson);
      return recordsList.map((json) => Record.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ 기록 데이터 로드 실패: $e');
      return [];
    }
  }
  
  Future<List<Record>> getRecordsForPet(String petId) async {
    final records = await getAllRecords();
    return records.where((record) => record.petId == petId).toList();
  }
  
  Future<void> saveRecord(Record record) async {
    try {
      final records = await getAllRecords();
      final index = records.indexWhere((r) => r.id == record.id);
      
      if (index >= 0) {
        records[index] = record;
      } else {
        records.add(record);
      }
      
      final recordsJson = json.encode(records.map((r) => r.toJson()).toList());
      await _setScopedString(_recordsKey, recordsJson);
    } catch (e) {
      print('❌ 기록 저장 실패: $e');
    }
  }
  
  Future<void> deleteRecord(String id) async {
    try {
      final records = await getAllRecords();
      records.removeWhere((record) => record.id == id);
      
      final recordsJson = json.encode(records.map((r) => r.toJson()).toList());
      await _setScopedString(_recordsKey, recordsJson);
    } catch (e) {
      print('❌ 기록 삭제 실패: $e');
    }
  }
  
  // Reminder operations
  Future<List<Reminder>> getAllReminders() async {
    try {
      final remindersJson = _getScopedString(_remindersKey);
      if (remindersJson == null) return [];
      
      final List<dynamic> remindersList = json.decode(remindersJson);
      return remindersList.map((json) => Reminder.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ 리마인더 데이터 로드 실패: $e');
      return [];
    }
  }
  
  Future<List<Reminder>> getRemindersForPet(String petId) async {
    final reminders = await getAllReminders();
    return reminders.where((reminder) => reminder.petId == petId).toList();
  }
  
  Future<void> saveReminder(Reminder reminder) async {
    try {
      final reminders = await getAllReminders();
      final index = reminders.indexWhere((r) => r.id == reminder.id);
      
      if (index >= 0) {
        reminders[index] = reminder;
      } else {
        reminders.add(reminder);
      }
      
      final remindersJson = json.encode(reminders.map((r) => r.toJson()).toList());
      await _setScopedString(_remindersKey, remindersJson);
    } catch (e) {
      print('❌ 리마인더 저장 실패: $e');
    }
  }
  
  Future<void> deleteReminder(String id) async {
    try {
      final reminders = await getAllReminders();
      reminders.removeWhere((reminder) => reminder.id == id);
      
      final remindersJson = json.encode(reminders.map((r) => r.toJson()).toList());
      await _setScopedString(_remindersKey, remindersJson);
    } catch (e) {
      print('❌ 리마인더 삭제 실패: $e');
    }
  }
}
