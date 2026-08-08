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

    // MA20
    if (currentPrice > movingAverage20) {
      score += 10;
      strengths.add('Цена выше MA20');
    } else {
      score -= 10;
      warnings.add('Цена ниже MA20');
    }

    // MA50
    if (currentPrice > movingAverage50) {
      score += 10;
      strengths.add('Цена выше MA50');
    } else {
      score -= 10;
      warnings.add('Цена ниже MA50');
    }

    // Направление тренда
    if (trendSlopePercentPerDay > 0.05) {
      score += 10;
      strengths.add('Положительное направление тренда');
    } else if (trendSlopePercentPerDay < -0.05) {
      score -= 10;
      warnings.add('Отрицательное направление тренда');
    }

    // Сила тренда
    if (trendStrengthPercent >= 70) {
      score += 10;
      strengths.add('Сильный устойчивый тренд');
    } else if (trendStrengthPercent < 25) {
      score -= 5;
      warnings.add('Слабая устойчивость тренда');
    }

    // Волатильность
    if (volatilityPercent < 25) {
      score += 5;
      strengths.add('Умеренная волатильность');
    } else if (volatilityPercent >= 50) {
      score -= 10;
      warnings.add('Высокая волатильность');
    } else if (volatilityPercent >= 35) {
      score -= 5;
      warnings.add('Повышенная волатильность');
    }

    // Максимальная просадка
    if (maxDrawdownPercent < 10) {
      score += 5;
      strengths.add('Небольшая максимальная просадка');
    } else if (maxDrawdownPercent >= 25) {
      score -= 10;
      warnings.add('Глубокая историческая просадка');
    } else if (maxDrawdownPercent >= 15) {
      score -= 5;
      warnings.add('Заметная историческая просадка');
    }

    if (score < 0) {
      score = 0;
    }

    if (score > 100) {
      score = 100;
    }

    return InvestMindScoreResult(
      score: score,
      rating: _ratingFor(score),
      strengths: strengths,
      warnings: warnings,
    );
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