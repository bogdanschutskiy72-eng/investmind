import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../services/historical_price_service.dart';
import '../../services/stock_service.dart';
import '../comparison/company_comparison.dart';
import 'market_catalog.dart';
import 'market_company.dart';
import 'market_data_cache.dart';
import 'market_signal.dart';
import 'market_signal_service.dart';
import 'opportunity_score_service.dart';

class MarketPersistentCacheService {
  MarketPersistentCacheService._();

  static final MarketPersistentCacheService instance =
      MarketPersistentCacheService._();

  static const String _quotesKey = 'market_persistent_quotes_v1';
  static const String _historicalKey = 'market_persistent_historical_v1';
  static const String _investMindKey = 'market_persistent_investmind_v1';

  final MarketDataCache _marketDataCache = MarketDataCache.instance;

  final MarketSignalService _marketSignalService = const MarketSignalService();

  final OpportunityScoreService _opportunityScoreService =
      const OpportunityScoreService();

  Timer? _saveTimer;
  bool _autoSaveStarted = false;

  void startAutoSave() {
    if (_autoSaveStarted) {
      return;
    }

    _autoSaveStarted = true;

    _marketDataCache.addListener(_scheduleSave);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();

    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(saveAll());
    });
  }

  Future<void> saveAll() async {
    await saveQuotes();
    await saveHistorical();
    await saveInvestMind();
  }

  Future<void> restoreAll() async {
    await restoreQuotes();
    await restoreHistorical();
    await restoreInvestMind();
  }

  Future<void> saveQuotes() async {
    final prefs = await SharedPreferences.getInstance();

    final quotes = <Map<String, dynamic>>[];

    for (final cached in _marketDataCache.allCompanies) {
      final quote = cached.quote;
      final quoteUpdatedAt = cached.quoteUpdatedAt;

      if (quote == null || quoteUpdatedAt == null) {
        continue;
      }

      quotes.add({
        'symbol': cached.company.symbol,
        'currentPrice': quote.currentPrice,
        'change': quote.change,
        'percentChange': quote.percentChange,
        'high': quote.high,
        'low': quote.low,
        'open': quote.open,
        'previousClose': quote.previousClose,
        'quoteSourceUpdatedAt': quote.updatedAt?.toIso8601String(),
        'quoteUpdatedAt': quoteUpdatedAt.toIso8601String(),
      });
    }

    await prefs.setString(_quotesKey, jsonEncode(quotes));
  }

  Future<void> saveHistorical() async {
    final prefs = await SharedPreferences.getInstance();

    final items = <Map<String, dynamic>>[];

    for (final cached in _marketDataCache.allCompanies) {
      final historical = cached.historical;
      final historicalUpdatedAt = cached.historicalUpdatedAt;

      if (historical == null || historicalUpdatedAt == null) {
        continue;
      }

      items.add({
        'symbol': cached.company.symbol,
        'historicalUpdatedAt': historicalUpdatedAt.toIso8601String(),
        'prices': historical.prices
            .map(
              (point) => {
                'date': point.date.toIso8601String(),
                'close': point.close,
              },
            )
            .toList(),
        'firstPrice': historical.firstPrice,
        'lastPrice': historical.lastPrice,
        'periodChangePercent': historical.periodChangePercent,
        'highestPrice': historical.highestPrice,
        'lowestPrice': historical.lowestPrice,
        'drawdownFromHighPercent': historical.drawdownFromHighPercent,
        'annualizedVolatilityPercent': historical.annualizedVolatilityPercent,
        'maxDrawdownPercent': historical.maxDrawdownPercent,
        'movingAverage20': historical.movingAverage20,
        'movingAverage50': historical.movingAverage50,
        'trendStrengthPercent': historical.trendStrengthPercent,
        'trendSlopePercentPerDay': historical.trendSlopePercentPerDay,
      });
    }

    await prefs.setString(_historicalKey, jsonEncode(items));
  }

  Future<void> saveInvestMind() async {
    final prefs = await SharedPreferences.getInstance();

    final items = <Map<String, dynamic>>[];

    for (final cached in _marketDataCache.allCompanies) {
      final comparison = cached.comparison;
      final analysisUpdatedAt = cached.analysisUpdatedAt;

      if (comparison == null || analysisUpdatedAt == null) {
        continue;
      }

      items.add({
        'symbol': cached.company.symbol,
        'analysisUpdatedAt': analysisUpdatedAt.toIso8601String(),
        'companyName': comparison.companyName,
        'industry': comparison.industry,
        'investMindScore': comparison.investMindScore,
        'technicalScore': comparison.technicalScore,
        'fundamentalScore': comparison.fundamentalScore,
        'growthScore': comparison.growthScore,
        'profitabilityScore': comparison.profitabilityScore,
        'valuationScore': comparison.valuationScore,
        'financialHealthScore': comparison.financialHealthScore,
        'riskScore': comparison.riskScore,
        'confidenceScore': comparison.confidenceScore,
        'dataCompletenessPercent': comparison.dataCompletenessPercent,
      });
    }

    await prefs.setString(_investMindKey, jsonEncode(items));
  }

  Future<void> restoreQuotes() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_quotesKey);

    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return;
      }

      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        final data = Map<String, dynamic>.from(item);

        final symbol = data['symbol']?.toString().trim().toUpperCase();

        if (symbol == null || symbol.isEmpty) {
          continue;
        }

        final company = _findCompany(symbol);

        if (company == null) {
          continue;
        }

        final quoteUpdatedAt = DateTime.tryParse(
          data['quoteUpdatedAt']?.toString() ?? '',
        );

        if (quoteUpdatedAt == null) {
          continue;
        }

        final quote = StockQuote(
          currentPrice: _readDouble(data['currentPrice']),
          change: _readDouble(data['change']),
          percentChange: _readDouble(data['percentChange']),
          high: _readDouble(data['high']),
          low: _readDouble(data['low']),
          open: _readDouble(data['open']),
          previousClose: _readDouble(data['previousClose']),
          updatedAt: _readDateTime(data['quoteSourceUpdatedAt']),
        );

        if (quote.currentPrice <= 0) {
          continue;
        }

        _marketDataCache.restoreQuote(
          company: company,
          quote: quote,
          updatedAt: quoteUpdatedAt,
        );
      }
    } catch (_) {
      // Повреждённый persistent cache
      // не должен мешать запуску приложения.
    }
  }

  Future<void> restoreHistorical() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_historicalKey);

    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return;
      }

      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        final data = Map<String, dynamic>.from(item);

        final symbol = data['symbol']?.toString().trim().toUpperCase();

        if (symbol == null || symbol.isEmpty) {
          continue;
        }

        final company = _findCompany(symbol);

        if (company == null) {
          continue;
        }

        final historicalUpdatedAt = DateTime.tryParse(
          data['historicalUpdatedAt']?.toString() ?? '',
        );

        if (historicalUpdatedAt == null) {
          continue;
        }

        final prices = _readPrices(data['prices']);

        if (prices.length < 2) {
          continue;
        }

        final historical = HistoricalPriceAnalysis(
          prices: prices,
          firstPrice: _readDouble(data['firstPrice']),
          lastPrice: _readDouble(data['lastPrice']),
          periodChangePercent: _readDouble(data['periodChangePercent']),
          highestPrice: _readDouble(data['highestPrice']),
          lowestPrice: _readDouble(data['lowestPrice']),
          drawdownFromHighPercent: _readDouble(data['drawdownFromHighPercent']),
          annualizedVolatilityPercent: _readDouble(
            data['annualizedVolatilityPercent'],
          ),
          maxDrawdownPercent: _readDouble(data['maxDrawdownPercent']),
          movingAverage20: _readDouble(data['movingAverage20']),
          movingAverage50: _readDouble(data['movingAverage50']),
          trendStrengthPercent: _readDouble(data['trendStrengthPercent']),
          trendSlopePercentPerDay: _readDouble(data['trendSlopePercentPerDay']),
        );

        final quote = _marketDataCache.getCompany(symbol)?.quote;

        List<MarketSignal> signals = const [];

        if (quote != null) {
          signals = _marketSignalService.buildSignals(
            quote: quote,
            historical: historical,
          );
        }

        _marketDataCache.restoreHistorical(
          company: company,
          historical: historical,
          updatedAt: historicalUpdatedAt,
          marketSignals: signals,
        );
      }
    } catch (_) {
      // Повреждённый historical cache
      // не должен мешать запуску приложения.
    }
  }

  Future<void> restoreInvestMind() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_investMindKey);

    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return;
      }

      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        final data = Map<String, dynamic>.from(item);

        final symbol = data['symbol']?.toString().trim().toUpperCase();

        if (symbol == null || symbol.isEmpty) {
          continue;
        }

        final company = _findCompany(symbol);

        if (company == null) {
          continue;
        }

        final analysisUpdatedAt = DateTime.tryParse(
          data['analysisUpdatedAt']?.toString() ?? '',
        );

        if (analysisUpdatedAt == null) {
          continue;
        }

        final cached = _marketDataCache.getCompany(symbol);

        final marketSignals = cached?.marketSignals ?? const <MarketSignal>[];
        final comparison = CompanyComparison(
          symbol: symbol,
          companyName: data['companyName']?.toString() ?? company.name,
          industry: data['industry']?.toString() ?? company.sector,
          investMindScore: _readInt(data['investMindScore']),
          technicalScore: _readInt(data['technicalScore']),
          fundamentalScore: _readInt(data['fundamentalScore']),
          growthScore: _readInt(data['growthScore']),
          profitabilityScore: _readInt(data['profitabilityScore']),
          valuationScore: _readInt(data['valuationScore']),
          financialHealthScore: _readInt(data['financialHealthScore']),
          riskScore: _readInt(data['riskScore']),
          confidenceScore: _readInt(data['confidenceScore']),
          dataCompletenessPercent: _readInt(data['dataCompletenessPercent']),
        );

        final opportunity = _opportunityScoreService.calculate(
          company: comparison,
          marketSignals: marketSignals,
        );

        _marketDataCache.restoreInvestMindData(
          company: company,
          comparison: comparison,
          opportunity: opportunity,
          updatedAt: analysisUpdatedAt,
        );
      }
    } catch (_) {
      // Повреждённый InvestMind cache
      // не должен мешать запуску приложения.
    }
  }

  List<HistoricalPricePoint> _readPrices(dynamic rawPrices) {
    if (rawPrices is! List) {
      return [];
    }

    final prices = <HistoricalPricePoint>[];

    for (final item in rawPrices) {
      if (item is! Map) {
        continue;
      }

      final data = Map<String, dynamic>.from(item);

      final date = DateTime.tryParse(data['date']?.toString() ?? '');

      final close = _readDouble(data['close']);

      if (date == null || close <= 0) {
        continue;
      }

      prices.add(HistoricalPricePoint(date: date, close: close));
    }

    prices.sort((a, b) => a.date.compareTo(b.date));

    return prices;
  }

  MarketCompany? _findCompany(String symbol) {
    for (final company in marketCompanies) {
      if (company.symbol.trim().toUpperCase() == symbol) {
        return company;
      }
    }

    return null;
  }

  double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_quotesKey);
    await prefs.remove(_historicalKey);
    await prefs.remove(_investMindKey);
  }
}
