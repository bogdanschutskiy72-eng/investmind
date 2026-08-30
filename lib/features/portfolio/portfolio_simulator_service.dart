import '../../services/portfolio_analytics_service.dart';
import 'portfolio_health_service.dart';

enum PortfolioSimulationType {
  reduceLargestPosition,
  addOutsideLargestPosition,
  rebalanceSelectedPosition,
}

class PortfolioSimulationResult {
  final PortfolioSimulationType type;
  final String title;
  final String description;
  final String symbol;

  final double requiredAmount;
  final double targetWeightPercent;
  final double beforeWeightPercent;
  final double afterWeightPercent;

  final PortfolioHealthResult beforeHealth;
  final PortfolioHealthResult afterHealth;

  final PortfolioAnalyticsResult simulatedAnalytics;

  const PortfolioSimulationResult({
    required this.type,
    required this.title,
    required this.description,
    required this.symbol,
    required this.requiredAmount,
    required this.targetWeightPercent,
    required this.beforeWeightPercent,
    required this.afterWeightPercent,
    required this.beforeHealth,
    required this.afterHealth,
    required this.simulatedAnalytics,
  });

  int get healthDelta => afterHealth.score - beforeHealth.score;

  int get diversificationDelta =>
      afterHealth.diversificationScore - beforeHealth.diversificationScore;

  int get concentrationDelta =>
      afterHealth.concentrationScore - beforeHealth.concentrationScore;

  int get opportunityDelta =>
      afterHealth.opportunityScore - beforeHealth.opportunityScore;

  int get riskDelta => afterHealth.riskScore - beforeHealth.riskScore;
}

class PortfolioPositionOptimizationResult {
  final String symbol;
  final double currentWeightPercent;
  final int currentHealthScore;
  final PortfolioSimulationResult? bestScenario;
  final int testedScenarios;

  const PortfolioPositionOptimizationResult({
    required this.symbol,
    required this.currentWeightPercent,
    required this.currentHealthScore,
    required this.bestScenario,
    required this.testedScenarios,
  });

  factory PortfolioPositionOptimizationResult.empty({
    required String symbol,
    required int currentHealthScore,
    double currentWeightPercent = 0.0,
  }) {
    return PortfolioPositionOptimizationResult(
      symbol: symbol,
      currentWeightPercent: currentWeightPercent,
      currentHealthScore: currentHealthScore,
      bestScenario: null,
      testedScenarios: 0,
    );
  }

  bool get hasImprovement => bestScenario != null;

  int get healthImprovement {
    final scenario = bestScenario;

    if (scenario == null) {
      return 0;
    }

    return scenario.afterHealth.score - currentHealthScore;
  }
}

class PortfolioScenarioRankingItem {
  final String symbol;
  final double currentWeightPercent;
  final PortfolioSimulationResult? bestScenario;
  final int currentHealthScore;
  final int testedScenarios;

  const PortfolioScenarioRankingItem({
    required this.symbol,
    required this.currentWeightPercent,
    required this.bestScenario,
    required this.currentHealthScore,
    required this.testedScenarios,
  });

  bool get hasImprovement => bestScenario != null;

  int get healthDelta {
    final scenario = bestScenario;

    if (scenario == null) {
      return 0;
    }

    return scenario.afterHealth.score - currentHealthScore;
  }

  double? get targetWeightPercent => bestScenario?.targetWeightPercent;

  double? get requiredAmount => bestScenario?.requiredAmount;
}

class PortfolioScenarioRankingResult {
  final List<PortfolioScenarioRankingItem> items;
  final int currentHealthScore;
  final int totalTestedScenarios;

  const PortfolioScenarioRankingResult({
    required this.items,
    required this.currentHealthScore,
    required this.totalTestedScenarios,
  });

  bool get hasImprovement => items.any((item) => item.hasImprovement);

  PortfolioScenarioRankingItem? get bestOverall {
    for (final item in items) {
      if (item.hasImprovement) {
        return item;
      }
    }

    return null;
  }
}

class PortfolioSimulatorService {
  final PortfolioHealthService _healthService;

  const PortfolioSimulatorService({
    this._healthService = const PortfolioHealthService(),
  });

  List<PortfolioSimulationResult> buildDefaultScenarios({
    required PortfolioAnalyticsResult analytics,
    double targetWeightPercent = 50.0,
  }) {
    if (analytics.positions.isEmpty) {
      return const [];
    }

    final symbol =
        analytics.largestPositionSymbol ??
        analytics.positions.first.position.symbol;

    return buildScenariosForPosition(
      analytics: analytics,
      symbol: symbol,
      targetWeightPercent: targetWeightPercent,
    );
  }

  List<PortfolioSimulationResult> buildScenariosForPosition({
    required PortfolioAnalyticsResult analytics,
    required String symbol,
    required double targetWeightPercent,
  }) {
    if (analytics.positions.isEmpty ||
        analytics.currentValue <= 0 ||
        targetWeightPercent <= 0 ||
        targetWeightPercent >= 100) {
      return const [];
    }

    final selected = _findPosition(analytics, symbol);

    if (selected == null) {
      return const [];
    }

    final currentWeight = selected.weightPercent;

    if (currentWeight <= targetWeightPercent) {
      return const [];
    }

    final results = <PortfolioSimulationResult>[];

    final reduceScenario = _simulateReduction(
      analytics: analytics,
      selected: selected,
      targetWeightPercent: targetWeightPercent,
    );

    if (reduceScenario != null) {
      results.add(reduceScenario);
    }

    final addScenario = _simulateAddingOutsideSelected(
      analytics: analytics,
      selected: selected,
      targetWeightPercent: targetWeightPercent,
    );

    if (addScenario != null) {
      results.add(addScenario);
    }

    final rebalanceScenario = _simulateRebalanceSelected(
      analytics: analytics,
      selected: selected,
      targetWeightPercent: targetWeightPercent,
    );

    if (rebalanceScenario != null) {
      results.add(rebalanceScenario);
    }

    return results;
  }

  PortfolioSimulationResult? _simulateReduction({
    required PortfolioAnalyticsResult analytics,
    required PortfolioAnalyticsPosition selected,
    required double targetWeightPercent,
  }) {
    final target = targetWeightPercent / 100.0;

    final selectedValue = selected.currentValue;
    final totalValue = analytics.currentValue;

    final numerator = selectedValue - target * totalValue;

    if (numerator <= 0 || target >= 1.0) {
      return null;
    }

    final reduceBy = numerator / (1.0 - target);

    if (reduceBy <= 0 || reduceBy >= selectedValue) {
      return null;
    }

    final simulatedPositions = <PortfolioAnalyticsPosition>[];

    for (final item in analytics.positions) {
      if (item.position.symbol == selected.position.symbol) {
        final newCurrentValue = item.currentValue - reduceBy;

        if (newCurrentValue <= 0) {
          continue;
        }

        simulatedPositions.add(
          _copyPositionWithCurrentValue(
            item,
            newCurrentValue: newCurrentValue,
            addedCapital: 0.0,
            removedCapital: reduceBy,
          ),
        );
      } else {
        simulatedPositions.add(item);
      }
    }

    final simulatedAnalytics = _rebuildAnalytics(
      original: analytics,
      positions: simulatedPositions,
    );

    final beforeHealth = _healthService.calculate(analytics);
    final afterHealth = _healthService.calculate(simulatedAnalytics);

    return PortfolioSimulationResult(
      type: PortfolioSimulationType.reduceLargestPosition,
      title: 'Уменьшить ${selected.position.symbol}',
      description:
          'Виртуально уменьшаем ${selected.position.symbol} до '
          '${targetWeightPercent.toStringAsFixed(0)}% портфеля.',
      symbol: selected.position.symbol,
      requiredAmount: reduceBy,
      targetWeightPercent: targetWeightPercent,
      beforeWeightPercent: selected.weightPercent,
      afterWeightPercent: _weightForSymbol(
        simulatedAnalytics,
        selected.position.symbol,
      ),
      beforeHealth: beforeHealth,
      afterHealth: afterHealth,
      simulatedAnalytics: simulatedAnalytics,
    );
  }

  PortfolioSimulationResult? _simulateAddingOutsideSelected({
    required PortfolioAnalyticsResult analytics,
    required PortfolioAnalyticsPosition selected,
    required double targetWeightPercent,
  }) {
    if (analytics.positions.length < 2) {
      return null;
    }

    final target = targetWeightPercent / 100.0;

    if (target <= 0) {
      return null;
    }

    final selectedValue = selected.currentValue;
    final totalValue = analytics.currentValue;

    final addOutside = selectedValue / target - totalValue;

    if (addOutside <= 0) {
      return null;
    }

    final otherPositions = analytics.positions
        .where((item) => item.position.symbol != selected.position.symbol)
        .toList();

    final otherCurrentValue = otherPositions.fold<double>(
      0.0,
      (sum, item) => sum + item.currentValue,
    );

    if (otherCurrentValue <= 0) {
      return null;
    }

    final simulatedPositions = <PortfolioAnalyticsPosition>[];

    for (final item in analytics.positions) {
      if (item.position.symbol == selected.position.symbol) {
        simulatedPositions.add(item);
        continue;
      }

      final shareOfOthers = item.currentValue / otherCurrentValue;

      final addedToPosition = addOutside * shareOfOthers;

      simulatedPositions.add(
        _copyPositionWithCurrentValue(
          item,
          newCurrentValue: item.currentValue + addedToPosition,
          addedCapital: addedToPosition,
          removedCapital: 0.0,
        ),
      );
    }

    final simulatedAnalytics = _rebuildAnalytics(
      original: analytics,
      positions: simulatedPositions,
    );

    final beforeHealth = _healthService.calculate(analytics);
    final afterHealth = _healthService.calculate(simulatedAnalytics);

    return PortfolioSimulationResult(
      type: PortfolioSimulationType.addOutsideLargestPosition,
      title: 'Добавить капитал вне ${selected.position.symbol}',
      description:
          'Виртуально распределяем новый капитал между '
          'остальными текущими позициями пропорционально их весам.',
      symbol: selected.position.symbol,
      requiredAmount: addOutside,
      targetWeightPercent: targetWeightPercent,
      beforeWeightPercent: selected.weightPercent,
      afterWeightPercent: _weightForSymbol(
        simulatedAnalytics,
        selected.position.symbol,
      ),
      beforeHealth: beforeHealth,
      afterHealth: afterHealth,
      simulatedAnalytics: simulatedAnalytics,
    );
  }

  PortfolioSimulationResult? _simulateRebalanceSelected({
    required PortfolioAnalyticsResult analytics,
    required PortfolioAnalyticsPosition selected,
    required double targetWeightPercent,
  }) {
    if (analytics.positions.length < 2 || analytics.currentValue <= 0) {
      return null;
    }

    final target = targetWeightPercent / 100.0;

    if (target <= 0 || target >= 1) {
      return null;
    }

    final totalValue = analytics.currentValue;
    final selectedValue = selected.currentValue;

    final targetSelectedValue = totalValue * target;

    final amountToRedistribute = selectedValue - targetSelectedValue;

    if (amountToRedistribute <= 0 || amountToRedistribute >= selectedValue) {
      return null;
    }

    final otherPositions = analytics.positions
        .where((item) => item.position.symbol != selected.position.symbol)
        .toList(growable: false);

    final otherCurrentValue = otherPositions.fold<double>(
      0.0,
      (sum, item) => sum + item.currentValue,
    );

    if (otherCurrentValue <= 0) {
      return null;
    }

    final simulatedPositions = <PortfolioAnalyticsPosition>[];

    for (final item in analytics.positions) {
      if (item.position.symbol == selected.position.symbol) {
        simulatedPositions.add(
          _copyPositionWithCurrentValue(
            item,
            newCurrentValue: targetSelectedValue,
            addedCapital: 0.0,
            removedCapital: amountToRedistribute,
          ),
        );

        continue;
      }

      final shareOfOthers = item.currentValue / otherCurrentValue;

      final addedToPosition = amountToRedistribute * shareOfOthers;

      simulatedPositions.add(
        _copyPositionWithCurrentValue(
          item,
          newCurrentValue: item.currentValue + addedToPosition,
          addedCapital: addedToPosition,
          removedCapital: 0.0,
        ),
      );
    }

    final simulatedAnalytics = _rebuildAnalytics(
      original: analytics,
      positions: simulatedPositions,
    );

    final beforeHealth = _healthService.calculate(analytics);

    final afterHealth = _healthService.calculate(simulatedAnalytics);

    return PortfolioSimulationResult(
      type: PortfolioSimulationType.rebalanceSelectedPosition,
      title: 'Перераспределить ${selected.position.symbol}',
      description:
          'Виртуально уменьшаем '
          '${selected.position.symbol} до '
          '${targetWeightPercent.toStringAsFixed(0)}% '
          'и распределяем высвободившуюся сумму '
          'между остальными текущими позициями. '
          'Общая стоимость портфеля не меняется.',
      symbol: selected.position.symbol,
      requiredAmount: amountToRedistribute,
      targetWeightPercent: targetWeightPercent,
      beforeWeightPercent: selected.weightPercent,
      afterWeightPercent: _weightForSymbol(
        simulatedAnalytics,
        selected.position.symbol,
      ),
      beforeHealth: beforeHealth,
      afterHealth: afterHealth,
      simulatedAnalytics: simulatedAnalytics,
    );
  }

  PortfolioScenarioRankingResult rankPortfolioScenarios({
    required PortfolioAnalyticsResult analytics,
    double minTargetWeightPercent = 1.0,
    double stepPercent = 0.5,
  }) {
    if (analytics.positions.isEmpty) {
      return const PortfolioScenarioRankingResult(
        items: [],
        currentHealthScore: 0,
        totalTestedScenarios: 0,
      );
    }

    final currentHealth = _healthService.calculate(analytics);

    final items = <PortfolioScenarioRankingItem>[];

    var totalTested = 0;

    for (final position in analytics.positions) {
      final optimization = optimizePosition(
        analytics: analytics,
        symbol: position.position.symbol,
        minTargetWeightPercent: minTargetWeightPercent,
        stepPercent: stepPercent,
      );

      totalTested += optimization.testedScenarios;

      items.add(
        PortfolioScenarioRankingItem(
          symbol: optimization.symbol,
          currentWeightPercent: optimization.currentWeightPercent,
          bestScenario: optimization.bestScenario,
          currentHealthScore: optimization.currentHealthScore,
          testedScenarios: optimization.testedScenarios,
        ),
      );
    }

    items.sort((a, b) {
      if (a.healthDelta != b.healthDelta) {
        return b.healthDelta.compareTo(a.healthDelta);
      }

      final aScenario = a.bestScenario;
      final bScenario = b.bestScenario;

      if (aScenario != null && bScenario != null) {
        final aHealth = aScenario.afterHealth;
        final bHealth = bScenario.afterHealth;

        if (aHealth.diversificationScore != bHealth.diversificationScore) {
          return bHealth.diversificationScore.compareTo(
            aHealth.diversificationScore,
          );
        }

        if (aHealth.concentrationScore != bHealth.concentrationScore) {
          return bHealth.concentrationScore.compareTo(
            aHealth.concentrationScore,
          );
        }

        if (aHealth.opportunityScore != bHealth.opportunityScore) {
          return bHealth.opportunityScore.compareTo(aHealth.opportunityScore);
        }

        if (aHealth.riskScore != bHealth.riskScore) {
          return bHealth.riskScore.compareTo(aHealth.riskScore);
        }

        return aScenario.requiredAmount.compareTo(bScenario.requiredAmount);
      }

      if (aScenario != null) {
        return -1;
      }

      if (bScenario != null) {
        return 1;
      }

      return b.currentWeightPercent.compareTo(a.currentWeightPercent);
    });

    return PortfolioScenarioRankingResult(
      items: items,
      currentHealthScore: currentHealth.score,
      totalTestedScenarios: totalTested,
    );
  }

  PortfolioPositionOptimizationResult optimizePosition({
    required PortfolioAnalyticsResult analytics,
    required String symbol,
    double minTargetWeightPercent = 1.0,
    double stepPercent = 0.5,
  }) {
    if (analytics.positions.isEmpty ||
        analytics.currentValue <= 0 ||
        stepPercent <= 0) {
      return PortfolioPositionOptimizationResult.empty(
        symbol: symbol,
        currentHealthScore: _healthService.calculate(analytics).score,
      );
    }

    final selected = _findPosition(analytics, symbol);

    if (selected == null) {
      return PortfolioPositionOptimizationResult.empty(
        symbol: symbol,
        currentHealthScore: _healthService.calculate(analytics).score,
      );
    }

    final currentHealth = _healthService.calculate(analytics);

    final currentWeight = selected.weightPercent;

    final maxTarget = currentWeight - 0.5;

    if (maxTarget < minTargetWeightPercent) {
      return PortfolioPositionOptimizationResult.empty(
        symbol: selected.position.symbol,
        currentHealthScore: currentHealth.score,
        currentWeightPercent: currentWeight,
      );
    }

    PortfolioSimulationResult? bestScenario;

    var testedScenarios = 0;
    var target = minTargetWeightPercent;

    while (target <= maxTarget + 0.000001) {
      final scenarios = buildScenariosForPosition(
        analytics: analytics,
        symbol: selected.position.symbol,
        targetWeightPercent: target,
      );

      for (final scenario in scenarios) {
        testedScenarios++;

        if (bestScenario == null ||
            _isBetterPositionScenario(scenario, bestScenario)) {
          bestScenario = scenario;
        }
      }

      target += stepPercent;
    }

    final improvement = bestScenario == null
        ? 0
        : bestScenario.afterHealth.score - currentHealth.score;

    return PortfolioPositionOptimizationResult(
      symbol: selected.position.symbol,
      currentWeightPercent: currentWeight,
      currentHealthScore: currentHealth.score,
      bestScenario: improvement > 0 ? bestScenario : null,
      testedScenarios: testedScenarios,
    );
  }

  bool _isBetterPositionScenario(
    PortfolioSimulationResult candidate,
    PortfolioSimulationResult currentBest,
  ) {
    final candidateHealth = candidate.afterHealth;
    final bestHealth = currentBest.afterHealth;

    if (candidateHealth.score != bestHealth.score) {
      return candidateHealth.score > bestHealth.score;
    }

    if (candidateHealth.diversificationScore !=
        bestHealth.diversificationScore) {
      return candidateHealth.diversificationScore >
          bestHealth.diversificationScore;
    }

    if (candidateHealth.concentrationScore != bestHealth.concentrationScore) {
      return candidateHealth.concentrationScore > bestHealth.concentrationScore;
    }

    if (candidateHealth.opportunityScore != bestHealth.opportunityScore) {
      return candidateHealth.opportunityScore > bestHealth.opportunityScore;
    }

    if (candidateHealth.riskScore != bestHealth.riskScore) {
      return candidateHealth.riskScore > bestHealth.riskScore;
    }

    return candidate.requiredAmount < currentBest.requiredAmount;
  }

  PortfolioAnalyticsPosition? _findPosition(
    PortfolioAnalyticsResult analytics,
    String symbol,
  ) {
    for (final item in analytics.positions) {
      if (item.position.symbol.toUpperCase() == symbol.toUpperCase()) {
        return item;
      }
    }

    return null;
  }

  PortfolioAnalyticsPosition _copyPositionWithCurrentValue(
    PortfolioAnalyticsPosition item, {
    required double newCurrentValue,
    required double addedCapital,
    required double removedCapital,
  }) {
    final originalCurrentValue = item.currentValue;

    final multiplier = originalCurrentValue <= 0
        ? 1.0
        : newCurrentValue / originalCurrentValue;

    return PortfolioAnalyticsPosition(
      position: item.position,
      quote: item.quote,
      comparison: item.comparison,
      marketSignals: item.marketSignals,
      opportunity: item.opportunity,
      currentValue: newCurrentValue,
      profit: item.profit + addedCapital - removedCapital,
      profitPercent: item.profitPercent,
      weightPercent: item.weightPercent * multiplier,
    );
  }

  PortfolioAnalyticsResult _rebuildAnalytics({
    required PortfolioAnalyticsResult original,
    required List<PortfolioAnalyticsPosition> positions,
  }) {
    final currentValue = positions.fold<double>(
      0.0,
      (sum, item) => sum + item.currentValue,
    );

    if (currentValue <= 0) {
      return original;
    }

    final rebuiltPositions = <PortfolioAnalyticsPosition>[];

    for (final item in positions) {
      rebuiltPositions.add(
        PortfolioAnalyticsPosition(
          position: item.position,
          quote: item.quote,
          comparison: item.comparison,
          marketSignals: item.marketSignals,
          opportunity: item.opportunity,
          currentValue: item.currentValue,
          profit: item.profit,
          profitPercent: item.profitPercent,
          weightPercent: item.currentValue / currentValue * 100.0,
        ),
      );
    }

    final investMindScore = _weightedScore(
      rebuiltPositions,
      (item) => item.comparison.investMindScore,
    );

    final opportunityScore = _weightedScore(
      rebuiltPositions,
      (item) => item.opportunity.score,
    );

    final marketContextScore = _weightedScore(
      rebuiltPositions,
      (item) => item.opportunity.marketContextScore,
    );

    final confidenceScore = _weightedScore(
      rebuiltPositions,
      (item) => (item.opportunity.confidenceContribution * 10).round(),
    );

    PortfolioAnalyticsPosition? largestPosition;

    for (final item in rebuiltPositions) {
      if (largestPosition == null ||
          item.weightPercent > largestPosition.weightPercent) {
        largestPosition = item;
      }
    }

    final profit = rebuiltPositions.fold<double>(
      0.0,
      (sum, item) => sum + item.profit,
    );

    final investedAmount = currentValue - profit;

    final profitPercent = investedAmount == 0
        ? 0.0
        : profit / investedAmount * 100.0;

    return PortfolioAnalyticsResult(
      positions: rebuiltPositions,
      investedAmount: investedAmount,
      currentValue: currentValue,
      profit: profit,
      profitPercent: profitPercent,
      investMindScore: investMindScore,
      opportunityScore: opportunityScore,
      marketContextScore: marketContextScore,
      confidenceScore: confidenceScore,
      largestPositionWeightPercent: largestPosition?.weightPercent ?? 0.0,
      largestPositionSymbol: largestPosition?.position.symbol,
      warnings: original.warnings,
    );
  }

  int _weightedScore(
    List<PortfolioAnalyticsPosition> positions,
    int Function(PortfolioAnalyticsPosition item) selector,
  ) {
    final totalValue = positions.fold<double>(
      0.0,
      (sum, item) => sum + item.currentValue,
    );

    if (totalValue <= 0) {
      return 0;
    }

    final weighted = positions.fold<double>(
      0.0,
      (sum, item) => sum + selector(item) * (item.currentValue / totalValue),
    );

    return weighted.round().clamp(0, 100);
  }

  double _weightForSymbol(PortfolioAnalyticsResult analytics, String symbol) {
    for (final item in analytics.positions) {
      if (item.position.symbol == symbol) {
        return item.weightPercent;
      }
    }

    return 0.0;
  }
}
