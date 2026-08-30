import '../comparison/company_comparison.dart';
import 'market_signal.dart';

class OpportunityScoreResult {
  final int score;
  final double rawScore;

  final int marketContextScore;

  final double investMindContribution;
  final double marketContextContribution;
  final double confidenceContribution;

  final String label;
  final List<String> reasons;

  const OpportunityScoreResult({
    required this.score,
    required this.rawScore,
    required this.marketContextScore,
    required this.investMindContribution,
    required this.marketContextContribution,
    required this.confidenceContribution,
    required this.label,
    required this.reasons,
  });
}

class OpportunityScoreService {
  const OpportunityScoreService();

  OpportunityScoreResult calculate({
    required CompanyComparison company,
    required List<MarketSignal> marketSignals,
  }) {
    int marketContextScore = 50;
    final List<String> reasons = [];

    for (final signal in marketSignals) {
      switch (signal.type) {
        case MarketSignalType.strongRise:
          marketContextScore += 8;
          reasons.add('Сильное дневное движение вверх');

        case MarketSignalType.strongFall:
          marketContextScore -= 8;
          reasons.add('Сильное дневное снижение');

        case MarketSignalType.bullishMomentum:
          marketContextScore += 12;
          reasons.add('Положительный рыночный momentum');

        case MarketSignalType.bearishMomentum:
          marketContextScore -= 12;
          reasons.add('Отрицательный рыночный momentum');

        case MarketSignalType.highVolatility:
          marketContextScore -= 6;
          reasons.add('Повышенная волатильность');

        case MarketSignalType.recovery:
          marketContextScore += 10;
          reasons.add('Восстановление после просадки');

        case MarketSignalType.breakdown:
          marketContextScore -= 10;
          reasons.add('Ослабление текущего тренда');
      }
    }

    marketContextScore = marketContextScore.clamp(0, 100);

    final double investMindContribution = company.investMindScore * 0.70;

    final double marketContextContribution = marketContextScore * 0.20;

    final double confidenceContribution = company.confidenceScore * 0.10;

    final double rawScore =
        investMindContribution +
        marketContextContribution +
        confidenceContribution;

    final int score = rawScore.round().clamp(0, 100);

    if (reasons.isEmpty) {
      reasons.add('Сильных краткосрочных рыночных сигналов сейчас нет');
    }

    return OpportunityScoreResult(
      score: score,
      rawScore: rawScore,
      marketContextScore: marketContextScore,
      investMindContribution: investMindContribution,
      marketContextContribution: marketContextContribution,
      confidenceContribution: confidenceContribution,
      label: _buildLabel(score),
      reasons: reasons,
    );
  }

  String _buildLabel(int score) {
    if (score >= 80) {
      return 'Высокий интерес';
    }

    if (score >= 65) {
      return 'Интересно наблюдать';
    }

    if (score >= 50) {
      return 'Нейтрально';
    }

    if (score >= 35) {
      return 'Слабый интерес';
    }

    return 'Низкий интерес';
  }
}
