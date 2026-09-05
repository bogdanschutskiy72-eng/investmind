import 'dart:math' as math;

import '../../services/portfolio_analytics_service.dart';

enum PortfolioHealthLevel {
  excellent,
  strong,
  balanced,
  elevatedRisk,
  highRisk,
}

enum PortfolioInsightType { strength, risk, improvement }

class PortfolioHealthUnavailableException implements Exception {
  final List<String> failedSymbols;

  const PortfolioHealthUnavailableException({required this.failedSymbols});

  @override
  String toString() {
    if (failedSymbols.isEmpty) {
      return 'Portfolio Health временно недоступен: '
          'аналитика портфеля неполная.';
    }

    return 'Portfolio Health временно недоступен: '
        'не удалось получить данные по '
        '${failedSymbols.join(', ')}.';
  }
}

class PortfolioHealthInsight {
  final PortfolioInsightType type;
  final String title;
  final String description;
  final int impact;

  const PortfolioHealthInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.impact,
  });
}

class PortfolioHealthResult {
  final int score;
  final PortfolioHealthLevel level;

  final int qualityScore;
  final int opportunityScore;
  final int diversificationScore;
  final int concentrationScore;
  final int riskScore;

  final List<PortfolioHealthInsight> insights;

  const PortfolioHealthResult({
    required this.score,
    required this.level,
    required this.qualityScore,
    required this.opportunityScore,
    required this.diversificationScore,
    required this.concentrationScore,
    required this.riskScore,
    required this.insights,
  });

  String get label {
    switch (level) {
      case PortfolioHealthLevel.excellent:
        return 'Отличное состояние';

      case PortfolioHealthLevel.strong:
        return 'Сильный портфель';

      case PortfolioHealthLevel.balanced:
        return 'Сбалансировано';

      case PortfolioHealthLevel.elevatedRisk:
        return 'Повышенный риск';

      case PortfolioHealthLevel.highRisk:
        return 'Высокий риск';
    }
  }
}

class PortfolioHealthService {
  const PortfolioHealthService();

  PortfolioHealthResult calculate(PortfolioAnalyticsResult analytics) {
    if (analytics.isPartial) {
      throw PortfolioHealthUnavailableException(
        failedSymbols: analytics.failedSymbols,
      );
    }

    if (analytics.positions.isEmpty) {
      return const PortfolioHealthResult(
        score: 0,
        level: PortfolioHealthLevel.highRisk,
        qualityScore: 0,
        opportunityScore: 0,
        diversificationScore: 0,
        concentrationScore: 0,
        riskScore: 0,
        insights: [],
      );
    }

    final qualityScore = analytics.investMindScore.clamp(0, 100);

    final opportunityScore = analytics.opportunityScore.clamp(0, 100);

    final diversificationScore = _calculateDiversificationScore(analytics);

    final concentrationScore = _calculateConcentrationScore(
      analytics.largestPositionWeightPercent,
    );

    final riskScore = _calculateRiskScore(analytics);

    final rawScore =
        qualityScore * 0.30 +
        opportunityScore * 0.20 +
        diversificationScore * 0.20 +
        concentrationScore * 0.15 +
        riskScore * 0.15;

    final score = rawScore.round().clamp(0, 100);

    final insights = _buildInsights(
      analytics,
      qualityScore: qualityScore,
      opportunityScore: opportunityScore,
      diversificationScore: diversificationScore,
      concentrationScore: concentrationScore,
      riskScore: riskScore,
    );

    return PortfolioHealthResult(
      score: score,
      level: _levelForScore(score),
      qualityScore: qualityScore,
      opportunityScore: opportunityScore,
      diversificationScore: diversificationScore,
      concentrationScore: concentrationScore,
      riskScore: riskScore,
      insights: insights,
    );
  }

  int _calculateDiversificationScore(PortfolioAnalyticsResult analytics) {
    final positions = analytics.positions;

    if (positions.isEmpty) {
      return 0;
    }

    if (positions.length == 1) {
      return 10;
    }

    final weights = positions
        .map((item) => (item.weightPercent / 100.0).clamp(0.0, 1.0))
        .where((weight) => weight > 0)
        .toList();

    if (weights.isEmpty) {
      return 0;
    }

    double entropy = 0.0;

    for (final weight in weights) {
      entropy -= weight * math.log(weight);
    }

    final maxEntropy = math.log(weights.length.toDouble());

    final balanceScore = maxEntropy <= 0
        ? 0.0
        : (entropy / maxEntropy * 100.0).clamp(0.0, 100.0);

    final countScore = _positionCountScore(weights.length);

    final diversification = balanceScore * 0.70 + countScore * 0.30;

    return diversification.round().clamp(0, 100);
  }

  int _positionCountScore(int count) {
    if (count >= 12) {
      return 100;
    }

    if (count >= 10) {
      return 95;
    }

    if (count >= 8) {
      return 88;
    }

    if (count >= 6) {
      return 78;
    }

    if (count >= 5) {
      return 70;
    }

    if (count >= 4) {
      return 60;
    }

    if (count == 3) {
      return 50;
    }

    if (count == 2) {
      return 35;
    }

    return 10;
  }

  int _calculateConcentrationScore(double largestWeight) {
    if (largestWeight <= 15) {
      return 100;
    }

    if (largestWeight <= 20) {
      return 92;
    }

    if (largestWeight <= 25) {
      return 82;
    }

    if (largestWeight <= 30) {
      return 72;
    }

    if (largestWeight <= 40) {
      return 58;
    }

    if (largestWeight <= 50) {
      return 42;
    }

    if (largestWeight <= 65) {
      return 25;
    }

    if (largestWeight <= 80) {
      return 10;
    }

    return 5;
  }

  int _calculateRiskScore(PortfolioAnalyticsResult analytics) {
    double weightedRisk = 0.0;
    double totalWeight = 0.0;

    for (final item in analytics.positions) {
      final weight = item.currentValue;

      if (weight <= 0) {
        continue;
      }

      weightedRisk += item.comparison.riskScore * weight;

      totalWeight += weight;
    }

    if (totalWeight <= 0) {
      return 0;
    }

    return (weightedRisk / totalWeight).round().clamp(0, 100);
  }

  PortfolioHealthLevel _levelForScore(int score) {
    if (score >= 85) {
      return PortfolioHealthLevel.excellent;
    }

    if (score >= 70) {
      return PortfolioHealthLevel.strong;
    }

    if (score >= 55) {
      return PortfolioHealthLevel.balanced;
    }

    if (score >= 40) {
      return PortfolioHealthLevel.elevatedRisk;
    }

    return PortfolioHealthLevel.highRisk;
  }

  List<PortfolioHealthInsight> _buildInsights(
    PortfolioAnalyticsResult analytics, {
    required int qualityScore,
    required int opportunityScore,
    required int diversificationScore,
    required int concentrationScore,
    required int riskScore,
  }) {
    final insights = <PortfolioHealthInsight>[];

    if (qualityScore >= 70) {
      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.strength,
          title: 'Сильное качество активов',
          description:
              'Средневзвешенный InvestMind Score '
              'портфеля — $qualityScore/100.',
          impact: 2,
        ),
      );
    }

    if (opportunityScore >= 65) {
      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.strength,
          title: 'Хороший текущий Opportunity',
          description:
              'Средневзвешенный Opportunity Score — '
              '$opportunityScore/100.',
          impact: 2,
        ),
      );
    }

    if (analytics.confidenceScore >= 80) {
      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.strength,
          title: 'Высокая уверенность данных',
          description:
              'Средняя Confidence по портфелю — '
              '${analytics.confidenceScore}%.',
          impact: 1,
        ),
      );
    }

    if (analytics.largestPositionWeightPercent >= 50) {
      final symbol = analytics.largestPositionSymbol ?? 'Крупнейшая позиция';

      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.risk,
          title: 'Очень высокая концентрация',
          description:
              '$symbol занимает '
              '${analytics.largestPositionWeightPercent.toStringAsFixed(1)}% '
              'портфеля.',
          impact: -3,
        ),
      );
    } else if (analytics.largestPositionWeightPercent >= 35) {
      final symbol = analytics.largestPositionSymbol ?? 'Крупнейшая позиция';

      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.risk,
          title: 'Повышенная концентрация',
          description:
              '$symbol занимает '
              '${analytics.largestPositionWeightPercent.toStringAsFixed(1)}% '
              'портфеля.',
          impact: -2,
        ),
      );
    }

    if (diversificationScore < 45) {
      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.improvement,
          title: 'Диверсификацию можно улучшить',
          description:
              'Текущая оценка диверсификации — '
              '$diversificationScore/100.',
          impact: -2,
        ),
      );
    } else if (diversificationScore >= 75) {
      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.strength,
          title: 'Хорошая диверсификация',
          description:
              'Распределение позиций выглядит '
              'достаточно сбалансированным: '
              '$diversificationScore/100.',
          impact: 1,
        ),
      );
    }

    if (riskScore < 50) {
      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.risk,
          title: 'Повышенный совокупный риск',
          description:
              'Средневзвешенный Risk Score — '
              '$riskScore/100.',
          impact: -2,
        ),
      );
    }

    if (qualityScore < 50) {
      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.improvement,
          title: 'Качество активов ниже среднего',
          description:
              'InvestMind Score портфеля — '
              '$qualityScore/100.',
          impact: -2,
        ),
      );
    }

    if (opportunityScore < 50) {
      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.improvement,
          title: 'Слабый текущий Opportunity',
          description:
              'Opportunity Score портфеля — '
              '$opportunityScore/100.',
          impact: -2,
        ),
      );
    }

    final strongestPosition = _bestOpportunityPosition(analytics);

    if (strongestPosition != null &&
        strongestPosition.opportunity.score >= 65) {
      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.strength,
          title: 'Сильная возможность в портфеле',
          description:
              '${strongestPosition.position.symbol} '
              'имеет Opportunity '
              '${strongestPosition.opportunity.score}/100.',
          impact: 1,
        ),
      );
    }

    final weakestPosition = _weakestOpportunityPosition(analytics);

    if (weakestPosition != null && weakestPosition.opportunity.score < 40) {
      insights.add(
        PortfolioHealthInsight(
          type: PortfolioInsightType.improvement,
          title: 'Слабая позиция по Opportunity',
          description:
              '${weakestPosition.position.symbol} '
              'имеет Opportunity '
              '${weakestPosition.opportunity.score}/100.',
          impact: -1,
        ),
      );
    }

    insights.sort((a, b) => b.impact.abs().compareTo(a.impact.abs()));

    return insights;
  }

  PortfolioAnalyticsPosition? _bestOpportunityPosition(
    PortfolioAnalyticsResult analytics,
  ) {
    if (analytics.positions.isEmpty) {
      return null;
    }

    return analytics.positions.reduce(
      (current, next) =>
          next.opportunity.score > current.opportunity.score ? next : current,
    );
  }

  PortfolioAnalyticsPosition? _weakestOpportunityPosition(
    PortfolioAnalyticsResult analytics,
  ) {
    if (analytics.positions.isEmpty) {
      return null;
    }

    return analytics.positions.reduce(
      (current, next) =>
          next.opportunity.score < current.opportunity.score ? next : current,
    );
  }
}
