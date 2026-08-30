import '../../services/portfolio_analytics_service.dart';
import 'portfolio_health_service.dart';
import 'portfolio_simulator_service.dart';

class PortfolioRebalanceOptimizationResult {
  final PortfolioHealthResult currentHealth;

  final PortfolioSimulationResult? bestOverall;
  final PortfolioSimulationResult? bestReduction;
  final PortfolioSimulationResult? bestAddition;

  final int testedScenarios;

  final double minTargetWeightPercent;
  final double maxTargetWeightPercent;

  const PortfolioRebalanceOptimizationResult({
    required this.currentHealth,
    required this.bestOverall,
    required this.bestReduction,
    required this.bestAddition,
    required this.testedScenarios,
    required this.minTargetWeightPercent,
    required this.maxTargetWeightPercent,
  });

  bool get hasRecommendation => bestOverall != null;

  int get bestHealthScore =>
      bestOverall?.afterHealth.score ?? currentHealth.score;

  int get healthImprovement => bestHealthScore - currentHealth.score;
}

class PortfolioRebalanceOptimizerService {
  final PortfolioSimulatorService _simulatorService;
  final PortfolioHealthService _healthService;

  const PortfolioRebalanceOptimizerService({
    this._simulatorService = const PortfolioSimulatorService(),
    this._healthService = const PortfolioHealthService(),
  });

  PortfolioRebalanceOptimizationResult optimize({
    required PortfolioAnalyticsResult analytics,
    double minTargetWeightPercent = 20.0,
    double maxTargetWeightPercent = 70.0,
    double stepPercent = 1.0,
  }) {
    final currentHealth = _healthService.calculate(analytics);

    if (analytics.positions.isEmpty ||
        analytics.currentValue <= 0 ||
        stepPercent <= 0) {
      return PortfolioRebalanceOptimizationResult(
        currentHealth: currentHealth,
        bestOverall: null,
        bestReduction: null,
        bestAddition: null,
        testedScenarios: 0,
        minTargetWeightPercent: minTargetWeightPercent,
        maxTargetWeightPercent: maxTargetWeightPercent,
      );
    }

    final currentLargestWeight = analytics.largestPositionWeightPercent;

    final effectiveMin = minTargetWeightPercent.clamp(1.0, 98.0);

    final effectiveMax = _effectiveMaxTarget(
      currentLargestWeight: currentLargestWeight,
      requestedMax: maxTargetWeightPercent,
      minTarget: effectiveMin,
    );

    if (effectiveMax <= effectiveMin) {
      return PortfolioRebalanceOptimizationResult(
        currentHealth: currentHealth,
        bestOverall: null,
        bestReduction: null,
        bestAddition: null,
        testedScenarios: 0,
        minTargetWeightPercent: effectiveMin,
        maxTargetWeightPercent: effectiveMax,
      );
    }

    final candidates = <PortfolioSimulationResult>[];

    double target = effectiveMin;

    while (target <= effectiveMax + 0.000001) {
      final scenarios = _simulatorService.buildDefaultScenarios(
        analytics: analytics,
        targetWeightPercent: target,
      );

      candidates.addAll(scenarios);

      target += stepPercent;
    }

    if (candidates.isEmpty) {
      return PortfolioRebalanceOptimizationResult(
        currentHealth: currentHealth,
        bestOverall: null,
        bestReduction: null,
        bestAddition: null,
        testedScenarios: 0,
        minTargetWeightPercent: effectiveMin,
        maxTargetWeightPercent: effectiveMax,
      );
    }

    final reductionCandidates = candidates
        .where(
          (item) => item.type == PortfolioSimulationType.reduceLargestPosition,
        )
        .toList();

    final additionCandidates = candidates
        .where(
          (item) =>
              item.type == PortfolioSimulationType.addOutsideLargestPosition,
        )
        .toList();

    final bestReduction = _bestCandidate(reductionCandidates);

    final bestAddition = _bestCandidate(additionCandidates);

    final bestOverall = _bestCandidate(candidates);

    return PortfolioRebalanceOptimizationResult(
      currentHealth: currentHealth,
      bestOverall: bestOverall,
      bestReduction: bestReduction,
      bestAddition: bestAddition,
      testedScenarios: candidates.length,
      minTargetWeightPercent: effectiveMin,
      maxTargetWeightPercent: effectiveMax,
    );
  }

  double _effectiveMaxTarget({
    required double currentLargestWeight,
    required double requestedMax,
    required double minTarget,
  }) {
    final belowCurrent = currentLargestWeight - 1.0;

    final cappedRequested = requestedMax.clamp(minTarget, 98.0);

    if (belowCurrent < cappedRequested) {
      return belowCurrent.clamp(minTarget, 98.0);
    }

    return cappedRequested;
  }

  PortfolioSimulationResult? _bestCandidate(
    List<PortfolioSimulationResult> candidates,
  ) {
    if (candidates.isEmpty) {
      return null;
    }

    final sorted = List<PortfolioSimulationResult>.from(candidates);

    sorted.sort(_compareCandidates);

    return sorted.first;
  }

  int _compareCandidates(
    PortfolioSimulationResult a,
    PortfolioSimulationResult b,
  ) {
    final healthCompare = b.afterHealth.score.compareTo(a.afterHealth.score);

    if (healthCompare != 0) {
      return healthCompare;
    }

    final diversificationCompare = b.afterHealth.diversificationScore.compareTo(
      a.afterHealth.diversificationScore,
    );

    if (diversificationCompare != 0) {
      return diversificationCompare;
    }

    final concentrationCompare = b.afterHealth.concentrationScore.compareTo(
      a.afterHealth.concentrationScore,
    );

    if (concentrationCompare != 0) {
      return concentrationCompare;
    }

    final opportunityCompare = b.afterHealth.opportunityScore.compareTo(
      a.afterHealth.opportunityScore,
    );

    if (opportunityCompare != 0) {
      return opportunityCompare;
    }

    final resilienceCompare = b.afterHealth.riskScore.compareTo(
      a.afterHealth.riskScore,
    );

    if (resilienceCompare != 0) {
      return resilienceCompare;
    }

    // Если качество результата одинаковое,
    // предпочитаем сценарий с меньшим объёмом ребаланса.
    return a.requiredAmount.compareTo(b.requiredAmount);
  }
}
