import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class WeightChartScreen extends ConsumerStatefulWidget {
  const WeightChartScreen({
    super.key,
    required this.petId,
    required this.petName,
  });

  final String petId;
  final String petName;

  @override
  ConsumerState<WeightChartScreen> createState() => _WeightChartScreenState();
}

class _WeightChartScreenState extends ConsumerState<WeightChartScreen> {
  String _viewMode = 'day'; // 'day', 'week', 'month'
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _rawWeightData = []; // 원본 데이터
  List<Map<String, dynamic>> _displayWeightData = []; // 표시용 집계 데이터
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeightData();
  }

  Future<void> _loadWeightData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 체중 데이터를 Supabase에서 가져오기
      final response = await Supabase.instance.client
          .from('labs')
          .select('*')
          .eq('pet_id', widget.petId)
          .not('items->체중->value', 'is', null)
          .gte('date', _startDate.toIso8601String().split('T')[0])
          .lte('date', _endDate.toIso8601String().split('T')[0])
          .order('date', ascending: true);

      if (response != null) {
        final List<Map<String, dynamic>> weightRecords = [];
        
        for (final record in response) {
          final items = record['items'] as Map<String, dynamic>?;
          if (items != null && items['체중'] != null) {
            final weightItem = items['체중'] as Map<String, dynamic>;
            final weightValue = weightItem['value'] as String?;
            
            if (weightValue != null && weightValue.isNotEmpty) {
              final weight = double.tryParse(weightValue);
              if (weight != null) {
                weightRecords.add({
                  'date': DateTime.parse(record['date']),
                  'weight': weight,
                });
              }
            }
          }
        }
        
        setState(() {
          _rawWeightData = weightRecords;
          _isLoading = false;
        });
        
        _applyAggregation();
      }
    } catch (e) {
      print('체중 데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyAggregation() {
    if (_rawWeightData.isEmpty) return;

    // 날짜별로 그룹화하고 평균 체중 계산
    final Map<String, List<double>> groupedData = {};
    
    for (final record in _rawWeightData) {
      final date = record['date'] as DateTime;
      String key;
      
      switch (_viewMode) {
        case 'day':
          key = DateFormat('yyyy-MM-dd').format(date);
          break;
        case 'week':
          // 주의 시작일(월요일) 기준으로 그룹화
          final int weekday = date.weekday; // Mon=1..Sun=7
          final startOfWeek = DateTime(date.year, date.month, date.day)
              .subtract(Duration(days: weekday - 1));
          key = DateFormat('yyyy-MM-dd').format(startOfWeek);
          break;
        case 'month':
          key = DateFormat('yyyy-MM').format(date);
          break;
        default:
          key = DateFormat('yyyy-MM-dd').format(date);
      }
      
      if (!groupedData.containsKey(key)) {
        groupedData[key] = [];
      }
      groupedData[key]!.add(record['weight'] as double);
    }
    
    // 평균 체중 계산
    final List<Map<String, dynamic>> aggregatedData = [];
    groupedData.forEach((key, weights) {
      final averageWeight = weights.reduce((a, b) => a + b) / weights.length;
      aggregatedData.add({
        'date': key,
        'weight': averageWeight,
      });
    });
    
    // 날짜순 정렬
    aggregatedData.sort((a, b) => a['date'].compareTo(b['date']));
    
    setState(() {
      _displayWeightData = aggregatedData;
    });
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
      _loadWeightData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.petName} - 체중 변화'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 날짜 선택 및 뷰 모드 선택
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 뷰 모드 선택
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('일간'),
                            selected: _viewMode == 'day',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _viewMode = 'day';
                                });
                                _applyAggregation();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('주간'),
                            selected: _viewMode == 'week',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _viewMode = 'week';
                                });
                                _applyAggregation();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('월간'),
                            selected: _viewMode == 'month',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _viewMode = 'month';
                                });
                                _applyAggregation();
                              }
                            },
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                // 차트
                Expanded(
                  child: _buildChart(),
                ),
              ],
            ),
    );
  }

  Widget _buildChart() {
    if (_displayWeightData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monitor_weight, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '체중 데이터가 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Y축 범위 자동 계산
    final values = _displayWeightData.map((data) => data['weight'] as double).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    
    // 체중 범위에 따른 적응형 Y축 설정
    double minY, maxY;
    if (range < 1.0) {
      // 체중 변화가 1kg 미만일 때: 0.2kg 단위
      final minYBase = (minValue * 5).floor() / 5; // 0.2kg 단위로 내림
      final maxYBase = (maxValue * 5).ceil() / 5;   // 0.2kg 단위로 올림
      minY = minYBase - 0.2;
      maxY = maxYBase + 0.2;
    } else if (range < 3.0) {
      // 체중 변화가 1-3kg일 때: 0.5kg 단위
      final minYBase = (minValue * 2).floor() / 2; // 0.5kg 단위로 내림
      final maxYBase = (maxValue * 2).ceil() / 2;   // 0.5kg 단위로 올림
      minY = minYBase - 0.5;
      maxY = maxYBase + 0.5;
    } else {
      // 체중 변화가 3kg 이상일 때: 1kg 단위
      final minYBase = minValue.floor().toDouble(); // 1kg 단위로 내림
      final maxYBase = maxValue.ceil().toDouble();   // 1kg 단위로 올림
      minY = minYBase - 1.0;
      maxY = maxYBase + 1.0;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  // 체중 범위에 따른 소수점 자리수 결정
                  String formattedValue;
                  if (range < 1.0) {
                    formattedValue = '${value.toStringAsFixed(1)}kg'; // 0.2kg 단위: 소수점 1자리
                  } else if (range < 3.0) {
                    formattedValue = '${value.toStringAsFixed(1)}kg'; // 0.5kg 단위: 소수점 1자리
                  } else {
                    formattedValue = '${value.toStringAsFixed(0)}kg'; // 1kg 단위: 정수
                  }
                  return Text(
                    formattedValue,
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < _displayWeightData.length) {
                    final dateStr = _displayWeightData[value.toInt()]['date'] as String;
                    switch (_viewMode) {
                      case 'day':
                        return Text(
                          DateFormat('MM/dd').format(DateTime.parse(dateStr)),
                          style: const TextStyle(fontSize: 12),
                        );
                      case 'week':
                        return Text(
                          DateFormat('MM/dd').format(DateTime.parse(dateStr)),
                          style: const TextStyle(fontSize: 12),
                        );
                      case 'month':
                        return Text(
                          DateFormat('MM월').format(DateTime.parse('${dateStr}-01')),
                          style: const TextStyle(fontSize: 12),
                        );
                    }
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: _displayWeightData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value['weight'] as double);
              }).toList(),
              isCurved: false,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 2,
                    strokeColor: Theme.of(context).colorScheme.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  final dataIndex = touchedSpot.x.toInt();
                  if (dataIndex >= 0 && dataIndex < _displayWeightData.length) {
                    final dateStr = _displayWeightData[dataIndex]['date'] as String;
                    final weight = _displayWeightData[dataIndex]['weight'] as double;
                    
                    String displayDate;
                    switch (_viewMode) {
                      case 'day':
                        displayDate = DateFormat('MM/dd').format(DateTime.parse(dateStr));
                        break;
                      case 'week':
                        displayDate = '${DateFormat('MM/dd').format(DateTime.parse(dateStr))}주';
                        break;
                      case 'month':
                        displayDate = DateFormat('yyyy년 MM월').format(DateTime.parse('${dateStr}-01'));
                        break;
                      default:
                        displayDate = dateStr;
                    }
                    
                    return LineTooltipItem(
                      '$displayDate\n${weight.toStringAsFixed(1)}kg',
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
    );
  }
}
