import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/historical_price_service.dart';

class HistoricalPriceChart extends StatelessWidget {
  final List<HistoricalPricePoint> prices;

  const HistoricalPriceChart({
    super.key,
    required this.prices,
  });

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month';
  }

  @override
  Widget build(BuildContext context) {
    if (prices.length < 2) {
      return const SizedBox.shrink();
    }

    final List<FlSpot> spots = [];

    double minPrice = prices.first.close;
    double maxPrice = prices.first.close;

    for (int i = 0; i < prices.length; i++) {
      final double price = prices[i].close;

      spots.add(
        FlSpot(
          i.toDouble(),
          price,
        ),
      );

      if (price < minPrice) {
        minPrice = price;
      }

      if (price > maxPrice) {
        maxPrice = price;
      }
    }

    double minY = minPrice * 0.98;
    double maxY = maxPrice * 1.02;

    if (minY == maxY) {
      minY = minPrice - 1.0;
      maxY = maxPrice + 1.0;
    }

    final int middleIndex = prices.length ~/ 2;
    final int lastIndex = prices.length - 1;

    return Container(
      width: double.infinity,
      height: 340,
      padding: const EdgeInsets.fromLTRB(
        16,
        24,
        20,
        12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: lastIndex.toDouble(),
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval:
                (maxY - minY) / 4.0,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white10,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: false,
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 58,
                getTitlesWidget: (
                  double value,
                  TitleMeta meta,
                ) {
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      '\$${value.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white54,
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
                reservedSize: 32,
                getTitlesWidget: (
                  double value,
                  TitleMeta meta,
                ) {
                  final int index = value.round();

                  String text = '';

                  if (index == 0) {
                    text = _formatDate(
                      prices.first.date,
                    );
                  } else if (index == middleIndex) {
                    text = _formatDate(
                      prices[middleIndex].date,
                    );
                  } else if (index == lastIndex) {
                    text = _formatDate(
                      prices.last.date,
                    );
                  }

                  if (text.isEmpty) {return const SizedBox.shrink();
                  }

                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white54,
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
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (
                List<LineBarSpot> touchedSpots,
              ) {
                return touchedSpots.map(
                  (spot) {
                    final int index =
                        spot.x.round();

                    if (index < 0 ||
                        index >= prices.length) {
                      return null;
                    }

                    final point = prices[index];

                    return LineTooltipItem(
                      '${_formatDate(point.date)}\n'
                      '\$${point.close.toStringAsFixed(2)}',
                      const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              barWidth: 3,
              color: const Color(0xFF20D3C2),
              dotData: const FlDotData(
                show: false,
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(
                  0xFF20D3C2,
                ).withValues(
                  alpha: 0.10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}