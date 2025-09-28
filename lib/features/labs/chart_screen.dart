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
  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = false;

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
            _selectedTestItem = testItems.first;
            _loadChartData();
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
                  });
                }
              }
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _chartData = chartData;
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

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(petByIdProvider(widget.petId));
    final petName = pet?.name ?? widget.petName;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('$petName - 검사 결과 차트'),
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

  List<String> _getTestItemOptions() {
    final Set<String> items = {};
    
    // Supabase에서 모든 검사 항목들을 가져오기
    for (final data in _chartData) {
      // 현재 차트 데이터에서 항목 수집
    }
    
    // 기본 검사 항목들 (실제 데이터가 있을 수 있는 항목들)
    return [
      'RBC', 'WBC', 'Hb', 'HCT', 'PLT',
      'ALT', 'AST', 'ALP', 'BUN', 'Creatinine', 'Glucose',
      'Na', 'K', 'Cl', 'Ca', 'P',
      '체중', '병원명', '비용'
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
              '정상범위: $reference',
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
                          final date = DateTime.parse(_chartData[value.toInt()]['date']);
                          return Text(
                            DateFormat('MM/dd').format(date),
                            style: const TextStyle(fontSize: 10),
                          );
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
                          final date = DateTime.parse(data['date']);
                          return LineTooltipItem(
                            '${DateFormat('yyyy-MM-dd').format(date)}\n${data['value']}${data['unit']}',
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
