import '../../services/historical_price_service.dart';
import '../../services/stock_service.dart';
import 'market_signal.dart';

class MarketSignalService {
  const MarketSignalService();

  List<MarketSignal> buildSignals({
    required StockQuote quote,
    required HistoricalPriceAnalysis historical,
  }) {
    final List<MarketSignal> signals = [];

    _addDailyMoveSignals(signals, quote);

    _addMomentumSignals(signals, quote, historical);

    _addVolatilitySignal(signals, historical);

    _addRecoverySignal(signals, quote, historical);

    _addBreakdownSignal(signals, quote, historical);

    signals.sort((a, b) => b.priority.compareTo(a.priority));

    return signals;
  }

  void _addDailyMoveSignals(List<MarketSignal> signals, StockQuote quote) {
    if (quote.percentChange >= 3) {
      signals.add(
        MarketSignal(
          type: MarketSignalType.strongRise,
          title: 'Сильный рост',
          description:
              'Акция выросла на ${quote.percentChange.toStringAsFixed(2)}% за день.',
          priority: 80,
        ),
      );
    }

    if (quote.percentChange <= -3) {
      signals.add(
        MarketSignal(
          type: MarketSignalType.strongFall,
          title: 'Сильное падение',
          description:
              'Акция снизилась на ${quote.percentChange.abs().toStringAsFixed(2)}% за день.',
          priority: 80,
        ),
      );
    }
  }

  void _addMomentumSignals(
    List<MarketSignal> signals,
    StockQuote quote,
    HistoricalPriceAnalysis historical,
  ) {
    final bool bullish =
        quote.currentPrice > historical.movingAverage20 &&
        historical.movingAverage20 > historical.movingAverage50 &&
        historical.trendStrengthPercent >= 5 &&
        historical.trendSlopePercentPerDay > 0;

    if (bullish) {
      signals.add(
        const MarketSignal(
          type: MarketSignalType.bullishMomentum,
          title: 'Бычий momentum',
          description:
              'Цена выше MA20 и MA50, а краткосрочный тренд остаётся положительным.',
          priority: 70,
        ),
      );
    }

    final bool bearish =
        quote.currentPrice < historical.movingAverage20 &&
        historical.movingAverage20 < historical.movingAverage50 &&
        historical.trendStrengthPercent <= -5 &&
        historical.trendSlopePercentPerDay < 0;

    if (bearish) {
      signals.add(
        const MarketSignal(
          type: MarketSignalType.bearishMomentum,
          title: 'Медвежий momentum',
          description:
              'Цена ниже MA20 и MA50, а краткосрочный тренд остаётся отрицательным.',
          priority: 70,
        ),
      );
    }
  }

  void _addVolatilitySignal(
    List<MarketSignal> signals,
    HistoricalPriceAnalysis historical,
  ) {
    if (historical.annualizedVolatilityPercent >= 45) {
      signals.add(
        MarketSignal(
          type: MarketSignalType.highVolatility,
          title: 'Высокая волатильность',
          description:
              'Годовая волатильность около ${historical.annualizedVolatilityPercent.toStringAsFixed(1)}%.',
          priority: 60,
        ),
      );
    }
  }

  void _addRecoverySignal(
    List<MarketSignal> signals,
    StockQuote quote,
    HistoricalPriceAnalysis historical,
  ) {
    final bool recovery =
        historical.maxDrawdownPercent <= -15 &&
        quote.currentPrice > historical.movingAverage20 &&
        historical.trendSlopePercentPerDay > 0;

    if (recovery) {
      signals.add(
        const MarketSignal(
          type: MarketSignalType.recovery,
          title: 'Восстановление после просадки',
          description:
              'Цена вернулась выше MA20 после заметной просадки и тренд начал улучшаться.',
          priority: 65,
        ),
      );
    }
  }

  void _addBreakdownSignal(
    List<MarketSignal> signals,
    StockQuote quote,
    HistoricalPriceAnalysis historical,
  ) {
    final bool breakdown =
        quote.currentPrice < historical.movingAverage50 &&
        historical.trendSlopePercentPerDay < 0 &&
        historical.periodChangePercent <= -8;

    if (breakdown) {
      signals.add(
        const MarketSignal(
          type: MarketSignalType.breakdown,
          title: 'Ослабление тренда',
          description:
              'Цена находится ниже MA50, а движение за период остаётся отрицательным.',
          priority: 65,
        ),
      );
    }
  }
}
