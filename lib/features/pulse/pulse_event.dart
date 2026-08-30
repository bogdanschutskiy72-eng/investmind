enum PulseEventType {
  portfolio,
  opportunity,
  marketSignal,
  concentration,
  risk,
}

enum PulsePriority { low, medium, high, critical }

class PulseEvent {
  final PulseEventType type;
  final PulsePriority priority;

  final String title;
  final String description;

  final String? symbol;

  final int? currentScore;
  final int? previousScore;

  final DateTime createdAt;

  const PulseEvent({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.createdAt,
    this.symbol,
    this.currentScore,
    this.previousScore,
  });

  int get scoreChange {
    if (currentScore == null || previousScore == null) {
      return 0;
    }

    return currentScore! - previousScore!;
  }

  bool get hasScoreChange {
    return currentScore != null &&
        previousScore != null &&
        currentScore != previousScore;
  }
}
