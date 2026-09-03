import 'dart:async';

import '../../services/historical_price_service.dart';
import '../../services/stock_service.dart';
import 'market_catalog.dart';
import 'market_data_cache.dart';
import 'market_signal_service.dart';

class MarketBackgroundRefreshService {
  MarketBackgroundRefreshService._();

  static final MarketBackgroundRefreshService instance =
      MarketBackgroundRefreshService._();

  final StockService _stockService = StockService();

  final HistoricalPriceService _historicalPriceService =
      HistoricalPriceService();

  final MarketSignalService _marketSignalService = const MarketSignalService();

  final MarketDataCache _marketDataCache = MarketDataCache.instance;

  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> refresh({int companyLimit = 12}) async {
    if (_isRunning || companyLimit <= 0) {
      return;
    }

    _isRunning = true;

    try {
      final companies = marketCompanies.take(companyLimit).toList();

      for (final company in companies) {
        try {
          final quote = await _stockService.fetchQuote(company.symbol);

          _marketDataCache.saveQuote(company: company, quote: quote);

          final cachedHistorical = _historicalPriceService.getCachedAnalysis(
            company.symbol,
            days: 90,
            allowExpired: false,
          );

          if (cachedHistorical != null) {
            final signals = _marketSignalService.buildSignals(
              quote: quote,
              historical: cachedHistorical,
            );

            _marketDataCache.saveMarketData(
              company: company,
              quote: quote,
              historical: cachedHistorical,
              marketSignals: signals,
            );

            continue;
          }

          final historical = await _historicalPriceService.fetchAnalysis(
            company.symbol,
            days: 90,
          );

          final signals = _marketSignalService.buildSignals(
            quote: quote,
            historical: historical,
          );

          _marketDataCache.saveMarketData(
            company: company,
            quote: quote,
            historical: historical,
            marketSignals: signals,
          );
        } catch (_) {
          // Ошибка одной компании не останавливает
          // фоновое обновление остальных.
        }
      }
    } finally {
      _isRunning = false;
    }
  }

  void start({int companyLimit = 12}) {
    if (_isRunning) {
      return;
    }

    unawaited(refresh(companyLimit: companyLimit));
  }
}
