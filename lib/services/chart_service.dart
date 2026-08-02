import 'dart:convert';

import 'package:http/http.dart' as http;

enum ChartPeriod {
  oneDay,
  oneWeek,
  oneMonth,
  threeMonths,
  oneYear,
}

class ChartPoint {
  final DateTime dateTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const ChartPoint({
    required this.dateTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory ChartPoint.fromJson(Map<String, dynamic> json) {
    double parseNumber(String key) {
      return double.tryParse(json[key]?.toString() ?? '') ?? 0;
    }

    final parsedDate = DateTime.tryParse(
      json['datetime']?.toString() ?? '',
    );

    if (parsedDate == null) {
      throw const FormatException('Некорректная дата графика.');
    }

    return ChartPoint(
      dateTime: parsedDate,
      open: parseNumber('open'),
      high: parseNumber('high'),
      low: parseNumber('low'),
      close: parseNumber('close'),
      volume: parseNumber('volume'),
    );
  }
}

class ChartService {
  static const String _apiKey = String.fromEnvironment(
    'TWELVE_DATA_API_KEY',
  );

  Future<List<ChartPoint>> fetchChart({
    required String symbol,
    required ChartPeriod period,
  }) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'Не передан ключ TWELVE_DATA_API_KEY.',
      );
    }

    final settings = _settingsForPeriod(period);

    final uri = Uri.https(
      'api.twelvedata.com',
      '/time_series',
      {
        'symbol': symbol.toUpperCase(),
        'interval': settings.interval,
        'outputsize': settings.outputSize.toString(),
        'order': 'ASC',
        'apikey': _apiKey,
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 429) {
      throw Exception('Превышен лимит запросов Twelve Data.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка Twelve Data: HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Получен неизвестный формат данных.',
      );
    }

    if (decoded['status'] == 'error') {
      throw Exception(
        decoded['message']?.toString() ??
            'Twelve Data вернул ошибку.',
      );
    }

    final values = decoded['values'];

    if (values is! List || values.isEmpty) {
      throw Exception(
        'Исторические данные для $symbol не найдены.',
      );
    }

    final points = values
        .whereType<Map<String, dynamic>>()
        .map(ChartPoint.fromJson)
        .toList()
      ..sort(
        (first, second) =>
            first.dateTime.compareTo(second.dateTime),
      );

    return points;
  }

  _ChartSettings _settingsForPeriod(ChartPeriod period) {
    switch (period) {
      case ChartPeriod.oneDay:
        return const _ChartSettings(
          interval: '5min',
          outputSize: 78,
        );

      case ChartPeriod.oneWeek:
        return const _ChartSettings(
          interval: '30min',
          outputSize: 65,
        );

      case ChartPeriod.oneMonth:
        return const _ChartSettings(
          interval: '1day',
          outputSize: 30,
        );

      case ChartPeriod.threeMonths:
        return const _ChartSettings(
          interval: '1day',
          outputSize: 90,
        );

      case ChartPeriod.oneYear:
        return const _ChartSettings(
          interval: '1day',
          outputSize: 365,
        );
    }
  }
}

class _ChartSettings {
  final String interval;
  final int outputSize;

  const _ChartSettings({
    required this.interval,
    required this.outputSize,
  });
}