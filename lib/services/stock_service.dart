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
  static const String _apiKey = String.fromEnvironment('FINNHUB_API_KEY');

  static const Duration _cacheDuration = Duration(seconds: 60);

  static const int _maxAttempts = 2;

  // Не отправляем большой пакет запросов в Finnhub одновременно.
  // Все HTTP-запросы этого сервиса проходят через одну очередь.
  static const Duration _minimumRequestInterval = Duration(milliseconds: 1100);

  static DateTime? _lastRequestAt;

  static Future<void> _requestQueue = Future<void>.value();

  static final Map<String, _CachedQuote> _quoteCache = <String, _CachedQuote>{};

  static final Map<String, Future<StockQuote>> _inFlightQuotes =
      <String, Future<StockQuote>>{};

  void _checkApiKey() {
    if (_apiKey.isEmpty) {
      throw StateError('API-ключ не передан через FINNHUB_API_KEY.');
    }
  }

  Future<StockQuote> fetchQuote(
    String symbol, {
    bool forceRefresh = false,
  }) async {
    _checkApiKey();

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
      final quote = await _fetchQuoteFromApi(symbol);

      _quoteCache[symbol] = _CachedQuote(quote: quote, savedAt: DateTime.now());

      return quote;
    } on _TemporaryStockException {
      if (staleQuote != null) {
        return staleQuote;
      }

      rethrow;
    } on TimeoutException {
      if (staleQuote != null) {
        return staleQuote;
      }

      throw Exception(
        'Finnhub временно не отвечает. '
        'Повтори позже.',
      );
    } on http.ClientException {
      if (staleQuote != null) {
        return staleQuote;
      }

      throw Exception('Не удалось подключиться к Finnhub.');
    }
  }

  Future<StockQuote> _fetchQuoteFromApi(String symbol) async {
    final uri = Uri.https('finnhub.io', '/api/v1/quote', {
      'symbol': symbol,
      'token': _apiKey,
    });

    final response = await _getWithRetry(uri);

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Finnhub отклонил API-ключ. '
        'Проверь FINNHUB_API_KEY.',
      );
    }

    if (response.statusCode == 429) {
      throw const _TemporaryStockException('Превышен лимит запросов Finnhub.');
    }

    if (response.statusCode >= 500) {
      throw const _TemporaryStockException('Finnhub временно недоступен.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка Finnhub: '
        'HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Finnhub вернул данные '
        'неизвестного формата.',
      );
    }

    final quote = StockQuote.fromJson(decoded);

    if (quote.currentPrice <= 0) {
      throw Exception('Котировка для $symbol не найдена.');
    }

    return quote;
  }

  Future<List<StockSearchResult>> searchSymbols(String query) async {
    _checkApiKey();

    final cleanedQuery = query.trim();

    if (cleanedQuery.isEmpty) {
      return [];
    }

    final uri = Uri.https('finnhub.io', '/api/v1/search', {
      'q': cleanedQuery,
      'token': _apiKey,
    });

    final response = await _getWithRetry(uri);

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Finnhub отклонил API-ключ. '
        'Проверь FINNHUB_API_KEY.',
      );
    }

    if (response.statusCode == 429) {
      throw Exception(
        'Слишком много запросов. '
        'Подожди несколько секунд.',
      );
    }

    if (response.statusCode >= 500) {
      throw Exception('Поиск Finnhub временно недоступен.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка поиска Finnhub: '
        'HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Finnhub вернул неизвестный '
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

  Future<http.Response> _getWithRetry(Uri uri) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await _rateLimitedGet(uri);

        final temporaryError =
            response.statusCode == 429 || response.statusCode >= 500;

        if (temporaryError && attempt < _maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 2));

          continue;
        }

        return response;
      } on TimeoutException catch (error) {
        lastError = error;

        if (attempt < _maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 2));

          continue;
        }
      } on http.ClientException catch (error) {
        lastError = error;

        if (attempt < _maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 2));

          continue;
        }
      }
    }

    if (lastError is TimeoutException) {
      throw lastError;
    }

    if (lastError is http.ClientException) {
      throw lastError;
    }

    throw Exception('Не удалось получить данные Finnhub.');
  }

  Future<http.Response> _rateLimitedGet(Uri uri) {
    final completer = Completer<http.Response>();

    _requestQueue = _requestQueue
        .then((_) async {
          try {
            final lastRequest = _lastRequestAt;

            if (lastRequest != null) {
              final elapsed = DateTime.now().difference(lastRequest);

              final remaining = _minimumRequestInterval - elapsed;

              if (remaining > Duration.zero) {
                await Future<void>.delayed(remaining);
              }
            }

            _lastRequestAt = DateTime.now();

            final response = await http
                .get(uri)
                .timeout(const Duration(seconds: 15));

            completer.complete(response);
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        })
        .catchError((_) {
          // Не позволяем ошибке одной операции
          // сломать очередь следующих запросов.
        });

    return completer.future;
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

class _TemporaryStockException implements Exception {
  final String message;

  const _TemporaryStockException(this.message);

  @override
  String toString() => message;
}
