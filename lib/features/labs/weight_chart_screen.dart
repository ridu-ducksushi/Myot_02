import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:petcare/ui/theme/app_colors.dart';

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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      return _buildEmptyChartState();
    }

    final metrics = _computeChartMetrics();
    final bottomInterval = _calculateBottomInterval();
    final colorScheme = Theme.of(context).colorScheme;
    const categoryKey = 'health';
    final primaryColor = AppColors.getRecordTypeColor('health_weight');
    final softColor = AppColors.getRecordCategorySoftColor(categoryKey);
    final darkColor = AppColors.getRecordCategoryDarkColor(categoryKey);
    final outlineColor = colorScheme.outlineVariant.withOpacity(0.35);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: softColor.withOpacity(0.4)),
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
              _buildChartHeader(
                primaryColor: primaryColor,
                softColor: softColor,
                darkColor: darkColor,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 260,
                child: LineChart(
                  _createChartData(
                    context: context,
                    metrics: metrics,
                    bottomInterval: bottomInterval,
                    primaryColor: primaryColor,
                    softColor: softColor,
                    outlineColor: outlineColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChartState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.65),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.monitor_weight_rounded,
                  color: colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '체중 데이터가 없습니다',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '체중을 기록하면 귀여운 그래프가 표시됩니다.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartHeader({
    required Color primaryColor,
    required Color softColor,
    required Color darkColor,
  }) {
    final theme = Theme.of(context);
    final summaryText = _buildLatestSummaryText();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: softColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.monitor_weight_rounded,
            color: darkColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '체중 변화',
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                summaryText,
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _buildLatestSummaryText() {
    if (_displayWeightData.isEmpty) {
      return '최근 기록 없음';
    }

    final latest = _displayWeightData.last;
    final dateKey = latest['date'] as String;
    final weight = latest['weight'] as double;
    final dateLabel = _formatDateForMode(dateKey, includeYear: false, includeSuffix: true);
    return '최근 $dateLabel · ${weight.toStringAsFixed(1)}kg';
  }

  LineChartData _createChartData({
    required BuildContext context,
    required _WeightChartMetrics metrics,
    required double bottomInterval,
    required Color primaryColor,
    required Color softColor,
    required Color outlineColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return LineChartData(
      minY: metrics.minY,
      maxY: metrics.maxY,
      minX: 0,
      maxX: metrics.spots.isEmpty ? 0 : metrics.spots.length - 1,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        horizontalInterval: metrics.leftInterval,
        verticalInterval: bottomInterval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: outlineColor,
          strokeWidth: 1.1,
          dashArray: const [4, 4],
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: outlineColor.withOpacity(0.6),
          strokeWidth: 1,
          dashArray: const [4, 4],
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 56,
            interval: metrics.leftInterval,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              axisSide: meta.axisSide,
              space: 8,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatLeftLabel(value, metrics.range),
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                ),
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: bottomInterval,
            getTitlesWidget: (value, meta) => _buildBottomTitle(
              context,
              value: value,
              interval: bottomInterval,
            ),
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: outlineColor),
          left: BorderSide(color: outlineColor),
          right: const BorderSide(color: Colors.transparent),
          top: const BorderSide(color: Colors.transparent),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: metrics.spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: primaryColor,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 6,
              color: primaryColor,
              strokeWidth: 4,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.32),
                softColor.withOpacity(0.18),
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
          tooltipRoundedRadius: 12,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tooltipBorder: BorderSide(color: outlineColor.withOpacity(0.6)),
          getTooltipColor: (_) => Colors.white,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.round();
              if (index < 0 || index >= _displayWeightData.length) {
                return null;
              }
              final data = _displayWeightData[index];
              final dateLabel = _formatDateForMode(
                data['date'] as String,
                includeYear: true,
                includeSuffix: true,
              );
              final weight = (data['weight'] as double).toStringAsFixed(1);
              final textStyle = theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ) ??
                  TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  );
              return LineTooltipItem(
                '$dateLabel\n$weight kg',
                textStyle,
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildBottomTitle(
    BuildContext context, {
    required double value,
    required double interval,
  }) {
    final index = value.round();
    if (index < 0 || index >= _displayWeightData.length) {
      return const SizedBox.shrink();
    }
    if (index % interval.round() != 0) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final label = _formatDateForMode(
      _displayWeightData[index]['date'] as String,
      includeYear: false,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
        textAlign: TextAlign.center,
      ),
    );
  }

  _WeightChartMetrics _computeChartMetrics() {
    final values = _displayWeightData.map((data) => data['weight'] as double).toList();
    double minValue = values.reduce((a, b) => a < b ? a : b);
    double maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs();

    double interval;
    if (range < 1.0) {
      interval = 0.2;
    } else if (range < 3.0) {
      interval = 0.5;
    } else {
      interval = 1.0;
    }

    double minY = (minValue / interval).floor() * interval;
    double maxY = (maxValue / interval).ceil() * interval;

    if (minY == maxY) {
      minY -= interval;
      maxY += interval;
    } else {
      minY -= interval;
      maxY += interval;
    }

    final spots = _displayWeightData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final weight = entry.value['weight'] as double;
      return FlSpot(index, weight);
    }).toList();

    return _WeightChartMetrics(
      spots: spots,
      minY: minY,
      maxY: maxY,
      leftInterval: interval,
      range: range,
    );
  }

  double _calculateBottomInterval() {
    final length = _displayWeightData.length;
    if (length <= 6) {
      return 1;
    }
    if (length <= 12) {
      return 2;
    }
    return (length / 6).ceilToDouble();
  }

  String _formatLeftLabel(double value, double range) {
    final precision = range < 3.0 ? 1 : 0;
    return '${value.toStringAsFixed(precision)} kg';
  }

  String _formatDateForMode(
    String rawDate, {
    bool includeYear = false,
    bool includeSuffix = false,
  }) {
    DateTime date;
    if (_viewMode == 'month') {
      date = DateTime.parse('$rawDate-01');
    } else {
      date = DateTime.parse(rawDate);
    }

    if (_viewMode == 'month') {
      final pattern = includeYear ? 'yyyy.MM' : 'MM월';
      return DateFormat(pattern).format(date);
    }

    final pattern = includeYear ? 'yyyy.MM.dd' : 'MM/dd';
    final formatted = DateFormat(pattern).format(date);

    if (_viewMode == 'week' && includeSuffix) {
      return '$formatted 주';
    }

    return formatted;
  }
}

class _WeightChartMetrics {
  const _WeightChartMetrics({
    required this.spots,
    required this.minY,
    required this.maxY,
    required this.leftInterval,
    required this.range,
  });

  final List<FlSpot> spots;
  final double minY;
  final double maxY;
  final double leftInterval;
  final double range;
}
