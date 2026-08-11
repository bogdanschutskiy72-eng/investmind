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
  final double beta;

  final double week52High;
  final double week52Low;

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
    required this.beta,
    required this.week52High,
    required this.week52Low,
  });

  bool get hasPe => pe > 0;

  bool get hasForwardPe => forwardPe > 0;

  bool get hasPriceToSales => priceToSales > 0;

  bool get hasEps => eps != 0;

  bool get hasRevenueGrowth =>
      revenueGrowthPercent != 0;

  bool get hasMargins =>
      grossMarginPercent != 0 ||
      netMarginPercent != 0;

  bool get hasRoe => roePercent != 0;

  bool get hasAnyData =>
      hasPe ||
      hasForwardPe ||
      hasPriceToSales ||
      hasEps ||
      hasRevenueGrowth ||
      hasMargins ||
      hasRoe;

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'pe': pe,
      'forwardPe': forwardPe,
      'priceToSales': priceToSales,
      'eps': eps,
      'epsGrowthPercent': epsGrowthPercent,
      'revenueGrowthPercent':
          revenueGrowthPercent,
      'grossMarginPercent':
          grossMarginPercent,
      'netMarginPercent':
          netMarginPercent,
      'roePercent': roePercent,
      'currentRatio': currentRatio,
      'beta': beta,
      'week52High': week52High,
      'week52Low': week52Low,
    };
  }
}

class FundamentalService {
  static const String _apiKey =
      String.fromEnvironment(
    'FINNHUB_API_KEY',
  );

  Future<FundamentalData> fetchFundamentals(
    String symbol,
  ) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'FINNHUB_API_KEY не передан при запуске приложения.',
      );
    }

    final String ticker =
        symbol.trim().toUpperCase();

    final Uri uri = Uri.https(
      'finnhub.io',
      '/api/v1/stock/metric',
      {
        'symbol': ticker,
        'metric': 'all',
        'token': _apiKey,
      },
    );

    final http.Response response =
        await http
            .get(uri)
            .timeout(
              const Duration(
                seconds: 15,
              ),
            );

    if (response.statusCode == 401 ||
        response.statusCode == 403) {
      throw Exception(
        'Finnhub отклонил API-ключ.',
      );
    }

    if (response.statusCode == 429) {
      throw Exception(
        'Finnhub временно ограничил количество запросов.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка Finnhub fundamentals: '
        '${response.statusCode}',
      );
    }

    final dynamic decoded =
        jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception(
        'Finnhub вернул некорректные '
        'фундаментальные данные.',
      );
    }

    final Map<String, dynamic> root =
        Map<String, dynamic>.from(
      decoded,
    );

    final dynamic rawMetric =
        root['metric'];

    if (rawMetric is! Map) {
      throw Exception(
        'Фундаментальные данные для '
        '$ticker не найдены.',
      );
    }

    final Map<String, dynamic> metric =
        Map<String, dynamic>.from(
      rawMetric,
    );

    if (metric.isEmpty) {
      throw Exception(
        'Фундаментальные данные для '
        '$ticker отсутствуют.',
      );
    }

    return FundamentalData(
      symbol: ticker,

      pe: _readDouble(
        metric,
        [
          'peTTM',
          'peBasicExclExtraTTM',
        ],),

      forwardPe: _readDouble(
        metric,
        [
          'forwardPE',
          'forwardPe',
        ],
      ),

      priceToSales: _readDouble(
        metric,
        [
          'psTTM',
          'priceToSalesTTM',
        ],
      ),

      eps: _readDouble(
        metric,
        [
          'epsTTM',
          'epsBasicExclExtraItemsTTM',
        ],
      ),

      epsGrowthPercent: _readDouble(
        metric,
        [
          'epsGrowthTTMYoy',
          'epsGrowth3Y',
        ],
      ),

      revenueGrowthPercent:
          _readDouble(
        metric,
        [
          'revenueGrowthTTMYoy',
          'revenueGrowth3Y',
        ],
      ),

      grossMarginPercent:
          _readDouble(
        metric,
        [
          'grossMarginTTM',
          'grossMarginAnnual',
        ],
      ),

      netMarginPercent:
          _readDouble(
        metric,
        [
          'netProfitMarginTTM',
          'netProfitMarginAnnual',
        ],
      ),

      roePercent: _readDouble(
        metric,
        [
          'roeTTM',
          'roeAnnual',
        ],
      ),

      currentRatio: _readDouble(
        metric,
        [
          'currentRatioTTM',
          'currentRatioAnnual',
        ],
      ),

      beta: _readDouble(
        metric,
        [
          'beta',
        ],
      ),

      week52High: _readDouble(
        metric,
        [
          '52WeekHigh',
        ],
      ),

      week52Low: _readDouble(
        metric,
        [
          '52WeekLow',
        ],
      ),
    );
  }

  static double _readDouble(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final dynamic value =
          source[key];

      if (value is num) {
        return value.toDouble();
      }

      if (value != null) {
        final double? parsed =
            double.tryParse(
          value.toString(),
        );

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0.0;
  }
}