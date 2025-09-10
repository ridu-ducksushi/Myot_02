import 'package:petcare/data/models/pet.dart';
import 'package:petcare/data/models/record.dart';

Future<Map<String, List<dynamic>>> seedLocalData() async {
  final now = DateTime.now();
  
  // Create 2 sample pets
  final pets = [
    Pet(
      id: 'pet_1',
      ownerId: 'user_1',
      name: '멍멍이',
      species: 'Dog',
      breed: '골든 리트리버',
      sex: 'Male',
      neutered: true,
      birthDate: DateTime(2020, 5, 15),
      weightKg: 25.5,
      createdAt: now,
      updatedAt: now,
    ),
    Pet(
      id: 'pet_2', 
      ownerId: 'user_1',
      name: '야옹이',
      species: 'Cat',
      breed: '페르시안',
      sex: 'Female',
      neutered: false,
      birthDate: DateTime(2021, 8, 10),
      weightKg: 4.2,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  // Create 2 records per pet
  final records = [
    // Pet 1 records
    Record(
      id: 'record_1',
      petId: 'pet_1',
      type: 'meal',
      title: '아침 사료',
      content: '사료 200g',
      at: now,
      createdAt: now,
      updatedAt: now,
    ),
    Record(
      id: 'record_2',
      petId: 'pet_1', 
      type: 'weight',
      title: '체중 측정',
      value: {'weight': 25.5, 'unit': 'kg'},
      at: now,
      createdAt: now,
      updatedAt: now,
    ),
    // Pet 2 records
    Record(
      id: 'record_3',
      petId: 'pet_2',
      type: 'meal', 
      title: '아침 사료',
      content: '습식 사료 1캔',
      at: now,
      createdAt: now,
      updatedAt: now,
    ),
    Record(
      id: 'record_4',
      petId: 'pet_2',
      type: 'weight',
      title: '체중 측정',
      value: {'weight': 4.2, 'unit': 'kg'},
      at: now,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  return {
    'pets': pets,
    'records': records,
  };
}
