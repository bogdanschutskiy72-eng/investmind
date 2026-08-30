import '../../services/portfolio_analytics_service.dart';
import 'portfolio_health_service.dart';

enum PortfolioRecommendationType {
  concentration,
  diversification,
  review,
  opportunity,
}

enum PortfolioRecommendationPriority { high, medium, low }

class PortfolioRecommendation {
  final PortfolioRecommendationType type;
  final PortfolioRecommendationPriority priority;

  final String title;
  final String description;

  final String? symbol;

  final double? currentWeightPercent;
  final double? targetWeightPercent;

  final double? reduceByValue;
  final double? addOutsidePositionValue;

  const PortfolioRecommendation({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    this.symbol,
    this.currentWeightPercent,
    this.targetWeightPercent,
    this.reduceByValue,
    this.addOutsidePositionValue,
  });
}

class PortfolioRecommendationResult {
  final List<PortfolioRecommendation> recommendations;

  const PortfolioRecommendationResult({required this.recommendations});

  bool get isEmpty => recommendations.isEmpty;
}

class PortfolioRecommendationService {
  const PortfolioRecommendationService();

  PortfolioRecommendationResult build({
    required PortfolioAnalyticsResult analytics,
    required PortfolioHealthResult health,
  }) {
    if (analytics.positions.isEmpty) {
      return const PortfolioRecommendationResult(recommendations: []);
    }

    final recommendations = <PortfolioRecommendation>[];

    _addConcentrationRecommendation(analytics, recommendations);

    _addDiversificationRecommendation(analytics, health, recommendations);

    _addWeakOpportunityRecommendations(analytics, recommendations);

    _addStrongOpportunityObservation(analytics, recommendations);

    recommendations.sort(
      (a, b) =>
          _priorityValue(b.priority).compareTo(_priorityValue(a.priority)),
    );

    return PortfolioRecommendationResult(recommendations: recommendations);
  }

  void _addConcentrationRecommendation(
    PortfolioAnalyticsResult analytics,
    List<PortfolioRecommendation> output,
  ) {
    final largestSymbol = analytics.largestPositionSymbol;

    if (largestSymbol == null ||
        analytics.positions.isEmpty ||
        analytics.currentValue <= 0) {
      return;
    }

    final largest = analytics.positions.first;

    final currentWeight = largest.weightPercent;

    double? targetWeight;

    PortfolioRecommendationPriority priority =
        PortfolioRecommendationPriority.low;

    if (currentWeight >= 65) {
      targetWeight = 50;
      priority = PortfolioRecommendationPriority.high;
    } else if (currentWeight >= 50) {
      targetWeight = 40;
      priority = PortfolioRecommendationPriority.high;
    } else if (currentWeight >= 35) {
      targetWeight = 30;
      priority = PortfolioRecommendationPriority.medium;
    }

    if (targetWeight == null) {
      return;
    }

    final target = targetWeight / 100.0;
    final largestValue = largest.currentValue;
    final totalValue = analytics.currentValue;

    double reduceBy = 0.0;

    if (target < 1.0) {
      final numerator = largestValue - target * totalValue;

      reduceBy = numerator <= 0 ? 0.0 : numerator / (1.0 - target);
    }

    final addOutside = largestValue / target - totalValue;

    final safeAddOutside = addOutside < 0 ? 0.0 : addOutside;

    output.add(
      PortfolioRecommendation(
        type: PortfolioRecommendationType.concentration,
        priority: priority,
        title: 'Снизить концентрацию $largestSymbol',
        description:
            '$largestSymbol занимает '
            '${currentWeight.toStringAsFixed(1)}% портфеля. '
            'Для ориентира можно рассмотреть снижение доли '
            'примерно до ${targetWeight.toStringAsFixed(0)}%.',
        symbol: largestSymbol,
        currentWeightPercent: currentWeight,
        targetWeightPercent: targetWeight,
        reduceByValue: reduceBy,
        addOutsidePositionValue: safeAddOutside,
      ),
    );
  }

  void _addDiversificationRecommendation(
    PortfolioAnalyticsResult analytics,
    PortfolioHealthResult health,
    List<PortfolioRecommendation> output,
  ) {
    if (health.diversificationScore >= 60) {
      return;
    }

    final count = analytics.positions.length;

    String description;

    if (count <= 2) {
      description =
          'В портфеле всего $count позиции. '
          'Добавление новых независимых позиций может '
          'снизить зависимость результата от одной компании.';
    } else if (count <= 4) {
      description =
          'Портфель пока остаётся достаточно узким. '
          'Дополнительная диверсификация может улучшить '
          'устойчивость портфеля.';
    } else {
      description =
          'Количество позиций уже приемлемое, но их веса '
          'распределены неравномерно.';
    }

    output.add(
      PortfolioRecommendation(
        type: PortfolioRecommendationType.diversification,
        priority: health.diversificationScore < 40
            ? PortfolioRecommendationPriority.high
            : PortfolioRecommendationPriority.medium,
        title: 'Улучшить диверсификацию',
        description:
            '$description Текущий Diversification Score — '
            '${health.diversificationScore}/100.',
      ),
    );
  }

  void _addWeakOpportunityRecommendations(
    PortfolioAnalyticsResult analytics,
    List<PortfolioRecommendation> output,
  ) {
    final weak =
        analytics.positions
            .where((item) => item.opportunity.score < 40)
            .toList()
          ..sort((a, b) => a.opportunity.score.compareTo(b.opportunity.score));

    for (final item in weak.take(2)) {
      output.add(
        PortfolioRecommendation(
          type: PortfolioRecommendationType.review,
          priority: PortfolioRecommendationPriority.medium,
          title: 'Пересмотреть ${item.position.symbol}',
          description:
              '${item.position.symbol} сейчас имеет '
              'Opportunity ${item.opportunity.score}/100 '
              'при весе '
              '${item.weightPercent.toStringAsFixed(1)}%. '
              'Позицию стоит проверить отдельно перед '
              'следующим решением по портфелю.',
          symbol: item.position.symbol,
          currentWeightPercent: item.weightPercent,
        ),
      );
    }
  }

  void _addStrongOpportunityObservation(
    PortfolioAnalyticsResult analytics,
    List<PortfolioRecommendation> output,
  ) {
    final strong =
        analytics.positions
            .where((item) => item.opportunity.score >= 70)
            .toList()
          ..sort((a, b) => b.opportunity.score.compareTo(a.opportunity.score));

    if (strong.isEmpty) {
      return;
    }

    final item = strong.first;

    output.add(
      PortfolioRecommendation(
        type: PortfolioRecommendationType.opportunity,
        priority: PortfolioRecommendationPriority.low,
        title: 'Сильный Opportunity: ${item.position.symbol}',
        description:
            '${item.position.symbol} имеет '
            'Opportunity ${item.opportunity.score}/100 '
            'и занимает '
            '${item.weightPercent.toStringAsFixed(1)}% портфеля. '
            'Это наблюдение, а не автоматический сигнал к покупке.',
        symbol: item.position.symbol,
        currentWeightPercent: item.weightPercent,
      ),
    );
  }

  int _priorityValue(PortfolioRecommendationPriority priority) {
    switch (priority) {
      case PortfolioRecommendationPriority.high:
        return 3;
      case PortfolioRecommendationPriority.medium:
        return 2;
      case PortfolioRecommendationPriority.low:
        return 1;
    }
  }
}
