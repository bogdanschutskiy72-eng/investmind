import '../../services/portfolio_analytics_service.dart';
import 'portfolio_simulator_service.dart';

class PortfolioOptimizationPoint {
  final double targetWeightPercent;

  final int? reductionHealthScore;
  final int? additionHealthScore;

  final double? reductionRequiredAmount;
  final double? additionRequiredAmount;

  const PortfolioOptimizationPoint({
    required this.targetWeightPercent,
    required this.reductionHealthScore,
    required this.additionHealthScore,
    required this.reductionRequiredAmount,
    required this.additionRequiredAmount,
  });

  int? get bestHealthScore {
    final values = <int>[?reductionHealthScore, ?additionHealthScore];
    if (values.isEmpty) {
      return null;
    }

    values.sort();
    return values.last;
  }
}

class PortfolioOptimizationCurveResult {
  final List<PortfolioOptimizationPoint> points;

  final double? optimalTargetWeightPercent;
  final int? optimalHealthScore;

  const PortfolioOptimizationCurveResult({
    required this.points,
    required this.optimalTargetWeightPercent,
    required this.optimalHealthScore,
  });

  bool get isEmpty => points.isEmpty;
}

class PortfolioOptimizationCurveService {
  final PortfolioSimulatorService _simulatorService;

  const PortfolioOptimizationCurveService({
    this._simulatorService = const PortfolioSimulatorService(),
  });

  PortfolioOptimizationCurveResult build({
    required PortfolioAnalyticsResult analytics,
    double minTargetWeightPercent = 20.0,
    double maxTargetWeightPercent = 70.0,
    double stepPercent = 5.0,
  }) {
    if (analytics.positions.isEmpty ||
        analytics.currentValue <= 0 ||
        stepPercent <= 0) {
      return const PortfolioOptimizationCurveResult(
        points: [],
        optimalTargetWeightPercent: null,
        optimalHealthScore: null,
      );
    }

    final currentLargestWeight = analytics.largestPositionWeightPercent;

    final effectiveMax = currentLargestWeight - 1.0 < maxTargetWeightPercent
        ? currentLargestWeight - 1.0
        : maxTargetWeightPercent;

    if (effectiveMax <= minTargetWeightPercent) {
      return const PortfolioOptimizationCurveResult(
        points: [],
        optimalTargetWeightPercent: null,
        optimalHealthScore: null,
      );
    }

    final points = <PortfolioOptimizationPoint>[];

    double target = minTargetWeightPercent;

    double? optimalTarget;
    int? optimalHealth;

    while (target <= effectiveMax + 0.000001) {
      final scenarios = _simulatorService.buildDefaultScenarios(
        analytics: analytics,
        targetWeightPercent: target,
      );

      PortfolioSimulationResult? reduction;
      PortfolioSimulationResult? addition;

      for (final scenario in scenarios) {
        switch (scenario.type) {
          case PortfolioSimulationType.reduceLargestPosition:
            reduction = scenario;
            break;

          case PortfolioSimulationType.addOutsideLargestPosition:
            addition = scenario;
            break;

          case PortfolioSimulationType.rebalanceSelectedPosition:
            break;
        }
      }

      final point = PortfolioOptimizationPoint(
        targetWeightPercent: target,
        reductionHealthScore: reduction?.afterHealth.score,
        additionHealthScore: addition?.afterHealth.score,
        reductionRequiredAmount: reduction?.requiredAmount,
        additionRequiredAmount: addition?.requiredAmount,
      );

      points.add(point);

      final best = point.bestHealthScore;

      if (best != null) {
        if (optimalHealth == null || best > optimalHealth) {
          optimalHealth = best;
          optimalTarget = target;
        } else if (best == optimalHealth &&
            optimalTarget != null &&
            (target - currentLargestWeight).abs() <
                (optimalTarget - currentLargestWeight).abs()) {
          optimalTarget = target;
        }
      }

      target += stepPercent;
    }

    return PortfolioOptimizationCurveResult(
      points: points,
      optimalTargetWeightPercent: optimalTarget,
      optimalHealthScore: optimalHealth,
    );
  }
}
