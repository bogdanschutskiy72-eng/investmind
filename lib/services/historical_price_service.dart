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
  static const String _backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const Duration _cacheDuration = Duration(minutes: 30);

  static const int _maxAttempts = 2;

  static final Map<String, _CachedHistoricalAnalysis> _cache =
      <String, _CachedHistoricalAnalysis>{};

  static final Map<String, Future<HistoricalPriceAnalysis>> _inFlight =
      <String, Future<HistoricalPriceAnalysis>>{};

  Future<HistoricalPriceAnalysis> fetchAnalysis(
    String symbol, {
    int days = 90,
    bool forceRefresh = false,
  }) async {
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

  Future<HistoricalPriceAnalysis> _loadAnalysis(
    String ticker,
    int days, {
    HistoricalPriceAnalysis? staleAnalysis,
  }) async {
    try {
      final analysis = await _fetchAnalysisFromBackend(ticker, days);

      _cache['$ticker:$days'] = _CachedHistoricalAnalysis(
        analysis: analysis,
        savedAt: DateTime.now(),
      );

      return analysis;
    } on _TemporaryHistoricalDataException {
      if (staleAnalysis != null) {
        return staleAnalysis;
      }

      rethrow;
    } on TimeoutException {
      if (staleAnalysis != null) {
        return staleAnalysis;
      }

      throw Exception(
        'Сервер InvestMind временно не отвечает. '
        'Повтори позже.',
      );
    } on http.ClientException {
      if (staleAnalysis != null) {
        return staleAnalysis;
      }

      throw Exception(
        'Не удалось подключиться '
        'к серверу InvestMind.',
      );
    }
  }

  Future<HistoricalPriceAnalysis> _fetchAnalysisFromBackend(
    String ticker,
    int days,
  ) async {
    final uri = Uri.parse('$_backendBaseUrl/api/market/time-series').replace(
      queryParameters: {
        'symbol': ticker,
        'interval': '1day',
        'outputsize': days.toString(),
        'order': 'ASC',
      },
    );

    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 90));

        if (response.statusCode == 429) {
          if (attempt < _maxAttempts) {
            await Future<void>.delayed(const Duration(seconds: 10));

            continue;
          }

          throw const _TemporaryHistoricalDataException(
            'Источник исторических данных '
            'временно ограничил запросы.',
          );
        }

        if (response.statusCode >= 500) {
          if (attempt < _maxAttempts) {
            await Future<void>.delayed(const Duration(seconds: 5));

            continue;
          }

          throw const _TemporaryHistoricalDataException(
            'Сервер InvestMind временно недоступен.',
          );
        }

        if (response.statusCode != 200) {
          throw Exception(
            'Ошибка получения исторических данных: '
            'HTTP ${response.statusCode}',
          );
        }

        final dynamic decoded = jsonDecode(response.body);

        if (decoded is! Map) {
          throw const FormatException('Некорректный ответ сервера.');
        }

        final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

        if (data['status'] == 'error') {
          final String message =
              data['message']?.toString() ??
              'Источник исторических данных '
                  'вернул ошибку.';

          final lowerMessage = message.toLowerCase();

          if (lowerMessage.contains('credit') ||
              lowerMessage.contains('limit') ||
              lowerMessage.contains('rate') ||
              lowerMessage.contains('слишком много') ||
              lowerMessage.contains('огранич')) {
            if (attempt < _maxAttempts) {
              await Future<void>.delayed(const Duration(seconds: 10));

              continue;
            }

            throw _TemporaryHistoricalDataException(message);
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

    throw const _TemporaryHistoricalDataException(
      'Не удалось получить исторические данные.',
    );
  }

  HistoricalPriceAnalysis _buildAnalysisFromResponse(
    Map<String, dynamic> data,
    String ticker,
  ) {
    final dynamic rawValues = data['values'];

    if (rawValues is! List || rawValues.isEmpty) {
      throw Exception(
        'Исторические данные для '
        '$ticker не найдены.',
      );
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
      throw Exception(
        'Недостаточно исторических '
        'данных для анализа.',
      );
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

  HistoricalPriceAnalysis? getCachedAnalysis(
    String symbol, {
    int days = 90,
    bool allowExpired = true,
  }) {
    final ticker = symbol.trim().toUpperCase();

    if (ticker.isEmpty) {
      return null;
    }

    final cacheKey = '$ticker:$days';

    final cached = _cache[cacheKey];

    if (cached == null) {
      return null;
    }

    if (!allowExpired && cached.isExpired) {
      return null;
    }

    return cached.analysis;
  }

  bool hasCachedAnalysis(String symbol, {int days = 90}) {
    final ticker = symbol.trim().toUpperCase();

    if (ticker.isEmpty) {
      return false;
    }

    return _cache.containsKey('$ticker:$days');
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

class _TemporaryHistoricalDataException implements Exception {
  final String message;

  const _TemporaryHistoricalDataException(this.message);

  @override
  String toString() => message;
}
