
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petcare/data/models/record.dart';
import 'package:petcare/core/providers/records_provider.dart';
import 'package:petcare/ui/theme/app_colors.dart';

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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.petName} - 레코드 차트 보기'),


        backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.95),
        elevation: 2,
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
      Flexible(
        fit: FlexFit.loose,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
        return '식사';
      case 'health':
        return '건강';
      case 'poop':
        return '배변';
      case 'activity':
        return '활동';
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
    if (_chartData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '선택한 기간에 데이터가 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    final spots = _chartData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return FlSpot(index.toDouble(), (data['count'] as int).toDouble());
    }).toList();
    
    // Y축 범위 자동 계산 (몸무게 차트와 동일한 방식)
    final values = _chartData.map((data) => data['count'] as int).toList();
    final maxValue = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 10;
    final minValue = 0;
    final range = maxValue - minValue;
    
    // 적응형 Y축 설정
    double minY, maxY;
    if (range <= 5) {
      // 작은 범위: 1 단위로 설정
      minY = 0;
      maxY = maxValue + 1;
    } else if (range <= 20) {
      // 중간 범위: 2 단위로 설정
      minY = 0;
      maxY = ((maxValue + 1) / 2).ceil() * 2;
    } else {
      // 큰 범위: 5 단위로 설정
      minY = 0;
      maxY = ((maxValue + 1) / 5).ceil() * 5;
    }
    
    final categoryKey = _selectedRecordType ?? 'food';
    final primaryColor = AppColors.getRecordCategoryDarkColor(categoryKey);
    final softColor = AppColors.getRecordCategorySoftColor(categoryKey);
    final totalCount = values.fold<int>(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: softColor.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: softColor.withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, 14),
              spreadRadius: -18,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: softColor.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getRecordCategoryIcon(categoryKey),
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getRecordTypeDisplayName(_selectedRecordType!)} 레코드',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '총 $totalCount개 기록',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 260,
                child: LineChart(
                  _createLineChartData(
                    context: context,
                    spots: spots,
                    minY: minY,
                    maxY: maxY,
                    primaryColor: primaryColor,
                    softColor: softColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // X축 라벨 간격 계산 (텍스트 겹침 방지)
  double _calculateBottomInterval() {
    final dataLength = _chartData.length;
    if (dataLength <= 7) {
      return 1.0; // 7개 이하면 모든 라벨 표시
    } else if (dataLength <= 14) {
      return 2.0; // 14개 이하면 2개마다 표시
    } else if (dataLength <= 30) {
      return 3.0; // 30개 이하면 3개마다 표시
    } else {
      return (dataLength / 10).ceil().toDouble(); // 10개 정도만 표시
    }
  }

  LineChartData _createLineChartData({
    required BuildContext context,
    required List<FlSpot> spots,
    required double minY,
    required double maxY,
    required Color primaryColor,
    required Color softColor,
  }) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        );
    final double bottomInterval = _calculateBottomInterval();

    return LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        horizontalInterval: _computeHorizontalInterval(maxY),
        verticalInterval: bottomInterval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
          strokeWidth: 1.2,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.25),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, __) => Text(
              '${value.toInt()}',
              style: labelStyle,
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: bottomInterval,
            getTitlesWidget: (value, __) {
              final index = value.toInt();
              if (index >= 0 && index < _chartData.length) {
                final label = _chartData[index]['label'] as String?;
                if (label != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _formatBottomLabel(label),
                      style: labelStyle,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: softColor.withOpacity(0.4)),
          left: BorderSide(color: softColor.withOpacity(0.4)),
          right: const BorderSide(color: Colors.transparent),
          top: const BorderSide(color: Colors.transparent),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: primaryColor,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, __, ___, ____) {
              return FlDotCirclePainter(
                radius: 6,
                color: primaryColor,
                strokeWidth: 4,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.35),
                softColor.withOpacity(0.15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 16,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          tooltipBorder: BorderSide(color: primaryColor.withOpacity(0.2)),
          getTooltipColor: (_) => Colors.white,
          getTooltipItems: (touchedSpots) {
            final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ) ??
                TextStyle(
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                );
            return touchedSpots.map((spot) {
              final dataIndex = spot.x.toInt();
              if (dataIndex >= 0 && dataIndex < _chartData.length) {
                final data = _chartData[dataIndex];
                final label = data['label'] as String? ?? data['date'] as String;
                return LineTooltipItem(
                  '${_formatTooltipLabel(label)}\n${data['count']}개',
                  textStyle,
                );
              }
              return null;
            }).toList();
          },
        ),
      ),
    );
  }

  double _computeHorizontalInterval(double maxY) {
    if (maxY <= 5) return 1;
    if (maxY <= 10) return 2;
    if (maxY <= 20) return 5;
    return (maxY / 4).ceilToDouble();
  }

  String _formatBottomLabel(String label) {
    if (_viewMode == 'day') {
      final date = DateTime.parse(label);
      return DateFormat('MM/dd').format(date);
    }
    if (_viewMode == 'week') {
      return label;
    }
    final monthDate = DateTime.parse('$label-01');
    return DateFormat('MM월').format(monthDate);
  }

  String _formatTooltipLabel(String label) {
    if (_viewMode == 'day') {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(label));
    }
    if (_viewMode == 'week') {
      return label;
    }
    return DateFormat('yyyy년 MM월').format(DateTime.parse('$label-01'));
  }

  IconData _getRecordCategoryIcon(String category) {
    switch (category) {
      case 'food':
        return Icons.dinner_dining;
      case 'activity':
        return Icons.sports_esports_rounded;
      case 'poop':
        return Icons.pets;
      case 'health':
        return Icons.healing;
      default:
        return Icons.analytics;
    }
  }
}
