import 'dart:convert';

import 'package:http/http.dart' as http;

class HistoricalPricePoint {
  final DateTime date;
  final double close;

  const HistoricalPricePoint({
    required this.date,
    required this.close,
  });
}

class HistoricalPriceAnalysis {
  final List<HistoricalPricePoint> prices;
  final double firstPrice;
  final double lastPrice;
  final double periodChangePercent;
  final double highestPrice;
  final double lowestPrice;
  final double drawdownFromHighPercent;

  const HistoricalPriceAnalysis({
    required this.prices,
    required this.firstPrice,
    required this.lastPrice,
    required this.periodChangePercent,
    required this.highestPrice,
    required this.lowestPrice,
    required this.drawdownFromHighPercent,
  });
}

class HistoricalPriceService {
  static const String _apiKey =
      String.fromEnvironment('TWELVE_DATA_API_KEY');

  Future<HistoricalPriceAnalysis> fetchAnalysis(
    String symbol, {
    int days = 90,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'TWELVE_DATA_API_KEY не передан при запуске приложения.',
      );
    }

    final String ticker = symbol.trim().toUpperCase();

    final Uri uri = Uri.https(
      'api.twelvedata.com',
      '/time_series',
      {
        'symbol': ticker,
        'interval': '1day',
        'outputsize': days.toString(),
        'order': 'ASC',
        'apikey': _apiKey,
      },
    );

    final http.Response response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка Twelve Data: ${response.statusCode}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception(
        'Некорректный ответ Twelve Data.',
      );
    }

    final Map<String, dynamic> data =
        Map<String, dynamic>.from(decoded);

    if (data['status'] == 'error') {
      throw Exception(
        data['message']?.toString() ??
            'Twelve Data вернул ошибку.',
      );
    }

    final dynamic rawValues = data['values'];

    if (rawValues is! List) {
      throw Exception(
        'Исторические данные для $ticker не найдены.',
      );
    }

    if (rawValues.isEmpty) {
      throw Exception(
        'Исторические данные для $ticker не найдены.',
      );
    }

    final List<HistoricalPricePoint> prices = [];

    for (final dynamic item in rawValues) {
      if (item is! Map) {
        continue;
      }

      final Map<String, dynamic> map =
          Map<String, dynamic>.from(item);

      final String dateText =
          map['datetime']?.toString() ?? '';

      final String closeText =
          map['close']?.toString() ?? '';

      if (dateText.isEmpty) {
        continue;
      }

      if (closeText.isEmpty) {
        continue;
      }

      final DateTime? parsedDate =
          DateTime.tryParse(dateText);

      if (parsedDate == null) {
        continue;
      }

      final double? parsedClose =
          double.tryParse(closeText);

      if (parsedClose == null) {
        continue;
      }

      if (parsedClose <= 0.0) {
        continue;
      }

      final DateTime date = parsedDate;
      final double closePrice = parsedClose;

      prices.add(
        HistoricalPricePoint(
          date: date,
          close: closePrice,
        ),
      );
    }

    if (prices.length < 2) {
      throw Exception(
        'Недостаточно исторических данных для анализа.',
      );
    }

    prices.sort(
      (HistoricalPricePoint a, HistoricalPricePoint b) {
        return a.date.compareTo(b.date);
      },
    );

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
    }final double periodChangePercent =
        ((lastPrice - firstPrice) / firstPrice) * 100.0;

    double drawdownFromHighPercent = 0.0;

    if (highestPrice > 0.0) {
      drawdownFromHighPercent =
          ((lastPrice - highestPrice) / highestPrice) *
              100.0;
    }

    return HistoricalPriceAnalysis(
      prices: prices,
      firstPrice: firstPrice,
      lastPrice: lastPrice,
      periodChangePercent: periodChangePercent,
      highestPrice: highestPrice,
      lowestPrice: lowestPrice,
      drawdownFromHighPercent:
          drawdownFromHighPercent,
    );
  }
}