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

enum SectorProfile {
  semiconductors,
  technology,
  financials,
  consumerStaples,
  consumerDiscretionary,
  energy,
  healthcare,
  automotive,
  industrials,
  utilities,
  realEstate,
  generic,
}

class _ScoreWeights {
  final double growth;
  final double profitability;
  final double valuation;
  final double financialHealth;
  final double risk;

  const _ScoreWeights({
    required this.growth,
    required this.profitability,
    required this.valuation,
    required this.financialHealth,
    required this.risk,
  });
}

class FundamentalScoreService {
  const FundamentalScoreService();

  FundamentalScoreResult calculate(
    FundamentalData data, {
    required String industry,
  }) {
    final SectorProfile sectorProfile = _resolveSectorProfile(industry);

    final _ScoreWeights weights = _weightsFor(sectorProfile);

    final int growthScore = _calculateGrowthScore(data, sectorProfile);

    final int profitabilityScore = _calculateProfitabilityScore(
      data,
      sectorProfile,
    );

    final int valuationScore = _calculateValuationScore(data, sectorProfile);

    final int financialHealthScore = _calculateFinancialHealthScore(
      data,
      sectorProfile,
    );

    final int riskScore = _calculateRiskScore(data, sectorProfile);

    final double weightedScore =
        growthScore * weights.growth +
        profitabilityScore * weights.profitability +
        valuationScore * weights.valuation +
        financialHealthScore * weights.financialHealth +
        riskScore * weights.risk;

    final int totalScore = _clampScore(weightedScore.round());

    final List<String> strengths = [];
    final List<String> warnings = [];

    _buildStrengths(
      data: data,
      sectorProfile: sectorProfile,
      strengths: strengths,
    );

    _buildWarnings(
      data: data,
      sectorProfile: sectorProfile,
      warnings: warnings,
    );

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

  // ------------------------------------------------------------
  // Sector profile
  // ------------------------------------------------------------

  SectorProfile _resolveSectorProfile(String industry) {
    final String value = industry.toLowerCase().trim();

    if (value.contains('semiconductor') || value.contains('chip')) {
      return SectorProfile.semiconductors;
    }

    if (value.contains('bank') ||
        value.contains('financial') ||
        value.contains('capital market') ||
        value.contains('insurance') ||
        value.contains('credit service') ||
        value.contains('asset management')) {
      return SectorProfile.financials;
    }

    if (value.contains('software') ||
        value.contains('information technology') ||
        value.contains('it service') ||
        value.contains('computer') ||
        value.contains('internet') ||
        value.contains('technology')) {
      return SectorProfile.technology;
    }

    if (value.contains('beverage') ||
        value.contains('food') ||
        value.contains('tobacco') ||
        value.contains('household') ||
        value.contains('personal product') ||
        value.contains('consumer defensive') ||
        value.contains('consumer staples')) {
      return SectorProfile.consumerStaples;
    }

    if (value.contains('retail') ||
        value.contains('restaurant') ||
        value.contains('apparel') ||
        value.contains('leisure') ||
        value.contains('travel') ||
        value.contains('consumer cyclical') ||
        value.contains('consumer discretionary')) {
      return SectorProfile.consumerDiscretionary;
    }

    if (value.contains('oil') ||
        value.contains('gas') ||
        value.contains('energy') ||
        value.contains('petroleum') ||
        value.contains('coal')) {
      return SectorProfile.energy;
    }

    if (value.contains('pharma') ||
        value.contains('biotech') ||
        value.contains('health') ||
        value.contains('medical') ||
        value.contains('drug')) {
      return SectorProfile.healthcare;
    }

    if (value.contains('automotive') ||
        value.contains('automobile') ||
        value.contains('vehicle') ||
        value.contains('auto manufacturer')) {
      return SectorProfile.automotive;
    }

    if (value.contains('industrial') ||
        value.contains('machinery') ||
        value.contains('aerospace') ||
        value.contains('defense') ||
        value.contains('construction') ||
        value.contains('transportation')) {
      return SectorProfile.industrials;
    }

    if (value.contains('utility') ||
        value.contains('utilities') ||
        value.contains('electric') ||
        value.contains('water utility')) {
      return SectorProfile.utilities;
    }

    if (value.contains('reit') || value.contains('real estate')) {
      return SectorProfile.realEstate;
    }

    return SectorProfile.generic;
  }

  // ------------------------------------------------------------
  // Sector weights
  // ------------------------------------------------------------

  _ScoreWeights _weightsFor(SectorProfile sectorProfile) {
    switch (sectorProfile) {
      case SectorProfile.semiconductors:
        return const _ScoreWeights(
          growth: 0.30,
          profitability: 0.25,
          valuation: 0.20,
          financialHealth: 0.10,
          risk: 0.15,
        );

      case SectorProfile.technology:
        return const _ScoreWeights(
          growth: 0.30,
          profitability: 0.25,
          valuation: 0.20,
          financialHealth: 0.10,
          risk: 0.15,
        );

      case SectorProfile.financials:
        return const _ScoreWeights(
          growth: 0.15,
          profitability: 0.30,
          valuation: 0.25,
          financialHealth: 0.15,
          risk: 0.15,
        );

      case SectorProfile.consumerStaples:
        return const _ScoreWeights(
          growth: 0.15,
          profitability: 0.30,
          valuation: 0.20,
          financialHealth: 0.20,
          risk: 0.15,
        );

      case SectorProfile.consumerDiscretionary:
        return const _ScoreWeights(
          growth: 0.25,
          profitability: 0.25,
          valuation: 0.20,
          financialHealth: 0.15,
          risk: 0.15,
        );

      case SectorProfile.energy:
        return const _ScoreWeights(
          growth: 0.15,
          profitability: 0.25,
          valuation: 0.20,
          financialHealth: 0.20,
          risk: 0.20,
        );

      case SectorProfile.healthcare:
        return const _ScoreWeights(
          growth: 0.25,
          profitability: 0.25,
          valuation: 0.20,
          financialHealth: 0.15,
          risk: 0.15,
        );

      case SectorProfile.automotive:
        return const _ScoreWeights(
          growth: 0.20,
          profitability: 0.25,
          valuation: 0.20,
          financialHealth: 0.20,
          risk: 0.15,
        );

      case SectorProfile.industrials:
        return const _ScoreWeights(
          growth: 0.20,
          profitability: 0.25,
          valuation: 0.20,
          financialHealth: 0.20,
          risk: 0.15,
        );

      case SectorProfile.utilities:
        return const _ScoreWeights(
          growth: 0.10,
          profitability: 0.25,
          valuation: 0.20,
          financialHealth: 0.25,
          risk: 0.20,
        );

      case SectorProfile.realEstate:
        return const _ScoreWeights(
          growth: 0.15,
          profitability: 0.20,
          valuation: 0.20,
          financialHealth: 0.25,
          risk: 0.20,
        );

      case SectorProfile.generic:
        return const _ScoreWeights(
          growth: 0.25,
          profitability: 0.25,
          valuation: 0.20,
          financialHealth: 0.15,
          risk: 0.15,
        );
    }
  }

  // ------------------------------------------------------------
  // Growth
  // ------------------------------------------------------------

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

    return _clampScore(score);
  }

  int _growthPoints(double growth, SectorProfile sectorProfile) {
    final double strong = _strongGrowthThreshold(sectorProfile);

    final double good = strong * 0.55;

    final double moderate = strong * 0.25;

    if (growth >= strong * 1.5) {
      return 25;
    }

    if (growth >= strong) {
      return 18;
    }

    if (growth >= good) {
      return 12;
    }

    if (growth >= moderate) {
      return 7;
    }

    if (growth >= 0) {
      return 2;
    }

    if (growth >= -10) {
      return -10;
    }

    return -25;
  }

  double _strongGrowthThreshold(SectorProfile sectorProfile) {
    switch (sectorProfile) {
      case SectorProfile.semiconductors:
        return 20;

      case SectorProfile.technology:
        return 18;

      case SectorProfile.financials:
        return 10;

      case SectorProfile.consumerStaples:
        return 8;

      case SectorProfile.consumerDiscretionary:
        return 12;

      case SectorProfile.energy:
        return 15;

      case SectorProfile.healthcare:
        return 15;

      case SectorProfile.automotive:
        return 10;

      case SectorProfile.industrials:
        return 10;

      case SectorProfile.utilities:
        return 6;

      case SectorProfile.realEstate:
        return 8;

      case SectorProfile.generic:
        return 15;
    }
  }

  bool _isStrongGrowth(double growth, SectorProfile sectorProfile) {
    return growth >= _strongGrowthThreshold(sectorProfile);
  }

  // ------------------------------------------------------------
  // Profitability
  // ------------------------------------------------------------

  int _calculateProfitabilityScore(
    FundamentalData data,
    SectorProfile sectorProfile,
  ) {
    int score = 50;

    if (data.hasNetMarginData) {
      score += _netMarginPoints(data.netMarginPercent, sectorProfile);
    }

    if (data.hasRoeData) {
      score += _roePoints(data.roePercent, sectorProfile);
    }

    return _clampScore(score);
  }

  int _netMarginPoints(double margin, SectorProfile sectorProfile) {
    if (margin < 0) {
      return -25;
    }

    switch (sectorProfile) {
      case SectorProfile.technology:
      case SectorProfile.semiconductors:
        if (margin >= 25) {
          return 25;
        }

        if (margin >= 15) {
          return 18;
        }

        if (margin >= 8) {
          return 10;
        }

        return 3;

      case SectorProfile.consumerStaples:
        if (margin >= 20) {
          return 25;
        }

        if (margin >= 12) {
          return 18;
        }

        if (margin >= 7) {
          return 10;
        }

        return 3;

      case SectorProfile.automotive:
      case SectorProfile.industrials:
        if (margin >= 12) {
          return 25;
        }

        if (margin >= 8) {
          return 18;
        }

        if (margin >= 4) {
          return 10;
        }

        return 3;

      case SectorProfile.financials:
        if (margin >= 25) {
          return 25;
        }

        if (margin >= 15) {
          return 18;
        }

        if (margin >= 8) {
          return 10;
        }

        return 3;

      case SectorProfile.energy:
        if (margin >= 20) {
          return 25;
        }

        if (margin >= 10) {
          return 18;
        }

        if (margin >= 5) {
          return 10;
        }

        return 3;

      case SectorProfile.healthcare:
        if (margin >= 20) {
          return 25;
        }

        if (margin >= 12) {
          return 18;
        }

        if (margin >= 5) {
          return 10;
        }

        return 3;

      case SectorProfile.utilities:
        if (margin >= 15) {
          return 25;
        }

        if (margin >= 10) {
          return 18;
        }

        if (margin >= 5) {
          return 10;
        }

        return 3;

      case SectorProfile.realEstate:
        if (margin >= 25) {
          return 25;
        }

        if (margin >= 15) {
          return 18;
        }

        if (margin >= 8) {
          return 10;
        }

        return 3;

      case SectorProfile.consumerDiscretionary:
      case SectorProfile.generic:
        if (margin >= 20) {
          return 25;
        }

        if (margin >= 12) {
          return 18;
        }

        if (margin >= 6) {
          return 10;
        }

        return 3;
    }
  }

  int _roePoints(double roe, SectorProfile sectorProfile) {
    if (roe < 0) {
      return -20;
    }

    switch (sectorProfile) {
      case SectorProfile.financials:
        if (roe >= 18) {
          return 25;
        }

        if (roe >= 12) {
          return 18;
        }

        if (roe >= 8) {
          return 10;
        }

        return 2;

      case SectorProfile.utilities:
      case SectorProfile.realEstate:
        if (roe >= 15) {
          return 25;
        }

        if (roe >= 10) {
          return 15;
        }

        if (roe >= 6) {
          return 8;
        }

        return 2;

      default:
        if (roe >= 25) {
          return 25;
        }

        if (roe >= 15) {
          return 15;
        }

        if (roe >= 8) {
          return 8;
        }

        return 2;
    }
  }

  // ------------------------------------------------------------
  // Valuation
  // ------------------------------------------------------------

  int _calculateValuationScore(
    FundamentalData data,
    SectorProfile sectorProfile,
  ) {
    int score = 50;

    if (data.hasPeData && data.pe > 0) {
      score += _pePoints(data.pe, sectorProfile);
    }

    if (data.hasPriceToSalesData && data.priceToSales > 0) {
      score += _psPoints(data.priceToSales, sectorProfile);
    }

    if (data.hasForwardPeData &&
        data.hasPeData &&
        data.forwardPe > 0 &&
        data.pe > 0) {
      final double difference = (data.pe - data.forwardPe) / data.pe;

      if (difference >= 0.25) {
        score += 10;
      } else if (difference >= 0.10) {
        score += 5;
      } else if (data.forwardPe > data.pe * 1.20) {
        score -= 5;
      }
    }

    return _clampScore(score);
  }

  int _pePoints(double pe, SectorProfile sectorProfile) {
    switch (sectorProfile) {
      case SectorProfile.semiconductors:
      case SectorProfile.technology:
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

      case SectorProfile.financials:
        if (pe <= 10) {
          return 22;
        }

        if (pe <= 15) {
          return 15;
        }

        if (pe <= 20) {
          return 5;
        }

        if (pe <= 30) {
          return -10;
        }

        return -25;

      case SectorProfile.consumerStaples:
        if (pe <= 18) {
          return 20;
        }

        if (pe <= 25) {
          return 12;
        }

        if (pe <= 32) {
          return 4;
        }

        if (pe <= 40) {
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

      case SectorProfile.energy:
        if (pe <= 10) {
          return 22;
        }

        if (pe <= 15) {
          return 15;
        }

        if (pe <= 22) {
          return 5;
        }

        if (pe <= 30) {
          return -10;
        }

        return -25;

      case SectorProfile.healthcare:
        if (pe <= 18) {
          return 20;
        }

        if (pe <= 28) {
          return 12;
        }

        if (pe <= 40) {
          return 5;
        }

        if (pe <= 55) {
          return -10;
        }

        return -25;

      case SectorProfile.utilities:
        if (pe <= 15) {
          return 20;
        }

        if (pe <= 22) {
          return 12;
        }

        if (pe <= 30) {
          return 4;
        }

        if (pe <= 40) {
          return -10;
        }

        return -25;

      case SectorProfile.realEstate:
        if (pe <= 20) {
          return 15;
        }

        if (pe <= 30) {
          return 8;
        }

        if (pe <= 45) {
          return 2;
        }

        if (pe <= 60) {
          return -10;
        }

        return -20;

      case SectorProfile.consumerDiscretionary:
      case SectorProfile.industrials:
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
      case SectorProfile.technology:
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

      case SectorProfile.financials:
        if (ps <= 2) {
          return 12;
        }

        if (ps <= 4) {
          return 5;
        }

        if (ps <= 7) {
          return -5;
        }

        return -15;

      case SectorProfile.consumerStaples:
        if (ps <= 3) {
          return 20;
        }

        if (ps <= 5) {
          return 10;
        }

        if (ps <= 8) {
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

      case SectorProfile.energy:
        if (ps <= 2) {
          return 20;
        }

        if (ps <= 4) {
          return 10;
        }

        if (ps <= 6) {
          return -5;
        }

        return -20;

      case SectorProfile.healthcare:
        if (ps <= 4) {
          return 20;
        }

        if (ps <= 7) {
          return 10;
        }

        if (ps <= 10) {
          return -5;
        }

        return -20;

      case SectorProfile.utilities:
        if (ps <= 3) {
          return 20;
        }

        if (ps <= 5) {
          return 10;
        }

        if (ps <= 8) {
          return -5;
        }

        return -20;

      case SectorProfile.realEstate:
        if (ps <= 5) {
          return 15;
        }

        if (ps <= 8) {
          return 8;
        }

        if (ps <= 12) {
          return -5;
        }

        return -15;

      case SectorProfile.consumerDiscretionary:
      case SectorProfile.industrials:
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
    return _pePoints(pe, sectorProfile) < 0;
  }

  bool _isExpensivePs(double ps, SectorProfile sectorProfile) {
    return _psPoints(ps, sectorProfile) < 0;
  }

  // ------------------------------------------------------------
  // Financial health
  // ------------------------------------------------------------

  int _calculateFinancialHealthScore(
    FundamentalData data,
    SectorProfile sectorProfile,
  ) {
    int score = 50;

    // Для банков/финансовых компаний Current Ratio
    // и Quick Ratio не оцениваем по правилам обычного бизнеса.
    if (sectorProfile != SectorProfile.financials) {
      if (data.hasCurrentRatioData) {
        final double currentRatio = data.currentRatio;

        if (currentRatio >= 2) {
          score += 18;
        } else if (currentRatio >= 1.5) {
          score += 14;
        } else if (currentRatio >= 1) {
          score += 5;
        } else if (currentRatio >= 0.8) {
          score -= 5;
        } else {
          score -= 18;
        }
      }

      if (data.hasQuickRatioData) {
        final double quickRatio = data.quickRatio;

        if (quickRatio >= 1.5) {
          score += 12;
        } else if (quickRatio >= 1) {
          score += 8;
        } else if (quickRatio >= 0.8) {
          score -= 3;
        } else {
          score -= 12;
        }
      }
    }

    if (data.hasDebtToEquityData) {
      score += _debtPoints(data.debtToEquity, sectorProfile);
    }

    if (data.hasFreeCashFlowPerShareData) {
      if (data.freeCashFlowPerShare > 0) {
        score += 10;
      } else if (data.freeCashFlowPerShare < 0) {
        score -= 15;
      }
    }

    return _clampScore(score);
  }

  int _debtPoints(double debtToEquity, SectorProfile sectorProfile) {
    // Financials используют долг как часть бизнес-модели.
    // Поэтому обычные D/E пороги здесь неприменимы.
    if (sectorProfile == SectorProfile.financials) {
      return 0;
    }

    if (sectorProfile == SectorProfile.utilities ||
        sectorProfile == SectorProfile.realEstate) {
      if (debtToEquity <= 1.0) {
        return 10;
      }

      if (debtToEquity <= 2.0) {
        return 5;
      }

      if (debtToEquity <= 3.5) {
        return -5;
      }

      return -12;
    }

    if (debtToEquity <= 0.5) {
      return 10;
    }

    if (debtToEquity <= 1.0) {
      return 5;
    }

    if (debtToEquity <= 2.0) {
      return -5;
    }

    return -15;
  }

  // ------------------------------------------------------------
  // Risk
  // ------------------------------------------------------------

  int _calculateRiskScore(FundamentalData data, SectorProfile sectorProfile) {
    int score = 70;

    if (data.hasBetaData && data.beta > 0) {
      final double beta = data.beta;

      if (beta <= 0.8) {
        score += 15;
      } else if (beta <= 1.2) {
        score += 8;
      } else if (beta <= 1.5) {
        score -= 5;
      } else if (beta <= 2) {
        score -= 15;
      } else {
        score -= 30;
      }
    }

    if (sectorProfile != SectorProfile.financials) {
      if (data.hasCurrentRatioData && data.currentRatio < 0.8) {
        score -= 12;
      }

      if (data.hasQuickRatioData && data.quickRatio < 0.8) {
        score -= 8;
      }
    }

    if (data.hasDebtToEquityData && sectorProfile != SectorProfile.financials) {
      final double debt = data.debtToEquity;

      if (sectorProfile == SectorProfile.utilities ||
          sectorProfile == SectorProfile.realEstate) {
        if (debt >= 4.0) {
          score -= 15;
        } else if (debt >= 3.0) {
          score -= 8;
        }
      } else {
        if (debt >= 3.0) {
          score -= 20;
        } else if (debt >= 2.0) {
          score -= 10;
        }
      }
    }

    if (data.hasFreeCashFlowPerShareData && data.freeCashFlowPerShare < 0) {
      score -= 15;
    }

    return _clampScore(score);
  }

  // ------------------------------------------------------------
  // Strengths
  // ------------------------------------------------------------

  void _buildStrengths({
    required FundamentalData data,
    required SectorProfile sectorProfile,
    required List<String> strengths,
  }) {
    if (data.hasRevenueGrowthData &&
        _isStrongGrowth(data.revenueGrowthPercent, sectorProfile)) {
      strengths.add(
        'Сильный для отрасли рост выручки: '
        '${data.revenueGrowthPercent.toStringAsFixed(1)}%',
      );
    }

    if (data.hasEpsGrowthData &&
        _isStrongGrowth(data.epsGrowthPercent, sectorProfile)) {
      strengths.add(
        'Сильный для отрасли рост EPS: '
        '${data.epsGrowthPercent.toStringAsFixed(1)}%',
      );
    }

    if (data.hasNetMarginData &&
        _netMarginPoints(data.netMarginPercent, sectorProfile) >= 18) {
      strengths.add(
        'Сильная чистая маржа относительно профиля отрасли: '
        '${data.netMarginPercent.toStringAsFixed(1)}%',
      );
    }

    if (data.hasRoeData && _roePoints(data.roePercent, sectorProfile) >= 15) {
      strengths.add(
        'Сильный ROE: '
        '${data.roePercent.toStringAsFixed(1)}%',
      );
    }

    if (sectorProfile != SectorProfile.financials) {
      if (data.hasCurrentRatioData && data.currentRatio >= 1.5) {
        strengths.add('Хорошая краткосрочная ликвидность.');
      }

      if (data.hasQuickRatioData && data.quickRatio >= 1.0) {
        strengths.add(
          'Quick Ratio указывает на достаточную '
          'быструю ликвидность.',
        );
      }
    }

    if (data.hasDebtToEquityData &&
        sectorProfile != SectorProfile.financials &&
        _debtPoints(data.debtToEquity, sectorProfile) >= 10) {
      strengths.add(
        'Долговая нагрузка выглядит умеренной '
        'для данного отраслевого профиля.',
      );
    }

    if (data.hasFreeCashFlowPerShareData && data.freeCashFlowPerShare > 0) {
      strengths.add(
        'Компания генерирует положительный '
        'свободный денежный поток на акцию.',
      );
    }
  }

  // ------------------------------------------------------------
  // Warnings
  // ------------------------------------------------------------

  void _buildWarnings({
    required FundamentalData data,
    required SectorProfile sectorProfile,
    required List<String> warnings,
  }) {
    if (data.hasPeData &&
        data.pe > 0 &&
        _isExpensivePe(data.pe, sectorProfile)) {
      warnings.add(
        'P/E выглядит высоким относительно '
        'отраслевого профиля.',
      );
    }

    if (data.hasPriceToSalesData &&
        data.priceToSales > 0 &&
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

    if (data.hasNetMarginData && data.netMarginPercent < 0) {
      warnings.add(
        'Чистая маржа отрицательная — бизнес убыточен '
        'по доступным данным.',
      );
    }

    if (data.hasRoeData && data.roePercent < 0) {
      warnings.add('ROE отрицательный.');
    }

    if (sectorProfile != SectorProfile.financials) {
      if (data.hasCurrentRatioData && data.currentRatio < 0.8) {
        warnings.add(
          'Current Ratio указывает на ограниченную '
          'краткосрочную ликвидность.',
        );
      }

      if (data.hasQuickRatioData && data.quickRatio < 0.8) {
        warnings.add(
          'Quick Ratio указывает на слабый запас '
          'быстрой ликвидности.',
        );
      }
    }

    if (data.hasDebtToEquityData && sectorProfile != SectorProfile.financials) {
      final int debtPoints = _debtPoints(data.debtToEquity, sectorProfile);

      if (debtPoints <= -12) {
        warnings.add(
          'Долговая нагрузка выглядит высокой '
          'относительно отраслевого профиля.',
        );
      }
    }

    if (data.hasFreeCashFlowPerShareData && data.freeCashFlowPerShare < 0) {
      warnings.add('Свободный денежный поток на акцию отрицательный.');
    }
  }

  // ------------------------------------------------------------
  // Utility
  // ------------------------------------------------------------

  int _clampScore(int score) {
    if (score < 0) {
      return 0;
    }

    if (score > 100) {
      return 100;
    }

    return score;
  }
}
