import 'package:flutter/foundation.dart';

import '../../services/historical_price_service.dart';
import '../../services/stock_service.dart';
import '../comparison/company_comparison.dart';
import 'market_company.dart';
import 'market_signal.dart';
import 'opportunity_score_service.dart';

class MarketCachedCompanyData {
  final MarketCompany company;

  final StockQuote? quote;
  final HistoricalPriceAnalysis? historical;
  final List<MarketSignal> marketSignals;

  final CompanyComparison? comparison;
  final OpportunityScoreResult? opportunity;

  final DateTime? marketUpdatedAt;
  final DateTime? analysisUpdatedAt;

  const MarketCachedCompanyData({
    required this.company,
    this.quote,
    this.historical,
    this.marketSignals = const [],
    this.comparison,
    this.opportunity,
    this.marketUpdatedAt,
    this.analysisUpdatedAt,
  });

  bool get hasMarketData {
    return quote != null && historical != null;
  }

  bool get hasInvestMindData {
    return comparison != null && opportunity != null;
  }

  DateTime? get lastUpdatedAt {
    final marketTime = marketUpdatedAt;
    final analysisTime = analysisUpdatedAt;

    if (marketTime == null) {
      return analysisTime;
    }

    if (analysisTime == null) {
      return marketTime;
    }

    return marketTime.isAfter(analysisTime) ? marketTime : analysisTime;
  }

  MarketCachedCompanyData copyWith({
    MarketCompany? company,
    StockQuote? quote,
    HistoricalPriceAnalysis? historical,
    List<MarketSignal>? marketSignals,
    CompanyComparison? comparison,
    OpportunityScoreResult? opportunity,
    DateTime? marketUpdatedAt,
    DateTime? analysisUpdatedAt,
  }) {
    return MarketCachedCompanyData(
      company: company ?? this.company,
      quote: quote ?? this.quote,
      historical: historical ?? this.historical,
      marketSignals: marketSignals ?? this.marketSignals,
      comparison: comparison ?? this.comparison,
      opportunity: opportunity ?? this.opportunity,
      marketUpdatedAt: marketUpdatedAt ?? this.marketUpdatedAt,
      analysisUpdatedAt: analysisUpdatedAt ?? this.analysisUpdatedAt,
    );
  }
}

class MarketDataCache extends ChangeNotifier {
  MarketDataCache._();

  static final MarketDataCache instance = MarketDataCache._();

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

  void saveMarketData({
    required MarketCompany company,
    required StockQuote quote,
    required HistoricalPriceAnalysis historical,
    required List<MarketSignal> marketSignals,
  }) {
    final symbol = _normalizeSymbol(company.symbol);
    final existing = _companies[symbol];

    if (existing == null) {
      _companies[symbol] = MarketCachedCompanyData(
        company: company,
        quote: quote,
        historical: historical,
        marketSignals: List<MarketSignal>.from(marketSignals),
        marketUpdatedAt: DateTime.now(),
      );

      notifyListeners();

      return;
    }

    _companies[symbol] = existing.copyWith(
      company: company,
      quote: quote,
      historical: historical,
      marketSignals: List<MarketSignal>.from(marketSignals),
      marketUpdatedAt: DateTime.now(),
    );

    notifyListeners();
  }

  void saveQuote({required MarketCompany company, required StockQuote quote}) {
    final symbol = _normalizeSymbol(company.symbol);
    final existing = _companies[symbol];

    if (existing == null) {
      _companies[symbol] = MarketCachedCompanyData(
        company: company,
        quote: quote,
        marketUpdatedAt: DateTime.now(),
      );

      notifyListeners();

      return;
    }

    _companies[symbol] = existing.copyWith(
      company: company,
      quote: quote,
      marketUpdatedAt: DateTime.now(),
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

    if (existing == null) {
      _companies[symbol] = MarketCachedCompanyData(
        company: company,
        comparison: comparison,
        opportunity: opportunity,
        analysisUpdatedAt: DateTime.now(),
      );

      notifyListeners();

      return;
    }

    _companies[symbol] = existing.copyWith(
      company: company,
      comparison: comparison,
      opportunity: opportunity,
      analysisUpdatedAt: DateTime.now(),
    );

    notifyListeners();
  }

  bool contains(String symbol) {
    return _companies.containsKey(_normalizeSymbol(symbol));
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
