import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/data/models/record.dart';

class SupabaseRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Pets CRUD
  Future<List<Pet>> getPets() async {
    final response = await _client.from('pets').select();
    return response.map((json) => Pet.fromJson(json)).toList();
  }

  Future<Pet> createPet(Pet pet) async {
    final response = await _client.from('pets').insert(pet.toJson()).select().single();
    return Pet.fromJson(response);
  }

  Future<Pet> updatePet(Pet pet) async {
    final response = await _client
        .from('pets')
        .update(pet.toJson())
        .eq('id', pet.id)
        .select()
        .single();
    return Pet.fromJson(response);
  }

  Future<void> deletePet(String id) async {
    await _client.from('pets').delete().eq('id', id);
  }

  // Records CRUD
  Future<List<Record>> getRecords(String petId) async {
    final response = await _client.from('records').select().eq('pet_id', petId);
    return response.map((json) => Record.fromJson(json)).toList();
  }

  Future<Record> createRecord(Record record) async {
    final response = await _client.from('records').insert(record.toJson()).select().single();
    return Record.fromJson(response);
  }

  Future<Record> updateRecord(Record record) async {
    final response = await _client
        .from('records')
        .update(record.toJson())
        .eq('id', record.id)
        .select()
        .single();
    return Record.fromJson(response);
  }

  Future<void> deleteRecord(String id) async {
    await _client.from('records').delete().eq('id', id);
  }
}
