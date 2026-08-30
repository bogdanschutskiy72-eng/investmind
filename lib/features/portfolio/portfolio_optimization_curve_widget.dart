import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'portfolio_optimization_curve_service.dart';

class PortfolioOptimizationCurveWidget extends StatelessWidget {
  final PortfolioOptimizationCurveResult curve;
  final double currentWeightPercent;
  final int currentHealthScore;

  const PortfolioOptimizationCurveWidget({
    super.key,
    required this.curve,
    required this.currentWeightPercent,
    required this.currentHealthScore,
  });

  @override
  Widget build(BuildContext context) {
    if (curve.isEmpty) {
      return const SizedBox.shrink();
    }

    final points = curve.points
        .where((point) => point.bestHealthScore != null)
        .toList(growable: false);

    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final allHealthScores = <double>[
      ...points.map((point) => point.bestHealthScore!.toDouble()),
      currentHealthScore.toDouble(),
    ];

    final minHealth = allHealthScores.reduce((a, b) => a < b ? a : b);
    final maxHealth = allHealthScores.reduce((a, b) => a > b ? a : b);

    final minY = (minHealth - 5).clamp(0, 100).toDouble();
    final maxY = (maxHealth + 5).clamp(0, 100).toDouble();

    final minX = 0.0;

    final maxX = 100.0;

    final curveSpots = points
        .map(
          (point) => FlSpot(
            point.targetWeightPercent,
            point.bestHealthScore!.toDouble(),
          ),
        )
        .toList(growable: false);

    final optimalTarget = curve.optimalTargetWeightPercent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Почему это оптимум',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'График показывает, как меняется Portfolio Health при изменении доли крупнейшей позиции.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 210,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY == minY ? minY + 10 : maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Color(0x22334155),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
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
                      reservedSize: 34,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.round().toString(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 10,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${value.round()}%',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
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
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final isCurrent = spot.barIndex == 1;

                        return LineTooltipItem(
                          isCurrent
                              ? 'Сейчас ${spot.x.toStringAsFixed(1)}%\nHealth ${spot.y.toInt()}'
                              : 'Цель ${spot.x.toStringAsFixed(0)}%\nHealth ${spot.y.toInt()}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: curveSpots,
                    isCurved: true,
                    barWidth: 3,
                    color: const Color(0xFF20D3C2),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isOptimal =
                            optimalTarget != null &&
                            (spot.x - optimalTarget).abs() < 0.01;

                        return FlDotCirclePainter(
                          radius: isOptimal ? 6 : 3,
                          color: isOptimal
                              ? const Color(0xFF20D3C2)
                              : const Color(0xFF94A3B8),
                          strokeWidth: isOptimal ? 2 : 0,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: [
                      FlSpot(
                        currentWeightPercent,
                        currentHealthScore.toDouble(),
                      ),
                    ],
                    isCurved: false,
                    barWidth: 0,
                    color: Colors.transparent,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 6,
                          color: const Color(0xFFFFB74D),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              const _LegendItem(color: Color(0xFF20D3C2), text: 'Симуляция'),
              const _LegendItem(
                color: Color(0xFFFFB74D),
                text: 'Текущий портфель',
              ),
              if (curve.optimalTargetWeightPercent != null &&
                  curve.optimalHealthScore != null)
                Text(
                  'Лучший результат: ${curve.optimalTargetWeightPercent!.toStringAsFixed(0)}% → Health ${curve.optimalHealthScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
      ],
    );
  }
}
