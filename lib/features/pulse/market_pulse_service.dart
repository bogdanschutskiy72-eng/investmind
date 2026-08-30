import '../../services/historical_price_service.dart';
import '../../services/stock_service.dart';
import '../comparison/comparison_service.dart';
import '../market/market_catalog.dart';
import '../market/market_company.dart';
import '../market/market_signal.dart';
import '../market/market_signal_service.dart';
import '../market/opportunity_score_service.dart';
import 'pulse_event.dart';

class MarketPulseService {
  final StockService _stockService;
  final ComparisonService _comparisonService;
  final HistoricalPriceService _historicalPriceService;
  final MarketSignalService _marketSignalService;
  final OpportunityScoreService _opportunityScoreService;

  MarketPulseService({
    StockService? stockService,
    ComparisonService? comparisonService,
    HistoricalPriceService? historicalPriceService,
    MarketSignalService? marketSignalService,
    OpportunityScoreService? opportunityScoreService,
  }) : _stockService = stockService ?? StockService(),
       _comparisonService = comparisonService ?? ComparisonService(),
       _historicalPriceService =
           historicalPriceService ?? HistoricalPriceService(),
       _marketSignalService =
           marketSignalService ?? const MarketSignalService(),
       _opportunityScoreService =
           opportunityScoreService ?? const OpportunityScoreService();

  Future<List<PulseEvent>> buildMarketEvents({
    int companyLimit = 20,
    int eventLimit = 10,
  }) async {
    if (companyLimit <= 0 || eventLimit <= 0) {
      return const [];
    }

    final companies = marketCompanies.take(companyLimit).toList();

    final events = <PulseEvent>[];

    for (final company in companies) {
      try {
        final companyEvents = await _analyzeCompanyFromCache(company);

        events.addAll(companyEvents);
      } catch (_) {
        // Ошибка одной компании не должна ломать Market Pulse.
      }
    }

    events.sort(_compareEvents);

    if (events.length <= eventLimit) {
      return events;
    }

    return events.take(eventLimit).toList();
  }

  Future<List<PulseEvent>> _analyzeCompanyFromCache(
    MarketCompany company,
  ) async {
    final symbol = company.symbol.trim().toUpperCase();

    final historical = _historicalPriceService.getCachedAnalysis(
      symbol,
      days: 90,
      allowExpired: true,
    );

    if (historical == null) {
      return const [];
    }

    final quote = await _stockService.fetchQuote(symbol);

    final comparison = await _comparisonService.loadCompany(symbol);

    final marketSignals = _marketSignalService.buildSignals(
      quote: quote,
      historical: historical,
    );

    final opportunity = _opportunityScoreService.calculate(
      company: comparison,
      marketSignals: marketSignals,
    );

    final events = <PulseEvent>[];

    final strongSignals = marketSignals
        .where((signal) => signal.priority >= 65)
        .toList();

    if (strongSignals.isNotEmpty) {
      events.add(
        _buildSignalEvent(company: company, signal: strongSignals.first),
      );
    }

    if (opportunity.score >= 80) {
      events.add(
        PulseEvent(
          type: PulseEventType.opportunity,
          priority: opportunity.score >= 90
              ? PulsePriority.high
              : PulsePriority.medium,
          title: 'Высокий Opportunity Score',
          description:
              '${company.name}: Opportunity Score '
              '${opportunity.score}/100. '
              'Market Context: '
              '${opportunity.marketContextScore}/100.',
          symbol: symbol,
          currentScore: opportunity.score,
          createdAt: DateTime.now(),
        ),
      );
    }

    return events;
  }

  PulseEvent _buildSignalEvent({
    required MarketCompany company,
    required MarketSignal signal,
  }) {
    return PulseEvent(
      type: PulseEventType.marketSignal,
      priority: _priorityForSignal(signal),
      title: signal.title,
      description: '${company.name}: ${signal.description}',
      symbol: company.symbol,
      createdAt: DateTime.now(),
    );
  }

  PulsePriority _priorityForSignal(MarketSignal signal) {
    switch (signal.type) {
      case MarketSignalType.strongRise:
      case MarketSignalType.strongFall:
        return PulsePriority.high;

      case MarketSignalType.bullishMomentum:
      case MarketSignalType.bearishMomentum:
        return PulsePriority.high;

      case MarketSignalType.recovery:
      case MarketSignalType.breakdown:
        return PulsePriority.medium;

      case MarketSignalType.highVolatility:
        return PulsePriority.medium;
    }
  }

  int _compareEvents(PulseEvent a, PulseEvent b) {
    final priorityComparison = _priorityValue(
      b.priority,
    ).compareTo(_priorityValue(a.priority));

    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final aScore = a.currentScore ?? 0;
    final bScore = b.currentScore ?? 0;

    final scoreComparison = bScore.compareTo(aScore);

    if (scoreComparison != 0) {
      return scoreComparison;
    }

    return b.createdAt.compareTo(a.createdAt);
  }

  int _priorityValue(PulsePriority priority) {
    switch (priority) {
      case PulsePriority.low:
        return 1;

      case PulsePriority.medium:
        return 2;

      case PulsePriority.high:
        return 3;

      case PulsePriority.critical:
        return 4;
    }
  }
}
