enum MarketSignalType {
  strongRise,
  strongFall,
  bullishMomentum,
  bearishMomentum,
  highVolatility,
  recovery,
  breakdown,
}

class MarketSignal {
  final MarketSignalType type;
  final String title;
  final String description;
  final int priority;

  const MarketSignal({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
  });
}
