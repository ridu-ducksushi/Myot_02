import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/core/providers/reminders_provider.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class PetHealthScreen extends ConsumerStatefulWidget {
  const PetHealthScreen({
    super.key,
    required this.petId,
  });

  final String petId;

  @override
  ConsumerState<PetHealthScreen> createState() => _PetHealthScreenState();
}

class _PetHealthScreenState extends ConsumerState<PetHealthScreen> {
  @override
  void initState() {
    super.initState();
    // Load reminders for this specific pet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(remindersProvider.notifier).loadReminders(widget.petId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(petByIdProvider(widget.petId));

    if (pet == null) {
      return Scaffold(
        appBar: AppBar(title: Text('pets.not_found'.tr())),
        body: AppEmptyState(
          icon: Icons.pets,
          title: 'pets.not_found'.tr(),
          message: 'pets.not_found_message'.tr(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${pet.name} - ${'tabs.health'.tr()}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pets/${widget.petId}'),
        ),
      ),
      body: _LabTable(species: pet.species, petId: pet.id),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.title,
    required this.reminders,
    required this.pet,
    required this.color,
  });

  final String title;
  final List<dynamic> reminders;
  final Pet pet;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${reminders.length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox.shrink(),
      ],
    );
  }
}

class _LabTable extends StatefulWidget {
  const _LabTable({required this.species, required this.petId});
  final String species; // 'Dog' or 'Cat'
  final String petId;

  @override
  State<_LabTable> createState() => _LabTableState();
}

class _LabTableState extends State<_LabTable> {
  final Map<String, TextEditingController> _valueCtrls = {};
  final Map<String, String> _units = {};
  final Map<String, String> _refDog = {};
  final Map<String, String> _refCat = {};
  DateTime _selectedDate = _today();
  Timer? _saveTimer;
  bool _isLoading = false;
  bool _isSaving = false;
  // Previous (직전) values cache
  final Map<String, String> _previousValues = {};
  String? _previousDateStr;
  
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _initRefs();
    // 모든 검사 항목에 대해 컨트롤러 생성
    for (final key in _orderedKeys()) {
      _valueCtrls[key] = TextEditingController();
      _valueCtrls[key]!.addListener(_onChanged);
    }
    _loadFromSupabase();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final c in _valueCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCat = widget.species.toLowerCase() == 'cat';
    final dateLabel = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}'
        ;
    final header = Padding(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          Text('검사 날짜: $dateLabel', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const Text('변경'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
                await _loadFromSupabase();
              }
            },
          ),
          if (_previousDateStr != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16),
                  const SizedBox(width: 6),
                  Text('직전: ${_previousDateStr!}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
          const SizedBox(width: 12),
          if (_isSaving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
        ),
      ),
    );
    final rows = _orderedKeys().map((k) {
      final ref = isCat ? _refCat[k] : _refDog[k];
      return DataRow(cells: [
        DataCell(Text(k)),
        DataCell(
          TextFormField(
            controller: _valueCtrls[k],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: InputBorder.none, hintText: '-'),
          ),
        ),
        DataCell(Text(_previousValues[k] ?? '-')),
        DataCell(Text(ref ?? '-')),
        DataCell(Text(_units[k] ?? '-')),
      ]);
    }).toList();

    return Column(
      children: [
        header,
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('검사명')),
                        DataColumn(label: Text('현재')),
                        DataColumn(label: Text('직전')),
                        DataColumn(label: Text('기준치')),
                        DataColumn(label: Text('단위')),
                      ],
                      rows: rows,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  List<String> _orderedKeys() {
    return [
      // CBC
      'RBC', 'WBC', 'Hb', 'HCT', 'PLT',
      // 혈청화학
      'ALT', 'AST', 'ALP', '총빌리루빈', 'BUN', 'Creatinine', 'SDMA', 'Glucose', '총단백', '알부민', '글로불린', '콜레스테롤', '중성지방',
      // 전해질
      'Na', 'K', 'Cl', 'Ca', 'P',
    ];
  }

  void _initRefs() {
    _units.addAll({
      'RBC': 'x10⁶/µL', 'WBC': '/µL', 'Hb': 'g/dL', 'HCT': '%', 'PLT': '/µL',
      'ALT': 'U/L', 'AST': 'U/L', 'ALP': 'U/L', '총빌리루빈': 'mg/dL', 'BUN': 'mg/dL', 'Creatinine': 'mg/dL', 'SDMA': 'µg/dL', 'Glucose': 'mg/dL', '총단백': 'g/dL', '알부민': 'g/dL', '글로불린': 'g/dL', '콜레스테롤': 'mg/dL', '중성지방': 'mg/dL',
      'Na': 'mmol/L', 'K': 'mmol/L', 'Cl': 'mmol/L', 'Ca': 'mg/dL', 'P': 'mg/dL',
    });
    _refDog.addAll({
      'RBC': '5.5~8.5', 'WBC': '6,000~17,000', 'Hb': '12~18', 'HCT': '37~55', 'PLT': '200,000~500,000',
      'ALT': '10~100', 'AST': '10~55', 'ALP': '20~150', '총빌리루빈': '0.1~0.6', 'BUN': '7~27', 'Creatinine': '0.5~1.5', 'SDMA': '≤14', 'Glucose': '75~120', '총단백': '5.5~7.5', '알부민': '2.6~4.0', '글로불린': '2.5~4.5', '콜레스테롤': '110~320', '중성지방': '25~150',
      'Na': '140~155', 'K': '3.6~5.5', 'Cl': '105~115', 'Ca': '8.9~11.4', 'P': '2.5~6.0',
    });
    _refCat.addAll({
      'RBC': '5.0~10.0', 'WBC': '5,500~19,500', 'Hb': '8~15', 'HCT': '24~45', 'PLT': '300,000~800,000',
      'ALT': '20~120', 'AST': '10~40', 'ALP': '20~60', '총빌리루빈': '0.1~0.4', 'BUN': '16~36', 'Creatinine': '0.8~2.4', 'SDMA': '≤14', 'Glucose': '70~150', '총단백': '6.0~8.0', '알부민': '2.3~3.5', '글로불린': '2.5~5.0', '콜레스테롤': '75~220', '중성지방': '25~160',
      'Na': '145~158', 'K': '3.4~5.6', 'Cl': '107~120', 'Ca': '8.0~11.8', 'P': '2.5~6.5',
    });
  }

  String _dateKey() {
    return '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadFromSupabase() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      print('🔍 Loading data: uid=$uid, petId=${widget.petId}, date=${_dateKey()}');
      
      if (uid == null) {
        print('❌ User not authenticated');
        setState(() => _isLoading = false);
        return;
      }
      
      // Fetch up to two entries: selected date (현재) and previous (직전)
      final resList = await Supabase.instance.client
          .from('labs')
          .select('date, items')
          .eq('user_id', uid)
          .eq('pet_id', widget.petId)
          .lte('date', _dateKey())
          .order('date', ascending: false)
          .limit(2);

      print('📊 Query result (<= selected date): $resList');

      // Reset previous values cache
      _previousValues.clear();
      _previousDateStr = null;

      Map<String, dynamic>? currentRow;
      Map<String, dynamic>? previousRow;

      if (resList is List && resList.isNotEmpty) {
        // Determine current vs previous by matching date
        for (final row in resList) {
          final r = row as Map<String, dynamic>;
          if (r['date'] == _dateKey()) {
            currentRow = r;
          }
        }
        if (resList.length >= 2) {
          // previous is the first row that is not the selected date
          for (final row in resList) {
            final r = row as Map<String, dynamic>;
            if (r['date'] != _dateKey()) {
              previousRow = r;
              break;
            }
          }
        } else if (currentRow == null) {
          // No exact match for selected date; treat first as previous reference
          previousRow = resList.first as Map<String, dynamic>;
        }
      }

      // Apply current values to controllers
      if (currentRow != null && currentRow['items'] is Map) {
        final Map items = currentRow['items'] as Map;
        print('✅ Current found with ${items.length} items');
        for (final k in _orderedKeys()) {
          final v = items[k];
          final value = (v is Map && v['value'] is String) ? v['value'] as String : '';
          _valueCtrls[k]?.text = value;
        }
      } else {
        // Clear current inputs if none
        for (final k in _orderedKeys()) {
          _valueCtrls[k]?.text = '';
        }
      }

      // Store previous values for display
      if (previousRow != null && previousRow['items'] is Map) {
        final Map items = previousRow['items'] as Map;
        _previousDateStr = previousRow['date'] as String?;
        print('ℹ️ Previous (${_previousDateStr ?? '-'}) with ${items.length} items');
        for (final k in _orderedKeys()) {
          final v = items[k];
          final value = (v is Map && v['value'] is String) ? v['value'] as String : '';
          _previousValues[k] = value;
        }
      }
    } catch (e) {
      print('❌ Load error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 로드 실패: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToSupabase() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      print('💾 Saving data: uid=$uid, petId=${widget.petId}, date=${_dateKey()}');
      
      if (uid == null) {
        print('❌ User not authenticated');
        setState(() => _isSaving = false);
        return;
      }
      
      final Map<String, dynamic> items = {};
      int nonEmptyCount = 0;
      for (final k in _orderedKeys()) {
        final val = _valueCtrls[k]?.text ?? '';
        items[k] = {'value': val};
        if (val.isNotEmpty) {
          nonEmptyCount++;
          print('  $k: $val');
        }
      }
      
      print('📝 Saving $nonEmptyCount non-empty items');
      
      final result = await Supabase.instance.client.from('labs').upsert({
        'user_id': uid,
        'pet_id': widget.petId,
        'date': _dateKey(),
        'panel': 'BloodTest', // 필수 컬럼 추가
        'items': items,
      }, onConflict: 'user_id,pet_id,date');
      
      print('✅ Save successful: $result');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 완료'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      print('❌ Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _onChanged() {
    // Debounce auto-save: only save after 2 seconds of no typing
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _saveToSupabase();
      }
    });
  }
}
