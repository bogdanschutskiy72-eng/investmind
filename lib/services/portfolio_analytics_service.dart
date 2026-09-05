import '../features/comparison/company_comparison.dart';
import '../features/comparison/comparison_service.dart';
import '../features/market/market_signal.dart';
import '../features/market/market_signal_service.dart';
import '../features/market/opportunity_score_service.dart';
import 'historical_price_service.dart';
import 'portfolio_service.dart';
import 'stock_service.dart';

enum PortfolioAnalyticsStatus { empty, complete, partial }

class PortfolioAnalyticsPosition {
  final PortfolioPosition position;
  final StockQuote quote;
  final CompanyComparison comparison;
  final List<MarketSignal> marketSignals;
  final OpportunityScoreResult opportunity;

  final double currentValue;
  final double profit;
  final double profitPercent;
  final double weightPercent;

  const PortfolioAnalyticsPosition({
    required this.position,
    required this.quote,
    required this.comparison,
    required this.marketSignals,
    required this.opportunity,
    required this.currentValue,
    required this.profit,
    required this.profitPercent,
    required this.weightPercent,
  });
}

class PortfolioAnalyticsResult {
  final List<PortfolioAnalyticsPosition> positions;

  final double investedAmount;
  final double currentValue;
  final double profit;
  final double profitPercent;

  final int investMindScore;
  final int opportunityScore;
  final int marketContextScore;
  final int confidenceScore;

  final double largestPositionWeightPercent;
  final String? largestPositionSymbol;

  final List<String> warnings;

  final PortfolioAnalyticsStatus status;
  final int requestedPositionCount;
  final List<String> failedSymbols;

  const PortfolioAnalyticsResult({
    required this.positions,
    required this.investedAmount,
    required this.currentValue,
    required this.profit,
    required this.profitPercent,
    required this.investMindScore,
    required this.opportunityScore,
    required this.marketContextScore,
    required this.confidenceScore,
    required this.largestPositionWeightPercent,
    required this.largestPositionSymbol,
    required this.warnings,
    required this.status,
    required this.requestedPositionCount,
    required this.failedSymbols,
  });

  int get loadedPositionCount => positions.length;

  bool get isComplete {
    return status == PortfolioAnalyticsStatus.complete;
  }

  bool get isPartial {
    return status == PortfolioAnalyticsStatus.partial;
  }

  bool get isEmpty {
    return status == PortfolioAnalyticsStatus.empty;
  }

  bool get hasFailures {
    return failedSymbols.isNotEmpty;
  }

  double get completionPercent {
    if (requestedPositionCount <= 0) {
      return 100.0;
    }

    return loadedPositionCount / requestedPositionCount * 100.0;
  }
}

class PortfolioAnalyticsService {
  final StockService _stockService;
  final ComparisonService _comparisonService;
  final HistoricalPriceService _historicalPriceService;
  final MarketSignalService _marketSignalService;
  final OpportunityScoreService _opportunityScoreService;

  PortfolioAnalyticsService({
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

  Future<PortfolioAnalyticsResult> analyze(
    List<PortfolioPosition> positions,
  ) async {
    if (positions.isEmpty) {
      return const PortfolioAnalyticsResult(
        positions: [],
        investedAmount: 0,
        currentValue: 0,
        profit: 0,
        profitPercent: 0,
        investMindScore: 0,
        opportunityScore: 0,
        marketContextScore: 0,
        confidenceScore: 0,
        largestPositionWeightPercent: 0,
        largestPositionSymbol: null,
        warnings: [],
        status: PortfolioAnalyticsStatus.empty,
        requestedPositionCount: 0,
        failedSymbols: [],
      );
    }

    final loaded = <_LoadedPosition>[];
    final failedSymbols = <String>[];

    for (final position in positions) {
      final symbol = position.symbol.trim().toUpperCase();

      try {
        final results = await Future.wait<dynamic>([
          _stockService.fetchQuote(symbol),
          _comparisonService.loadCompany(symbol),
          _historicalPriceService.fetchAnalysis(symbol, days: 90),
        ]);

        final quote = results[0] as StockQuote;
        final comparison = results[1] as CompanyComparison;
        final historical = results[2] as HistoricalPriceAnalysis;

        final marketSignals = _marketSignalService.buildSignals(
          quote: quote,
          historical: historical,
        );

        final opportunity = _opportunityScoreService.calculate(
          company: comparison,
          marketSignals: marketSignals,
        );

        final currentValue = quote.currentPrice * position.quantity;

        final profit = currentValue - position.investedAmount;

        final profitPercent = position.investedAmount <= 0
            ? 0.0
            : profit / position.investedAmount * 100.0;

        loaded.add(
          _LoadedPosition(
            position: position,
            quote: quote,
            comparison: comparison,
            marketSignals: marketSignals,
            opportunity: opportunity,
            currentValue: currentValue,
            profit: profit,
            profitPercent: profitPercent,
          ),
        );
      } catch (_) {
        if (symbol.isNotEmpty && !failedSymbols.contains(symbol)) {
          failedSymbols.add(symbol);
        }
      }
    }

    if (loaded.isEmpty) {
      throw StateError(
        'Не удалось получить аналитику ни по одной позиции портфеля. '
        'Проблемные тикеры: ${failedSymbols.join(', ')}.',
      );
    }

    final investedAmount = loaded.fold<double>(
      0,
      (sum, item) => sum + item.position.investedAmount,
    );

    final currentValue = loaded.fold<double>(
      0,
      (sum, item) => sum + item.currentValue,
    );

    final profit = currentValue - investedAmount;

    final profitPercent = investedAmount <= 0
        ? 0.0
        : profit / investedAmount * 100.0;

    final resultPositions = <PortfolioAnalyticsPosition>[];

    for (final item in loaded) {
      final weightPercent = currentValue <= 0
          ? 0.0
          : item.currentValue / currentValue * 100.0;

      resultPositions.add(
        PortfolioAnalyticsPosition(
          position: item.position,
          quote: item.quote,
          comparison: item.comparison,
          marketSignals: item.marketSignals,
          opportunity: item.opportunity,
          currentValue: item.currentValue,
          profit: item.profit,
          profitPercent: item.profitPercent,
          weightPercent: weightPercent,
        ),
      );
    }

    resultPositions.sort((a, b) => b.weightPercent.compareTo(a.weightPercent));

    final investMindScore = _weightedAverage(
      resultPositions,
      (item) => item.comparison.investMindScore.toDouble(),
    );

    final opportunityScore = _weightedAverage(
      resultPositions,
      (item) => item.opportunity.score.toDouble(),
    );

    final marketContextScore = _weightedAverage(
      resultPositions,
      (item) => item.opportunity.marketContextScore.toDouble(),
    );

    final confidenceScore = _weightedAverage(
      resultPositions,
      (item) => item.comparison.confidenceScore.toDouble(),
    );

    final largestPosition = resultPositions.first;

    final status = failedSymbols.isEmpty
        ? PortfolioAnalyticsStatus.complete
        : PortfolioAnalyticsStatus.partial;

    final warnings = _buildWarnings(
      resultPositions,
      investMindScore: investMindScore,
      opportunityScore: opportunityScore,
      confidenceScore: confidenceScore,
      requestedPositionCount: positions.length,
      failedSymbols: failedSymbols,
    );

    return PortfolioAnalyticsResult(
      positions: resultPositions,
      investedAmount: investedAmount,
      currentValue: currentValue,
      profit: profit,
      profitPercent: profitPercent,
      investMindScore: investMindScore,
      opportunityScore: opportunityScore,
      marketContextScore: marketContextScore,
      confidenceScore: confidenceScore,
      largestPositionWeightPercent: largestPosition.weightPercent,
      largestPositionSymbol: largestPosition.position.symbol,
      warnings: warnings,
      status: status,
      requestedPositionCount: positions.length,
      failedSymbols: List<String>.unmodifiable(failedSymbols),
    );
  }

  int _weightedAverage(
    List<PortfolioAnalyticsPosition> positions,
    double Function(PortfolioAnalyticsPosition item) readValue,
  ) {
    double total = 0.0;
    double totalWeight = 0.0;

    for (final item in positions) {
      final weight = item.currentValue;

      if (weight <= 0) {
        continue;
      }

      total += readValue(item) * weight;
      totalWeight += weight;
    }

    if (totalWeight <= 0) {
      return 0;
    }

    return (total / totalWeight).round().clamp(0, 100);
  }

  List<String> _buildWarnings(
    List<PortfolioAnalyticsPosition> positions, {
    required int investMindScore,
    required int opportunityScore,
    required int confidenceScore,
    required int requestedPositionCount,
    required List<String> failedSymbols,
  }) {
    final warnings = <String>[];

    if (positions.isEmpty) {
      return warnings;
    }

    if (failedSymbols.isNotEmpty) {
      warnings.add(
        'Аналитика портфеля неполная: загружено '
        '${positions.length} из $requestedPositionCount позиций. '
        'Не удалось получить данные: ${failedSymbols.join(', ')}.',
      );
    }

    final largest = positions.first;

    if (largest.weightPercent >= 50) {
      warnings.add(
        '${largest.position.symbol} занимает '
        '${largest.weightPercent.toStringAsFixed(1)}% '
        'проанализированной части портфеля — '
        'очень высокая концентрация.',
      );
    } else if (largest.weightPercent >= 35) {
      warnings.add(
        '${largest.position.symbol} занимает '
        '${largest.weightPercent.toStringAsFixed(1)}% '
        'проанализированной части портфеля — '
        'концентрация повышена.',
      );
    }

    if (failedSymbols.isEmpty) {
      if (positions.length == 1) {
        warnings.add(
          'Портфель состоит из одной позиции '
          'и почти не диверсифицирован.',
        );
      } else if (positions.length <= 3) {
        warnings.add(
          'В портфеле мало позиций — '
          'диверсификация ограничена.',
        );
      }
    }

    if (investMindScore < 50) {
      warnings.add(
        'Средневзвешенный InvestMind Score '
        'проанализированных позиций ниже 50.',
      );
    }

    if (opportunityScore < 50) {
      warnings.add(
        'Средневзвешенный Opportunity Score '
        'проанализированных позиций ниже 50.',
      );
    }

    if (confidenceScore < 70) {
      warnings.add(
        'Уверенность аналитических данных '
        'по проанализированным позициям ниже 70%.',
      );
    }

    final weakPositions = positions
        .where((item) => item.opportunity.score < 35)
        .map((item) => item.position.symbol)
        .toList();

    if (weakPositions.isNotEmpty) {
      warnings.add('Низкий Opportunity Score: ${weakPositions.join(', ')}.');
    }

    return warnings;
  }
}

class _LoadedPosition {
  final PortfolioPosition position;
  final StockQuote quote;
  final CompanyComparison comparison;
  final List<MarketSignal> marketSignals;
  final OpportunityScoreResult opportunity;

  final double currentValue;
  final double profit;
  final double profitPercent;

  const _LoadedPosition({
    required this.position,
    required this.quote,
    required this.comparison,
    required this.marketSignals,
    required this.opportunity,
    required this.currentValue,
    required this.profit,
    required this.profitPercent,
  });
}
