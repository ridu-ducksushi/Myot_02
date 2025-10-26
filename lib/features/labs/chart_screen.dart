import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petcare/core/providers/pets_provider.dart';

class ChartScreen extends ConsumerStatefulWidget {
  const ChartScreen({
    super.key,
    required this.petId,
    required this.petName,
  });

  final String petId;
  final String petName;

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> {
  String? _selectedTestItem;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  // Aggregated data used for the chart rendering
  List<Map<String, dynamic>> _chartData = [];
  // Raw per-day data fetched from Supabase; aggregation derives from this
  List<Map<String, dynamic>> _rawData = [];
  bool _isLoading = false;
  // View granularity: day | week | month
  String _viewMode = 'day';

  @override
  void initState() {
    super.initState();
    _loadTestItems();
  }

  Future<void> _loadTestItems() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final res = await Supabase.instance.client
          .from('labs')
          .select('items')
          .eq('user_id', uid)
          .eq('pet_id', widget.petId)
          .gte('date', _startDate.toIso8601String().split('T')[0])
          .lte('date', _endDate.toIso8601String().split('T')[0])
          .order('date', ascending: true);

      final Set<String> testItems = {};
      
      if (res is List && res.isNotEmpty) {
        for (final row in res) {
          final items = row['items'] as Map<String, dynamic>?;
          if (items != null) {
            for (final key in items.keys) {
              final item = items[key];
              if (item is Map && item['value'] != null && item['value'].toString().isNotEmpty) {
                final value = double.tryParse(item['value'].toString());
                if (value != null) {
                  testItems.add(key);
                }
              }
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          if (testItems.isNotEmpty) {
            // 체중, 병원명, 비용을 제외한 항목들 중에서 선택
            final validItems = testItems.where((item) => 
              !['체중', '병원명', '비용'].contains(item)).toList();
            if (validItems.isNotEmpty) {
              _selectedTestItem = validItems.first;
              _loadChartData();
            }
          }
        });
      }
    } catch (e) {
      print('❌ Load test items error: $e');
    }
  }

  Future<void> _loadChartData() async {
    if (_selectedTestItem == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final res = await Supabase.instance.client
          .from('labs')
          .select('date, items')
          .eq('user_id', uid)
          .eq('pet_id', widget.petId)
          .gte('date', _startDate.toIso8601String().split('T')[0])
          .lte('date', _endDate.toIso8601String().split('T')[0])
          .order('date', ascending: true);

      final List<Map<String, dynamic>> chartData = [];
      
      if (res is List) {
        for (final row in res) {
          final items = row['items'] as Map<String, dynamic>?;
          if (items != null && items.containsKey(_selectedTestItem)) {
            final item = items[_selectedTestItem!];
            if (item is Map && item['value'] != null) {
              final valueStr = item['value'].toString().trim();
              // 빈 값이나 "-"인 경우는 차트에 포함하지 않음
              if (valueStr.isNotEmpty && valueStr != '-') {
                final value = double.tryParse(valueStr);
                if (value != null) {
                  chartData.add({
                    'date': row['date'],
                    'value': value,
                    'unit': item['unit']?.toString() ?? '',
                    'reference': item['reference']?.toString() ?? '',
                    // label is filled later depending on view mode
                  });
                }
              }
            }
          }
        }
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
      // Keep as-is; ensure label exists
      _chartData = _rawData
          .map((e) => {
                ...e,
                'label': e['date'],
              })
          .toList();
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
        key = DateFormat('yyyy-MM-dd').format(monthStart); // yyyy-MM-dd 형식으로 변경
        label = DateFormat('yyyy-MM').format(monthStart); // 표시용은 yyyy-MM
      }

      final list = grouped.putIfAbsent(key, () => []);
      list.add({
        ...row,
        'group_key': key,
        'label': label,
      });
    }

    // Aggregate using average for numeric values
    final List<Map<String, dynamic>> aggregated = [];
    for (final entry in grouped.entries) {
      final rows = entry.value;
      if (rows.isEmpty) continue;
      final double avg = rows.map((r) => (r['value'] as double)).fold(0.0, (a, b) => a + b) / rows.length;
      final first = rows.first;
      aggregated.add({
        'date': entry.key, // key acts as representative date
        'label': first['label'] ?? entry.key,
        'value': avg,
        'unit': first['unit'] ?? '',
        'reference': first['reference'] ?? '',
      });
    }

    // Sort by date ascending based on key
    aggregated.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    _chartData = aggregated;
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(petByIdProvider(widget.petId));
    final petName = pet?.name ?? widget.petName;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('$petName - 검사 결과 차트'),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.95),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pets/${widget.petId}/health'),
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
                // 검사 항목 선택
                Row(
                  children: [
                    const Text('검사 항목: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedTestItem,
                        hint: const Text('검사 항목을 선택하세요'),
                        isExpanded: true,
                        items: _getTestItemOptions().map((item) {
                          return DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTestItem = value;
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
                              Flexible(
                                child: Text(
                                  '시작: ${DateFormat('yyyy-MM-dd').format(_startDate)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
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
                              Flexible(
                                child: Text(
                                  '종료: ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
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

  double _getBottomTitleInterval() {
    final dataCount = _chartData.length;
    
    if (dataCount <= 1) return 1.0;
    
    switch (_viewMode) {
      case 'day':
        // 일간 모드: 데이터가 많으면 간격을 늘림
        if (dataCount <= 7) return 1.0;
        if (dataCount <= 14) return 2.0;
        if (dataCount <= 30) return 3.0;
        return (dataCount / 10).ceil().toDouble();
      case 'week':
        // 주간 모드: 모든 주를 표시하되, 너무 많으면 간격 조정
        if (dataCount <= 8) return 1.0;
        if (dataCount <= 16) return 2.0;
        return (dataCount / 8).ceil().toDouble();
      case 'month':
        // 월간 모드: 모든 월을 표시
        return 1.0;
      default:
        return 1.0;
    }
  }

  double _getLeftTitleInterval(double minValue, double maxValue) {
    final range = maxValue - minValue;
    
    // Y축 범위에 따라 적절한 간격 계산
    if (range <= 1) return 0.2;
    if (range <= 5) return 1.0;
    if (range <= 10) return 2.0;
    if (range <= 50) return 10.0;
    if (range <= 100) return 20.0;
    if (range <= 500) return 100.0;
    if (range <= 1000) return 200.0;
    if (range <= 5000) return 1000.0;
    if (range <= 10000) return 2000.0;
    return (range / 5).ceil().toDouble();
  }

  String _formatYAxisValue(double value) {
    // 음수 처리
    if (value < 0) {
      return '-${_formatPositiveValue(-value)}';
    }
    return _formatPositiveValue(value);
  }

  String _formatPositiveValue(double value) {
    if (value >= 1000000) {
      // 백만 이상
      final millions = (value / 1000000);
      if (millions == millions.roundToDouble()) {
        return '${millions.round()}M';
      }
      return '${millions.toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      // 천 이상
      final thousands = (value / 1000);
      if (thousands == thousands.roundToDouble()) {
        return '${thousands.round()}K';
      }
      return '${thousands.toStringAsFixed(1)}K';
    } else {
      // 천 미만
      if (value == value.roundToDouble()) {
        return value.round().toString();
      }
      return value.toStringAsFixed(1);
    }
  }

  List<String> _getTestItemOptions() {
    // pet_health_screen.dart의 baseKeys와 동일한 항목들 (ABC 순)
    return [
      'ALB', 'ALB/GLB', 'ALP', 'ALT GPT', 'AST GOT', 'BUN', 'BUN/CRE', 'Ca', 'CK', 
      'Cl', 'CREA', 'GGT', 'GLU', 'GLOB', 'K', 'LIPA', 'Na', 'Na/K', 'NH3', 
      'PHOS', 'T-CHOL', 'TBIL', 'TG', 'TPRO', 'vAMY-P', 'SDMA', 'HCT', 'HGB', 'MCH', 
      'MCHC', 'MCV', 'MPV', 'PLT', 'RBC', 'RDW-CV', 'WBC', 'WBC-GRAN(#)', 
      'WBC-GRAN(%)', 'WBC-LYM(#)', 'WBC-LYM(%)', 'WBC-MONO(#)', 'WBC-MONO(%)', 
      'WBC-EOS(#)', 'WBC-EOS(%)'
    ];
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
      return FlSpot(index.toDouble(), data['value']);
    }).toList();
    
    final unit = _chartData.isNotEmpty ? _chartData.first['unit'] : '';
    final reference = _chartData.isNotEmpty ? _chartData.first['reference'] : '';
    
    // Y축 범위 자동 계산
    final values = _chartData.map((data) => data['value'] as double).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final padding = range * 0.1; // 10% 패딩 추가
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_selectedTestItem ${unit.isNotEmpty ? '($unit)' : ''}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'labs.reference_range'.tr() + ': $reference',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minValue - padding,
                maxY: maxValue + padding,
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      interval: _getLeftTitleInterval(minValue, maxValue),
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            _formatYAxisValue(value),
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
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
                      reservedSize: 40,
                      interval: _getBottomTitleInterval(),
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < _chartData.length) {
                          final label = _chartData[value.toInt()]['label'] as String?;
                          if (label != null) {
                            String displayText;
                            // For day mode, label is yyyy-MM-dd
                            if (_viewMode == 'day') {
                              final date = DateTime.parse(label);
                              displayText = DateFormat('MM/dd').format(date);
                            } else {
                              // For week/month, label is already human-readable
                              displayText = label;
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                displayText,
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
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
                            '$labelText\n${(data['value'] as double).toStringAsFixed(2)}${data['unit']}',
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
    );
  }
}
