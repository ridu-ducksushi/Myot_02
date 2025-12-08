import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petcare/core/providers/pets_provider.dart';
import 'package:petcare/core/providers/reminders_provider.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petcare/data/services/lab_reference_ranges.dart';
import 'package:petcare/data/services/ocr_service.dart';
import 'package:petcare/utils/date_utils.dart' as app_date_utils;
import 'package:petcare/ui/widgets/common_widgets.dart';
import 'package:petcare/ui/widgets/app_record_calendar.dart';
import 'package:petcare/ui/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'weight_chart_screen.dart';
import 'ocr_result_screen.dart';

class PetHealthScreen extends ConsumerStatefulWidget {
  const PetHealthScreen({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<PetHealthScreen> createState() => _PetHealthScreenState();
}

class _PetHealthScreenState extends ConsumerState<PetHealthScreen> {
  // 건강 차트 테이블에 접근하기 위한 키 (새 검사 항목 추가 시 현재 날짜만 다시 로드)
  final GlobalKey<_LabTableState> _labTableKey = GlobalKey<_LabTableState>();
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
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surfaceVariant.withOpacity(0.95),
        elevation: 2,
        automaticallyImplyLeading: false,
      ),
      body: _LabTable(
        key: _labTableKey,
        species: pet.species,
        petId: pet.id,
        petName: pet.name,
        petWeight: pet.weightKg,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(pet),
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
        builder: (context) => WeightChartScreen(petId: petId, petName: petName),
      ),
    );
  }

  void _showAddOptions(Pet pet) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'labs.add_test_title'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text('labs.manual_input'.tr()),
                subtitle: Text('labs.manual_input_subtitle'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _showAddItemDialog(pet.species, pet.id);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                title: Text('labs.ocr_scan'.tr()),
                subtitle: Text('labs.ocr_scan_subtitle'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _showOcrOptions(pet);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOcrTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
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
          // 새 검사 항목이 추가되면 현재 선택된 날짜만 다시 로드
          // (날짜는 유지하고 내용만 갱신)
          _labTableKey.currentState?.reloadCurrentDate();
        },
      ),
    );
  }

  void _showOcrOptions(Pet pet) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'labs.scan_health_report'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'labs.scan_description'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'labs.ocr_tips'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    _buildOcrTip('labs.ocr_tip_1'.tr()),
                    _buildOcrTip('labs.ocr_tip_2'.tr()),
                    _buildOcrTip('labs.ocr_tip_3'.tr()),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text('labs.camera_capture'.tr()),
                subtitle: Text('labs.camera_capture_subtitle'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _startOcrFromCamera(pet);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                title: Text('labs.gallery_select'.tr()),
                subtitle: Text('labs.gallery_select_subtitle'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _startOcrFromGallery(pet);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 이미지 선택 및 OCR 처리 (카메라/갤러리 공통)
  Future<void> _startOcrFromSource(Pet pet, ImageSource source) async {
    try {
      final imageFile = source == ImageSource.camera
          ? await OcrService.pickFromCamera()
          : await OcrService.pickFromGallery();
      
      if (imageFile != null && mounted) {
        await _navigateToOcrResult(imageFile, pet);
      } else if (mounted && source == ImageSource.camera) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('labs.camera_canceled'.tr())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showImagePickerError(e, source);
    }
  }

  /// 이미지 선택 오류 메시지 표시
  void _showImagePickerError(dynamic error, ImageSource source) {
    final isCamera = source == ImageSource.camera;
    final errorStr = error.toString();
    
    String message = isCamera 
        ? '카메라를 사용할 수 없습니다.'
        : '갤러리에서 이미지를 불러올 수 없습니다.';
    
    if (errorStr.contains('permission') || errorStr.contains('권한')) {
      message = isCamera
          ? '카메라 권한이 필요합니다. 설정에서 권한을 허용해 주세요.'
          : '갤러리 접근 권한이 필요합니다. 설정에서 권한을 허용해 주세요.';
    } else if (errorStr.contains('camera') || errorStr.contains('카메라')) {
      message = '카메라에 접근할 수 없습니다. 다른 앱에서 카메라를 사용 중일 수 있습니다.';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _startOcrFromCamera(Pet pet) async {
    await _startOcrFromSource(pet, ImageSource.camera);
  }

  Future<void> _startOcrFromGallery(Pet pet) async {
    await _startOcrFromSource(pet, ImageSource.gallery);
  }

  Future<void> _navigateToOcrResult(File imageFile, Pet pet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OcrResultScreen(
          imageFile: imageFile,
          species: pet.species,
          existingKeys: LabReferenceRanges.getAllTestKeys(),
          onConfirm: (results) => _applyOcrResults(pet, results),
        ),
      ),
    );
  }

  Future<void> _applyOcrResults(Pet pet, Map<String, String> results) async {
    if (results.isEmpty) return;

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('labs.login_required'.tr())),
          );
        }
        return;
      }

      final dateKey = app_date_utils.DateUtils.toDateKey(DateTime.now());

      // 현재 날짜의 기존 데이터 가져오기
      final currentRes = await Supabase.instance.client
          .from('labs')
          .select('items')
          .eq('user_id', uid)
          .eq('pet_id', pet.id)
          .eq('date', dateKey)
          .eq('panel', 'BloodTest')
          .maybeSingle();

      Map<String, dynamic> currentItems = {};
      if (currentRes != null) {
        currentItems = Map<String, dynamic>.from(currentRes['items'] ?? {});
      }

      // OCR 결과 추가
      for (final entry in results.entries) {
        final reference = LabReferenceRanges.getReference(
          pet.species,
          entry.key,
        );
        currentItems[entry.key] = {
          'value': entry.value,
          'unit': _getDefaultUnit(entry.key),
          'reference': reference,
        };
      }

      // Supabase에 저장
      await Supabase.instance.client.from('labs').upsert({
        'user_id': uid,
        'pet_id': pet.id,
        'date': dateKey,
        'panel': 'BloodTest',
        'items': currentItems,
      }, onConflict: 'user_id,pet_id,date');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('labs.items_saved'.tr(namedArgs: {'count': results.length.toString()})),
            backgroundColor: Colors.green,
          ),
        );
        // 화면 새로고침
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('labs.save_ocr_error'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    }
  }

  String _getDefaultUnit(String testName) {
    const units = {
      'ALB': 'g/dL',
      'ALP': 'U/L',
      'ALT GPT': 'U/L',
      'AST GOT': 'U/L',
      'BUN': 'mg/dL',
      'Ca': 'mg/dL',
      'CK': 'U/L',
      'Cl': 'mmol/L',
      'CREA': 'mg/dL',
      'GGT': 'U/L',
      'GLU': 'mg/dL',
      'K': 'mmol/L',
      'LIPA': 'U/L',
      'Na': 'mmol/L',
      'NH3': 'µmol/L',
      'PHOS': 'mg/dL',
      'TBIL': 'mg/dL',
      'T-CHOL': 'mg/dL',
      'TG': 'mg/dL',
      'TPRO': 'g/dL',
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
    };
    return units[testName] ?? '';
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
  const _LabTable({
    required this.species,
    required this.petId,
    required this.petName,
    this.petWeight,
    Key? key,
  }) : super(key: key);
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
  // 검사 항목 리스트 스크롤 위치 유지용 컨트롤러
  final ScrollController _listScrollController = ScrollController();
  // 기본 검사 항목 키 목록 (표에 항상 표시되는 항목)
  static const List<String> _baseKeys = [
    // 사용자 정의 순서 (ABC 순으로 정렬된 기본 검사 항목)
    'ALB',
    'ALP',
    'ALT GPT',
    'AST GOT',
    'BUN',
    'Ca',
    'CK',
    'Cl',
    'CREA',
    'GGT',
    'GLU',
    'K',
    'LIPA',
    'Na',
    'NH3',
    'PHOS',
    'TBIL',
    'T-CHOL',
    'TG',
    'TPRO',
    'Na/K',
    'ALB/GLB',
    'BUN/CRE',
    'GLOB',
    'vAMY-P',
    'SDMA',
    'HCT',
    'HGB',
    'MCH',
    'MCHC',
    'MCV',
    'MPV',
    'PLT',
    'RBC',
    'RDW-CV',
    'WBC',
    'WBC-GRAN(#)',
    'WBC-GRAN(%)',
    'WBC-LYM(#)',
    'WBC-LYM(%)',
    'WBC-MONO(#)',
    'WBC-MONO(%)',
    'WBC-EOS(#)',
    'WBC-EOS(%)',
  ];
  // 기본정보 항목 (차트에 표시하지 않음)
  static const List<String> _basicInfoKeys = ['체중', '병원명', '비용'];
  static const String _keyWeight = '체중';
  static const String _keyHospitalName = '병원명';
  static const String _keyCost = '비용';
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
  // 마지막으로 기억한 스크롤 위치
  double _lastScrollOffset = 0;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 외부(상위 위젯)에서 현재 선택된 날짜의 데이터를 다시 불러올 때 사용
  void reloadCurrentDate() {
    _loadFromSupabase();
  }

  /// 기본 검사 항목들은 값이 없더라도 항상 리스트에 표시하기 위해
  /// 최소한의 컨트롤러만 보장해 둔다.
  void _ensureBaseControllers() {
    for (final key in _baseKeys) {
      if (!_valueCtrls.containsKey(key)) {
        _valueCtrls[key] = TextEditingController();
        _valueCtrls[key]!.addListener(_onChanged);
      }
    }
  }

  void _captureScrollOffset() {
    if (_listScrollController.hasClients) {
      _lastScrollOffset = _listScrollController.offset;
    }
  }

  void _restoreScrollOffset() {
    if (!_listScrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listScrollController.hasClients) return;
      final max = _listScrollController.position.maxScrollExtent;
      final target = _lastScrollOffset.clamp(0.0, max);
      _listScrollController.jumpTo(target);
    });
  }

  @override
  void initState() {
    super.initState();
    _initRefs();
    _loadCustomOrder();
    // 기록 날짜를 먼저 로드하고, 가장 최근 날짜를 선택
    _loadRecordDatesAndSetLatest();
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
    _listScrollController.dispose();
    for (final c in _valueCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCat = widget.species.toLowerCase() == 'cat';
    final dateLabel =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
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
                Text('labs.test_date'.tr() + ': ', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _showCalendarDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dateLabel,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
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
            InkWell(
              onTap: () async {
                // 직전 날짜로 이동
                final parts = _previousDateStr!.split('-');
                if (parts.length == 3) {
                  setState(() {
                    _selectedDate = DateTime(
                      int.parse(parts[0]),
                      int.parse(parts[1]),
                      int.parse(parts[2]),
                    );
                  });
                  await _loadFromSupabase();
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'labs.previous_date'.tr(namedArgs: {'date': _previousDateStr!}),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
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
            'labs.basic_info'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildBasicInfoRow(_keyWeight, 'kg', _weight),
                _buildDivider(),
                _buildBasicInfoRow(_keyHospitalName, '', _hospitalName),
                _buildDivider(),
                _buildBasicInfoRow(_keyCost, '', _cost),
              ],
            ),
          ),
        ],
      ),
    );
    // 기본 검사 항목 컨트롤러를 먼저 보장한 뒤 정렬된 키 목록을 계산
    _ensureBaseControllers();
    final baseKeys = _orderedKeys();
    // 사용자 정의 순서가 있으면 사용, 없으면 기본 순서
    final sortedKeys = _customOrder.isEmpty ? baseKeys : _customOrder;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              header,
              basicInfoSection,
              // 헤더 행
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'labs.test_name'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: Text(
                              'labs.current_value'.tr(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: Text(
                              'labs.previous_value'.tr(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: Text(
                              'labs.reference_range'.tr(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: Text(
                              'labs.unit'.tr(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                      onTap: _customOrder.isNotEmpty
                          ? () async {
                              setState(() {
                                _customOrder.clear();
                              });
                              // 저장된 순서 삭제
                              try {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final uid = Supabase
                                    .instance
                                    .client
                                    .auth
                                    .currentUser
                                    ?.id;
                                if (uid != null) {
                                  final key =
                                      'lab_custom_order_${uid}_${widget.petId}';
                                  await prefs.remove(key);
                                }
                              } catch (e) {
                                print('순서 삭제 오류: $e');
                              }
                            }
                          : null,
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
                  scrollController: _listScrollController,
                  itemBuilder: (context, index) {
                    final k = sortedKeys[index];
                    final ref = _getReference(k);
                    final isPinned = _pinnedKeys.contains(k);

                    return Container(
                      key: ValueKey(k),
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showEditDialog(k),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              // 검사명
                              Expanded(
                                flex: 2,
                                child: Text(
                                  k,
                                  style: const TextStyle(fontSize: 14),
                                ),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      (_valueCtrls[k]?.text ?? '').length > 5
                                          ? (_valueCtrls[k]?.text ?? '')
                                                .substring(0, 5)
                                          : (_valueCtrls[k]?.text ?? ''),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _getValueColor(
                                          _valueCtrls[k]?.text,
                                          ref,
                                        ),
                                        fontWeight:
                                            _valueCtrls[k]?.text != null &&
                                                _valueCtrls[k]!.text.isNotEmpty
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
                                        ? (_previousValues[k] ?? '-').substring(
                                            0,
                                            5,
                                          )
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
    // 기본 항목: 값이 없어도 항상 표시
    final List<String> baseKeys = List<String>.from(_baseKeys);

    // 커스텀 항목: 실제 데이터(값/단위)가 있는 항목만 표시
    // → 사용자가 새로 추가한 항목은 기본 항목보다 위쪽에 보이도록 먼저 배치
    final customKeys = _valueCtrls.keys
        .where(
          (k) =>
              !_baseKeys.contains(k) &&
              !_basicInfoKeys.contains(k) && // 기본정보 항목 제외
              (_valueCtrls[k]?.text.isNotEmpty == true ||
                  _units.containsKey(k)),
        )
        .toList()
      ..sort();

    // 사용자 경험상: 커스텀(사용자 추가) 항목이 위, 기본 항목이 아래에 오도록 정렬
    return [...customKeys, ...baseKeys];
  }

  bool _isCustomItemKey(String key) {
    return !_baseKeys.contains(key) && !_basicInfoKeys.contains(key);
  }

  void _clearItemValue(String key) {
    if (!_valueCtrls.containsKey(key)) {
      _valueCtrls[key] = TextEditingController();
      _valueCtrls[key]!.addListener(_onChanged);
    }
    _valueCtrls[key]!.text = '';
  }

  void _removeItemCompletely(String key) {
    _valueCtrls[key]?.dispose();
    _valueCtrls.remove(key);
    if (_isCustomItemKey(key)) {
      // 커스텀 항목은 단위/기준치까지 완전히 제거
      _units.remove(key);
      _refDog.remove(key);
      _refCat.remove(key);
    }
    _previousValues.remove(key);
    _pinnedKeys.remove(key);
    _pinnedKeysOrder.removeWhere((k) => k == key);
    _customOrder.remove(key);
  }

  void _initRefs() {
    // ABC 순으로 정렬된 단위 (한글 → 영어 변경)
    _units.addAll({
      'ALB': 'g/dL', // 알부민 → ALB
      'ALP': 'U/L',
      'ALT GPT': 'U/L',
      'AST GOT': 'U/L',
      'BUN': 'mg/dL',
      'Ca': 'mg/dL',
      'CK': 'U/L', // 크레아틴 키나아제
      'Cl': 'mmol/L',
      'CREA': 'mg/dL', // Creatinine → Creat
      'GGT': 'U/L', // 글로불린 → Glob
      'GLU': 'mg/dL',
      'K': 'mmol/L',
      'LIPA': 'U/L',
      'Na': 'mmol/L',
      'NH3': 'µmol/L',
      'PHOS': 'mg/dL',
      'TBIL': 'mg/dL',
      'T-CHOL': 'mg/dL',
      'TG': 'mg/dL', // 총빌리루빈 → TBil
      'TPRO': 'g/dL', // 중성지방 → TG
      'Na/K': '-', // 총단백 → TP
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

    // 기본 기준치는 LabReferenceRanges에서 가져오므로 여기서는 초기화하지 않음
    // _refDog와 _refCat는 사용자가 수정한 커스텀 기준치만 저장
  }

  String _dateKey() {
    return app_date_utils.DateUtils.toDateKey(_selectedDate);
  }

  /// 검사 항목의 기준치를 반환합니다.
  /// 커스텀 기준치가 있으면 그것을 사용하고, 없으면 LabReferenceRanges에서 가져옵니다.
  String _getReference(String testItem) {
    final isCat = widget.species.toLowerCase() == 'cat';
    final customRef = isCat ? _refCat[testItem] : _refDog[testItem];
    if (customRef != null && customRef.isNotEmpty) {
      return customRef;
    }
    return LabReferenceRanges.getReference(widget.species, testItem);
  }

  // 현재 값이 기준치 범위 내에 있는지 확인하고 색상 반환
  Color _getValueColor(String? valueStr, String? reference) {
    if (valueStr == null ||
        valueStr.isEmpty ||
        reference == null ||
        reference.isEmpty ||
        reference == '-') {
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

  Future<void> _loadRecordDatesAndSetLatest() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        await _loadFromSupabase();
        return;
      }

      // Supabase에서 이 펫의 모든 기록 날짜를 가져옴
      final resList = await Supabase.instance.client
          .from('labs')
          .select('date, items')
          .eq('user_id', uid)
          .eq('pet_id', widget.petId)
          .order('date', ascending: false);

      final validDates = <DateTime>[];

      for (final row in resList) {
        // Check if this row has actual data (non-empty values)
        final items = row['items'];
        if (items is! Map) continue;

        bool hasData = false;
        for (final k in items.keys) {
          final v = items[k];
          final value = (v is Map && v['value'] is String)
              ? v['value'] as String
              : '';
          if (value.isNotEmpty) {
            hasData = true;
            break;
          }
        }

        if (hasData) {
          final dateStr = row['date'] as String;
          final parts = dateStr.split('-');
          validDates.add(
            DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            ),
          );
        }
      }

      setState(() {
        _recordDates = validDates.toSet();

        // 가장 최근 기록 날짜를 선택 (오늘 이전의 가장 최근 날짜)
        final today = _today();
        final pastDates = validDates
            .where((d) => d.isBefore(today) || isSameDay(d, today))
            .toList();
        if (pastDates.isNotEmpty) {
          pastDates.sort((a, b) => b.compareTo(a)); // 내림차순 정렬
          _selectedDate = pastDates.first;
          print('📅 가장 최근 기록 날짜로 설정: ${_dateKey()}');
        } else {
          // 기록이 없으면 오늘 날짜 유지
          _selectedDate = _today();
        }
      });

      // 날짜 설정 후 데이터 로드
      await _loadFromSupabase();
    } catch (e) {
      print('❌ Error loading record dates: $e');
      await _loadFromSupabase();
    }
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
                final value = (v is Map && v['value'] is String)
                    ? v['value'] as String
                    : '';
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
    final pickedDate = await showRecordCalendarDialog(
      context: context,
      initialDate: _selectedDate,
      markedDates: _recordDates,
      lastDay: DateTime.now(),
    );

    if (pickedDate != null && !isSameDay(pickedDate, _selectedDate)) {
      setState(() => _selectedDate = pickedDate);
      await _loadFromSupabase();
    }
  }

  Future<void> _loadFromSupabase() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      print(
        '🔍 Loading data: uid=$uid, petId=${widget.petId}, date=${_dateKey()}',
      );

      if (uid == null) {
        print('❌ User not authenticated → 로컬 캐시에서 로드');
        await _loadFromLocal();
        setState(() => _isLoading = false);
        return;
      }

      // Clear custom controllers from previous pets to avoid cross-contamination
      // Use the same baseKeys as _orderedKeys() to ensure consistency
      final baseKeys = [
        'ALB',
        'ALP',
        'ALT GPT',
        'AST GOT',
        'BUN',
        'Ca',
        'CK',
        'Cl',
        'CREA',
        'GGT',
        'GLU',
        'K',
        'LIPA',
        'Na',
        'NH3',
        'PHOS',
        'TBIL',
        'T-CHOL',
        'TG',
        'TPRO',
        'Na/K',
        'ALB/GLB',
        'BUN/CRE',
        'GLOB',
        'vAMY-P',
        'SDMA',
        'HCT',
        'HGB',
        'MCH',
        'MCHC',
        'MCV',
        'MPV',
        'PLT',
        'RBC',
        'RDW-CV',
        'WBC',
        'WBC-GRAN(#)',
        'WBC-GRAN(%)',
        'WBC-LYM(#)',
        'WBC-LYM(%)',
        'WBC-MONO(#)',
        'WBC-MONO(%)',
        'WBC-EOS(#)',
        'WBC-EOS(%)',
      ];

      // Remove custom controllers that are not in base keys
      final customKeysToRemove = _valueCtrls.keys
          .where((k) => !baseKeys.contains(k))
          .toList();
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
              final value = (v is Map && v['value'] is String)
                  ? v['value'] as String
                  : '';
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

        // Ensure controllers exist for all items
        for (final k in items.keys) {
          if (!_valueCtrls.containsKey(k)) {
            _valueCtrls[k] = TextEditingController();
            _valueCtrls[k]!.addListener(_onChanged);
          }
        }

        // Update unit, reference, and values from stored data
        for (final k in items.keys) {
          final v = items[k];
          if (v is Map) {
            // 단위 동기화
            if (v['unit'] is String) {
              _units[k] = v['unit'] as String;
            }

            // 기준치 동기화: 저장된 reference가 있으면 커스텀 기준치로 사용
            // 없으면 커스텀 기준치를 제거하고 기본값을 사용
            final refStr =
                v['reference'] is String ? (v['reference'] as String).trim() : '';
            final isCat = widget.species.toLowerCase() == 'cat';
            if (refStr.isEmpty) {
              if (isCat) {
                _refCat.remove(k);
              } else {
                _refDog.remove(k);
              }
            } else {
              if (isCat) {
                _refCat[k] = refStr;
              } else {
                _refDog[k] = refStr;
              }
            }

            // 값 동기화
            final value = v['value'] is String ? v['value'] as String : '';
            _valueCtrls[k]?.text = value;
          } else {
            _valueCtrls[k]?.text = '';
          }
        }

        // Load basic info data
        _weight = (items[_keyWeight] is Map && items[_keyWeight]['value'] is String)
            ? items[_keyWeight]['value'] as String
            : (widget.petWeight != null ? widget.petWeight.toString() : '');
        _hospitalName = (items[_keyHospitalName] is Map && items[_keyHospitalName]['value'] is String)
            ? items[_keyHospitalName]['value'] as String
            : '';
        _cost = (items[_keyCost] is Map && items[_keyCost]['value'] is String)
            ? items[_keyCost]['value'] as String
            : '';

        print(
          '🏋️ Weight loaded: $_weight (from labs: ${items[_keyWeight]}, from pet: ${widget.petWeight})',
        );

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

        print(
          '🏋️ No lab data, using pet weight: $_weight (from pet: ${widget.petWeight})',
        );
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
          final value = (v is Map && v['value'] is String)
              ? v['value'] as String
              : '';
          if (value.isNotEmpty) {
            hasActualData = true;
            break;
          }
        }

        // Only set as previous if there's actual data
        if (hasActualData) {
          _previousDateStr = previousRow['date'] as String?;
          print(
            'ℹ️ Previous (${_previousDateStr ?? '-'}) with ${items.length} items',
          );
          for (final k in _orderedKeys()) {
            final v = items[k];
            final value = (v is Map && v['value'] is String)
                ? v['value'] as String
                : '';
            _previousValues[k] = value;
          }
        } else {
          print('ℹ️ Previous row has no actual data, skipping');
        }
      }
    } catch (e) {
      print('❌ Load error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('labs.load_error'.tr(namedArgs: {'error': e.toString()}))));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEditDialog(String itemKey) {
    final currentValue = _valueCtrls[itemKey]?.text ?? '';
    final unit = _units[itemKey] ?? '';
    final ref = _getReference(itemKey);

    _captureScrollOffset();

    showDialog(
      context: context,
      builder: (context) => _EditLabValueDialog(
        itemKey: itemKey,
        currentValue: currentValue,
        reference: ref ?? '',
        unit: unit,
        onSave: (newItemKey, newValue, newReference, newUnit) {
          _captureScrollOffset();
          setState(() {
            // 키가 변경된 경우: 기존 항목 정리 후 새 키로 이동
            if (newItemKey != itemKey) {
              _valueCtrls.remove(itemKey);
              _units.remove(itemKey);
              _refDog.remove(itemKey);
              _refCat.remove(itemKey);

              _valueCtrls[newItemKey] = TextEditingController(text: newValue);
              _valueCtrls[newItemKey]!.addListener(_onChanged);

              // 단위 업데이트 (빈 문자열이면 이전 값 유지)
              if (newUnit.isNotEmpty) {
                _units[newItemKey] = newUnit;
              } else if (unit.isNotEmpty) {
                _units[newItemKey] = unit;
              }

              // 기준치 업데이트 (빈 문자열이면 커스텀 기준치 제거 → 기본값 사용)
              final trimmedRef = newReference.trim();
              final isCat = widget.species.toLowerCase() == 'cat';
              if (trimmedRef.isEmpty) {
                if (isCat) {
                  _refCat.remove(newItemKey);
                } else {
                  _refDog.remove(newItemKey);
                }
              } else {
                if (isCat) {
                  _refCat[newItemKey] = trimmedRef;
                } else {
                  _refDog[newItemKey] = trimmedRef;
                }
              }
            } else {
              // 같은 키에서 값/단위/기준치만 수정
              if (_valueCtrls[itemKey] == null) {
                _valueCtrls[itemKey] = TextEditingController(text: newValue);
                _valueCtrls[itemKey]!.addListener(_onChanged);
              } else {
                _valueCtrls[itemKey]!.text = newValue;
              }

              if (newUnit.isNotEmpty) {
                _units[itemKey] = newUnit;
              }

              final trimmedRef = newReference.trim();
              final isCat = widget.species.toLowerCase() == 'cat';
              if (trimmedRef.isEmpty) {
                if (isCat) {
                  _refCat.remove(itemKey);
                } else {
                  _refDog.remove(itemKey);
                }
              } else {
                if (isCat) {
                  _refCat[itemKey] = trimmedRef;
                } else {
                  _refDog[itemKey] = trimmedRef;
                }
              }
            }
          });
          _saveToSupabase();
        },
        onDelete: () {
          _captureScrollOffset();
          setState(() {
            // 모든 항목에 대해 행 자체를 제거 (기본/커스텀 공통)
            _removeItemCompletely(itemKey);
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
      print(
        '💾 Saving data: uid=$uid, petId=${widget.petId}, date=${_dateKey()}',
      );

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
      final isCat = widget.species.toLowerCase() == 'cat';
      for (final k in _valueCtrls.keys) {
        final val = _valueCtrls[k]?.text ?? '';
        if (val.isNotEmpty || _units.containsKey(k)) {
          items[k] = {
            'value': val,
            'unit': _units[k] ?? '',
            'reference': _getReference(k),
          };
          if (val.isNotEmpty) {
            nonEmptyCount++;
            print('  $k: $val');
          }
        }
      }

      // 기본 정보도 항상 저장 (값이 비어있어도 저장하여 삭제 반영)
      items[_keyWeight] = {'value': _weight, 'unit': 'kg', 'reference': ''};
      items[_keyHospitalName] = {'value': _hospitalName, 'unit': '', 'reference': ''};
      items[_keyCost] = {'value': _cost, 'unit': '', 'reference': ''};

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('labs.save_error'.tr(namedArgs: {'error': e.toString()}))));
      }
    } finally {
      setState(() => _isSaving = false);
      // 저장 과정에서 빌드/레이아웃이 변경된 후에도
      // 사용자가 보던 검사 항목 위치를 유지하도록 스크롤 복원
      _restoreScrollOffset();
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

    if (label == _keyCost && value.isNotEmpty) {
      // 숫자만 추출
      final numericValue = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (numericValue.isNotEmpty) {
        // 천 단위 쉼표 추가
        final number = int.tryParse(numericValue);
        if (number != null) {
          final formatter = NumberFormat('#,###');
          displayValue = formatter.format(number);
          displayUnit = 'labs.currency_unit'.tr();
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
            // 모든 행에 동일한 너비의 공간 확보 (체중 항목만 아이콘 표시)
            SizedBox(
              width: 48, // 아이콘 영역 고정 너비
              child: label == _keyWeight
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () => _showWeightChartDialog(
                          widget.petId,
                          widget.petName,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.bar_chart,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
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
        builder: (context) => WeightChartScreen(petId: petId, petName: petName),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 0.5, color: Colors.grey[300]);
  }

  void _showBasicInfoEditDialog(String label, String currentValue) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('labs.edit_basic_info'.tr(namedArgs: {'label': label})),
        content: TextField(
          controller: controller,
          keyboardType: label == _keyWeight || label == _keyCost
              ? TextInputType.number
              : TextInputType.text,
          inputFormatters: label == _keyWeight
              ? [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ]
              : label == _keyCost
                  ? [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ]
                  : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            hintText: label == _keyWeight
                ? 'labs.weight_hint'.tr()
                : label == _keyHospitalName
                ? 'labs.hospital_name_hint'.tr()
                : 'labs.cost_hint'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = controller.text.trim();
              // 로컬 상태 먼저 업데이트하여 UI 즉시 반영
              setState(() {
                switch (label) {
                  case _keyWeight:
                    _weight = newValue;
                    break;
                  case _keyHospitalName:
                    _hospitalName = newValue;
                    break;
                  case _keyCost:
                    _cost = newValue;
                    break;
                }
              });
              Navigator.of(context).pop();
              // Supabase에 저장 (비동기, 백그라운드에서 처리)
              // 저장 실패 시에만 에러 표시, 성공 시에는 UI가 이미 업데이트됨
              await _saveBasicInfoToSupabase();
            },
            child: Text('common.save'.tr()),
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
      // 사용자가 값을 지웠을 때는 빈 문자열로 저장 (기존 값 유지하지 않음)
      currentItems[_keyWeight] = {
        'value': _weight,
        'unit': 'kg',
        'reference': '',
      };
      currentItems[_keyHospitalName] = {
        'value': _hospitalName,
        'unit': '',
        'reference': '',
      };
      currentItems[_keyCost] = {'value': _cost, 'unit': '', 'reference': ''};

      // Save to Supabase
      await Supabase.instance.client.from('labs').upsert({
        'user_id': uid,
        'pet_id': widget.petId,
        'date': _dateKey(),
        'panel': 'BloodTest',
        'items': currentItems,
      }, onConflict: 'user_id,pet_id,date');

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('labs.save_error'.tr(namedArgs: {'error': e.toString()}))));
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
        'reference': _getReference(k),
      };
    }
    items[_keyWeight] = {'value': _weight, 'unit': 'kg', 'reference': ''};
    items[_keyHospitalName] = {'value': _hospitalName, 'unit': '', 'reference': ''};
    items[_keyCost] = {'value': _cost, 'unit': '', 'reference': ''};
    return items;
  }

  String _scopeId() =>
      Supabase.instance.client.auth.currentUser?.id ?? 'local-user';

  Future<void> _saveToLocal(
    Map<String, dynamic> items, {
    bool enqueuePending = false,
  }) async {
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
      final Map<String, dynamic> items =
          jsonDecode(jsonStr) as Map<String, dynamic>;
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
      _weight = (items[_keyWeight] is Map && items[_keyWeight]['value'] is String)
          ? items[_keyWeight]['value'] as String
          : _weight;
      _hospitalName = (items[_keyHospitalName] is Map && items[_keyHospitalName]['value'] is String)
          ? items[_keyHospitalName]['value'] as String
          : _hospitalName;
      _cost = (items[_keyCost] is Map && items[_keyCost]['value'] is String)
          ? items[_keyCost]['value'] as String
          : _cost;
      print('📥 로컬 캐시에서 로드 완료: key=$key');
      final datesKey = 'labs_dates_${scope}_${widget.petId}';
      final dates = (prefs.getStringList(datesKey) ?? <String>[]);
      setState(() {
        _recordDates = dates.map((d) {
          final parts = d.split('-');
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
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
  // (newItemKey, newValue, newReference, newUnit)
  final void Function(String, String, String, String) onSave;
  final VoidCallback? onDelete; // 현재 수치 삭제

  const _EditLabValueDialog({
    required this.itemKey,
    required this.currentValue,
    required this.reference,
    required this.unit,
    required this.onSave,
    this.onDelete,
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
      title: Text('labs.edit_test_value'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _itemKeyController,
              decoration: InputDecoration(
                labelText: 'labs.test_name_label'.tr(),
                border: const OutlineInputBorder(),
                hintText: 'labs.test_name_hint'.tr(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'labs.test_value_label'.tr(),
                border: const OutlineInputBorder(),
                hintText: 'labs.test_value_hint'.tr(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'labs.reference_label'.tr(),
                border: const OutlineInputBorder(),
                hintText: 'labs.reference_hint'.tr(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _unitController,
              decoration: InputDecoration(
                labelText: 'labs.unit_label'.tr(),
                border: const OutlineInputBorder(),
                hintText: 'labs.unit_hint'.tr(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        TextButton(
          onPressed: () {
            widget.onDelete?.call();
            Navigator.of(context).pop();
          },
          child: Text('common.delete'.tr()),
        ),
        ElevatedButton(
          onPressed: () {
            final newItemKey = _itemKeyController.text.trim();
            final newValue = _valueController.text.trim();
            final newReference = _referenceController.text.trim();
            final newUnit = _unitController.text.trim();
            if (newItemKey.isNotEmpty) {
              widget.onSave(newItemKey, newValue, newReference, newUnit);
              Navigator.of(context).pop();
            }
          },
          child: Text('common.save'.tr()),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('labs.test_name_required'.tr())));
      return;
    }

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('labs.login_required'.tr())));
        return;
      }

      final dateKey = app_date_utils.DateUtils.toDateKey(DateTime.now());

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
      await Supabase.instance.client.from('labs').upsert({
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('labs.save_ocr_error'.tr(namedArgs: {'error': e.toString()}))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('labs.add_new_test_item'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _itemKeyController,
              decoration: InputDecoration(
                labelText: 'labs.test_name_asterisk'.tr(),
                border: const OutlineInputBorder(),
                hintText: 'labs.add_test_name_hint'.tr(),
                helperText: 'labs.add_test_name_helper'.tr(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'labs.test_value_label'.tr(),
                border: const OutlineInputBorder(),
                hintText: 'labs.test_value_hint'.tr(),
                helperText: 'labs.add_test_value_helper'.tr(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'labs.reference_label'.tr(),
                border: const OutlineInputBorder(),
                hintText: 'labs.reference_hint'.tr(),
                helperText: 'labs.add_reference_helper'.tr(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _unitController,
              decoration: InputDecoration(
                labelText: 'labs.unit_label'.tr(),
                border: const OutlineInputBorder(),
                hintText: 'labs.unit_hint'.tr(),
                helperText: 'labs.add_unit_helper'.tr(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(onPressed: _saveNewItem, child: Text('common.add'.tr())),
      ],
    );
  }
}
