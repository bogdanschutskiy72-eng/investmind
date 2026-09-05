import 'dart:async';

import '../../services/historical_price_service.dart';
import '../../services/stock_service.dart';
import 'market_catalog.dart';
import 'market_company.dart';
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
          await _refreshCompany(company);
        } catch (_) {
          // Ошибка одной компании не должна
          // останавливать обновление остальных.
        }
      }
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _refreshCompany(MarketCompany company) async {
    final symbol = company.symbol;

    final cached = _marketDataCache.getCompany(symbol);

    StockQuote? quote = cached?.quote;

    HistoricalPriceAnalysis? historical = cached?.historical;

    final quoteNeedsRefresh = _marketDataCache.needsQuoteRefresh(symbol);

    final historicalNeedsRefresh = _marketDataCache.needsHistoricalRefresh(
      symbol,
    );

    var quoteWasRefreshed = false;
    var historicalWasRefreshed = false;

    if (quoteNeedsRefresh) {
      try {
        quote = await _stockService.fetchQuote(symbol);

        quoteWasRefreshed = true;

        _marketDataCache.saveQuote(company: company, quote: quote);
      } catch (_) {
        if (quote == null) {
          rethrow;
        }
      }
    }

    if (historicalNeedsRefresh) {
      try {
        final serviceCachedHistorical = _historicalPriceService
            .getCachedAnalysis(symbol, days: 90, allowExpired: false);

        if (serviceCachedHistorical != null) {
          historical = serviceCachedHistorical;

          historicalWasRefreshed = true;
        } else {
          historical = await _historicalPriceService.fetchAnalysis(
            symbol,
            days: 90,
          );

          historicalWasRefreshed = true;
        }
      } catch (_) {
        if (historical == null) {
          rethrow;
        }
      }
    }

    if (quote == null || historical == null) {
      return;
    }

    final signals = _marketSignalService.buildSignals(
      quote: quote,
      historical: historical,
    );

    _marketDataCache.saveMarketData(
      company: company,
      quote: quote,
      historical: historical,
      marketSignals: signals,

      // Если saveQuote уже обновил timestamp,
      // повторно отмечать quote свежим не требуется.
      markQuoteFresh: quoteWasRefreshed,

      // Historical timestamp обновляем только
      // если historical действительно был
      // получен заново или из свежего service-cache.
      markHistoricalFresh: historicalWasRefreshed,
    );
  }

  void start({int companyLimit = 12}) {
    if (_isRunning) {
      return;
    }

    unawaited(refresh(companyLimit: companyLimit));
  }
}
