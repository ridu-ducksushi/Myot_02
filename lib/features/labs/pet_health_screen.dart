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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';
import 'dart:convert';
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
        title: Text('tabs.health'.tr()),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.95),
        elevation: 2,
        automaticallyImplyLeading: false,
      ),
      body: _LabTable(species: pet.species, petId: pet.id, petName: pet.name, petWeight: pet.weightKg, key: ValueKey(pet.id)),
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
  const _LabTable({required this.species, required this.petId, required this.petName, this.petWeight, Key? key}) : super(key: key);
  final String species; // 'Dog' or 'Cat'
  final String petId;
  final String petName;
  final double? petWeight;

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
  // Pinned keys order for drag and drop
  List<String> _pinnedKeysOrder = [];
  List<String> _customOrder = []; // 사용자 정의 순서
  
  // Basic info data
  String _weight = '';
  String _hospitalName = '';
  String _cost = '';
  
  // 기록이 있는 날짜 목록
  Set<DateTime> _recordDates = {};
  
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
    _loadCustomOrder();
    _loadRecordDates();
    _loadFromSupabase();
    // 온라인이면 보류된 항목 동기화
    unawaited(_syncPendingIfOnline());
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
                  onTap: _showCalendarDialog,
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
            const SizedBox(height: 3),
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
          const SizedBox(height: 3),
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
    // 사용자 정의 순서가 있으면 사용, 없으면 기본 순서
    final sortedKeys = _customOrder.isEmpty ? baseKeys : _customOrder;

    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : Column(
            children: [
              header,
              basicInfoSection,
              // 헤더 행
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(flex: 2, child: Text('검사명', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: const Text('현재', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: const Text('직전', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: const Text('기준치', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: const Text('단위', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 새로고침 버튼 (절대 위치)
                  Positioned(
                    right: 8,
                    top: 6,
                    child: InkWell(
                      onTap: _customOrder.isNotEmpty ? () async {
                        setState(() {
                          _customOrder.clear();
                        });
                        // 저장된 순서 삭제
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final uid = Supabase.instance.client.auth.currentUser?.id;
                          if (uid != null) {
                            final key = 'lab_custom_order_${uid}_${widget.petId}';
                            await prefs.remove(key);
                          }
                        } catch (e) {
                          print('순서 삭제 오류: $e');
                        }
                      } : null,
                      child: Icon(
                        Icons.refresh,
                        size: 20,
                        color: _customOrder.isNotEmpty 
                          ? Theme.of(context).colorScheme.primary 
                          : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              ),
              // 드래그 가능한 리스트
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.all(8),
                  onReorder: _onReorder,
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final k = sortedKeys[index];
                    final ref = isCat ? _refCat[k] : _refDog[k];
                    final isPinned = _pinnedKeys.contains(k);
                    
                    return Container(
                      key: ValueKey(k),
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showEditDialog(k),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              // 검사명
                              Expanded(
                                flex: 2,
                                child: Text(k, style: const TextStyle(fontSize: 14)),
                              ),
                              const SizedBox(width: 8),
                              // 현재 값
                              SizedBox(
                                width: 60,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.pink.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Text(
                                      (_valueCtrls[k]?.text ?? '').length > 5 
                                        ? (_valueCtrls[k]?.text ?? '').substring(0, 5)
                                        : (_valueCtrls[k]?.text ?? ''),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _getValueColor(_valueCtrls[k]?.text, ref),
                                        fontWeight: _valueCtrls[k]?.text != null && _valueCtrls[k]!.text.isNotEmpty
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 직전 값
                              SizedBox(
                                width: 60,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: Text(
                                    (_previousValues[k] ?? '-').length > 5 
                                      ? (_previousValues[k] ?? '-').substring(0, 5)
                                      : (_previousValues[k] ?? '-'),
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 기준치
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: Text(
                                    (ref ?? '-').length > 10 
                                      ? (ref ?? '-').substring(0, 10)
                                      : (ref ?? '-'),
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 단위
                              SizedBox(
                                width: 60,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: Text(
                                    (_units[k] ?? '').length > 5 
                                      ? (_units[k] ?? '').substring(0, 5)
                                      : (_units[k] ?? ''),
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.clip,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      // 사용자 정의 순서가 비어있으면 현재 sortedKeys로 초기화
      if (_customOrder.isEmpty) {
        _customOrder = List<String>.from(_orderedKeys());
      }
      
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _customOrder.removeAt(oldIndex);
      _customOrder.insert(newIndex.clamp(0, _customOrder.length), item);
      
      // 순서 변경 시 저장
      _saveCustomOrder();
    });
  }

  // 사용자 정의 순서 로드
  Future<void> _loadCustomOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      
      final key = 'lab_custom_order_${uid}_${widget.petId}';
      final orderJson = prefs.getString(key);
      if (orderJson != null) {
        final orderList = jsonDecode(orderJson) as List<dynamic>;
        setState(() {
          _customOrder = orderList.cast<String>();
        });
      }
    } catch (e) {
      print('순서 로드 오류: $e');
    }
  }

  // 사용자 정의 순서 저장
  Future<void> _saveCustomOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      
      final key = 'lab_custom_order_${uid}_${widget.petId}';
      await prefs.setString(key, jsonEncode(_customOrder));
    } catch (e) {
      print('순서 저장 오류: $e');
    }
  }

  List<String> _orderedKeys() {
    final baseKeys = [
      // 사용자 정의 순서 (ABC 순으로 정렬된 기본 검사 항목)
      'ALB', 'ALP', 'ALT GPT', 'AST GOT', 'BUN', 'Ca', 'CK', 'Cl', 'CREA', 'GGT', 
      'GLU', 'K', 'LIPA', 'Na', 'NH3', 'PHOS', 'TBIL', 'T-CHOL', 'TG', 'TPRO', 
      'Na/K', 'ALB/GLB', 'BUN/CRE', 'GLOB', 'vAMY-P', 'SDMA', 'HCT', 'HGB', 'MCH', 
      'MCHC', 'MCV', 'MPV', 'PLT', 'RBC', 'RDW-CV', 'WBC', 'WBC-GRAN(#)', 
      'WBC-GRAN(%)', 'WBC-LYM(#)', 'WBC-LYM(%)', 'WBC-MONO(#)', 'WBC-MONO(%)', 
      'WBC-EOS(#)', 'WBC-EOS(%)'
    ];
    
    // 기본정보 항목들 (차트에 표시하지 않음)
    final basicInfoKeys = ['체중', '병원명', '비용'];
    
    // Only include custom keys that have actual data for this pet
    // This prevents showing custom items from other pets
    final customKeys = _valueCtrls.keys.where((k) => 
      !baseKeys.contains(k) && 
      !basicInfoKeys.contains(k) && // 기본정보 항목 제외
      (_valueCtrls[k]?.text.isNotEmpty == true || _units.containsKey(k))
    ).toList();
    customKeys.sort(); // Sort custom keys alphabetically
    
    return [...customKeys, ...baseKeys];
  }

  void _initRefs() {
    // ABC 순으로 정렬된 단위 (한글 → 영어 변경)
    _units.addAll({
      'ALB': 'g/dL',        // 알부민 → ALB
      'ALP': 'U/L',
      'ALT GPT': 'U/L',
      'AST GOT': 'U/L',
      'BUN': 'mg/dL',
      'Ca': 'mg/dL',
      'CK': 'U/L',      // 크레아틴 키나아제
      'Cl': 'mmol/L',
      'CREA': 'mg/dL',     // Creatinine → Creat
      'GGT': 'U/L',       // 글로불린 → Glob
      'GLU': 'mg/dL',
      'K': 'mmol/L',
      'LIPA': 'U/L',
      'Na': 'mmol/L',
      'NH3': 'µmol/L',
      'PHOS': 'mg/dL',
      'TBIL': 'mg/dL',
      'T-CHOL': 'mg/dL',
      'TG': 'mg/dL',      // 총빌리루빈 → TBil
      'TPRO': 'g/dL',        // 중성지방 → TG
      'Na/K': '-',         // 총단백 → TP
      'ALB/GLB': '-',
      'BUN/CRE': '-',
      'GLOB': 'g/dL',
      'vAMY-P': '-',
      'SDMA': '-',
      'HCT': '%',
      'HGB': 'g/dL',
      'MCH': 'pg',
      'MCHC': 'g/dL',
      'MCV': 'fL',
      'MPV': 'fL',
      'PLT': '10⁹/L',
      'RBC': '10x12/L',
      'RDW-CV': '%',
      'WBC': '10⁹/L',
      'WBC-GRAN(#)': '10⁹/L',
      'WBC-GRAN(%)': '%',
      'WBC-LYM(#)': '10⁹/L',
      'WBC-LYM(%)': '%',
      'WBC-MONO(#)': '10⁹/L',
      'WBC-MONO(%)': '%',
      'WBC-EOS(#)': '10³/mm³',
      'WBC-EOS(%)': '%',
    });
    
    // 강아지 기준치 (ABC 순)
    _refDog.addAll({
      'ALB': '2.6~4.0',     // 알부민
      'ALP': '20~150',
      'ALT GPT': '10~100',
      'AST GOT': '15~66',
      'BUN': '9.2~29.2',
      'Ca': '9.0~12.0',
      'CK': '59~895',       // 크레아틴 키나아제
      'Cl': '106~120',
      'CREA': '0.5~1.6',    // 크레아티닌
      'GGT': '0~13',        // 감마글루타밀전이효소
      'GLU': '65~118',
      'K': '3.6~5.5',
      'LIPA': '100~750',
      'Na': '140~155',
      'NH3': '16~90',
      'PHOS': '2.5~6.8',
      'TBIL': '0.1~0.6',
      'T-CHOL': '110~320',
      'TG': '20~150',       // 중성지방
      'TPRO': '5.4~7.8',    // 총단백
      'Na/K': '27~38',
      'ALB/GLB': '0.8~1.5',
      'BUN/CRE': '10~27',
      'GLOB': '2.0~4.5',
      'vAMY-P': '500~1500',
      'SDMA': '~14',
      'HCT': '37~55',
      'HGB': '12~18',
      'MCH': '19~23',
      'MCHC': '32~36',
      'MCV': '60~77',
      'MPV': '7~12',
      'PLT': '200~500',
      'RBC': '5.5~8.5',
      'RDW-CV': '14~18',
      'WBC': '6~17',
      'WBC-GRAN(#)': '4~12',
      'WBC-GRAN(%)': '0~100',
      'WBC-LYM(#)': '1~4.8',
      'WBC-LYM(%)': '0~100',
      'WBC-MONO(#)': '0~1.3',
      'WBC-MONO(%)': '0~100',
      'WBC-EOS(#)': '0~1.2',
      'WBC-EOS(%)': '0~100',
    });
    
    // 고양이 기준치 (ABC 순)
    _refCat.addAll({
      'ALB': '2.3~3.5',     // 알부민
      'ALP': '9~53',
      'ALT GPT': '20~120',
      'AST GOT': '18~51',
      'BUN': '17.6~32.8',
      'Ca': '8.8~11.9',
      'CK': '87~309',     // 크레아틴 키나아제
      'Cl': '107~120',
      'CREA': '0.8~1.8',   // Creatinine
      'GGT': '1~10',    // 글로불린
      'GLU': '71~148',
      'K': '3.4~4.6',
      'LIPA': '0~30',
      'Na': '147~156',
      'NH3': '23~78',
      'PHOS': '2.6~6.0',
      'TBIL': '0.1~0.4',
      'T-CHOL': '89~176',
      'TG': '17~104',    // 총빌리루빈
      'TPRO': '5.7~7.8',       // 중성지방
      'Na/K': '33.6~44.2',      // 총단백
      'ALB/GLB': '0.4~1.1',
      'BUN/CRE': '17.5~21.9',
      'GLOB': '2.7~5.2',
      'vAMY-P': '200~1900',
      'SDMA': '~14',
      'HCT': '27~47',
      'HGB': '8~17',
      'MCH': '13~17',
      'MCHC': '31~36',
      'MCV': '40~55',
      'MPV': '6.5~15',
      'PLT': '180~430',
      'RBC': '5~10',
      'RDW-CV': '17~22',
      'WBC': '5~11',
      'WBC-GRAN(#)': '3~12',
      'WBC-GRAN(%)': '0~100',
      'WBC-LYM(#)': '1~4',
      'WBC-LYM(%)': '0~100',
      'WBC-MONO(#)': '0~0.5',
      'WBC-MONO(%)': '0~100',
      'WBC-EOS(#)': '0~0.6',
      'WBC-EOS(%)': '0~100',
    });
  }

  String _dateKey() {
    return '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
  }

  // 현재 값이 기준치 범위 내에 있는지 확인하고 색상 반환
  Color _getValueColor(String? valueStr, String? reference) {
    if (valueStr == null || valueStr.isEmpty || reference == null || reference.isEmpty || reference == '-') {
      return Colors.black; // 기본 색상
    }

    final value = double.tryParse(valueStr);
    if (value == null) return Colors.black;

    // 기준치 파싱 (예: "9~53", "~14", "≤14" 등)
    if (reference.startsWith('~') || reference.startsWith('≤')) {
      // 최대값만 있는 경우 (예: "~14", "≤14")
      final maxStr = reference.replaceAll(RegExp(r'[~≤]'), '').trim();
      final maxValue = double.tryParse(maxStr);
      if (maxValue != null && value > maxValue) {
        return Colors.red; // 기준치 초과
      }
      return Colors.black; // 정상
    }

    // "min~max" 형식 파싱
    if (reference.contains('~')) {
      final parts = reference.split('~');
      if (parts.length == 2) {
        final minValue = double.tryParse(parts[0].replaceAll(',', '').trim());
        final maxValue = double.tryParse(parts[1].replaceAll(',', '').trim());
        
        if (minValue != null && maxValue != null) {
          if (value < minValue) {
            return Colors.blue; // 기준치 미달
          } else if (value > maxValue) {
            return Colors.red; // 기준치 초과
          }
        }
      }
    }

    return Colors.black; // 정상 또는 파싱 불가
  }

  Future<void> _loadRecordDates() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      
      // Supabase에서 이 펫의 모든 기록 날짜를 가져옴
      final resList = await Supabase.instance.client
          .from('labs')
          .select('date, items')
          .eq('user_id', uid)
          .eq('pet_id', widget.petId);
      
      setState(() {
        _recordDates = resList
            .where((row) {
              // Check if this row has actual data (non-empty values)
              final items = row['items'];
              if (items is! Map) return false;
              
              for (final k in items.keys) {
                final v = items[k];
                final value = (v is Map && v['value'] is String) ? v['value'] as String : '';
                if (value.isNotEmpty) {
                  return true; // Has actual data
                }
              }
              return false; // No actual data
            })
            .map((row) {
              final dateStr = row['date'] as String;
              final parts = dateStr.split('-');
              return DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            })
            .toSet();
      });
    } catch (e) {
      print('❌ Error loading record dates: $e');
      await _loadFromLocal();
    }
  }

  Future<void> _showCalendarDialog() async {
    DateTime? tempSelected = _selectedDate;
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TableCalendar(
                firstDay: DateTime(2000),
                lastDay: DateTime.now(),
                focusedDay: tempSelected ?? _selectedDate,
                selectedDayPredicate: (day) => isSameDay(day, tempSelected),
                onDaySelected: (selectedDay, focusedDay) {
                  tempSelected = selectedDay;
                  Navigator.pop(context);
                },
                calendarFormat: CalendarFormat.month,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final hasRecord = _recordDates.any((d) => isSameDay(d, day));
                    if (hasRecord) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${day.day}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return null;
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final hasRecord = _recordDates.any((d) => isSameDay(d, day));
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${day.day}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hasRecord)
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    final hasRecord = _recordDates.any((d) => isSameDay(d, day));
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${day.day}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (hasRecord)
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    
    if (tempSelected != null && !isSameDay(tempSelected, _selectedDate)) {
      setState(() => _selectedDate = DateTime(
        tempSelected!.year,
        tempSelected!.month,
        tempSelected!.day,
      ));
      await _loadFromSupabase();
    }
  }

  Future<void> _loadFromSupabase() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      print('🔍 Loading data: uid=$uid, petId=${widget.petId}, date=${_dateKey()}');
      
      if (uid == null) {
        print('❌ User not authenticated → 로컬 캐시에서 로드');
        await _loadFromLocal();
        setState(() => _isLoading = false);
        return;
      }
      
      // Clear custom controllers from previous pets to avoid cross-contamination
      // Use the same baseKeys as _orderedKeys() to ensure consistency
      final baseKeys = [
        'ALB', 'ALP', 'ALT GPT', 'AST GOT', 'BUN', 'Ca', 'CK', 'Cl', 'CREA', 'GGT', 
        'GLU', 'K', 'LIPA', 'Na', 'NH3', 'PHOS', 'TBIL', 'T-CHOL', 'TG', 'TPRO', 
        'Na/K', 'ALB/GLB', 'BUN/CRE', 'GLOB', 'vAMY-P', 'SDMA', 'HCT', 'HGB', 'MCH', 
        'MCHC', 'MCV', 'MPV', 'PLT', 'RBC', 'RDW-CV', 'WBC', 'WBC-GRAN(#)', 
        'WBC-GRAN(%)', 'WBC-LYM(#)', 'WBC-LYM(%)', 'WBC-MONO(#)', 'WBC-MONO(%)', 
        'WBC-EOS(#)', 'WBC-EOS(%)'
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
      
      // Fetch up to 10 entries to find the most recent with actual data
      final resList = await Supabase.instance.client
          .from('labs')
          .select('date, items')
          .eq('user_id', uid)
          .eq('pet_id', widget.petId)
          .lte('date', _dateKey())
          .order('date', ascending: false)
          .limit(10);

      print('📊 Query result (<= selected date): $resList');

      // Reset previous values cache
      _previousValues.clear();
      _previousDateStr = null;

      Map<String, dynamic>? currentRow;
      Map<String, dynamic>? previousRow;

      if (resList is List && resList.isNotEmpty) {
        // Find current row (exact date match)
        for (final row in resList) {
          final r = row as Map<String, dynamic>;
          if (r['date'] == _dateKey()) {
            currentRow = r;
            break;
          }
        }
        
        // Find previous row with actual data (skip empty data)
        for (final row in resList) {
          final r = row as Map<String, dynamic>;
          if (r['date'] != _dateKey() && r['items'] is Map) {
            final items = r['items'] as Map;
            // Check if this row has actual data
            bool hasData = false;
            for (final k in items.keys) {
              final v = items[k];
              final value = (v is Map && v['value'] is String) ? v['value'] as String : '';
              if (value.isNotEmpty) {
                hasData = true;
                break;
              }
            }
            if (hasData) {
              previousRow = r;
              break;
            }
          }
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
            ? items['체중']['value'] as String 
            : (widget.petWeight != null ? widget.petWeight.toString() : '');
        _hospitalName = (items['병원명'] is Map && items['병원명']['value'] is String) 
            ? items['병원명']['value'] as String : '';
        _cost = (items['비용'] is Map && items['비용']['value'] is String) 
            ? items['비용']['value'] as String : '';
        
        print('🏋️ Weight loaded: $_weight (from labs: ${items['체중']}, from pet: ${widget.petWeight})');
        
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
        
        // Use pet's weight as default if no lab data exists
        _weight = widget.petWeight != null ? widget.petWeight.toString() : '';
        _hospitalName = '';
        _cost = '';
        
        print('🏋️ No lab data, using pet weight: $_weight (from pet: ${widget.petWeight})');
        // 서버 데이터 없을 때 로컬 캐시에서 보강 로드
        await _loadFromLocal();
      }

      // Store previous values for display (only if there's actual data)
      if (previousRow != null && previousRow['items'] is Map) {
        final Map items = previousRow['items'] as Map;
        
        // Check if there's any actual data (non-empty values)
        bool hasActualData = false;
        for (final k in items.keys) {
          final v = items[k];
          final value = (v is Map && v['value'] is String) ? v['value'] as String : '';
          if (value.isNotEmpty) {
            hasActualData = true;
            break;
          }
        }
        
        // Only set as previous if there's actual data
        if (hasActualData) {
          _previousDateStr = previousRow['date'] as String?;
          print('ℹ️ Previous (${_previousDateStr ?? '-'}) with ${items.length} items');
          for (final k in _orderedKeys()) {
            final v = items[k];
            final value = (v is Map && v['value'] is String) ? v['value'] as String : '';
            _previousValues[k] = value;
          }
        } else {
          print('ℹ️ Previous row has no actual data, skipping');
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
          setState(() {
            // If item key changed, remove old controller and add new one
            if (newItemKey != itemKey) {
              _valueCtrls.remove(itemKey);
              _units.remove(itemKey);
              _refDog.remove(itemKey);
              _refCat.remove(itemKey);
              
              _valueCtrls[newItemKey] = TextEditingController(text: newValue);
              _valueCtrls[newItemKey]!.addListener(_onChanged);
              _units[newItemKey] = unit;
              if (ref != null) {
                _refDog[newItemKey] = ref;
                _refCat[newItemKey] = ref;
              }
            } else {
              // Ensure controller exists before setting value
              if (_valueCtrls[itemKey] == null) {
                _valueCtrls[itemKey] = TextEditingController(text: newValue);
                _valueCtrls[itemKey]!.addListener(_onChanged);
              } else {
                _valueCtrls[itemKey]!.text = newValue;
              }
            }
          });
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
        print('❌ User not authenticated → 로컬 저장');
        final offlineItems = _collectItemsForSave();
        await _saveToLocal(offlineItems, enqueuePending: true);
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
      // 로컬 캐시에도 저장 (오프라인 표시/재로딩용)
      await _saveToLocal(items);
      
      // 저장 후 기록 날짜 목록 업데이트
      await _loadRecordDates();
      
      // 성공 시에는 알림을 띄우지 않음 (건강 탭 UX 정책)
    } catch (e) {
      print('❌ Save error: $e');
      // 실패 시 로컬 저장 및 보류 큐에 추가
      final fallback = _collectItemsForSave();
      await _saveToLocal(fallback, enqueuePending: true);
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
    // 비용 항목일 때 숫자 포맷팅 적용
    String displayValue = value;
    String displayUnit = unit;
    
    if (label == '비용' && value.isNotEmpty) {
      // 숫자만 추출
      final numericValue = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (numericValue.isNotEmpty) {
        // 천 단위 쉼표 추가
        final number = int.tryParse(numericValue);
        if (number != null) {
          final formatter = NumberFormat('#,###');
          displayValue = formatter.format(number);
          displayUnit = '원';
        }
      }
    }
    
    return InkWell(
      onTap: () => _showBasicInfoEditDialog(label, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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
              flex: 2,
              child: Text(
                displayValue.isEmpty ? '-' : displayValue,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                displayUnit,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 모든 행에 동일한 너비의 공간 확보 (체중 항목만 아이콘 표시)
            SizedBox(
              width: 44, // 아이콘 영역 고정 너비
              child: label == '체중'
                  ? Padding(
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
                    )
                  : const SizedBox(), // 투명한 공간
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

      // Add basic info to items (for storage but not displayed in chart)
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

      // Update pet's weight if weight value is not empty
      if (_weight.isNotEmpty) {
        final weightValue = double.tryParse(_weight);
        if (weightValue != null) {
          // Update pet's weightKg in the database directly
          await Supabase.instance.client
              .from('pets')
              .update({
                'weight_kg': weightValue,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', widget.petId);
        }
      }

      // 성공 시에는 알림을 띄우지 않음 (건강 탭 UX 정책)
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  // ===== Offline-first helpers =====
  Map<String, dynamic> _collectItemsForSave() {
    final Map<String, dynamic> items = {};
    for (final k in _valueCtrls.keys) {
      final val = _valueCtrls[k]?.text ?? '';
      items[k] = {
        'value': val,
        'unit': _units[k] ?? '',
        'reference': _refDog[k] ?? _refCat[k] ?? '',
      };
    }
    items['체중'] = {'value': _weight, 'unit': 'kg', 'reference': ''};
    items['병원명'] = {'value': _hospitalName, 'unit': '', 'reference': ''};
    items['비용'] = {'value': _cost, 'unit': '', 'reference': ''};
    return items;
  }

  String _scopeId() => Supabase.instance.client.auth.currentUser?.id ?? 'local-user';

  Future<void> _saveToLocal(Map<String, dynamic> items, {bool enqueuePending = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scope = _scopeId();
      final key = 'labs_${scope}_${widget.petId}_${_dateKey()}';
      await prefs.setString(key, jsonEncode(items));
      final datesKey = 'labs_dates_${scope}_${widget.petId}';
      final dates = (prefs.getStringList(datesKey) ?? <String>[]).toSet();
      dates.add(_dateKey());
      await prefs.setStringList(datesKey, dates.toList());
      if (enqueuePending) {
        final pendingKey = 'labs_pending_${scope}';
        final pending = (prefs.getStringList(pendingKey) ?? <String>[]).toSet();
        pending.add('${widget.petId}|${_dateKey()}');
        await prefs.setStringList(pendingKey, pending.toList());
      }
      print('💾 로컬 저장 완료: key=$key');
    } catch (e) {
      print('❌ 로컬 저장 실패: $e');
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scope = _scopeId();
      final key = 'labs_${scope}_${widget.petId}_${_dateKey()}';
      final jsonStr = prefs.getString(key);
      if (jsonStr == null) {
        print('ℹ️ 로컬 데이터 없음: $key');
        return;
      }
      final Map<String, dynamic> items = jsonDecode(jsonStr) as Map<String, dynamic>;
      for (final entry in items.entries) {
        final k = entry.key;
        final v = entry.value;
        if (!_valueCtrls.containsKey(k)) {
          _valueCtrls[k] = TextEditingController();
          _valueCtrls[k]!.addListener(_onChanged);
        }
        if (v is Map) {
          if (v['unit'] is String) _units[k] = v['unit'] as String;
          if (v['reference'] is String) {
            if (widget.species.toLowerCase() == 'cat') {
              _refCat[k] = v['reference'] as String;
            } else {
              _refDog[k] = v['reference'] as String;
            }
          }
          final value = v['value'] is String ? v['value'] as String : '';
          _valueCtrls[k]?.text = value;
        }
      }
      _weight = (items['체중'] is Map && items['체중']['value'] is String) ? items['체중']['value'] as String : _weight;
      _hospitalName = (items['병원명'] is Map && items['병원명']['value'] is String) ? items['병원명']['value'] as String : _hospitalName;
      _cost = (items['비용'] is Map && items['비용']['value'] is String) ? items['비용']['value'] as String : _cost;
      print('📥 로컬 캐시에서 로드 완료: key=$key');
      final datesKey = 'labs_dates_${scope}_${widget.petId}';
      final dates = (prefs.getStringList(datesKey) ?? <String>[]);
      setState(() {
        _recordDates = dates.map((d) {
          final parts = d.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }).toSet();
      });
    } catch (e) {
      print('❌ 로컬 로드 실패: $e');
    }
  }

  Future<void> _syncPendingIfOnline() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingKey = 'labs_pending_${uid}';
      final list = prefs.getStringList(pendingKey) ?? <String>[];
      if (list.isEmpty) return;
      print('⏫ 보류된 업로드 ${list.length}건 동기화 시도');
      for (final entry in List<String>.from(list)) {
        final parts = entry.split('|');
        if (parts.length != 2) continue;
        final petId = parts[0];
        final date = parts[1];
        final key = 'labs_${uid}_${petId}_${date}';
        final jsonStr = prefs.getString(key);
        if (jsonStr == null) continue;
        final items = jsonDecode(jsonStr) as Map<String, dynamic>;
        try {
          await Supabase.instance.client.from('labs').upsert({
            'user_id': uid,
            'pet_id': petId,
            'date': date,
            'panel': 'BloodTest',
            'items': items,
          }, onConflict: 'user_id,pet_id,date');
          final set = (prefs.getStringList(pendingKey) ?? <String>[]).toSet();
          set.remove(entry);
          await prefs.setStringList(pendingKey, set.toList());
          print('✅ 보류 업로드 성공: $petId@$date');
        } catch (e) {
          print('⚠️ 보류 업로드 실패(유지): $petId@$date → $e');
        }
      }
    } catch (e) {
      print('❌ 보류 동기화 실패: $e');
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
        // 성공 시에는 알림을 띄우지 않음 (건강 탭 UX 정책)
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
