import '../market/market_data_cache.dart';
import '../market/market_signal.dart';
import 'pulse_event.dart';

class MarketPulseService {
  final MarketDataCache _marketDataCache;

  MarketPulseService({MarketDataCache? marketDataCache})
    : _marketDataCache = marketDataCache ?? MarketDataCache.instance;

  Future<List<PulseEvent>> buildMarketEvents({
    int companyLimit = 20,
    int eventLimit = 10,
  }) async {
    if (companyLimit <= 0 || eventLimit <= 0) {
      return const [];
    }

    final cachedCompanies = _marketDataCache.allCompanies
        .take(companyLimit)
        .toList();

    final events = <PulseEvent>[];

    for (final cached in cachedCompanies) {
      final company = cached.company;

      final strongSignals =
          cached.marketSignals.where((signal) => signal.priority >= 65).toList()
            ..sort((a, b) => b.priority.compareTo(a.priority));

      if (strongSignals.isNotEmpty) {
        events.add(
          _buildSignalEvent(
            companyName: company.name,
            symbol: company.symbol,
            signal: strongSignals.first,
            createdAt: cached.marketUpdatedAt ?? DateTime.now(),
          ),
        );
      }

      final opportunity = cached.opportunity;

      if (opportunity != null && opportunity.score >= 80) {
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
            symbol: company.symbol,
            currentScore: opportunity.score,
            createdAt:
                cached.analysisUpdatedAt ??
                cached.marketUpdatedAt ??
                DateTime.now(),
          ),
        );
      }
    }

    events.sort(_compareEvents);

    if (events.length <= eventLimit) {
      return events;
    }

    return events.take(eventLimit).toList();
  }

  PulseEvent _buildSignalEvent({
    required String companyName,
    required String symbol,
    required MarketSignal signal,
    required DateTime createdAt,
  }) {
    return PulseEvent(
      type: PulseEventType.marketSignal,
      priority: _priorityForSignal(signal),
      title: signal.title,
      description: '$companyName: ${signal.description}',
      symbol: symbol,
      createdAt: createdAt,
    );
  }

  PulsePriority _priorityForSignal(MarketSignal signal) {
    switch (signal.type) {
      case MarketSignalType.strongRise:
      case MarketSignalType.strongFall:
      case MarketSignalType.bullishMomentum:
      case MarketSignalType.bearishMomentum:
        return PulsePriority.high;

      case MarketSignalType.recovery:
      case MarketSignalType.breakdown:
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
