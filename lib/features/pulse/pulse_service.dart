import '../portfolio/portfolio_health_service.dart';
import '../../services/portfolio_analytics_service.dart';
import 'pulse_event.dart';

class PulseService {
  const PulseService();

  List<PulseEvent> buildPortfolioEvents({
    required PortfolioAnalyticsResult analytics,
    required PortfolioHealthResult health,
  }) {
    final events = <PulseEvent>[];
    final now = DateTime.now();

    if (health.score < 40) {
      events.add(
        PulseEvent(
          type: PulseEventType.portfolio,
          priority: PulsePriority.critical,
          title: 'Portfolio Health требует внимания',
          description:
              'Текущий Portfolio Health: ${health.score}. '
              'Портфель находится в зоне повышенного риска по модели InvestMind.',
          currentScore: health.score,
          createdAt: now,
        ),
      );
    } else if (health.score < 55) {
      events.add(
        PulseEvent(
          type: PulseEventType.portfolio,
          priority: PulsePriority.high,
          title: 'Portfolio Health ниже сбалансированного уровня',
          description:
              'Текущий Portfolio Health: ${health.score}. '
              'Стоит проверить концентрацию, диверсификацию и устойчивость.',
          currentScore: health.score,
          createdAt: now,
        ),
      );
    }

    if (analytics.largestPositionWeightPercent >= 70) {
      events.add(
        PulseEvent(
          type: PulseEventType.concentration,
          priority: PulsePriority.critical,
          title: 'Очень высокая концентрация портфеля',
          description:
              '${analytics.largestPositionSymbol ?? 'Крупнейшая позиция'} '
              'занимает '
              '${analytics.largestPositionWeightPercent.toStringAsFixed(1)}% '
              'портфеля.',
          symbol: analytics.largestPositionSymbol,
          createdAt: now,
        ),
      );
    } else if (analytics.largestPositionWeightPercent >= 50) {
      events.add(
        PulseEvent(
          type: PulseEventType.concentration,
          priority: PulsePriority.high,
          title: 'Повышенная концентрация портфеля',
          description:
              '${analytics.largestPositionSymbol ?? 'Крупнейшая позиция'} '
              'занимает '
              '${analytics.largestPositionWeightPercent.toStringAsFixed(1)}% '
              'портфеля.',
          symbol: analytics.largestPositionSymbol,
          createdAt: now,
        ),
      );
    }

    if (health.diversificationScore < 40) {
      events.add(
        PulseEvent(
          type: PulseEventType.portfolio,
          priority: PulsePriority.high,
          title: 'Низкая диверсификация',
          description:
              'Показатель диверсификации: '
              '${health.diversificationScore}/100.',
          currentScore: health.diversificationScore,
          createdAt: now,
        ),
      );
    }

    if (health.riskScore < 45) {
      events.add(
        PulseEvent(
          type: PulseEventType.risk,
          priority: PulsePriority.high,
          title: 'Низкая устойчивость портфеля',
          description:
              'Показатель устойчивости: '
              '${health.riskScore}/100.',
          currentScore: health.riskScore,
          createdAt: now,
        ),
      );
    }

    if (health.opportunityScore >= 75) {
      events.add(
        PulseEvent(
          type: PulseEventType.opportunity,
          priority: PulsePriority.medium,
          title: 'Высокий Opportunity Score портфеля',
          description:
              'Opportunity Score: '
              '${health.opportunityScore}/100.',
          currentScore: health.opportunityScore,
          createdAt: now,
        ),
      );
    }

    events.sort(
      (a, b) =>
          _priorityValue(b.priority).compareTo(_priorityValue(a.priority)),
    );

    return events;
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
