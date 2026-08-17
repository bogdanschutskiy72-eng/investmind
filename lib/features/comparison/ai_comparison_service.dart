import 'dart:convert';

import 'package:http/http.dart' as http;

import 'company_comparison.dart';

class AiComparisonCompanyInsight {
  final String symbol;
  final String insight;

  const AiComparisonCompanyInsight({
    required this.symbol,
    required this.insight,
  });

  factory AiComparisonCompanyInsight.fromJson(Map<String, dynamic> json) {
    return AiComparisonCompanyInsight(
      symbol: json['symbol']?.toString() ?? '',
      insight: json['insight']?.toString() ?? '',
    );
  }
}

class AiComparisonResult {
  final String summary;
  final String leader;
  final String leaderReason;
  final List<String> tradeoffs;
  final List<AiComparisonCompanyInsight> companyInsights;
  final List<String> watch;

  const AiComparisonResult({
    required this.summary,
    required this.leader,
    required this.leaderReason,
    required this.tradeoffs,
    required this.companyInsights,
    required this.watch,
  });

  factory AiComparisonResult.fromJson(Map<String, dynamic> json) {
    return AiComparisonResult(
      summary: json['summary']?.toString() ?? '',
      leader: json['leader']?.toString() ?? '',
      leaderReason: json['leaderReason']?.toString() ?? '',
      tradeoffs: _stringList(json['tradeoffs']),
      companyInsights: _companyInsightsFrom(json['companyInsights']),
      watch: _stringList(json['watch']),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value.map((item) => item.toString()).toList();
  }

  static List<AiComparisonCompanyInsight> _companyInsightsFrom(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => AiComparisonCompanyInsight.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}

class AiComparisonBackendResponse {
  final String status;
  final String message;
  final AiComparisonResult comparison;

  const AiComparisonBackendResponse({
    required this.status,
    required this.message,
    required this.comparison,
  });

  factory AiComparisonBackendResponse.fromJson(Map<String, dynamic> json) {
    final dynamic rawComparison = json['comparison'];

    if (rawComparison is! Map) {
      throw Exception('Backend вернул некорректное AI-сравнение.');
    }

    return AiComparisonBackendResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      comparison: AiComparisonResult.fromJson(
        Map<String, dynamic>.from(rawComparison),
      ),
    );
  }
}

class AiComparisonService {
  const AiComparisonService();

  static const String _backendBaseUrl = 'http://localhost:3000';

  Future<AiComparisonBackendResponse> compareCompanies(
    List<CompanyComparison> companies,
  ) async {
    if (companies.length < 2 || companies.length > 4) {
      throw ArgumentError(
        'AI-сравнение поддерживает '
        'от 2 до 4 компаний.',
      );
    }

    final Uri uri = Uri.parse('$_backendBaseUrl/api/compare');

    final Map<String, dynamic> body = {
      'companies': companies.map(_companyToJson).toList(),
    };

    final http.Response response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception('Backend вернул некорректный ответ.');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

    if (response.statusCode != 200) {
      throw Exception(
        data['message']?.toString() ??
            'Ошибка backend: '
                '${response.statusCode}',
      );
    }

    return AiComparisonBackendResponse.fromJson(data);
  }

  Map<String, dynamic> _companyToJson(CompanyComparison company) {
    return {
      'symbol': company.symbol,
      'name': company.companyName,
      'industry': company.industry,
      'investMindScore': company.investMindScore,
      'technicalScore': company.technicalScore,
      'fundamentalScore': company.fundamentalScore,
      'growthScore': company.growthScore,
      'profitabilityScore': company.profitabilityScore,
      'valuationScore': company.valuationScore,
      'financialHealthScore': company.financialHealthScore,
      'riskScore': company.riskScore,
      'confidenceScore': company.confidenceScore,
      'dataCompletenessPercent': company.dataCompletenessPercent,
    };
  }
}
