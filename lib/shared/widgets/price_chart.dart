import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/chart_service.dart';

class PriceChart extends StatefulWidget {
  final String symbol;

  const PriceChart({
    super.key,
    required this.symbol,
  });

  @override
  State<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends State<PriceChart> {
  final ChartService _chartService = ChartService();

  ChartPeriod _selectedPeriod = ChartPeriod.oneDay;
  late Future<List<ChartPoint>> _chartFuture;

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  @override
  void didUpdateWidget(covariant PriceChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.symbol != widget.symbol) {
      _loadChart();
    }
  }

  void _loadChart() {
    _chartFuture = _chartService.fetchChart(
      symbol: widget.symbol,
      period: _selectedPeriod,
    );
  }

  void _changePeriod(ChartPeriod period) {
    if (_selectedPeriod == period) return;

    setState(() {
      _selectedPeriod = period;
      _loadChart();
    });
  }

  void _refreshChart() {
    setState(() {
      _loadChart();
    });
  }

  List<ChartPoint> _trimPoints(List<ChartPoint> points) {
    int maximumPoints;

    switch (_selectedPeriod) {
      case ChartPeriod.oneDay:
        maximumPoints = 78;
        break;
      case ChartPeriod.oneWeek:
        maximumPoints = 65;
        break;
      case ChartPeriod.oneMonth:
        maximumPoints = 22;
        break;
      case ChartPeriod.threeMonths:
        maximumPoints = 66;
        break;
      case ChartPeriod.oneYear:
        maximumPoints = 252;
        break;
    }

    if (points.length <= maximumPoints) {
      return points;
    }

    return points.sublist(points.length - maximumPoints);
  }

  String _periodLabel(ChartPeriod period) {
    switch (period) {
      case ChartPeriod.oneDay:
        return '1Д';
      case ChartPeriod.oneWeek:
        return '1Н';
      case ChartPeriod.oneMonth:
        return '1М';
      case ChartPeriod.threeMonths:
        return '3М';
      case ChartPeriod.oneYear:
        return '1Г';
    }
  }

  String _formatAxisDate(DateTime dateTime) {
    switch (_selectedPeriod) {
      case ChartPeriod.oneDay:
      case ChartPeriod.oneWeek:
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');

        return '$hour:$minute';

      case ChartPeriod.oneMonth:
      case ChartPeriod.threeMonths:
        final day = dateTime.day.toString().padLeft(2, '0');
        final month = dateTime.month.toString().padLeft(2, '0');

        return '$day.$month';

      case ChartPeriod.oneYear:
        final month = dateTime.month.toString().padLeft(2, '0');

        return '$month.${dateTime.year.toString().substring(2)}';
    }
  }

  String _formatTooltipDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    switch (_selectedPeriod) {
      case ChartPeriod.oneDay:
      case ChartPeriod.oneWeek:
        return '$day.$month  $hour:$minute';

      case ChartPeriod.oneMonth:
      case ChartPeriod.threeMonths:
      case ChartPeriod.oneYear:
        return '$day.$month.${dateTime.year}';
    }
  }

  Widget _buildPeriodButton(ChartPeriod period) {
    final isSelected = _selectedPeriod == period;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: () => _changePeriod(period),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF20D3C2): const Color(0xFF111827),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              _periodLabel(period),
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF111827)
                    : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart(List<ChartPoint> originalPoints) {
    final points = _trimPoints(originalPoints);

    if (points.length < 2) {
      return const Center(
        child: Text(
          'Недостаточно данных для графика.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final spots = List<FlSpot>.generate(
      points.length,
      (index) => FlSpot(
        index.toDouble(),
        points[index].close,
      ),
    );

    final prices = points.map((point) => point.close).toList();

    double minimumPrice = prices.reduce(
      (first, second) => first < second ? first : second,
    );

    double maximumPrice = prices.reduce(
      (first, second) => first > second ? first : second,
    );

    double difference = maximumPrice - minimumPrice;

    if (difference == 0) {
      difference = maximumPrice * 0.01;

      if (difference == 0) {
        difference = 1;
      }
    }

    final padding = difference * 0.15;

    minimumPrice -= padding;
    maximumPrice += padding;

    final firstPrice = points.first.close;
    final lastPrice = points.last.close;
    final isPositive = lastPrice >= firstPrice;

    final chartColor = isPositive
        ? const Color(0xFF20D3C2)
        : Colors.redAccent;

    final changePercent = firstPrice == 0
        ? 0.0
        : ((lastPrice - firstPrice) / firstPrice) * 100;

    final lastIndex = points.length - 1;
    final middleIndex = lastIndex ~/ 2;
    final horizontalInterval =
        (maximumPrice - minimumPrice) / 3;

    return Column(
      children: [
        Row(
          children: [
            Text(
              '\$${lastPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${changePercent >= 0 ? '+' : ''}'
              '${changePercent.toStringAsFixed(2)}%',
              style: TextStyle(
                color: chartColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: lastIndex.toDouble(),
              minY: minimumPrice,
              maxY: maximumPrice,
              clipData: const FlClipData.all(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: horizontalInterval,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.white.withValues(alpha: 0.07),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    interval: horizontalInterval,
                    getTitlesWidget: (value, meta) {
                      return SideTitleWidget(
                        meta: meta,space: 8,
                        child: Text(
                          '\$${value.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();

                      final shouldShow =
                          index == 0 ||
                          index == middleIndex ||
                          index == lastIndex;

                      if (!shouldShow ||
                          index < 0 ||
                          index >= points.length) {
                        return const SizedBox.shrink();
                      }

                      return SideTitleWidget(
                        meta: meta,
                        space: 8,
                        child: Text(
                          _formatAxisDate(
                            points[index].dateTime,
                          ),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) {
                    return const Color(0xFF0F172A);
                  },
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x
                          .round()
                          .clamp(0, points.length - 1)
                          .toInt();

                      final point = points[index];

                      return LineTooltipItem(
                        '${_formatTooltipDate(point.dateTime)}\n'
                        '\$${point.close.toStringAsFixed(2)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      );
                    }).toList();
                  },
                ),
                getTouchedSpotIndicator: (
                  barData,
                  spotIndexes,
                ) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: Colors.white38,
                        strokeWidth: 1,
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (
                          spot,
                          percent,
                          barData,
                          index,
                        ) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: chartColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,color: chartColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        chartColor.withValues(alpha: 0.30),
                        chartColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 350),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 390,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'История цены',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _refreshChart,
                tooltip: 'Обновить график',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ChartPeriod.values
                .map(_buildPeriodButton)
                .toList(),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: FutureBuilder<List<ChartPoint>>(
              future: _chartFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.show_chart,
                            color: Colors.redAccent,
                            size: 38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _refreshChart,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final points = snapshot.data ?? [];

                return _buildChart(points);
              },
            ),
          ),
        ],
      ),
    );
  }
}