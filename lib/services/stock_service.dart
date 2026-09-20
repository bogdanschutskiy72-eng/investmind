import 'dart:async';
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

  factory StockSearchResult.fromJson(Map<String, dynamic> json) {
    return StockSearchResult(
      symbol: json['symbol']?.toString() ?? '',
      displaySymbol: json['displaySymbol']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }
}

class StockService {
  static const String _backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const Duration _cacheDuration = Duration(seconds: 60);

  static final Map<String, _CachedQuote> _quoteCache = <String, _CachedQuote>{};

  static final Map<String, Future<StockQuote>> _inFlightQuotes =
      <String, Future<StockQuote>>{};

  Future<StockQuote> fetchQuote(
    String symbol, {
    bool forceRefresh = false,
  }) async {
    final normalizedSymbol = symbol.trim().toUpperCase();

    if (normalizedSymbol.isEmpty) {
      throw ArgumentError('Тикер не указан.');
    }

    final cached = _quoteCache[normalizedSymbol];

    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.quote;
    }

    final activeRequest = _inFlightQuotes[normalizedSymbol];

    if (activeRequest != null) {
      return activeRequest;
    }

    final request = _loadQuote(normalizedSymbol, staleQuote: cached?.quote);

    _inFlightQuotes[normalizedSymbol] = request;

    try {
      return await request;
    } finally {
      _inFlightQuotes.remove(normalizedSymbol);
    }
  }

  Future<StockQuote> _loadQuote(String symbol, {StockQuote? staleQuote}) async {
    try {
      final quote = await _fetchQuoteFromBackend(symbol);

      _quoteCache[symbol] = _CachedQuote(quote: quote, savedAt: DateTime.now());

      return quote;
    } on TimeoutException {
      if (staleQuote != null) {
        return staleQuote;
      }

      throw Exception(
        'Сервер InvestMind временно '
        'не отвечает.',
      );
    } on http.ClientException {
      if (staleQuote != null) {
        return staleQuote;
      }

      throw Exception(
        'Не удалось подключиться '
        'к серверу InvestMind.',
      );
    } catch (_) {
      if (staleQuote != null) {
        return staleQuote;
      }

      rethrow;
    }
  }

  Future<StockQuote> _fetchQuoteFromBackend(String symbol) async {
    final uri = Uri.parse(
      '$_backendBaseUrl/api/market/quote',
    ).replace(queryParameters: {'symbol': symbol});

    final response = await http.get(uri).timeout(const Duration(seconds: 25));

    if (response.statusCode == 429) {
      throw Exception(
        'Источник рыночных данных '
        'временно ограничил запросы.',
      );
    }

    if (response.statusCode >= 500) {
      throw Exception(
        'Сервер InvestMind временно '
        'недоступен.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка получения котировки: '
        'HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Сервер вернул данные '
        'неизвестного формата.',
      );
    }

    final quote = StockQuote.fromJson(decoded);

    if (quote.currentPrice <= 0) {
      throw Exception(
        'Котировка для $symbol '
        'не найдена.',
      );
    }

    return quote;
  }

  Future<List<StockSearchResult>> searchSymbols(String query) async {
    final cleanedQuery = query.trim();

    if (cleanedQuery.isEmpty) {
      return [];
    }

    final uri = Uri.parse(
      '$_backendBaseUrl/api/market/search',
    ).replace(queryParameters: {'q': cleanedQuery});

    final response = await http.get(uri).timeout(const Duration(seconds: 25));

    if (response.statusCode == 429) {
      throw Exception(
        'Слишком много запросов. '
        'Подожди несколько секунд.',
      );
    }

    if (response.statusCode >= 500) {
      throw Exception(
        'Поиск InvestMind временно '
        'недоступен.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка поиска: '
        'HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Сервер вернул неизвестный '
        'формат поиска.',
      );
    }

    final rawResults = decoded['result'];

    if (rawResults is! List) {
      return [];
    }

    return rawResults
        .whereType<Map<String, dynamic>>()
        .map(StockSearchResult.fromJson)
        .where((item) => item.symbol.isNotEmpty && item.description.isNotEmpty)
        .take(20)
        .toList();
  }

  void clearQuoteCache([String? symbol]) {
    if (symbol == null) {
      _quoteCache.clear();
      return;
    }

    _quoteCache.remove(symbol.trim().toUpperCase());
  }
}

class _CachedQuote {
  final StockQuote quote;
  final DateTime savedAt;

  const _CachedQuote({required this.quote, required this.savedAt});

  bool get isExpired {
    return DateTime.now().difference(savedAt) > StockService._cacheDuration;
  }
}
