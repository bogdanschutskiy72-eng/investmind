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

enum SectorProfile { semiconductors, automotive, generic }

class FundamentalScoreService {
  const FundamentalScoreService();

  FundamentalScoreResult calculate(
    FundamentalData data, {
    required String industry,
  }) {
    final SectorProfile sectorProfile = _resolveSectorProfile(industry);

    final int growthScore = _calculateGrowthScore(data, sectorProfile);

    final int profitabilityScore = _calculateProfitabilityScore(data);

    final int valuationScore = _calculateValuationScore(data, sectorProfile);

    final int financialHealthScore = _calculateFinancialHealthScore(data);

    final int riskScore = _calculateRiskScore(data);

    final double weightedScore =
        growthScore * 0.25 +
        profitabilityScore * 0.25 +
        valuationScore * 0.20 +
        financialHealthScore * 0.15 +
        riskScore * 0.15;

    final int totalScore = weightedScore.round().clamp(0, 100);

    final List<String> strengths = [];
    final List<String> warnings = [];

    if (data.hasRevenueGrowthData &&
        _isStrongGrowth(data.revenueGrowthPercent, sectorProfile)) {
      strengths.add(
        'Сильный рост выручки: '
        '${data.revenueGrowthPercent.toStringAsFixed(1)}%',
      );
    }

    if (data.hasEpsGrowthData &&
        _isStrongGrowth(data.epsGrowthPercent, sectorProfile)) {
      strengths.add(
        'Сильный рост EPS: '
        '${data.epsGrowthPercent.toStringAsFixed(1)}%',
      );
    }

    if (data.hasNetMarginData && data.netMarginPercent >= 20) {
      strengths.add(
        'Высокая чистая маржа: '
        '${data.netMarginPercent.toStringAsFixed(1)}%',
      );
    }

    if (data.hasRoeData && data.roePercent >= 20) {
      strengths.add(
        'Высокий ROE: '
        '${data.roePercent.toStringAsFixed(1)}%',
      );
    }

    if (data.hasCurrentRatioData && data.currentRatio >= 1.5) {
      strengths.add('Хорошая краткосрочная ликвидность.');
    }

    if (data.hasQuickRatioData && data.quickRatio >= 1.0) {
      strengths.add(
        'Quick Ratio указывает на хорошую '
        'ликвидность без учёта запасов.',
      );
    }

    if (data.hasDebtToEquityData && data.debtToEquity <= 0.5) {
      strengths.add('Долговая нагрузка относительно капитала низкая.');
    }

    if (data.hasFreeCashFlowPerShareData && data.freeCashFlowPerShare > 0) {
      strengths.add(
        'Компания генерирует положительный '
        'свободный денежный поток на акцию.',
      );
    }

    if (data.hasPeData && _isExpensivePe(data.pe, sectorProfile)) {
      warnings.add(
        'P/E выглядит высоким относительно '
        'отраслевого профиля.',
      );
    }

    if (data.hasPriceToSalesData &&
        _isExpensivePs(data.priceToSales, sectorProfile)) {
      warnings.add(
        'P/S выглядит высоким относительно '
        'отраслевого профиля.',
      );
    }

    if (data.hasBetaData && data.beta >= 1.5) {
      warnings.add(
        'Beta ${data.beta.toStringAsFixed(2)} '
        'указывает на повышенную чувствительность '
        'акции к движениям рынка.',
      );
    }

    if (data.hasRevenueGrowthData && data.revenueGrowthPercent < 0) {
      warnings.add('Выручка сокращается.');
    }

    if (data.hasEpsGrowthData && data.epsGrowthPercent < 0) {
      warnings.add('EPS показывает отрицательную динамику.');
    }

    if (data.hasCurrentRatioData && data.currentRatio < 1) {
      warnings.add(
        'Current Ratio ниже 1 — '
        'ликвидность требует внимания.',
      );
    }

    if (data.hasQuickRatioData && data.quickRatio < 0.8) {
      warnings.add(
        'Quick Ratio ниже 0.8 — '
        'ликвидность без учёта запасов слабая.',
      );
    }

    if (data.hasDebtToEquityData && data.debtToEquity >= 2.0) {
      warnings.add(
        'Высокое соотношение долга к капиталу '
        'повышает финансовый риск.',
      );
    }

    if (data.hasFreeCashFlowPerShareData && data.freeCashFlowPerShare < 0) {
      warnings.add('Свободный денежный поток на акцию отрицательный.');
    }

    return FundamentalScoreResult(
      score: totalScore,
      growthScore: growthScore,
      profitabilityScore: profitabilityScore,
      valuationScore: valuationScore,
      financialHealthScore: financialHealthScore,
      riskScore: riskScore,
      strengths: strengths,
      warnings: warnings,
    );
  }

  SectorProfile _resolveSectorProfile(String industry) {
    final String value = industry.toLowerCase();

    if (value.contains('semiconductor') || value.contains('chip')) {
      return SectorProfile.semiconductors;
    }

    if (value.contains('automotive') ||
        value.contains('automobile') ||
        value.contains('vehicle') ||
        value.contains('auto manufacturer')) {
      return SectorProfile.automotive;
    }

    return SectorProfile.generic;
  }

  int _calculateGrowthScore(FundamentalData data, SectorProfile sectorProfile) {
    int score = 50;
    int usedMetrics = 0;

    if (data.hasRevenueGrowthData) {
      score += _growthPoints(data.revenueGrowthPercent, sectorProfile);
      usedMetrics++;
    }

    if (data.hasEpsGrowthData) {
      score += _growthPoints(data.epsGrowthPercent, sectorProfile);
      usedMetrics++;
    }

    if (usedMetrics == 0) {
      return 50;
    }

    return score.clamp(0, 100);
  }

  int _growthPoints(double growth, SectorProfile sectorProfile) {
    switch (sectorProfile) {
      case SectorProfile.semiconductors:
        if (growth >= 35) {
          return 25;
        }

        if (growth >= 20) {
          return 18;
        }

        if (growth >= 10) {
          return 10;
        }

        if (growth >= 0) {
          return 3;
        }

        if (growth >= -10) {
          return -10;
        }

        return -25;

      case SectorProfile.automotive:
        if (growth >= 20) {
          return 25;
        }

        if (growth >= 10) {
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

      case SectorProfile.generic:
        if (growth >= 30) {
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
  }

  bool _isStrongGrowth(double growth, SectorProfile sectorProfile) {
    switch (sectorProfile) {
      case SectorProfile.semiconductors:
        return growth >= 20;

      case SectorProfile.automotive:
        return growth >= 10;

      case SectorProfile.generic:
        return growth >= 15;
    }
  }

  int _calculateProfitabilityScore(FundamentalData data) {
    int score = 50;

    if (data.hasNetMarginData) {
      final double netMargin = data.netMarginPercent;

      if (netMargin >= 25) {
        score += 25;
      } else if (netMargin >= 15) {
        score += 18;
      } else if (netMargin >= 8) {
        score += 10;
      } else if (netMargin > 0) {
        score += 3;
      } else if (netMargin < 0) {
        score -= 20;
      }
    }

    if (data.hasRoeData) {
      final double roe = data.roePercent;

      if (roe >= 25) {
        score += 25;
      } else if (roe >= 15) {
        score += 15;
      } else if (roe >= 8) {
        score += 8;
      } else if (roe > 0) {
        score += 2;
      } else if (roe < 0) {
        score -= 15;
      }
    }

    return score.clamp(0, 100);
  }

  int _calculateValuationScore(
    FundamentalData data,
    SectorProfile sectorProfile,
  ) {
    int score = 50;

    if (data.hasPeData) {
      score += _pePoints(data.pe, sectorProfile);
    }

    if (data.hasPriceToSalesData) {
      score += _psPoints(data.priceToSales, sectorProfile);
    }

    if (data.hasForwardPeData && data.hasPeData && data.forwardPe < data.pe) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  int _pePoints(double pe, SectorProfile sectorProfile) {
    switch (sectorProfile) {
      case SectorProfile.semiconductors:
        if (pe <= 20) {
          return 20;
        }

        if (pe <= 30) {
          return 12;
        }

        if (pe <= 45) {
          return 5;
        }

        if (pe <= 65) {
          return -10;
        }

        return -25;

      case SectorProfile.automotive:
        if (pe <= 8) {
          return 25;
        }

        if (pe <= 12) {
          return 15;
        }

        if (pe <= 18) {
          return 5;
        }

        if (pe <= 25) {
          return -10;
        }

        return -25;

      case SectorProfile.generic:
        if (pe <= 15) {
          return 25;
        }

        if (pe <= 25) {
          return 15;
        }

        if (pe <= 35) {
          return 5;
        }

        if (pe <= 50) {
          return -10;
        }

        return -25;
    }
  }

  int _psPoints(double ps, SectorProfile sectorProfile) {
    switch (sectorProfile) {
      case SectorProfile.semiconductors:
        if (ps <= 4) {
          return 20;
        }

        if (ps <= 8) {
          return 10;
        }

        if (ps <= 12) {
          return -5;
        }

        return -20;

      case SectorProfile.automotive:
        if (ps <= 1) {
          return 20;
        }

        if (ps <= 2) {
          return 10;
        }

        if (ps <= 4) {
          return -5;
        }

        return -20;

      case SectorProfile.generic:
        if (ps <= 3) {
          return 20;
        }

        if (ps <= 6) {
          return 10;
        }

        if (ps <= 10) {
          return -5;
        }

        return -20;
    }
  }

  bool _isExpensivePe(double pe, SectorProfile sectorProfile) {
    switch (sectorProfile) {
      case SectorProfile.semiconductors:
        return pe > 45;

      case SectorProfile.automotive:
        return pe > 18;

      case SectorProfile.generic:
        return pe > 35;
    }
  }

  bool _isExpensivePs(double ps, SectorProfile sectorProfile) {
    switch (sectorProfile) {
      case SectorProfile.semiconductors:
        return ps > 8;

      case SectorProfile.automotive:
        return ps > 2;

      case SectorProfile.generic:
        return ps > 6;
    }
  }

  int _calculateFinancialHealthScore(FundamentalData data) {
    int score = 50;

    if (data.hasCurrentRatioData) {
      final double currentRatio = data.currentRatio;

      if (currentRatio >= 2) {
        score += 20;
      } else if (currentRatio >= 1.5) {
        score += 15;
      } else if (currentRatio >= 1) {
        score += 5;
      } else {
        score -= 20;
      }
    }

    if (data.hasQuickRatioData) {
      final double quickRatio = data.quickRatio;

      if (quickRatio >= 1.5) {
        score += 15;
      } else if (quickRatio >= 1) {
        score += 10;
      } else if (quickRatio < 0.8) {
        score -= 15;
      }
    }

    if (data.hasDebtToEquityData) {
      final double debtToEquity = data.debtToEquity;

      if (debtToEquity <= 0.5) {
        score += 10;
      } else if (debtToEquity <= 1.0) {
        score += 5;
      } else if (debtToEquity <= 2.0) {
        score -= 5;
      } else {
        score -= 15;
      }
    }

    if (data.hasFreeCashFlowPerShareData) {
      if (data.freeCashFlowPerShare > 0) {
        score += 10;
      } else if (data.freeCashFlowPerShare < 0) {
        score -= 15;
      }
    }

    return score.clamp(0, 100);
  }

  int _calculateRiskScore(FundamentalData data) {
    int score = 70;

    if (data.hasBetaData) {
      final double beta = data.beta;

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

    if (data.hasCurrentRatioData && data.currentRatio < 1) {
      score -= 15;
    }

    if (data.hasQuickRatioData && data.quickRatio < 0.8) {
      score -= 10;
    }

    if (data.hasDebtToEquityData) {
      if (data.debtToEquity >= 3.0) {
        score -= 20;
      } else if (data.debtToEquity >= 2.0) {
        score -= 10;
      }
    }

    if (data.hasFreeCashFlowPerShareData && data.freeCashFlowPerShare < 0) {
      score -= 15;
    }

    return score.clamp(0, 100);
  }
}
