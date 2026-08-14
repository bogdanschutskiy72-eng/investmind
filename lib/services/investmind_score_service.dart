class InvestMindScoreResult {
  final int score;
  final String rating;
  final List<String> strengths;
  final List<String> warnings;

  const InvestMindScoreResult({
    required this.score,
    required this.rating,
    required this.strengths,
    required this.warnings,
  });
}

class InvestMindScoreService {
  const InvestMindScoreService();

  InvestMindScoreResult calculate({
    required double currentPrice,
    required double movingAverage20,
    required double movingAverage50,
    required double volatilityPercent,
    required double maxDrawdownPercent,
    required double trendStrengthPercent,
    required double trendSlopePercentPerDay,
  }) {
    int score = 50;

    final List<String> strengths = [];
    final List<String> warnings = [];

    // ------------------------------------------------------------
    // MA20
    // ------------------------------------------------------------

    score += _movingAveragePoints(
      currentPrice: currentPrice,
      movingAverage: movingAverage20,
      label: 'MA20',
      strengths: strengths,
      warnings: warnings,
    );

    // ------------------------------------------------------------
    // MA50
    // ------------------------------------------------------------

    score += _movingAveragePoints(
      currentPrice: currentPrice,
      movingAverage: movingAverage50,
      label: 'MA50',
      strengths: strengths,
      warnings: warnings,
    );

    // ------------------------------------------------------------
    // Направление тренда
    // ------------------------------------------------------------

    if (trendSlopePercentPerDay >= 0.20) {
      score += 10;

      strengths.add('Выраженное положительное направление тренда');
    } else if (trendSlopePercentPerDay >= 0.05) {
      score += 6;

      strengths.add('Положительное направление тренда');
    } else if (trendSlopePercentPerDay <= -0.20) {
      score -= 10;

      warnings.add('Выраженное отрицательное направление тренда');
    } else if (trendSlopePercentPerDay <= -0.05) {
      score -= 6;

      warnings.add('Отрицательное направление тренда');
    }

    // ------------------------------------------------------------
    // Сила тренда
    // ------------------------------------------------------------

    if (trendStrengthPercent >= 70) {
      score += 10;

      strengths.add('Сильный устойчивый тренд');
    } else if (trendStrengthPercent >= 50) {
      score += 5;

      strengths.add('Умеренно устойчивый тренд');
    } else if (trendStrengthPercent < 20) {
      score -= 7;

      warnings.add('Очень слабая устойчивость тренда');
    } else if (trendStrengthPercent < 30) {
      score -= 3;

      warnings.add('Слабая устойчивость тренда');
    }

    // ------------------------------------------------------------
    // Волатильность
    // ------------------------------------------------------------

    if (volatilityPercent < 20) {
      score += 5;

      strengths.add('Низкая волатильность');
    } else if (volatilityPercent < 30) {
      score += 3;

      strengths.add('Умеренная волатильность');
    } else if (volatilityPercent >= 60) {
      score -= 10;

      warnings.add('Очень высокая волатильность');
    } else if (volatilityPercent >= 45) {
      score -= 7;

      warnings.add('Высокая волатильность');
    } else if (volatilityPercent >= 35) {
      score -= 4;

      warnings.add('Повышенная волатильность');
    }

    // ------------------------------------------------------------
    // Максимальная просадка
    // ------------------------------------------------------------

    if (maxDrawdownPercent < 10) {
      score += 5;

      strengths.add('Небольшая максимальная просадка');
    } else if (maxDrawdownPercent >= 30) {
      score -= 10;

      warnings.add('Глубокая историческая просадка');
    } else if (maxDrawdownPercent >= 20) {
      score -= 7;

      warnings.add('Значительная историческая просадка');
    } else if (maxDrawdownPercent >= 15) {
      score -= 4;

      warnings.add('Заметная историческая просадка');
    }

    score = score.clamp(0, 100);

    return InvestMindScoreResult(
      score: score,
      rating: _ratingFor(score),
      strengths: strengths,
      warnings: warnings,
    );
  }

  int _movingAveragePoints({
    required double currentPrice,
    required double movingAverage,
    required String label,
    required List<String> strengths,
    required List<String> warnings,
  }) {
    if (currentPrice <= 0 || movingAverage <= 0) {
      return 0;
    }

    final double distancePercent =
        ((currentPrice - movingAverage) / movingAverage) * 100;

    // Цена существенно выше средней.
    if (distancePercent >= 3.0) {
      strengths.add('Цена значительно выше $label');

      return 10;
    }

    // Цена уверенно выше средней.
    if (distancePercent >= 1.0) {
      strengths.add('Цена выше $label');

      return 6;
    }

    // Небольшое преимущество над средней.
    if (distancePercent >= 0.5) {
      strengths.add('Цена немного выше $label');

      return 3;
    }

    // В пределах ±0.5% считаем цену около MA.
    // Никакого штрафа или бонуса.
    if (distancePercent > -0.5) {
      return 0;
    }

    // Немного ниже средней.
    if (distancePercent > -1.0) {
      warnings.add('Цена немного ниже $label');

      return -3;
    }

    // Уверенно ниже средней.
    if (distancePercent > -3.0) {
      warnings.add('Цена ниже $label');

      return -6;
    }

    // Существенно ниже средней.
    warnings.add('Цена значительно ниже $label');

    return -10;
  }

  String _ratingFor(int score) {
    if (score >= 85) {
      return 'Очень сильное состояние';
    }

    if (score >= 70) {
      return 'Сильное состояние';
    }

    if (score >= 55) {
      return 'Умеренно положительное';
    }

    if (score >= 40) {
      return 'Нейтральное';
    }

    if (score >= 25) {
      return 'Слабое состояние';
    }

    return 'Высокий риск';
  }
}
