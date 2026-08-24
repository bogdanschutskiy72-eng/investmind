import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

class HistoricalPricePoint {
  final DateTime date;
  final double close;

  const HistoricalPricePoint({required this.date, required this.close});
}

class HistoricalPriceAnalysis {
  final List<HistoricalPricePoint> prices;

  final double firstPrice;
  final double lastPrice;

  final double periodChangePercent;

  final double highestPrice;
  final double lowestPrice;

  final double drawdownFromHighPercent;

  final double annualizedVolatilityPercent;
  final double maxDrawdownPercent;

  final double movingAverage20;
  final double movingAverage50;

  final double trendStrengthPercent;
  final double trendSlopePercentPerDay;

  const HistoricalPriceAnalysis({
    required this.prices,
    required this.firstPrice,
    required this.lastPrice,
    required this.periodChangePercent,
    required this.highestPrice,
    required this.lowestPrice,
    required this.drawdownFromHighPercent,
    required this.annualizedVolatilityPercent,
    required this.maxDrawdownPercent,
    required this.movingAverage20,
    required this.movingAverage50,
    required this.trendStrengthPercent,
    required this.trendSlopePercentPerDay,
  });
}

class HistoricalPriceService {
  static const String _apiKey = String.fromEnvironment('TWELVE_DATA_API_KEY');

  // Twelve Data free plan currently allows 8 API credits per minute.
  // 8 seconds between requests keeps us safely below that limit.
  static const Duration _minimumRequestInterval = Duration(seconds: 8);

  // Historical daily data does not need to be downloaded again every time
  // the user changes a filter or reopens a company.
  static const Duration _cacheDuration = Duration(minutes: 30);

  static const int _maxAttempts = 2;

  static final Map<String, _CachedHistoricalAnalysis> _cache =
      <String, _CachedHistoricalAnalysis>{};

  static final Map<String, Future<HistoricalPriceAnalysis>> _inFlight =
      <String, Future<HistoricalPriceAnalysis>>{};

  static Future<void> _rateLimitQueue = Future<void>.value();
  static DateTime? _lastRequestStartedAt;

  Future<HistoricalPriceAnalysis> fetchAnalysis(
    String symbol, {
    int days = 90,
    bool forceRefresh = false,
  }) async {
    _checkApiKey();

    final String ticker = symbol.trim().toUpperCase();

    if (ticker.isEmpty) {
      throw ArgumentError('Тикер не указан.');
    }

    if (days < 2) {
      throw ArgumentError('Для анализа требуется минимум 2 дня.');
    }

    final String cacheKey = '$ticker:$days';
    final cached = _cache[cacheKey];

    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.analysis;
    }

    final activeRequest = _inFlight[cacheKey];

    if (activeRequest != null) {
      return activeRequest;
    }

    final request = _loadAnalysis(
      ticker,
      days,
      staleAnalysis: cached?.analysis,
    );

    _inFlight[cacheKey] = request;

    try {
      return await request;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  void _checkApiKey() {
    if (_apiKey.isEmpty) {
      throw StateError(
        'TWELVE_DATA_API_KEY не передан при запуске приложения.',
      );
    }
  }

  Future<HistoricalPriceAnalysis> _loadAnalysis(
    String ticker,
    int days, {
    HistoricalPriceAnalysis? staleAnalysis,
  }) async {
    try {
      final analysis = await _fetchAnalysisFromApi(ticker, days);

      _cache['$ticker:$days'] = _CachedHistoricalAnalysis(
        analysis: analysis,
        savedAt: DateTime.now(),
      );

      return analysis;
    } on _TemporaryTwelveDataException {
      if (staleAnalysis != null) {
        return staleAnalysis;
      }

      rethrow;
    } on TimeoutException {
      if (staleAnalysis != null) {
        return staleAnalysis;
      }

      throw Exception('Twelve Data временно не отвечает. Повтори позже.');
    } on http.ClientException {
      if (staleAnalysis != null) {
        return staleAnalysis;
      }

      throw Exception('Не удалось подключиться к Twelve Data.');
    }
  }

  Future<HistoricalPriceAnalysis> _fetchAnalysisFromApi(
    String ticker,
    int days,
  ) async {
    final Uri uri = Uri.https('api.twelvedata.com', '/time_series', {
      'symbol': ticker,
      'interval': '1day',
      'outputsize': days.toString(),
      'order': 'ASC',
      'apikey': _apiKey,
    });

    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        await _waitForRequestSlot();

        final http.Response response = await http
            .get(uri)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 401 || response.statusCode == 403) {
          throw Exception(
            'Twelve Data отклонил API-ключ. '
            'Проверь TWELVE_DATA_API_KEY.',
          );
        }

        if (response.statusCode == 429) {
          if (attempt < _maxAttempts) {
            await Future<void>.delayed(const Duration(seconds: 10));
            continue;
          }

          throw const _TemporaryTwelveDataException(
            'Превышен минутный лимит Twelve Data.',
          );
        }

        if (response.statusCode >= 500) {
          if (attempt < _maxAttempts) {
            await Future<void>.delayed(const Duration(seconds: 5));
            continue;
          }

          throw const _TemporaryTwelveDataException(
            'Twelve Data временно недоступен.',
          );
        }

        if (response.statusCode != 200) {
          throw Exception('Ошибка Twelve Data: HTTP ${response.statusCode}');
        }

        final dynamic decoded = jsonDecode(response.body);

        if (decoded is! Map) {
          throw const FormatException('Некорректный ответ Twelve Data.');
        }

        final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

        if (data['status'] == 'error') {
          final String message =
              data['message']?.toString() ?? 'Twelve Data вернул ошибку.';

          final lowerMessage = message.toLowerCase();

          if (lowerMessage.contains('credit') ||
              lowerMessage.contains('limit') ||
              lowerMessage.contains('rate')) {
            if (attempt < _maxAttempts) {
              await Future<void>.delayed(const Duration(seconds: 10));
              continue;
            }

            throw _TemporaryTwelveDataException(message);
          }

          throw Exception(message);
        }

        return _buildAnalysisFromResponse(data, ticker);
      } on TimeoutException catch (error) {
        lastError = error;

        if (attempt < _maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 5));
          continue;
        }
      } on http.ClientException catch (error) {
        lastError = error;

        if (attempt < _maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 5));
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

    throw const _TemporaryTwelveDataException(
      'Не удалось получить исторические данные Twelve Data.',
    );
  }

  Future<void> _waitForRequestSlot() {
    final completer = Completer<void>();

    _rateLimitQueue = _rateLimitQueue
        .then((_) async {
          final lastRequest = _lastRequestStartedAt;

          if (lastRequest != null) {
            final elapsed = DateTime.now().difference(lastRequest);
            final remaining = _minimumRequestInterval - elapsed;

            if (remaining > Duration.zero) {
              await Future<void>.delayed(remaining);
            }
          }

          _lastRequestStartedAt = DateTime.now();

          if (!completer.isCompleted) {
            completer.complete();
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        });

    return completer.future;
  }

  HistoricalPriceAnalysis _buildAnalysisFromResponse(
    Map<String, dynamic> data,
    String ticker,
  ) {
    final dynamic rawValues = data['values'];

    if (rawValues is! List || rawValues.isEmpty) {
      throw Exception('Исторические данные для $ticker не найдены.');
    }

    final List<HistoricalPricePoint> prices = [];

    for (final dynamic item in rawValues) {
      if (item is! Map) {
        continue;
      }

      final Map<String, dynamic> map = Map<String, dynamic>.from(item);

      final String dateText = map['datetime']?.toString() ?? '';

      final String closeText = map['close']?.toString() ?? '';

      if (dateText.isEmpty || closeText.isEmpty) {
        continue;
      }

      final DateTime? parsedDate = DateTime.tryParse(dateText);

      final double? parsedClose = double.tryParse(closeText);

      if (parsedDate == null || parsedClose == null || parsedClose <= 0.0) {
        continue;
      }

      prices.add(HistoricalPricePoint(date: parsedDate, close: parsedClose));
    }

    if (prices.length < 2) {
      throw Exception('Недостаточно исторических данных для анализа.');
    }

    prices.sort((HistoricalPricePoint a, HistoricalPricePoint b) {
      return a.date.compareTo(b.date);
    });

    final double firstPrice = prices.first.close;
    final double lastPrice = prices.last.close;

    double highestPrice = firstPrice;
    double lowestPrice = firstPrice;

    for (final HistoricalPricePoint point in prices) {
      if (point.close > highestPrice) {
        highestPrice = point.close;
      }

      if (point.close < lowestPrice) {
        lowestPrice = point.close;
      }
    }

    final double periodChangePercent =
        ((lastPrice - firstPrice) / firstPrice) * 100.0;

    double drawdownFromHighPercent = 0.0;

    if (highestPrice > 0.0) {
      drawdownFromHighPercent =
          ((lastPrice - highestPrice) / highestPrice) * 100.0;
    }

    final double annualizedVolatilityPercent = _calculateAnnualizedVolatility(
      prices,
    );

    final double maxDrawdownPercent = _calculateMaxDrawdown(prices);

    final double movingAverage20 = _calculateMovingAverage(prices, 20);

    final double movingAverage50 = _calculateMovingAverage(prices, 50);

    final _TrendResult trend = _calculateTrend(prices);

    return HistoricalPriceAnalysis(
      prices: prices,
      firstPrice: firstPrice,
      lastPrice: lastPrice,
      periodChangePercent: periodChangePercent,
      highestPrice: highestPrice,
      lowestPrice: lowestPrice,
      drawdownFromHighPercent: drawdownFromHighPercent,
      annualizedVolatilityPercent: annualizedVolatilityPercent,
      maxDrawdownPercent: maxDrawdownPercent,
      movingAverage20: movingAverage20,
      movingAverage50: movingAverage50,
      trendStrengthPercent: trend.strengthPercent,
      trendSlopePercentPerDay: trend.slopePercentPerDay,
    );
  }

  double _calculateMovingAverage(
    List<HistoricalPricePoint> prices,
    int period,
  ) {
    if (prices.isEmpty) {
      return 0.0;
    }

    final int count = prices.length < period ? prices.length : period;

    final int startIndex = prices.length - count;

    double total = 0.0;

    for (int i = startIndex; i < prices.length; i++) {
      total += prices[i].close;
    }

    return total / count;
  }

  double _calculateAnnualizedVolatility(List<HistoricalPricePoint> prices) {
    if (prices.length < 3) {
      return 0.0;
    }

    final List<double> returns = [];

    for (int i = 1; i < prices.length; i++) {
      final double previous = prices[i - 1].close;
      final double current = prices[i].close;

      if (previous <= 0.0) {
        continue;
      }

      final double dailyReturn = (current / previous) - 1.0;

      returns.add(dailyReturn);
    }

    if (returns.length < 2) {
      return 0.0;
    }

    double total = 0.0;

    for (final double value in returns) {
      total += value;
    }

    final double mean = total / returns.length;

    double squaredDifferenceTotal = 0.0;

    for (final double value in returns) {
      final double difference = value - mean;

      squaredDifferenceTotal += difference * difference;
    }

    final double variance = squaredDifferenceTotal / (returns.length - 1);

    final double dailyVolatility = math.sqrt(variance);

    final double annualizedVolatility = dailyVolatility * math.sqrt(252.0);

    return annualizedVolatility * 100.0;
  }

  double _calculateMaxDrawdown(List<HistoricalPricePoint> prices) {
    if (prices.isEmpty) {
      return 0.0;
    }

    double peak = prices.first.close;
    double maxDrawdown = 0.0;

    for (final HistoricalPricePoint point in prices) {
      final double price = point.close;

      if (price > peak) {
        peak = price;
      }

      if (peak <= 0.0) {
        continue;
      }

      final double drawdown = ((peak - price) / peak) * 100.0;

      if (drawdown > maxDrawdown) {
        maxDrawdown = drawdown;
      }
    }

    return maxDrawdown;
  }

  _TrendResult _calculateTrend(List<HistoricalPricePoint> prices) {
    final int n = prices.length;

    if (n < 2) {
      return const _TrendResult(strengthPercent: 0.0, slopePercentPerDay: 0.0);
    }

    double sumX = 0.0;
    double sumY = 0.0;
    double sumXY = 0.0;
    double sumX2 = 0.0;

    for (int i = 0; i < n; i++) {
      final double x = i.toDouble();
      final double y = prices[i].close;

      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final double denominator = n * sumX2 - sumX * sumX;

    if (denominator == 0.0) {
      return const _TrendResult(strengthPercent: 0.0, slopePercentPerDay: 0.0);
    }

    final double slope = (n * sumXY - sumX * sumY) / denominator;

    final double meanX = sumX / n;
    final double meanY = sumY / n;

    final double intercept = meanY - slope * meanX;

    double totalVariation = 0.0;
    double residualVariation = 0.0;

    for (int i = 0; i < n; i++) {
      final double x = i.toDouble();
      final double actual = prices[i].close;
      final double predicted = intercept + slope * x;

      final double totalDifference = actual - meanY;

      final double residualDifference = actual - predicted;

      totalVariation += totalDifference * totalDifference;

      residualVariation += residualDifference * residualDifference;
    }

    double rSquared = 0.0;

    if (totalVariation > 0.0) {
      rSquared = 1.0 - residualVariation / totalVariation;
    }

    if (rSquared < 0.0) {
      rSquared = 0.0;
    }

    if (rSquared > 1.0) {
      rSquared = 1.0;
    }

    final double strengthPercent = rSquared * 100.0;

    double slopePercentPerDay = 0.0;

    if (meanY > 0.0) {
      slopePercentPerDay = (slope / meanY) * 100.0;
    }

    return _TrendResult(
      strengthPercent: strengthPercent,
      slopePercentPerDay: slopePercentPerDay,
    );
  }

  void clearCache([String? symbol]) {
    if (symbol == null) {
      _cache.clear();
      return;
    }

    final ticker = symbol.trim().toUpperCase();

    _cache.removeWhere((key, value) => key.startsWith('$ticker:'));
  }
}

class _CachedHistoricalAnalysis {
  final HistoricalPriceAnalysis analysis;
  final DateTime savedAt;

  const _CachedHistoricalAnalysis({
    required this.analysis,
    required this.savedAt,
  });

  bool get isExpired {
    return DateTime.now().difference(savedAt) >
        HistoricalPriceService._cacheDuration;
  }
}

class _TrendResult {
  final double strengthPercent;
  final double slopePercentPerDay;

  const _TrendResult({
    required this.strengthPercent,
    required this.slopePercentPerDay,
  });
}

class _TemporaryTwelveDataException implements Exception {
  final String message;

  const _TemporaryTwelveDataException(this.message);

  @override
  String toString() => message;
}
