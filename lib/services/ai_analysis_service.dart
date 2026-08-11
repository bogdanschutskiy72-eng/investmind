import 'dart:convert';

import 'package:http/http.dart' as http;

import 'company_profile_service.dart';
import 'historical_price_service.dart';
import 'investmind_score_service.dart';
import 'stock_service.dart';

class AiCompanyAnalysisInput {
  final String symbol;
  final String companyName;
  final String industry;

  final double currentPrice;
  final double dailyChangePercent;

  final double periodChangePercent;
  final double volatilityPercent;
  final double maxDrawdownPercent;

  final double movingAverage20;
  final double movingAverage50;

  final double trendStrengthPercent;
  final double trendSlopePercentPerDay;

  final double marketCapitalization;

  final int investMindScore;
  final String investMindRating;

  final List<String> strengths;
  final List<String> warnings;

  const AiCompanyAnalysisInput({
    required this.symbol,
    required this.companyName,
    required this.industry,
    required this.currentPrice,
    required this.dailyChangePercent,
    required this.periodChangePercent,
    required this.volatilityPercent,
    required this.maxDrawdownPercent,
    required this.movingAverage20,
    required this.movingAverage50,
    required this.trendStrengthPercent,
    required this.trendSlopePercentPerDay,
    required this.marketCapitalization,
    required this.investMindScore,
    required this.investMindRating,
    required this.strengths,
    required this.warnings,
  });

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'companyName': companyName,
      'industry': industry,
      'currentPrice': currentPrice,
      'dailyChangePercent': dailyChangePercent,
      'periodChangePercent': periodChangePercent,
      'volatilityPercent': volatilityPercent,
      'maxDrawdownPercent': maxDrawdownPercent,
      'movingAverage20': movingAverage20,
      'movingAverage50': movingAverage50,
      'trendStrengthPercent': trendStrengthPercent,
      'trendSlopePercentPerDay': trendSlopePercentPerDay,
      'marketCapitalization': marketCapitalization,
      'investMindScore': investMindScore,
      'investMindRating': investMindRating,
      'strengths': strengths,
      'warnings': warnings,
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
    required InvestMindScoreResult score,
  }) {
    return AiCompanyAnalysisInput(
      symbol: profile.ticker,
      companyName: profile.name,
      industry: profile.industry,
      currentPrice: quote.currentPrice,
      dailyChangePercent: quote.percentChange,
      periodChangePercent: historical.periodChangePercent,
      volatilityPercent: historical.annualizedVolatilityPercent,
      maxDrawdownPercent: historical.maxDrawdownPercent,
      movingAverage20: historical.movingAverage20,
      movingAverage50: historical.movingAverage50,
      trendStrengthPercent: historical.trendStrengthPercent,
      trendSlopePercentPerDay: historical.trendSlopePercentPerDay,
      marketCapitalization: profile.marketCapitalization,
      investMindScore: score.score,
      investMindRating: score.rating,
      strengths: List<String>.from(score.strengths),
      warnings: List<String>.from(score.warnings),
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
