import 'dart:convert';

import 'package:http/http.dart' as http;

class FundamentalData {
  final String symbol;

  final double pe;
  final double forwardPe;
  final double priceToSales;

  final double eps;
  final double epsGrowthPercent;
  final double revenueGrowthPercent;

  final double grossMarginPercent;
  final double netMarginPercent;
  final double roePercent;

  final double currentRatio;
  final double quickRatio;
  final double debtToEquity;
  final double freeCashFlowPerShare;

  final double beta;

  final double week52High;
  final double week52Low;

  final Set<String> availableMetrics;

  const FundamentalData({
    required this.symbol,
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
    required this.availableMetrics,
  });

  bool _hasAnyMetric(List<String> keys) {
    return keys.any(availableMetrics.contains);
  }

  bool get hasPeData => _hasAnyMetric(['peTTM', 'peBasicExclExtraTTM']);

  bool get hasForwardPeData => _hasAnyMetric(['forwardPE', 'forwardPe']);

  bool get hasPriceToSalesData => _hasAnyMetric(['psTTM', 'priceToSalesTTM']);

  bool get hasEpsData => _hasAnyMetric(['epsTTM', 'epsBasicExclExtraItemsTTM']);

  bool get hasEpsGrowthData => _hasAnyMetric([
    'epsGrowthTTMYoy',
    'epsGrowthQuarterlyYoy',
    'epsGrowth3Y',
    'epsGrowth5Y',
  ]);

  bool get hasRevenueGrowthData => _hasAnyMetric([
    'revenueGrowthTTMYoy',
    'revenueGrowthQuarterlyYoy',
    'revenueGrowth3Y',
    'revenueGrowth5Y',
  ]);

  bool get hasGrossMarginData =>
      _hasAnyMetric(['grossMarginTTM', 'grossMarginAnnual']);

  bool get hasNetMarginData =>
      _hasAnyMetric(['netProfitMarginTTM', 'netProfitMarginAnnual']);

  bool get hasRoeData => _hasAnyMetric(['roeTTM', 'roeAnnual']);

  bool get hasCurrentRatioData =>
      _hasAnyMetric(['currentRatioQuarterly', 'currentRatioAnnual']);

  bool get hasQuickRatioData =>
      _hasAnyMetric(['quickRatioQuarterly', 'quickRatioAnnual']);

  bool get hasDebtToEquityData => _hasAnyMetric([
    'totalDebt/totalEquityQuarterly',
    'totalDebt/totalEquityAnnual',
  ]);

  bool get hasFreeCashFlowPerShareData => _hasAnyMetric([
    'freeCashFlowPerShareTTM',
    'freeCashFlowPerShareQuarterly',
    'freeCashFlowPerShareAnnual',
  ]);

  bool get hasBetaData => _hasAnyMetric(['beta']);

  bool get hasWeek52HighData => _hasAnyMetric(['52WeekHigh']);

  bool get hasWeek52LowData => _hasAnyMetric(['52WeekLow']);

  // Совместимость с уже существующим UI.
  bool get hasPe => hasPeData;

  bool get hasForwardPe => hasForwardPeData;

  bool get hasPriceToSales => hasPriceToSalesData;

  bool get hasEps => hasEpsData;

  bool get hasRevenueGrowth => hasRevenueGrowthData;

  bool get hasMargins => hasGrossMarginData || hasNetMarginData;

  bool get hasRoe => hasRoeData;

  bool get hasAnyData =>
      hasPeData ||
      hasForwardPeData ||
      hasPriceToSalesData ||
      hasEpsData ||
      hasEpsGrowthData ||
      hasRevenueGrowthData ||
      hasGrossMarginData ||
      hasNetMarginData ||
      hasRoeData ||
      hasCurrentRatioData ||
      hasQuickRatioData ||
      hasDebtToEquityData ||
      hasFreeCashFlowPerShareData ||
      hasBetaData;

  // ------------------------------------------------------------
  // DATA COMPLETENESS// ------------------------------------------------------------
  //
  // Не все показатели одинаково важны.
  // Поэтому полнота считается по весам,
  // а не просто по количеству доступных полей.
  //
  // Общая сумма весов = 100.
  // ------------------------------------------------------------

  int get dataCompletenessPercent {
    int score = 0;

    // Growth — 20
    if (hasRevenueGrowthData) {
      score += 10;
    }

    if (hasEpsGrowthData) {
      score += 10;
    }

    // Profitability — 25
    if (hasNetMarginData) {
      score += 8;
    }

    if (hasRoeData) {
      score += 8;
    }

    if (hasGrossMarginData) {
      score += 4;
    }

    if (hasEpsData) {
      score += 5;
    }

    // Valuation — 20
    if (hasPeData) {
      score += 8;
    }

    if (hasForwardPeData) {
      score += 6;
    }

    if (hasPriceToSalesData) {
      score += 6;
    }

    // Financial health — 29
    if (hasCurrentRatioData) {
      score += 7;
    }

    if (hasQuickRatioData) {
      score += 6;
    }

    if (hasDebtToEquityData) {
      score += 8;
    }

    if (hasFreeCashFlowPerShareData) {
      score += 8;
    }

    // Market risk — 6
    if (hasBetaData) {
      score += 6;
    }

    return score.clamp(0, 100);
  }

  double get dataCompletenessRatio => dataCompletenessPercent / 100.0;

  String get dataCompletenessRating {
    final int value = dataCompletenessPercent;

    if (value >= 90) {
      return 'Очень высокая полнота данных';
    }

    if (value >= 75) {
      return 'Высокая полнота данных';
    }

    if (value >= 60) {
      return 'Средняя полнота данных';
    }

    if (value >= 40) {
      return 'Ограниченная полнота данных';
    }

    return 'Низкая полнота данных';
  }

  List<String> get missingCoreMetrics {
    final List<String> missing = [];

    if (!hasRevenueGrowthData) {
      missing.add('Revenue Growth');
    }

    if (!hasEpsGrowthData) {
      missing.add('EPS Growth');
    }

    if (!hasNetMarginData) {
      missing.add('Net Margin');
    }

    if (!hasRoeData) {
      missing.add('ROE');
    }

    if (!hasGrossMarginData) {
      missing.add('Gross Margin');
    }

    if (!hasEpsData) {
      missing.add('EPS');
    }

    if (!hasPeData) {
      missing.add('P/E');
    }

    if (!hasForwardPeData) {
      missing.add('Forward P/E');
    }

    if (!hasPriceToSalesData) {
      missing.add('P/S');
    }

    if (!hasCurrentRatioData) {
      missing.add('Current Ratio');
    }

    if (!hasQuickRatioData) {
      missing.add('Quick Ratio');
    }

    if (!hasDebtToEquityData) {
      missing.add('Debt/Equity');
    }

    if (!hasFreeCashFlowPerShareData) {
      missing.add('Free Cash Flow per Share');
    }

    if (!hasBetaData) {
      missing.add('Beta');
    }

    return missing;
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,

      'pe': hasPeData ? pe : null,

      'forwardPe': hasForwardPeData ? forwardPe : null,

      'priceToSales': hasPriceToSalesData ? priceToSales : null,

      'eps': hasEpsData ? eps : null,

      'epsGrowthPercent': hasEpsGrowthData ? epsGrowthPercent : null,

      'revenueGrowthPercent': hasRevenueGrowthData
          ? revenueGrowthPercent
          : null,

      'grossMarginPercent': hasGrossMarginData ? grossMarginPercent : null,

      'netMarginPercent': hasNetMarginData ? netMarginPercent : null,

      'roePercent': hasRoeData ? roePercent : null,

      'currentRatio': hasCurrentRatioData ? currentRatio : null,

      'quickRatio': hasQuickRatioData ? quickRatio : null,

      'debtToEquity': hasDebtToEquityData ? debtToEquity : null,

      'freeCashFlowPerShare': hasFreeCashFlowPerShareData
          ? freeCashFlowPerShare
          : null,

      'beta': hasBetaData ? beta : null,

      'week52High': hasWeek52HighData ? week52High : null,

      'week52Low': hasWeek52LowData ? week52Low : null,

      'dataCompletenessPercent': dataCompletenessPercent,

      'dataCompletenessRating': dataCompletenessRating,

      'missingCoreMetrics': missingCoreMetrics,

      'availableMetrics': availableMetrics.toList(),
    };
  }
}

class FundamentalService {
  static const String _apiKey = String.fromEnvironment('FINNHUB_API_KEY');

  Future<FundamentalData> fetchFundamentals(String symbol) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'FINNHUB_API_KEY не передан '
        'при запуске приложения.',
      );
    }

    final String ticker = symbol.trim().toUpperCase();

    final Uri uri = Uri.https('finnhub.io', '/api/v1/stock/metric', {
      'symbol': ticker,
      'metric': 'all',
      'token': _apiKey,
    });

    final http.Response response = await http
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Finnhub отклонил API-ключ.');
    }

    if (response.statusCode == 429) {
      throw Exception(
        'Finnhub временно ограничил '
        'количество запросов.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка Finnhub fundamentals: '
        '${response.statusCode}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception(
        'Finnhub вернул некорректные '
        'фундаментальные данные.',
      );
    }

    final Map<String, dynamic> root = Map<String, dynamic>.from(decoded);

    final dynamic rawMetric = root['metric'];

    if (rawMetric is! Map) {
      throw Exception(
        'Фундаментальные данные для '
        '$ticker не найдены.',
      );
    }

    final Map<String, dynamic> metric = Map<String, dynamic>.from(rawMetric);

    if (metric.isEmpty) {
      throw Exception(
        'Фундаментальные данные для '
        '$ticker отсутствуют.',
      );
    }

    final Set<String> availableMetrics = _collectAvailableMetrics(metric);

    return FundamentalData(
      symbol: ticker,

      pe: _readDouble(metric, ['peTTM', 'peBasicExclExtraTTM']),

      forwardPe: _readDouble(metric, ['forwardPE', 'forwardPe']),

      priceToSales: _readDouble(metric, ['psTTM', 'priceToSalesTTM']),

      eps: _readDouble(metric, ['epsTTM', 'epsBasicExclExtraItemsTTM']),

      epsGrowthPercent: _readDouble(metric, [
        'epsGrowthTTMYoy',
        'epsGrowthQuarterlyYoy',
        'epsGrowth3Y',
        'epsGrowth5Y',
      ]),

      revenueGrowthPercent: _readDouble(metric, [
        'revenueGrowthTTMYoy',
        'revenueGrowthQuarterlyYoy',
        'revenueGrowth3Y',
        'revenueGrowth5Y',
      ]),

      grossMarginPercent: _readDouble(metric, [
        'grossMarginTTM',
        'grossMarginAnnual',
      ]),

      netMarginPercent: _readDouble(metric, [
        'netProfitMarginTTM',
        'netProfitMarginAnnual',
      ]),

      roePercent: _readDouble(metric, ['roeTTM', 'roeAnnual']),

      currentRatio: _readDouble(metric, [
        'currentRatioQuarterly',
        'currentRatioAnnual',
      ]),

      quickRatio: _readDouble(metric, [
        'quickRatioQuarterly',
        'quickRatioAnnual',
      ]),

      debtToEquity: _readDouble(metric, [
        'totalDebt/totalEquityQuarterly',
        'totalDebt/totalEquityAnnual',
      ]),

      freeCashFlowPerShare: _readDouble(metric, [
        'freeCashFlowPerShareTTM',
        'freeCashFlowPerShareQuarterly',
        'freeCashFlowPerShareAnnual',
      ]),

      beta: _readDouble(metric, ['beta']),

      week52High: _readDouble(metric, ['52WeekHigh']),

      week52Low: _readDouble(metric, ['52WeekLow']),

      availableMetrics: availableMetrics,
    );
  }

  static Set<String> _collectAvailableMetrics(Map<String, dynamic> source) {
    final Set<String> result = {};

    for (final MapEntry<String, dynamic> entry in source.entries) {
      if (_tryReadValue(entry.value) != null) {
        result.add(entry.key);
      }
    }

    return result;
  }

  static double _readDouble(Map<String, dynamic> source, List<String> keys) {
    for (final String key in keys) {
      final double? value = _tryReadValue(source[key]);

      if (value != null) {
        return value;
      }
    }

    return 0.0;
  }

  static double? _tryReadValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value == null) {
      return null;
    }

    return double.tryParse(value.toString());
  }
}
