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
import 'weight_chart_screen.dart';

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
      body: _LabTable(species: pet.species, petId: pet.id, petName: pet.name, key: ValueKey(pet.id)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(pet.species, pet.id),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showWeightChartDialog(String petId, String petName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightChartScreen(
          petId: petId,
          petName: petName,
        ),
      ),
    );
  }

  void _showLabWeightChartDialog(String petId, String petName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightChartScreen(
          petId: petId,
          petName: petName,
        ),
      ),
    );
  }

  void _showAddItemDialog(String species, String petId) {
    showDialog(
      context: context,
      builder: (context) => _AddLabItemDialog(
        species: species,
        petId: petId,
        onItemAdded: () {
          // Force rebuild the widget by changing the key
          setState(() {});
        },
      ),
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
  const _LabTable({required this.species, required this.petId, required this.petName, Key? key}) : super(key: key);
  final String species; // 'Dog' or 'Cat'
  final String petId;
  final String petName;

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
  // Pinned rows
  final Set<String> _pinnedKeys = <String>{};
  
  // Basic info data
  String _weight = '';
  String _hospitalName = '';
  String _cost = '';
  
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _initRefs();
    // 기본 검사 항목들에 대해서만 컨트롤러 생성
    final baseKeys = [
      'RBC', 'WBC', 'Hb', 'HCT', 'PLT',
      'ALT', 'AST', 'ALP', '총빌리루빈', 'BUN', 'Creatinine', 'SDMA', 'Glucose', '총단백', '알부민', '글로불린', '콜레스테롤', '중성지방',
      'Na', 'K', 'Cl', 'Ca', 'P',
    ];
    for (final key in baseKeys) {
      _valueCtrls[key] = TextEditingController();
      _valueCtrls[key]!.addListener(_onChanged);
    }
    _loadFromSupabase();
  }

  @override
  void didUpdateWidget(_LabTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget이 업데이트되면 데이터를 다시 로드
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('검사 날짜: ', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () async {
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(dateLabel, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        )),
                        const SizedBox(width: 4),
                        Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 차트 아이콘 추가
                InkWell(
                  onTap: () => _showChartDialog(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.bar_chart,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
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
          if (_previousDateStr != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('직전: ${_previousDateStr!}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                )),
              ],
            ),
          ],
        ],
      ),
    );

    // 기본정보 차트 추가
    final basicInfoSection = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '기본정보',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildBasicInfoRow('체중', 'kg', _weight),
                _buildDivider(),
                _buildBasicInfoRow('병원명', '', _hospitalName),
                _buildDivider(),
                _buildBasicInfoRow('비용', '', _cost),
              ],
            ),
          ),
        ],
      ),
    );
    final baseKeys = _orderedKeys();
    final sortedKeys = [
      ...baseKeys.where((k) => _pinnedKeys.contains(k)),
      ...baseKeys.where((k) => !_pinnedKeys.contains(k)),
    ];

    final rows = sortedKeys.map((k) {
      final ref = isCat ? _refCat[k] : _refDog[k];
      return DataRow(cells: [
        DataCell(Checkbox(
          value: _pinnedKeys.contains(k),
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _pinnedKeys.add(k);
              } else {
                _pinnedKeys.remove(k);
              }
            });
          },
        )),
        DataCell(InkWell(
          onTap: () => _showEditDialog(k),
          child: Text(k, style: const TextStyle(fontSize: 14)),
        )),
        DataCell(InkWell(
          onTap: () => _showEditDialog(k),
          child: TextFormField(
            controller: _valueCtrls[k],
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none, 
              hintText: '-',
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            ),
            enabled: false, // Disable direct editing, use popup instead
          ),
        )),
        DataCell(InkWell(
          onTap: () => _showEditDialog(k),
          child: Text(_previousValues[k] ?? '-', style: const TextStyle(fontSize: 14)),
        )),
        DataCell(InkWell(
          onTap: () => _showEditDialog(k),
          child: Text(ref ?? '-', style: const TextStyle(fontSize: 14)),
        )),
        DataCell(InkWell(
          onTap: () => _showEditDialog(k),
          child: Text(_units[k] ?? '-', style: const TextStyle(fontSize: 14)),
        )),
      ]);
    }).toList();

    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : SingleChildScrollView(
            child: Column(
              children: [
                header,
                basicInfoSection,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                      columnSpacing: 8,
                      horizontalMargin: 12,
                      headingRowHeight: 48,
                      dataRowHeight: 48,
                      columns: const [
                        DataColumn(label: Text('선택', style: TextStyle(fontSize: 14))),
                        DataColumn(label: Text('검사명', style: TextStyle(fontSize: 14))),
                        DataColumn(label: Text('현재', style: TextStyle(fontSize: 14))),
                        DataColumn(label: Text('직전', style: TextStyle(fontSize: 14))),
                        DataColumn(label: Text('기준치', style: TextStyle(fontSize: 14))),
                        DataColumn(label: Text('단위', style: TextStyle(fontSize: 14))),
                      ],
                      rows: rows,
                    ),
                  ),
              ],
            ),
          );
  }

  List<String> _orderedKeys() {
    final baseKeys = [
      // CBC
      'RBC', 'WBC', 'Hb', 'HCT', 'PLT',
      // 혈청화학
      'ALT', 'AST', 'ALP', '총빌리루빈', 'BUN', 'Creatinine', 'SDMA', 'Glucose', '총단백', '알부민', '글로불린', '콜레스테롤', '중성지방',
      // 전해질
      'Na', 'K', 'Cl', 'Ca', 'P',
    ];
    
    // Only include custom keys that have actual data for this pet
    // This prevents showing custom items from other pets
    final customKeys = _valueCtrls.keys.where((k) => 
      !baseKeys.contains(k) && 
      (_valueCtrls[k]?.text.isNotEmpty == true || _units.containsKey(k))
    ).toList();
    customKeys.sort(); // Sort custom keys alphabetically
    
    return [...baseKeys, ...customKeys];
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
      
      // Clear custom controllers from previous pets to avoid cross-contamination
      final baseKeys = [
        'RBC', 'WBC', 'Hb', 'HCT', 'PLT',
        'ALT', 'AST', 'ALP', '총빌리루빈', 'BUN', 'Creatinine', 'SDMA', 'Glucose', '총단백', '알부민', '글로불린', '콜레스테롤', '중성지방',
        'Na', 'K', 'Cl', 'Ca', 'P',
      ];
      
      // Remove custom controllers that are not in base keys
      final customKeysToRemove = _valueCtrls.keys.where((k) => !baseKeys.contains(k)).toList();
      for (final key in customKeysToRemove) {
        _valueCtrls[key]?.dispose();
        _valueCtrls.remove(key);
        _units.remove(key);
        _refDog.remove(key);
        _refCat.remove(key);
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
        
        // Create controllers for any new items that don't exist yet
        for (final k in items.keys) {
          if (!_valueCtrls.containsKey(k)) {
            _valueCtrls[k] = TextEditingController();
            _valueCtrls[k]!.addListener(_onChanged);
            
            // Set unit and reference values from the stored data
            final v = items[k];
            if (v is Map) {
              if (v['unit'] is String) {
                _units[k] = v['unit'] as String;
              }
              if (v['reference'] is String) {
                final isCat = widget.species.toLowerCase() == 'cat';
                if (isCat) {
                  _refCat[k] = v['reference'] as String;
                } else {
                  _refDog[k] = v['reference'] as String;
                }
              }
            }
          }
        }
        
        // Update existing controllers with values
        for (final k in items.keys) {
          final v = items[k];
          final value = (v is Map && v['value'] is String) ? v['value'] as String : '';
          _valueCtrls[k]?.text = value;
        }
        
        // Load basic info data
        _weight = (items['체중'] is Map && items['체중']['value'] is String) 
            ? items['체중']['value'] as String : '';
        _hospitalName = (items['병원명'] is Map && items['병원명']['value'] is String) 
            ? items['병원명']['value'] as String : '';
        _cost = (items['비용'] is Map && items['비용']['value'] is String) 
            ? items['비용']['value'] as String : '';
        
        // Clear controllers for items not in current data
        for (final k in _orderedKeys()) {
          if (!items.containsKey(k)) {
            _valueCtrls[k]?.text = '';
          }
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

  void _showEditDialog(String itemKey) {
    final currentValue = _valueCtrls[itemKey]?.text ?? '';
    final unit = _units[itemKey] ?? '';
    final isCat = widget.species.toLowerCase() == 'cat';
    final ref = isCat ? _refCat[itemKey] : _refDog[itemKey];

    showDialog(
      context: context,
      builder: (context) => _EditLabValueDialog(
        itemKey: itemKey,
        currentValue: currentValue,
        reference: ref ?? '',
        unit: unit,
        onSave: (newItemKey, newValue) {
          // If item key changed, remove old controller and add new one
          if (newItemKey != itemKey) {
            _valueCtrls.remove(itemKey);
            _units.remove(itemKey);
            _refDog.remove(itemKey);
            _refCat.remove(itemKey);
            
            _valueCtrls[newItemKey] = TextEditingController(text: newValue);
            _units[newItemKey] = unit;
            if (ref != null) {
              _refDog[newItemKey] = ref;
              _refCat[newItemKey] = ref;
            }
          } else {
            _valueCtrls[itemKey]?.text = newValue;
          }
          _saveToSupabase();
        },
      ),
    );
  }

  Future<void> _saveToSupabase() async {
    if (_isSaving) return;
    
    if (!mounted) return; // Add mounted check
    
    setState(() => _isSaving = true);
    
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      print('💾 Saving data: uid=$uid, petId=${widget.petId}, date=${_dateKey()}');
      
      if (uid == null) {
        print('❌ User not authenticated');
        if (mounted) setState(() => _isSaving = false);
        return;
      }
      
      final Map<String, dynamic> items = {};
      int nonEmptyCount = 0;
      
      // Only save items that actually have data or are custom items for this pet
      for (final k in _valueCtrls.keys) {
        final val = _valueCtrls[k]?.text ?? '';
        if (val.isNotEmpty || _units.containsKey(k)) {
          items[k] = {
            'value': val,
            'unit': _units[k] ?? '',
            'reference': _refDog[k] ?? _refCat[k] ?? '',
          };
          if (val.isNotEmpty) {
            nonEmptyCount++;
            print('  $k: $val');
          }
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

  Widget _buildBasicInfoRow(String label, String unit, String value) {
    return InkWell(
      onTap: () => _showBasicInfoEditDialog(label, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                value.isEmpty ? '-' : value,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 체중 항목에 체중계 아이콘 추가
            if (label == '체중')
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: InkWell(
                  onTap: () => _showWeightChartDialog(widget.petId, widget.petName),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.monitor_weight,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showWeightChartDialog(String petId, String petName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightChartScreen(
          petId: petId,
          petName: petName,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.grey[300],
    );
  }

  void _showBasicInfoEditDialog(String label, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label 수정'),
        content: TextField(
          controller: controller,
          keyboardType: label == '체중' || label == '비용' 
              ? TextInputType.number 
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            hintText: label == '체중' ? '예: 5.2' 
                    : label == '병원명' ? '예: 서울동물병원' 
                    : '예: 150000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = controller.text.trim();
              setState(() {
                switch (label) {
                  case '체중':
                    _weight = newValue;
                    break;
                  case '병원명':
                    _hospitalName = newValue;
                    break;
                  case '비용':
                    _cost = newValue;
                    break;
                }
              });
              _saveBasicInfoToSupabase();
              Navigator.of(context).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBasicInfoToSupabase() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      // Get current lab data for today
      final currentRes = await Supabase.instance.client
          .from('labs')
          .select('items')
          .eq('user_id', uid)
          .eq('pet_id', widget.petId)
          .eq('date', _dateKey())
          .eq('panel', 'BloodTest')
          .maybeSingle();

      Map<String, dynamic> currentItems = {};
      if (currentRes != null) {
        currentItems = Map<String, dynamic>.from(currentRes['items'] ?? {});
      }

      // Add basic info to items
      currentItems['체중'] = {
        'value': _weight,
        'unit': 'kg',
        'reference': '',
      };
      currentItems['병원명'] = {
        'value': _hospitalName,
        'unit': '',
        'reference': '',
      };
      currentItems['비용'] = {
        'value': _cost,
        'unit': '',
        'reference': '',
      };

      // Save to Supabase
      await Supabase.instance.client
          .from('labs')
          .upsert({
            'user_id': uid,
            'pet_id': widget.petId,
            'date': _dateKey(),
            'panel': 'BloodTest',
            'items': currentItems,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기본정보가 저장되었습니다'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  void _showChartDialog() {
    // 바로 차트 화면으로 이동
    context.go('/pets/${widget.petId}/chart');
  }
}

class _EditLabValueDialog extends StatefulWidget {
  final String itemKey;
  final String currentValue;
  final String reference;
  final String unit;
  final Function(String, String) onSave; // (newItemKey, newValue)

  const _EditLabValueDialog({
    required this.itemKey,
    required this.currentValue,
    required this.reference,
    required this.unit,
    required this.onSave,
  });

  @override
  State<_EditLabValueDialog> createState() => _EditLabValueDialogState();
}

class _EditLabValueDialogState extends State<_EditLabValueDialog> {
  late TextEditingController _itemKeyController;
  late TextEditingController _valueController;
  late TextEditingController _referenceController;
  late TextEditingController _unitController;

  @override
  void initState() {
    super.initState();
    _itemKeyController = TextEditingController(text: widget.itemKey);
    _valueController = TextEditingController(text: widget.currentValue);
    _referenceController = TextEditingController(text: widget.reference);
    _unitController = TextEditingController(text: widget.unit);
  }

  @override
  void dispose() {
    _itemKeyController.dispose();
    _valueController.dispose();
    _referenceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('검사 수치 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _itemKeyController,
              decoration: const InputDecoration(
                labelText: '검사명',
                border: OutlineInputBorder(),
                hintText: '예: RBC, WBC, Hb 등',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '현재 수치',
                border: OutlineInputBorder(),
                hintText: '수치를 입력하세요',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: '기준치',
                border: OutlineInputBorder(),
                hintText: '예: 5.5~8.5',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: '단위',
                border: OutlineInputBorder(),
                hintText: '예: x10⁶/µL',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final newItemKey = _itemKeyController.text.trim();
            final newValue = _valueController.text.trim();
            if (newItemKey.isNotEmpty) {
              widget.onSave(newItemKey, newValue);
              Navigator.of(context).pop();
            }
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _AddLabItemDialog extends StatefulWidget {
  final String species;
  final String petId;
  final VoidCallback onItemAdded;

  const _AddLabItemDialog({
    required this.species,
    required this.petId,
    required this.onItemAdded,
  });

  @override
  State<_AddLabItemDialog> createState() => _AddLabItemDialogState();
}

class _AddLabItemDialogState extends State<_AddLabItemDialog> {
  late TextEditingController _itemKeyController;
  late TextEditingController _valueController;
  late TextEditingController _referenceController;
  late TextEditingController _unitController;

  @override
  void initState() {
    super.initState();
    _itemKeyController = TextEditingController();
    _valueController = TextEditingController();
    _referenceController = TextEditingController();
    _unitController = TextEditingController();
  }

  @override
  void dispose() {
    _itemKeyController.dispose();
    _valueController.dispose();
    _referenceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _saveNewItem() async {
    final itemKey = _itemKeyController.text.trim();
    final value = _valueController.text.trim();
    
    if (itemKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검사명을 입력해주세요')),
      );
      return;
    }

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        return;
      }

      final today = DateTime.now();
      final dateKey = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Get current lab data for today
      final currentRes = await Supabase.instance.client
          .from('labs')
          .select('items')
          .eq('user_id', uid)
          .eq('pet_id', widget.petId)
          .eq('date', dateKey)
          .eq('panel', 'BloodTest')
          .maybeSingle();

      Map<String, dynamic> currentItems = {};
      if (currentRes != null) {
        currentItems = Map<String, dynamic>.from(currentRes['items'] ?? {});
      }

      // Add new item to the current items
      currentItems[itemKey] = {
        'value': value,
        'unit': _unitController.text.trim(),
        'reference': _referenceController.text.trim(),
      };

      // Save to Supabase
      await Supabase.instance.client
          .from('labs')
          .upsert({
            'user_id': uid,
            'pet_id': widget.petId,
            'date': dateKey,
            'panel': 'BloodTest',
            'items': currentItems,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('새로운 검사 항목 "$itemKey"이 추가되었습니다')),
        );
        widget.onItemAdded();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 검사 항목 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _itemKeyController,
              decoration: const InputDecoration(
                labelText: '검사명 *',
                border: OutlineInputBorder(),
                hintText: '예: 새로운 검사 항목',
                helperText: '검사 항목의 이름을 입력하세요',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '검사 수치',
                border: OutlineInputBorder(),
                hintText: '수치를 입력하세요',
                helperText: '선택사항: 검사 결과값',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: '기준치',
                border: OutlineInputBorder(),
                hintText: '예: 5.5~8.5',
                helperText: '선택사항: 정상 범위',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: '단위',
                border: OutlineInputBorder(),
                hintText: '예: x10⁶/µL',
                helperText: '선택사항: 측정 단위',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _saveNewItem,
          child: const Text('추가'),
        ),
      ],
    );
  }
}
