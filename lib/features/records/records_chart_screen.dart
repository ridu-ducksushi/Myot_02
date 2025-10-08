
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petcare/core/providers/records_provider.dart';
import 'package:petcare/data/models/pet.dart';
import 'package:petcare/data/models/record.dart';

class RecordsChartScreen extends ConsumerStatefulWidget {
  final String petId;
  final String petName;

  const RecordsChartScreen({
    Key? key,
    required this.petId,
    required this.petName,
  }) : super(key: key);

  @override
  _RecordsChartScreenState createState() => _RecordsChartScreenState();
}

class _RecordsChartScreenState extends ConsumerState<RecordsChartScreen> {
  String? _selectedRecordType;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  // Aggregated data used for the chart rendering
  List<Map<String, dynamic>> _chartData = [];
  // Raw per-day data fetched from records; aggregation derives from this
  List<Map<String, dynamic>> _rawData = [];
  // Pie chart data for subcategory breakdown
  List<PieChartSectionData> _pieChartData = [];
  Map<String, int> _allSubcategoryData = {}; // 모든 소분류 데이터 (0 포함)
  bool _isLoading = false;
  // View granularity: day | week | month
  String _viewMode = 'day';

  @override
  void initState() {
    super.initState();
    _loadRecordTypes();
  }

  Future<void> _loadRecordTypes() async {
    try {
      // 4가지 대분류 중에서 첫 번째를 기본 선택
      if (mounted) {
        setState(() {
          _selectedRecordType = 'food'; // 기본값으로 'food' 선택
          _loadChartData();
        });
      }
    } catch (e) {
      print('❌ Load record types error: $e');
    }
  }

  Future<void> _loadChartData() async {
    if (_selectedRecordType == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final records = ref.read(recordsProvider).records
          .where((r) => r.petId == widget.petId)
          .where((r) => _isRecordTypeMatch(r.type, _selectedRecordType!))
          .where((r) => r.at.isAfter(_startDate.subtract(const Duration(days: 1))))
          .where((r) => r.at.isBefore(_endDate.add(const Duration(days: 1))))
          .toList();

      final List<Map<String, dynamic>> chartData = [];
      
      // Group records by date
      final Map<String, List<Record>> groupedRecords = {};
      for (final record in records) {
        final dateStr = DateFormat('yyyy-MM-dd').format(record.at);
        groupedRecords.putIfAbsent(dateStr, () => []).add(record);
      }
      
      // Convert to chart data format
      for (final entry in groupedRecords.entries) {
        final date = entry.key;
        final recordsForDate = entry.value;
        
        chartData.add({
          'date': date,
          'count': recordsForDate.length,
        });
      }
      
      if (mounted) {
        setState(() {
          _rawData = chartData;
          _applyAggregation();
          _isLoading = false;
        });
        // Generate pie chart data after setState
        _generatePieChartData();
      }
    } catch (e) {
      print('❌ Load chart data error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Aggregate _rawData into _chartData based on _viewMode
  void _applyAggregation() {
    if (_viewMode == 'day') {
      // Keep as-is but sort by date
      _chartData = _rawData
          .map((e) => {
                ...e,
                'label': e['date'],
              })
          .toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
      return;
    }

    // Helper to parse date
    DateTime parseDate(String d) => DateTime.parse(d);

    // Grouping map
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final row in _rawData) {
      final dateStr = row['date'] as String;
      final dt = parseDate(dateStr);
      String key;
      String label;

      if (_viewMode == 'week') {
        // Start of week (Mon)
        final int weekday = dt.weekday; // Mon=1..Sun=7
        final startOfWeek = DateTime(dt.year, dt.month, dt.day)
            .subtract(Duration(days: weekday - 1));
        key = DateFormat('yyyy-MM-dd').format(startOfWeek);
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        label = '${DateFormat('MM/dd').format(startOfWeek)}~${DateFormat('MM/dd').format(endOfWeek)}';
      } else {
        // month
        final monthStart = DateTime(dt.year, dt.month, 1);
        key = DateFormat('yyyy-MM').format(monthStart);
        label = DateFormat('yyyy-MM').format(monthStart);
      }

      final list = grouped.putIfAbsent(key, () => []);
      list.add({
        ...row,
        'group_key': key,
        'label': label,
      });
    }

    // Aggregate using sum for counts
    final List<Map<String, dynamic>> aggregated = [];
    for (final entry in grouped.entries) {
      final rows = entry.value;
      if (rows.isEmpty) continue;
      final int sum = rows.map((r) => r['count'] as int).fold(0, (a, b) => a + b);
      final first = rows.first;
      aggregated.add({
        'date': entry.key, // key acts as representative date
        'label': first['label'] ?? entry.key,
        'count': sum,
      });
    }

    // Sort by date ascending based on key
    aggregated.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    _chartData = aggregated;
  }

  // Generate pie chart data for subcategory breakdown
  List<String> _getAllSubcategoriesForType(String category) {
    switch (category) {
      case 'food':
        return ['Meal', 'Snack', 'Water', 'Medicine', 'Supplement'];
      case 'health':
        return ['Medicine', 'Vaccine', 'Visit', 'Weight'];
      case 'poop':
        return ['Litter', 'Feces', 'Urine'];
      case 'activity':
        return ['Activity', 'Other'];
      default:
        return [];
    }
  }

  void _generatePieChartData() {
    if (_selectedRecordType == null) {
      setState(() {
        _pieChartData = [];
      });
      return;
    }

    final List<Record> allRecords = ref.read(recordsForPetProvider(widget.petId));
    final List<Record> filteredRecords = allRecords
        .where((r) => _isRecordTypeMatch(r.type, _selectedRecordType!))
        .where((r) => r.at.isAfter(_startDate.subtract(const Duration(days: 1))))
        .where((r) => r.at.isBefore(_endDate.add(const Duration(days: 1))))
        .toList();

    // Get all subcategories for this type
    final List<String> allSubcategories = _getAllSubcategoriesForType(_selectedRecordType!);
    
    // Initialize all subcategories with 0 count
    final Map<String, int> subcategoryCounts = {};
    for (final subcategory in allSubcategories) {
      subcategoryCounts[subcategory] = 0;
    }

    // Count actual records
    for (final record in filteredRecords) {
      final subcategory = _getSubcategoryDisplayName(record.type);
      if (subcategoryCounts.containsKey(subcategory)) {
        subcategoryCounts[subcategory] = subcategoryCounts[subcategory]! + 1;
      }
    }

    if (allSubcategories.isEmpty) {
      setState(() {
        _pieChartData = [];
      });
      return;
    }

    // Generate pie chart sections - 연한 색상으로 변경
    final List<Color> colors = [
      Colors.blue.shade200,
      Colors.green.shade200,
      Colors.orange.shade200,
      Colors.purple.shade200,
      Colors.teal.shade200,
      Colors.pink.shade200,
      Colors.indigo.shade200,
      Colors.red.shade200,
    ];

    final List<PieChartSectionData> pieChartData = [];
    int colorIndex = 0;
    final totalCount = subcategoryCounts.values.fold(0, (sum, count) => sum + count);

    // Only add sections with actual data to pie chart
    subcategoryCounts.forEach((subcategory, count) {
      if (count > 0) {
        pieChartData.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: count.toDouble(),
            title: '${((count / totalCount) * 100).toStringAsFixed(1)}%\n$subcategory',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        );
        colorIndex++;
      }
    });

    setState(() {
      _pieChartData = pieChartData;
      _allSubcategoryData = subcategoryCounts; // 모든 소분류 데이터 저장 (0 포함)
    });
  }

  // Get display name for subcategory
  String _getSubcategoryDisplayName(String recordType) {
    switch (recordType) {
      // Food subcategories
      case 'food_meal':
        return 'Meal';
      case 'food_snack':
        return 'Snack';
      case 'food_water':
        return 'Water';
      case 'food_treat':
        return 'Snack';
      case 'food_med':
        return 'Medicine';
      case 'food_supplement':
        return 'Supplement';
      
      // Health subcategories
      case 'health_med':
      case 'med':
        return 'Medicine';
      case 'health_vaccine':
      case 'vaccine':
        return 'Vaccine';
      case 'health_visit':
      case 'visit':
        return 'Visit';
      case 'health_weight':
      case 'weight':
        return 'Weight';
      
      // Poop subcategories
      case 'litter':
        return 'Litter';
      case 'poop_feces':
        return 'Feces';
      case 'poop_urine':
        return 'Urine';
      
      // Activity subcategories
      case 'activity':
        return 'Activity';
      case 'other':
        return 'Other';
      
      default:
        return recordType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.petName} - 레코드 차트 보기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pets/${widget.petId}/records'),
        ),
      ),
      body: Column(
        children: [
          // 필터 섹션
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                // 레코드 타입 선택
                Row(
                  children: [
                    const Text('레코드 타입: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedRecordType,
                        hint: const Text('레코드 타입을 선택하세요'),
                        isExpanded: true,
                        items: _getRecordTypeOptions().map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getRecordTypeDisplayName(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRecordType = value;
                          });
                          _loadChartData();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 뷰 모드 (일/주/월)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('일간'),
                        selected: _viewMode == 'day',
                        onSelected: (v) {
                          if (!v) return;
                          setState(() {
                            _viewMode = 'day';
                            _applyAggregation();
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('주간'),
                        selected: _viewMode == 'week',
                        onSelected: (v) {
                          if (!v) return;
                          setState(() {
                            _viewMode = 'week';
                            _applyAggregation();
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('월간'),
                        selected: _viewMode == 'month',
                        onSelected: (v) {
                          if (!v) return;
                          setState(() {
                            _viewMode = 'month';
                            _applyAggregation();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 날짜 범위 선택
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(true),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text('시작: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(false),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text('종료: ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 차트 영역
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _chartData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '선택한 기간에 데이터가 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildChart(),
          ),
        ],
      ),
    );
  }

  List<String> _getRecordTypeOptions() {
    // Records 화면 플로팅 버튼 순서와 일치: food, activity, poop, health
    return ['food', 'activity', 'poop', 'health'];
  }

  String _getRecordTypeDisplayName(String type) {
    switch (type) {
      case 'food':
        return 'Food';
      case 'health':
        return 'Health';
      case 'poop':
        return 'Poop';
      case 'activity':
        return 'Activity';
      default:
        return type;
    }
  }

  bool _isRecordTypeMatch(String recordType, String category) {
    switch (category) {
      case 'food':
        return recordType.startsWith('food_') || recordType == 'food';
      case 'health':
        return recordType.startsWith('health_') || 
               recordType == 'health' ||
               recordType == 'med' || 
               recordType == 'vaccine' || 
               recordType == 'visit' || 
               recordType == 'weight';
      case 'poop':
        return recordType == 'litter' || recordType == 'poop_feces' || recordType.startsWith('poop');
      case 'activity':
        return recordType.startsWith('activity_') || 
               recordType == 'activity' || 
               recordType == 'other';
      default:
        return false;
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadChartData();
    }
  }

  Widget _buildChart() {
    if (_chartData.isEmpty) return const SizedBox.shrink();
    
    final spots = _chartData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return FlSpot(index.toDouble(), data['count'].toDouble());
    }).toList();
    
    // Y축 범위 자동 계산
    final values = _chartData.map((data) => data['count'] as int).toList();
    final maxValue = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 10;
    final minValue = 0;
    final range = maxValue - minValue;
    final padding = range * 0.1; // 10% 패딩 추가
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pie Chart Section (moved to top)
          if (_pieChartData.isNotEmpty) ...[
            Text(
              '$_selectedRecordType 소분류별 비율',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                SizedBox(
                  height: 250,
                  child: Center(
                    child: PieChart(
                      PieChartData(
                        sections: _pieChartData,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: _allSubcategoryData.entries.map((entry) {
                    final subcategory = entry.key;
                    final count = entry.value;
                    final totalCount = _allSubcategoryData.values.fold(0, (sum, c) => sum + c);
                    final percentage = totalCount > 0 ? '${((count / totalCount) * 100).toStringAsFixed(1)}%' : '0.0%';
                    
                    // 색상 결정 (실제 데이터가 있는 항목과 동일한 색상 사용)
                    Color color = Colors.grey.shade300; // 기본 회색
                    if (count > 0) {
                      // 실제 데이터가 있는 항목의 색상 찾기
                      final pieChartEntry = _pieChartData.firstWhere(
                        (section) => section.title.split('\n').last == subcategory,
                        orElse: () => PieChartSectionData(
                          color: Colors.grey.shade300,
                          value: 0,
                          title: '',
                        ),
                      );
                      color = pieChartEntry.color;
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$subcategory ($percentage)',
                            style: TextStyle(
                              fontSize: 12,
                              color: count > 0 ? Colors.black : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
          // Line Chart Section (moved to bottom)
          Text(
            '$_selectedRecordType 레코드 수',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '총 ${values.fold(0, (a, b) => a + b)}개 기록',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400, // 고정 높이 설정
            child: LineChart(
              LineChartData(
                minY: minValue - padding,
                maxY: maxValue + padding,
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < _chartData.length) {
                          final label = _chartData[value.toInt()]['label'] as String?;
                          if (label != null) {
                            // For day mode, label is yyyy-MM-dd
                            if (_viewMode == 'day') {
                              final date = DateTime.parse(label);
                              return Text(
                                DateFormat('MM/dd').format(date),
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                            // For week/month, label is already human-readable
                            return Text(
                              label,
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 2,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: false,
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final dataIndex = spot.x.toInt();
                        if (dataIndex < _chartData.length) {
                          final data = _chartData[dataIndex];
                          final label = data['label'] as String? ?? data['date'] as String;
                          String labelText;
                          if (_viewMode == 'day') {
                            final date = DateTime.parse(label);
                            labelText = DateFormat('yyyy-MM-dd').format(date);
                          } else {
                            labelText = label; // already formatted for week/month
                          }
                          return LineTooltipItem(
                            '$labelText\n${data['count']}개',
                            TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
