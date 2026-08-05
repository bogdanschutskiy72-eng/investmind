import 'dart:convert';

import 'package:http/http.dart' as http;

class StockQuote {
  final double currentPrice;
  final double change;
  final double percentChange;
  final double high;
  final double low;
  final double open;
  final double previousClose;
  final DateTime? updatedAt;

  const StockQuote({
    required this.currentPrice,
    required this.change,
    required this.percentChange,
    required this.high,
    required this.low,
    required this.open,
    required this.previousClose,
    required this.updatedAt,
  });

  factory StockQuote.fromJson(Map<String, dynamic> json) {
    double readNumber(String key) {
      return (json[key] as num?)?.toDouble() ?? 0;
    }

    final timestamp = (json['t'] as num?)?.toInt() ?? 0;

    return StockQuote(
      currentPrice: readNumber('c'),
      change: readNumber('d'),
      percentChange: readNumber('dp'),
      high: readNumber('h'),
      low: readNumber('l'),
      open: readNumber('o'),
      previousClose: readNumber('pc'),
      updatedAt: timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              timestamp * 1000,
              isUtc: true,
            ).toLocal()
          : null,
    );
  }
}

class StockSearchResult {
  final String symbol;
  final String displaySymbol;
  final String description;
  final String type;

  const StockSearchResult({
    required this.symbol,
    required this.displaySymbol,
    required this.description,
    required this.type,
  });

  factory StockSearchResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return StockSearchResult(
      symbol: json['symbol']?.toString() ?? '',
      displaySymbol: json['displaySymbol']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }
}

class StockService {
  static const String _apiKey = String.fromEnvironment(
    'FINNHUB_API_KEY',
  );

  void _checkApiKey() {
    if (_apiKey.isEmpty) {
      throw StateError(
        'API-ключ не передан через FINNHUB_API_KEY.',
      );
    }
  }

  Future<StockQuote> fetchQuote(String symbol) async {
    _checkApiKey();

    final uri = Uri.https(
      'finnhub.io',
      '/api/v1/quote',
      {
        'symbol': symbol.toUpperCase(),
        'token': _apiKey,
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 429) {
      throw Exception('Превышен лимит запросов Finnhub.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка Finnhub: HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Finnhub вернул данные неизвестного формата.',
      );
    }

    final quote = StockQuote.fromJson(decoded);

    if (quote.currentPrice <= 0) {
      throw Exception(
        'Котировка для $symbol не найдена.',
      );
    }

    return quote;
  }

  Future<List<StockSearchResult>> searchSymbols(
    String query,
  ) async {
    _checkApiKey();

    final cleanedQuery = query.trim();

    if (cleanedQuery.isEmpty) {
      return [];
    }

    final uri = Uri.https(
      'finnhub.io',
      '/api/v1/search',
      {
        'q': cleanedQuery,
        'token': _apiKey,
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 429) {
      throw Exception('Превышен лимит запросов Finnhub.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка поиска Finnhub: HTTP '
        '${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Finnhub вернул неизвестный формат поиска.',
      );
    }

    final rawResults = decoded['result'];

    if (rawResults is! List) {
      return [];
    }

    final results = rawResults
        .whereType<Map<String, dynamic>>().map(StockSearchResult.fromJson)
        .where((item) {
          return item.symbol.isNotEmpty &&
              item.description.isNotEmpty;
        })
        .take(20)
        .toList();

    return results;
  }
}