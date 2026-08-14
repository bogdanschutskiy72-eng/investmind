import 'dart:convert';

import 'package:http/http.dart' as http;

import 'combined_score_service.dart';
import 'company_profile_service.dart';
import 'fundamental_score_service.dart';
import 'fundamental_service.dart';
import 'historical_price_service.dart';
import 'investmind_score_service.dart';
import 'stock_service.dart';

class AiCompanyAnalysisInput {
  final String symbol;
  final String companyName;
  final String industry;

  // Market
  final double currentPrice;
  final double dailyChangePercent;
  final double marketCapitalization;

  // Technical
  final double periodChangePercent;
  final double volatilityPercent;
  final double maxDrawdownPercent;
  final double movingAverage20;
  final double movingAverage50;
  final double trendStrengthPercent;
  final double trendSlopePercentPerDay;

  // Fundamental
  final double? pe;
  final double? forwardPe;
  final double? priceToSales;
  final double? eps;
  final double? epsGrowthPercent;
  final double? revenueGrowthPercent;
  final double? grossMarginPercent;
  final double? netMarginPercent;
  final double? roePercent;
  final double? currentRatio;
  final double? quickRatio;
  final double? debtToEquity;
  final double? freeCashFlowPerShare;
  final double? beta;
  final double? week52High;
  final double? week52Low;

  // Scores
  final int technicalScore;
  final int fundamentalScore;
  final int combinedScore;

  final int growthScore;
  final int profitabilityScore;
  final int valuationScore;
  final int financialHealthScore;
  final int fundamentalRiskScore;

  // InvestMind reliability
  final int fundamentalDataCompleteness;
  final int confidenceScore;

  // Dynamic weights
  final double technicalWeight;
  final double fundamentalWeight;

  final String combinedRating;

  final List<String> technicalStrengths;
  final List<String> technicalWarnings;

  final List<String> fundamentalStrengths;
  final List<String> fundamentalWarnings;

  const AiCompanyAnalysisInput({
    required this.symbol,
    required this.companyName,
    required this.industry,
    required this.currentPrice,
    required this.dailyChangePercent,
    required this.marketCapitalization,
    required this.periodChangePercent,
    required this.volatilityPercent,
    required this.maxDrawdownPercent,
    required this.movingAverage20,
    required this.movingAverage50,
    required this.trendStrengthPercent,
    required this.trendSlopePercentPerDay,
    required this.pe,
    required this.forwardPe,
    required this.priceToSales,
    required this.eps,
    required this.epsGrowthPercent,
    required this.revenueGrowthPercent,
    required this.grossMarginPercent,
    required this.netMarginPercent,
    required this.roePercent,
    required this.currentRatio,
    required this.quickRatio,
    required this.debtToEquity,
    required this.freeCashFlowPerShare,
    required this.beta,
    required this.week52High,
    required this.week52Low,
    required this.technicalScore,
    required this.fundamentalScore,
    required this.combinedScore,
    required this.growthScore,
    required this.profitabilityScore,
    required this.valuationScore,
    required this.financialHealthScore,
    required this.fundamentalRiskScore,
    required this.fundamentalDataCompleteness,
    required this.confidenceScore,
    required this.technicalWeight,
    required this.fundamentalWeight,
    required this.combinedRating,
    required this.technicalStrengths,
    required this.technicalWarnings,
    required this.fundamentalStrengths,
    required this.fundamentalWarnings,
  });

  Map<String, dynamic> toJson() {
    return {
      'company': {
        'symbol': symbol,
        'name': companyName,
        'industry': industry,
        'marketCapitalization': marketCapitalization,
      },
      'market': {
        'currentPrice': currentPrice,
        'dailyChangePercent': dailyChangePercent,
      },
      'technical': {
        'periodChangePercent': periodChangePercent,
        'volatilityPercent': volatilityPercent,
        'maxDrawdownPercent': maxDrawdownPercent,
        'movingAverage20': movingAverage20,
        'movingAverage50': movingAverage50,
        'trendStrengthPercent': trendStrengthPercent,
        'trendSlopePercentPerDay': trendSlopePercentPerDay,
        'score': technicalScore,
        'strengths': technicalStrengths,
        'warnings': technicalWarnings,
      },
      'fundamental': {
        'pe': pe,
        'forwardPe': forwardPe,
        'priceToSales': priceToSales,
        'eps': eps,
        'epsGrowthPercent': epsGrowthPercent,
        'revenueGrowthPercent': revenueGrowthPercent,
        'grossMarginPercent': grossMarginPercent,
        'netMarginPercent': netMarginPercent,
        'roePercent': roePercent,
        'currentRatio': currentRatio,
        'quickRatio': quickRatio,
        'debtToEquity': debtToEquity,
        'freeCashFlowPerShare': freeCashFlowPerShare,
        'beta': beta,
        'week52High': week52High,
        'week52Low': week52Low,
        'score': fundamentalScore,
        'growthScore': growthScore,
        'profitabilityScore': profitabilityScore,
        'valuationScore': valuationScore,
        'financialHealthScore': financialHealthScore,
        'riskScore': fundamentalRiskScore,
        'dataCompletenessPercent': fundamentalDataCompleteness,
        'strengths': fundamentalStrengths,
        'warnings': fundamentalWarnings,
      },
      'investMind': {
        'combinedScore': combinedScore,
        'rating': combinedRating,
        'technicalWeight': technicalWeight,
        'fundamentalWeight': fundamentalWeight,
        'confidenceScore': confidenceScore,
      },
    };
  }
}

class AiStructuredAnalysis {
  final String summary;
  final List<String> strengths;
  final List<String> risks;
  final List<String> watch;
  final int confidence;

  const AiStructuredAnalysis({
    required this.summary,
    required this.strengths,
    required this.risks,
    required this.watch,
    required this.confidence,
  });

  factory AiStructuredAnalysis.fromJson(Map<String, dynamic> json) {
    return AiStructuredAnalysis(
      summary: json['summary']?.toString() ?? '',
      strengths: _stringListFrom(json['strengths']),
      risks: _stringListFrom(json['risks']),
      watch: _stringListFrom(json['watch']),
      confidence: _intFrom(json['confidence']),
    );
  }

  static List<String> _stringListFrom(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value.map((item) => item.toString()).toList();
  }

  static int _intFrom(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AiBackendResponse {
  final String status;
  final String message;
  final AiStructuredAnalysis analysis;

  const AiBackendResponse({
    required this.status,
    required this.message,
    required this.analysis,
  });

  factory AiBackendResponse.fromJson(Map<String, dynamic> json) {
    final dynamic rawAnalysis = json['analysis'];

    if (rawAnalysis is! Map) {
      throw Exception('Backend вернул некорректный AI-анализ.');
    }

    final Map<String, dynamic> analysisData = Map<String, dynamic>.from(
      rawAnalysis,
    );

    return AiBackendResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      analysis: AiStructuredAnalysis.fromJson(analysisData),
    );
  }
}

class AiAnalysisService {
  const AiAnalysisService();

  static const String _backendBaseUrl = 'http://localhost:3000';

  AiCompanyAnalysisInput buildCompanyInput({
    required StockQuote quote,
    required CompanyProfile profile,
    required HistoricalPriceAnalysis historical,
    required FundamentalData fundamentals,
    required InvestMindScoreResult technicalScore,
    required FundamentalScoreResult fundamentalScore,
    required CombinedScoreResult combinedScore,
    required int confidenceScore,
  }) {
    return AiCompanyAnalysisInput(
      symbol: profile.ticker,
      companyName: profile.name,
      industry: profile.industry,

      // Market
      currentPrice: quote.currentPrice,
      dailyChangePercent: quote.percentChange,
      marketCapitalization: profile.marketCapitalization,

      // Technical
      periodChangePercent: historical.periodChangePercent,
      volatilityPercent: historical.annualizedVolatilityPercent,
      maxDrawdownPercent: historical.maxDrawdownPercent,
      movingAverage20: historical.movingAverage20,
      movingAverage50: historical.movingAverage50,
      trendStrengthPercent: historical.trendStrengthPercent,
      trendSlopePercentPerDay: historical.trendSlopePercentPerDay,

      // Fundamental
      pe: fundamentals.hasPeData ? fundamentals.pe : null,

      forwardPe: fundamentals.hasForwardPeData ? fundamentals.forwardPe : null,

      priceToSales: fundamentals.hasPriceToSalesData
          ? fundamentals.priceToSales
          : null,

      eps: fundamentals.hasEpsData ? fundamentals.eps : null,

      epsGrowthPercent: fundamentals.hasEpsGrowthData
          ? fundamentals.epsGrowthPercent
          : null,

      revenueGrowthPercent: fundamentals.hasRevenueGrowthData
          ? fundamentals.revenueGrowthPercent
          : null,

      grossMarginPercent: fundamentals.hasGrossMarginData
          ? fundamentals.grossMarginPercent
          : null,

      netMarginPercent: fundamentals.hasNetMarginData
          ? fundamentals.netMarginPercent
          : null,

      roePercent: fundamentals.hasRoeData ? fundamentals.roePercent : null,

      currentRatio: fundamentals.hasCurrentRatioData
          ? fundamentals.currentRatio
          : null,

      quickRatio: fundamentals.hasQuickRatioData
          ? fundamentals.quickRatio
          : null,

      debtToEquity: fundamentals.hasDebtToEquityData
          ? fundamentals.debtToEquity
          : null,

      freeCashFlowPerShare: fundamentals.hasFreeCashFlowPerShareData
          ? fundamentals.freeCashFlowPerShare
          : null,

      beta: fundamentals.hasBetaData ? fundamentals.beta : null,

      week52High: fundamentals.hasWeek52HighData
          ? fundamentals.week52High
          : null,

      week52Low: fundamentals.hasWeek52LowData ? fundamentals.week52Low : null,

      // Scores
      technicalScore: technicalScore.score,
      fundamentalScore: fundamentalScore.score,
      combinedScore: combinedScore.score,

      growthScore: fundamentalScore.growthScore,
      profitabilityScore: fundamentalScore.profitabilityScore,
      valuationScore: fundamentalScore.valuationScore,
      financialHealthScore: fundamentalScore.financialHealthScore,
      fundamentalRiskScore: fundamentalScore.riskScore,

      // Reliability
      fundamentalDataCompleteness: fundamentals.dataCompletenessPercent,
      confidenceScore: confidenceScore,

      // Dynamic weights
      technicalWeight: combinedScore.technicalWeight,
      fundamentalWeight: combinedScore.fundamentalWeight,

      combinedRating: combinedScore.rating,

      technicalStrengths: List<String>.from(technicalScore.strengths),

      technicalWarnings: List<String>.from(technicalScore.warnings),

      fundamentalStrengths: List<String>.from(fundamentalScore.strengths),

      fundamentalWarnings: List<String>.from(fundamentalScore.warnings),
    );
  }

  Future<AiBackendResponse> sendToBackend(AiCompanyAnalysisInput input) async {
    final Uri uri = Uri.parse('$_backendBaseUrl/api/analyze');

    final http.Response response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 30));

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception('Backend вернул некорректный ответ.');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

    if (response.statusCode != 200) {
      throw Exception(
        data['message']?.toString() ?? 'Ошибка backend: ${response.statusCode}',
      );
    }

    return AiBackendResponse.fromJson(data);
  }
}
