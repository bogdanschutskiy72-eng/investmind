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

  factory CompanyProfile.fromJson(
    Map<String, dynamic> json,
  ) {
    return CompanyProfile(
      ticker: json['ticker']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      exchange: json['exchange']?.toString() ?? '',
      industry: json['finnhubIndustry']?.toString() ?? '',
      ipo: json['ipo']?.toString() ?? '',
      marketCapitalization:
          (json['marketCapitalization'] as num?)
                  ?.toDouble() ??
              0,
      shareOutstanding:
          (json['shareOutstanding'] as num?)
                  ?.toDouble() ??
              0,
      webUrl: json['weburl']?.toString() ?? '',
    );
  }
}

class CompanyProfileService {
  static const String _apiKey =
      String.fromEnvironment('FINNHUB_API_KEY');

  Future<CompanyProfile> fetchProfile(
    String symbol,
  ) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'FINNHUB_API_KEY не передан при запуске приложения.',
      );
    }

    final ticker = symbol.trim().toUpperCase();

    final uri = Uri.https(
      'finnhub.io',
      '/api/v1/stock/profile2',
      {
        'symbol': ticker,
        'token': _apiKey,
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 15),
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
        'Ошибка Finnhub: ${response.statusCode}',
      );
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (data.isEmpty ||
        data['ticker'] == null ||
        data['ticker'].toString().isEmpty) {
      throw Exception(
        'Данные компании $ticker не найдены.',
      );
    }

    return CompanyProfile.fromJson(data);
  }
}