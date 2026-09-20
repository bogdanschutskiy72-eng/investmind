import 'dart:convert';

import 'package:http/http.dart' as http;

class CompanyProfile {
  final String ticker;
  final String name;
  final String country;
  final String currency;
  final String exchange;
  final String industry;
  final String ipo;
  final double marketCapitalization;
  final double shareOutstanding;
  final String webUrl;

  const CompanyProfile({
    required this.ticker,
    required this.name,
    required this.country,
    required this.currency,
    required this.exchange,
    required this.industry,
    required this.ipo,
    required this.marketCapitalization,
    required this.shareOutstanding,
    required this.webUrl,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      ticker: json['ticker']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      exchange: json['exchange']?.toString() ?? '',
      industry: json['finnhubIndustry']?.toString() ?? '',
      ipo: json['ipo']?.toString() ?? '',
      marketCapitalization:
          (json['marketCapitalization'] as num?)?.toDouble() ?? 0,
      shareOutstanding: (json['shareOutstanding'] as num?)?.toDouble() ?? 0,
      webUrl: json['weburl']?.toString() ?? '',
    );
  }
}

class CompanyProfileService {
  static const String _backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );

  Future<CompanyProfile> fetchProfile(String symbol) async {
    final ticker = symbol.trim().toUpperCase();

    if (ticker.isEmpty) {
      throw ArgumentError('Тикер не указан.');
    }

    final uri = Uri.parse(
      '$_backendBaseUrl/api/market/profile',
    ).replace(queryParameters: {'symbol': ticker});

    final response = await http.get(uri).timeout(const Duration(seconds: 25));

    if (response.statusCode == 429) {
      throw Exception(
        'Источник данных временно '
        'ограничил запросы.',
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
        'Ошибка получения профиля компании: '
        'HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Сервер вернул некорректный '
        'профиль компании.',
      );
    }

    if (decoded.isEmpty ||
        decoded['ticker'] == null ||
        decoded['ticker'].toString().isEmpty) {
      throw Exception(
        'Данные компании $ticker '
        'не найдены.',
      );
    }

    return CompanyProfile.fromJson(decoded);
  }
}
