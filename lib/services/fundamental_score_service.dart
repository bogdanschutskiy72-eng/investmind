import 'fundamental_service.dart';

class FundamentalScoreResult {
  final int score;

  final int growthScore;
  final int profitabilityScore;
  final int valuationScore;
  final int financialHealthScore;
  final int riskScore;

  final List<String> strengths;
  final List<String> warnings;

  const FundamentalScoreResult({
    required this.score,
    required this.growthScore,
    required this.profitabilityScore,
    required this.valuationScore,
    required this.financialHealthScore,
    required this.riskScore,
    required this.strengths,
    required this.warnings,
  });

  String get rating {
    if (score >= 80) {
      return 'Сильные фундаментальные показатели';
    }

    if (score >= 65) {
      return 'Выше среднего';
    }

    if (score >= 50) {
      return 'Нейтральная фундаментальная картина';
    }

    if (score >= 35) {
      return 'Ниже среднего';
    }

    return 'Повышенный фундаментальный риск';
  }
}

class FundamentalScoreService {
  const FundamentalScoreService();

  FundamentalScoreResult calculate(
    FundamentalData data,
  ) {
    final int growthScore =
        _calculateGrowthScore(data);

    final int profitabilityScore =
        _calculateProfitabilityScore(data);

    final int valuationScore =
        _calculateValuationScore(data);

    final int financialHealthScore =
        _calculateFinancialHealthScore(data);

    final int riskScore =
        _calculateRiskScore(data);

    final double weightedScore =
        growthScore * 0.25 +
        profitabilityScore * 0.25 +
        valuationScore * 0.20 +
        financialHealthScore * 0.15 +
        riskScore * 0.15;

    final int totalScore =
        weightedScore.round().clamp(0, 100);

    final List<String> strengths = [];
    final List<String> warnings = [];

    if (data.revenueGrowthPercent >= 15) {
      strengths.add(
        'Сильный рост выручки: '
        '${data.revenueGrowthPercent.toStringAsFixed(1)}%',
      );
    }

    if (data.epsGrowthPercent >= 15) {
      strengths.add(
        'Сильный рост EPS: '
        '${data.epsGrowthPercent.toStringAsFixed(1)}%',
      );
    }

    if (data.netMarginPercent >= 20) {
      strengths.add(
        'Высокая чистая маржа: '
        '${data.netMarginPercent.toStringAsFixed(1)}%',
      );
    }

    if (data.roePercent >= 20) {
      strengths.add(
        'Высокий ROE: '
        '${data.roePercent.toStringAsFixed(1)}%',
      );
    }

    if (data.currentRatio >= 1.5) {
      strengths.add(
        'Хорошая краткосрочная ликвидность.',
      );
    }

    if (data.pe >= 40) {
      warnings.add(
        'Высокий P/E может означать '
        'повышенные ожидания рынка.',
      );
    }

    if (data.priceToSales >= 10) {
      warnings.add(
        'Высокий P/S указывает на '
        'дорогую оценку относительно выручки.',
      );
    }

    if (data.beta >= 1.5) {
      warnings.add(
        'Beta ${data.beta.toStringAsFixed(2)} '
        'указывает на повышенную чувствительность '
        'акции к движениям рынка.',
      );
    }

    if (data.revenueGrowthPercent < 0) {
      warnings.add(
        'Выручка сокращается.',
      );
    }

    if (data.epsGrowthPercent < 0) {
      warnings.add(
        'EPS показывает отрицательную динамику.',
      );
    }

    if (data.currentRatio > 0 &&
        data.currentRatio < 1) {
      warnings.add(
        'Current Ratio ниже 1 — '
        'ликвидность требует внимания.',
      );
    }

    return FundamentalScoreResult(
      score: totalScore,
      growthScore: growthScore,
      profitabilityScore: profitabilityScore,
      valuationScore: valuationScore,
      financialHealthScore:
          financialHealthScore,
      riskScore: riskScore,
      strengths: strengths,
      warnings: warnings,
    );
  }

  int _calculateGrowthScore(
    FundamentalData data,
  ) {
    int score = 50;

    score += _growthPoints(
      data.revenueGrowthPercent,
    );

    score += _growthPoints(
      data.epsGrowthPercent,
    );

    return score.clamp(0, 100);
  }

  int _growthPoints(
    double growth,
  ) {if (growth >= 30) {
      return 25;
    }

    if (growth >= 15) {
      return 18;
    }

    if (growth >= 5) {
      return 10;
    }

    if (growth >= 0) {
      return 3;
    }

    if (growth >= -10) {
      return -10;
    }

    return -25;
  }

  int _calculateProfitabilityScore(
    FundamentalData data,
  ) {
    int score = 50;

    final double netMargin =
        data.netMarginPercent;

    if (netMargin >= 25) {
      score += 25;
    } else if (netMargin >= 15) {
      score += 18;
    } else if (netMargin >= 8) {
      score += 10;
    } else if (netMargin > 0) {
      score += 3;
    } else {
      score -= 20;
    }

    final double roe = data.roePercent;

    if (roe >= 25) {
      score += 25;
    } else if (roe >= 15) {
      score += 15;
    } else if (roe >= 8) {
      score += 8;
    } else if (roe > 0) {
      score += 2;
    } else {
      score -= 15;
    }

    return score.clamp(0, 100);
  }

  int _calculateValuationScore(
    FundamentalData data,
  ) {
    int score = 50;

    if (data.pe > 0) {
      if (data.pe <= 15) {
        score += 25;
      } else if (data.pe <= 25) {
        score += 15;
      } else if (data.pe <= 35) {
        score += 5;
      } else if (data.pe <= 50) {
        score -= 10;
      } else {
        score -= 25;
      }
    }

    if (data.priceToSales > 0) {
      if (data.priceToSales <= 3) {
        score += 20;
      } else if (data.priceToSales <= 6) {
        score += 10;
      } else if (data.priceToSales <= 10) {
        score -= 5;
      } else {
        score -= 20;
      }
    }

    if (data.forwardPe > 0 &&
        data.pe > 0 &&
        data.forwardPe < data.pe) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  int _calculateFinancialHealthScore(
    FundamentalData data,
  ) {
    int score = 50;

    final double ratio = data.currentRatio;

    if (ratio >= 2) {
      score += 30;
    } else if (ratio >= 1.5) {
      score += 20;
    } else if (ratio >= 1) {
      score += 5;
    } else if (ratio > 0) {
      score -= 25;
    }

    if (data.grossMarginPercent >= 50) {
      score += 15;
    } else if (data.grossMarginPercent >= 30) {
      score += 8;
    }

    return score.clamp(0, 100);
  }

  int _calculateRiskScore(
    FundamentalData data,
  ) {
    int score = 70;

    final double beta = data.beta;

    if (beta > 0) {
      if (beta <= 0.8) {
        score += 20;
      } else if (beta <= 1.2) {
        score += 10;
      } else if (beta <= 1.5) {
        score -= 5;
      } else if (beta <= 2) {
        score -= 15;
      } else {
        score -= 30;
      }
    }

    if (data.currentRatio > 0 &&
        data.currentRatio < 1) {
      score -= 20;
    }

    return score.clamp(0, 100);
  }
}