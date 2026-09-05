import 'package:flutter/foundation.dart';

import '../../services/historical_price_service.dart';
import '../../services/stock_service.dart';
import '../comparison/company_comparison.dart';
import 'market_company.dart';
import 'market_signal.dart';
import 'opportunity_score_service.dart';

enum MarketCacheFreshness { fresh, stale, missing }

class MarketCachedCompanyData {
  final MarketCompany company;

  final StockQuote? quote;
  final HistoricalPriceAnalysis? historical;
  final List<MarketSignal> marketSignals;

  final CompanyComparison? comparison;
  final OpportunityScoreResult? opportunity;

  final DateTime? quoteUpdatedAt;
  final DateTime? historicalUpdatedAt;
  final DateTime? analysisUpdatedAt;

  /// Последнее обновление любой части рыночных данных.
  /// Оставлено для совместимости с Pulse и другими экранами.
  final DateTime? marketUpdatedAt;

  const MarketCachedCompanyData({
    required this.company,
    this.quote,
    this.historical,
    this.marketSignals = const [],
    this.comparison,
    this.opportunity,
    this.quoteUpdatedAt,
    this.historicalUpdatedAt,
    this.analysisUpdatedAt,
    this.marketUpdatedAt,
  });

  bool get hasQuote => quote != null;

  bool get hasHistorical => historical != null;

  bool get hasMarketData {
    return quote != null && historical != null;
  }

  bool get hasInvestMindData {
    return comparison != null && opportunity != null;
  }

  DateTime? get lastUpdatedAt {
    final times = <DateTime>[
      ?quoteUpdatedAt,
      ?historicalUpdatedAt,
      ?analysisUpdatedAt,
      ?marketUpdatedAt,
    ];

    if (times.isEmpty) {
      return null;
    }

    times.sort();

    return times.last;
  }

  MarketCachedCompanyData copyWith({
    MarketCompany? company,
    StockQuote? quote,
    HistoricalPriceAnalysis? historical,
    List<MarketSignal>? marketSignals,
    CompanyComparison? comparison,
    OpportunityScoreResult? opportunity,
    DateTime? quoteUpdatedAt,
    DateTime? historicalUpdatedAt,
    DateTime? analysisUpdatedAt,
    DateTime? marketUpdatedAt,
  }) {
    return MarketCachedCompanyData(
      company: company ?? this.company,
      quote: quote ?? this.quote,
      historical: historical ?? this.historical,
      marketSignals: marketSignals ?? this.marketSignals,
      comparison: comparison ?? this.comparison,
      opportunity: opportunity ?? this.opportunity,
      quoteUpdatedAt: quoteUpdatedAt ?? this.quoteUpdatedAt,
      historicalUpdatedAt: historicalUpdatedAt ?? this.historicalUpdatedAt,
      analysisUpdatedAt: analysisUpdatedAt ?? this.analysisUpdatedAt,
      marketUpdatedAt: marketUpdatedAt ?? this.marketUpdatedAt,
    );
  }
}

class MarketDataCache extends ChangeNotifier {
  MarketDataCache._();

  static final MarketDataCache instance = MarketDataCache._();

  static const Duration quoteTtl = Duration(minutes: 2);

  static const Duration historicalTtl = Duration(minutes: 30);

  static const Duration analysisTtl = Duration(minutes: 30);

  final Map<String, MarketCachedCompanyData> _companies =
      <String, MarketCachedCompanyData>{};

  String _normalizeSymbol(String symbol) {
    return symbol.trim().toUpperCase();
  }

  MarketCachedCompanyData? getCompany(String symbol) {
    return _companies[_normalizeSymbol(symbol)];
  }

  List<MarketCachedCompanyData> get allCompanies {
    final values = _companies.values.toList();

    values.sort((a, b) {
      final aTime = a.lastUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      final bTime = b.lastUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bTime.compareTo(aTime);
    });

    return values;
  }

  List<MarketCachedCompanyData> get companiesWithMarketData {
    return allCompanies.where((item) => item.hasMarketData).toList();
  }

  List<MarketCachedCompanyData> get companiesWithInvestMindData {
    return allCompanies.where((item) => item.hasInvestMindData).toList();
  }

  List<MarketCachedCompanyData> get companiesWithFreshMarketData {
    return allCompanies
        .where((item) => isMarketDataFresh(item.company.symbol))
        .toList();
  }

  List<MarketCachedCompanyData> get companiesWithFreshInvestMindData {
    return allCompanies
        .where((item) => isInvestMindDataFresh(item.company.symbol))
        .toList();
  }

  bool _isTimestampFresh(DateTime? timestamp, Duration ttl) {
    if (timestamp == null) {
      return false;
    }

    final age = DateTime.now().difference(timestamp);

    if (age.isNegative) {
      return true;
    }

    return age <= ttl;
  }

  DateTime? _latestMarketTimestamp({
    required DateTime? quoteUpdatedAt,
    required DateTime? historicalUpdatedAt,
  }) {
    if (quoteUpdatedAt == null) {
      return historicalUpdatedAt;
    }

    if (historicalUpdatedAt == null) {
      return quoteUpdatedAt;
    }

    return quoteUpdatedAt.isAfter(historicalUpdatedAt)
        ? quoteUpdatedAt
        : historicalUpdatedAt;
  }

  MarketCacheFreshness quoteFreshness(String symbol) {
    final cached = getCompany(symbol);

    if (cached == null ||
        cached.quote == null ||
        cached.quoteUpdatedAt == null) {
      return MarketCacheFreshness.missing;
    }

    if (_isTimestampFresh(cached.quoteUpdatedAt, quoteTtl)) {
      return MarketCacheFreshness.fresh;
    }

    return MarketCacheFreshness.stale;
  }

  MarketCacheFreshness historicalFreshness(String symbol) {
    final cached = getCompany(symbol);

    if (cached == null ||
        cached.historical == null ||
        cached.historicalUpdatedAt == null) {
      return MarketCacheFreshness.missing;
    }

    if (_isTimestampFresh(cached.historicalUpdatedAt, historicalTtl)) {
      return MarketCacheFreshness.fresh;
    }

    return MarketCacheFreshness.stale;
  }

  MarketCacheFreshness investMindFreshness(String symbol) {
    final cached = getCompany(symbol);

    if (cached == null ||
        cached.comparison == null ||
        cached.opportunity == null ||
        cached.analysisUpdatedAt == null) {
      return MarketCacheFreshness.missing;
    }

    if (_isTimestampFresh(cached.analysisUpdatedAt, analysisTtl)) {
      return MarketCacheFreshness.fresh;
    }

    return MarketCacheFreshness.stale;
  }

  bool isQuoteFresh(String symbol) {
    return quoteFreshness(symbol) == MarketCacheFreshness.fresh;
  }

  bool isHistoricalFresh(String symbol) {
    return historicalFreshness(symbol) == MarketCacheFreshness.fresh;
  }

  bool isMarketDataFresh(String symbol) {
    return isQuoteFresh(symbol) && isHistoricalFresh(symbol);
  }

  bool isInvestMindDataFresh(String symbol) {
    return investMindFreshness(symbol) == MarketCacheFreshness.fresh;
  }

  bool needsQuoteRefresh(String symbol) {
    return !isQuoteFresh(symbol);
  }

  bool needsHistoricalRefresh(String symbol) {
    return !isHistoricalFresh(symbol);
  }

  bool needsMarketRefresh(String symbol) {
    return !isMarketDataFresh(symbol);
  }

  bool needsInvestMindRefresh(String symbol) {
    return !isInvestMindDataFresh(symbol);
  }

  Duration? quoteAge(String symbol) {
    final timestamp = getCompany(symbol)?.quoteUpdatedAt;

    if (timestamp == null) {
      return null;
    }

    final age = DateTime.now().difference(timestamp);

    if (age.isNegative) {
      return Duration.zero;
    }

    return age;
  }

  Duration? historicalAge(String symbol) {
    final timestamp = getCompany(symbol)?.historicalUpdatedAt;

    if (timestamp == null) {
      return null;
    }

    final age = DateTime.now().difference(timestamp);

    if (age.isNegative) {
      return Duration.zero;
    }

    return age;
  }

  Duration? investMindAge(String symbol) {
    final timestamp = getCompany(symbol)?.analysisUpdatedAt;

    if (timestamp == null) {
      return null;
    }

    final age = DateTime.now().difference(timestamp);

    if (age.isNegative) {
      return Duration.zero;
    }

    return age;
  }

  void saveMarketData({
    required MarketCompany company,
    required StockQuote quote,
    required HistoricalPriceAnalysis historical,
    required List<MarketSignal> marketSignals,

    /// true только если котировка действительно
    /// была обновлена сейчас.
    bool markQuoteFresh = true,

    /// true только если historical действительно
    /// был обновлён сейчас.
    bool markHistoricalFresh = true,
  }) {
    final symbol = _normalizeSymbol(company.symbol);

    final existing = _companies[symbol];

    final now = DateTime.now();

    final quoteTimestamp = markQuoteFresh ? now : existing?.quoteUpdatedAt;

    final historicalTimestamp = markHistoricalFresh
        ? now
        : existing?.historicalUpdatedAt;

    final marketTimestamp = _latestMarketTimestamp(
      quoteUpdatedAt: quoteTimestamp,
      historicalUpdatedAt: historicalTimestamp,
    );

    if (existing == null) {
      _companies[symbol] = MarketCachedCompanyData(
        company: company,
        quote: quote,
        historical: historical,
        marketSignals: List<MarketSignal>.from(marketSignals),
        quoteUpdatedAt: quoteTimestamp,
        historicalUpdatedAt: historicalTimestamp,
        marketUpdatedAt: marketTimestamp,
      );

      notifyListeners();

      return;
    }

    _companies[symbol] = existing.copyWith(
      company: company,
      quote: quote,
      historical: historical,
      marketSignals: List<MarketSignal>.from(marketSignals),
      quoteUpdatedAt: quoteTimestamp,
      historicalUpdatedAt: historicalTimestamp,
      marketUpdatedAt: marketTimestamp,
    );

    notifyListeners();
  }

  void saveQuote({required MarketCompany company, required StockQuote quote}) {
    final symbol = _normalizeSymbol(company.symbol);

    final existing = _companies[symbol];

    final now = DateTime.now();

    final marketTimestamp = _latestMarketTimestamp(
      quoteUpdatedAt: now,
      historicalUpdatedAt: existing?.historicalUpdatedAt,
    );

    if (existing == null) {
      _companies[symbol] = MarketCachedCompanyData(
        company: company,
        quote: quote,
        quoteUpdatedAt: now,
        marketUpdatedAt: marketTimestamp,
      );

      notifyListeners();

      return;
    }

    _companies[symbol] = existing.copyWith(
      company: company,
      quote: quote,
      quoteUpdatedAt: now,
      marketUpdatedAt: marketTimestamp,
    );

    notifyListeners();
  }

  void saveInvestMindData({
    required MarketCompany company,
    required CompanyComparison comparison,
    required OpportunityScoreResult opportunity,
  }) {
    final symbol = _normalizeSymbol(company.symbol);

    final existing = _companies[symbol];

    final now = DateTime.now();

    if (existing == null) {
      _companies[symbol] = MarketCachedCompanyData(
        company: company,
        comparison: comparison,
        opportunity: opportunity,
        analysisUpdatedAt: now,
      );

      notifyListeners();

      return;
    }

    _companies[symbol] = existing.copyWith(
      company: company,
      comparison: comparison,
      opportunity: opportunity,
      analysisUpdatedAt: now,
    );

    notifyListeners();
  }

  bool contains(String symbol) {
    return _companies.containsKey(_normalizeSymbol(symbol));
  }

  bool containsFreshQuote(String symbol) {
    return contains(symbol) && isQuoteFresh(symbol);
  }

  bool containsFreshHistorical(String symbol) {
    return contains(symbol) && isHistoricalFresh(symbol);
  }

  bool containsFreshMarketData(String symbol) {
    return contains(symbol) && isMarketDataFresh(symbol);
  }

  bool containsFreshInvestMindData(String symbol) {
    return contains(symbol) && isInvestMindDataFresh(symbol);
  }

  void remove(String symbol) {
    final removed = _companies.remove(_normalizeSymbol(symbol));

    if (removed != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_companies.isEmpty) {
      return;
    }

    _companies.clear();

    notifyListeners();
  }
}
