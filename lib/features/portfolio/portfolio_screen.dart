import 'package:flutter/material.dart';

import '../../company/company_screen.dart';
import '../../services/historical_price_service.dart';
import '../../services/portfolio_analytics_service.dart';
import '../../services/portfolio_service.dart';
import '../../services/stock_service.dart';
import '../comparison/company_comparison.dart';
import '../comparison/comparison_service.dart';
import '../market/market_signal.dart';
import '../market/market_signal_service.dart';
import '../market/opportunity_score_service.dart';
import 'portfolio_health_service.dart';
import 'portfolio_optimization_curve_service.dart';
import 'portfolio_optimization_curve_widget.dart';
import 'portfolio_rebalance_optimizer_service.dart';
import 'portfolio_recommendation_service.dart';
import 'portfolio_simulator_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final StockService _stockService = StockService();
  final ComparisonService _comparisonService = ComparisonService();
  final HistoricalPriceService _historicalPriceService =
      HistoricalPriceService();
  final MarketSignalService _marketSignalService = const MarketSignalService();
  final OpportunityScoreService _opportunityScoreService =
      const OpportunityScoreService();
  final PortfolioAnalyticsService _portfolioAnalyticsService =
      PortfolioAnalyticsService();
  final PortfolioHealthService _portfolioHealthService =
      const PortfolioHealthService();
  final PortfolioRecommendationService _portfolioRecommendationService =
      const PortfolioRecommendationService();
  final PortfolioSimulatorService _portfolioSimulatorService =
      const PortfolioSimulatorService();
  final PortfolioRebalanceOptimizerService _portfolioRebalanceOptimizerService =
      const PortfolioRebalanceOptimizerService();
  final PortfolioOptimizationCurveService _portfolioOptimizationCurveService =
      const PortfolioOptimizationCurveService();

  final Map<String, Future<StockQuote>> _quoteFutures =
      <String, Future<StockQuote>>{};

  final Map<String, Future<_PortfolioAnalytics>> _analyticsFutures =
      <String, Future<_PortfolioAnalytics>>{};

  Future<PortfolioAnalyticsResult>? _portfolioAnalyticsFuture;
  String? _portfolioAnalyticsSignature;

  double _simulationTargetWeightPercent = 50.0;
  String? _simulationSymbol;

  Future<StockQuote> _quoteFor(String symbol) {
    final normalized = symbol.trim().toUpperCase();

    return _quoteFutures.putIfAbsent(
      normalized,
      () => _stockService.fetchQuote(normalized),
    );
  }

  Future<_PortfolioAnalytics> _analyticsFor(String symbol) {
    final normalized = symbol.trim().toUpperCase();

    return _analyticsFutures.putIfAbsent(
      normalized,
      () => _loadAnalytics(normalized),
    );
  }

  Future<_PortfolioAnalytics> _loadAnalytics(String symbol) async {
    final quoteFuture = _quoteFor(symbol);

    final comparisonFuture = _comparisonService.loadCompany(symbol);
    final historicalFuture = _historicalPriceService.fetchAnalysis(
      symbol,
      days: 90,
    );

    final quote = await quoteFuture;
    final comparison = await comparisonFuture;
    final historical = await historicalFuture;

    final marketSignals = _marketSignalService.buildSignals(
      quote: quote,
      historical: historical,
    );

    final opportunity = _opportunityScoreService.calculate(
      company: comparison,
      marketSignals: marketSignals,
    );

    return _PortfolioAnalytics(
      comparison: comparison,
      marketSignals: marketSignals,
      opportunity: opportunity,
    );
  }

  Future<PortfolioAnalyticsResult> _portfolioAnalyticsFor(
    List<PortfolioPosition> positions,
  ) {
    final signature = positions
        .map(
          (position) =>
              '${position.symbol}:${position.quantity}:${position.averagePrice}',
        )
        .join('|');

    if (_portfolioAnalyticsFuture == null ||
        _portfolioAnalyticsSignature != signature) {
      _portfolioAnalyticsSignature = signature;
      _portfolioAnalyticsFuture = _portfolioAnalyticsService.analyze(positions);
    }

    return _portfolioAnalyticsFuture!;
  }

  void _refreshData() {
    setState(() {
      _quoteFutures.clear();
      _analyticsFutures.clear();
      _portfolioAnalyticsFuture = null;
      _portfolioAnalyticsSignature = null;
    });
  }

  String _formatMoney(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(4);
  }

  double? _parseNumber(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  Future<void> _showPositionDialog({PortfolioPosition? position}) async {
    final companyController = TextEditingController(
      text: position?.company ?? '',
    );

    final symbolController = TextEditingController(
      text: position?.symbol ?? '',
    );

    final quantityController = TextEditingController(
      text: position == null ? '' : _formatQuantity(position.quantity),
    );

    final averagePriceController = TextEditingController(
      text: position == null ? '' : position.averagePrice.toStringAsFixed(2),
    );

    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            position == null ? 'Добавить позицию' : 'Редактировать позицию',
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: companyController,
                      decoration: const InputDecoration(
                        labelText: 'Компания',
                        hintText: 'Например, NVIDIA',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: symbolController,
                      enabled: position == null,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Тикер',
                        hintText: 'Например, NVDA',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите тикер';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Количество акций',
                      ),
                      validator: (value) {
                        final quantity = _parseNumber(value ?? '');
                        if (quantity == null || quantity <= 0) {
                          return 'Введите количество больше нуля';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: averagePriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Средняя цена',
                        prefixText: '\$ ',
                      ),
                      validator: (value) {
                        final price = _parseNumber(value ?? '');
                        if (price == null || price <= 0) {
                          return 'Введите цену больше нуля';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                await PortfolioService.instance.addOrUpdatePosition(
                  company: companyController.text.trim(),
                  symbol: symbolController.text.trim().toUpperCase(),
                  quantity: _parseNumber(quantityController.text)!,
                  averagePrice: _parseNumber(averagePriceController.text)!,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    companyController.dispose();
    symbolController.dispose();
    quantityController.dispose();
    averagePriceController.dispose();

    if (saved == true && mounted) {
      _refreshData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Позиция сохранена'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showSellDialog({
    required PortfolioPosition position,
    required double currentPrice,
  }) async {
    final quantityController = TextEditingController(
      text: _formatQuantity(position.quantity),
    );

    final priceController = TextEditingController(
      text: currentPrice.toStringAsFixed(2),
    );

    final formKey = GlobalKey<FormState>();

    final sold = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Продать акции'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${position.company} • ${position.symbol}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'В портфеле: '
                      '${_formatQuantity(position.quantity)} шт.\n'
                      'Средняя цена: '
                      '${_formatMoney(position.averagePrice)}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Количество для продажи',
                      ),
                      validator: (value) {
                        final quantity = _parseNumber(value ?? '');
                        if (quantity == null || quantity <= 0) {
                          return 'Введите количество больше нуля';
                        }
                        if (quantity > position.quantity) {
                          return 'В портфеле недостаточно акций';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Цена продажи',
                        prefixText: '\$ ',
                      ),
                      validator: (value) {
                        final price = _parseNumber(value ?? '');
                        if (price == null || price <= 0) {
                          return 'Введите цену больше нуля';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                try {
                  final profit = await PortfolioService.instance.sellPosition(
                    symbol: position.symbol,
                    quantity: _parseNumber(quantityController.text)!,
                    salePrice: _parseNumber(priceController.text)!,
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }

                  if (mounted) {
                    final resultText = profit >= 0
                        ? 'Прибыль: ${_formatMoney(profit)}'
                        : 'Убыток: ${_formatMoney(profit.abs())}';

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Продажа сохранена. $resultText'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Продать'),
            ),
          ],
        );
      },
    );

    quantityController.dispose();
    priceController.dispose();

    if (sold == true && mounted) {
      _refreshData();
    }
  }

  Future<void> _confirmDelete(PortfolioPosition position) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить позицию?'),
          content: Text(
            '${position.company} • ${position.symbol}\n\n'
            'Позиция будет удалена без записи продажи '
            'в историю.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Удалить',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await PortfolioService.instance.removePosition(position.symbol);
      _refreshData();
    }
  }

  Future<_PortfolioSummary> _loadSummary(
    List<PortfolioPosition> positions,
  ) async {
    double invested = 0;
    double currentValue = 0;

    for (final position in positions) {
      invested += position.investedAmount;

      try {
        final quote = await _quoteFor(position.symbol);
        currentValue += quote.currentPrice * position.quantity;
      } catch (_) {
        currentValue += position.investedAmount;
      }
    }

    return _PortfolioSummary(invested: invested, currentValue: currentValue);
  }

  Widget _buildAnalytics(PortfolioPosition position) {
    return FutureBuilder<_PortfolioAnalytics>(
      future: _analyticsFor(position.symbol),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 14),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _analyticsBadge('InvestMind ${data.comparison.investMindScore}'),
              _analyticsBadge(
                'Opportunity ${data.opportunity.score}',
                highlight: true,
              ),
              _analyticsBadge('Context ${data.opportunity.marketContextScore}'),
            ],
          ),
        );
      },
    );
  }

  Widget _analyticsBadge(String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF20D3C2).withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: highlight ? const Color(0xFF20D3C2) : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPortfolioAnalyticsBlock(List<PortfolioPosition> positions) {
    return FutureBuilder<PortfolioAnalyticsResult>(
      future: _portfolioAnalyticsFor(positions),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text(
                  'Анализируем портфель...',
                  style: TextStyle(color: Colors.white60),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Portfolio Analytics временно недоступен',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        final result = snapshot.data!;

        if (result.isPartial) {
          return _buildPartialAnalyticsState(result);
        }

        final health = _portfolioHealthService.calculate(result);

        final recommendations = _portfolioRecommendationService.build(
          analytics: result,
          health: health,
        );
        final defaultSimulationSymbol =
            result.largestPositionSymbol ??
            result.positions.first.position.symbol;

        final selectedSimulationPosition = result.positions.firstWhere(
          (item) =>
              item.position.symbol ==
              (_simulationSymbol ?? defaultSimulationSymbol),
          orElse: () => result.positions.firstWhere(
            (item) => item.position.symbol == defaultSimulationSymbol,
          ),
        );

        final selectedSimulationSymbol =
            selectedSimulationPosition.position.symbol;
        final selectedSimulationWeight =
            selectedSimulationPosition.weightPercent;

        const minSimulationTarget = 1.0;

        final maxSimulationTarget = selectedSimulationWeight > 70.0
            ? 70.0
            : (selectedSimulationWeight - 0.5).clamp(minSimulationTarget, 70.0);

        final effectiveSimulationTarget = _simulationTargetWeightPercent.clamp(
          minSimulationTarget,
          maxSimulationTarget,
        );

        final simulations = _portfolioSimulatorService
            .buildScenariosForPosition(
              analytics: result,
              symbol: selectedSimulationSymbol,
              targetWeightPercent: effectiveSimulationTarget,
            );
        final selectedPositionOptimization = _portfolioSimulatorService
            .optimizePosition(
              analytics: result,
              symbol: selectedSimulationSymbol,
              minTargetWeightPercent: 1.0,
              stepPercent: 0.5,
            );
        final portfolioScenarioRanking = _portfolioSimulatorService
            .rankPortfolioScenarios(
              analytics: result,
              minTargetWeightPercent: 1.0,
              stepPercent: 0.5,
            );
        final optimization = _portfolioRebalanceOptimizerService.optimize(
          analytics: result,
          minTargetWeightPercent: 20.0,
          maxTargetWeightPercent: 70.0,
          stepPercent: 1.0,
        );
        final optimizationCurve = _portfolioOptimizationCurveService.build(
          analytics: result,
          minTargetWeightPercent: 20.0,
          maxTargetWeightPercent: 70.0,
          stepPercent: 5.0,
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights_outlined, color: Color(0xFF20D3C2)),
                  SizedBox(width: 10),
                  Text(
                    'Portfolio Analytics',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPortfolioHealthHero(health),
              const SizedBox(height: 16),
              const Text(
                'Компоненты Health Score',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _healthComponentCard(
                    title: 'Качество',
                    value: health.qualityScore,
                    weight: '30%',
                  ),
                  _healthComponentCard(
                    title: 'Opportunity',
                    value: health.opportunityScore,
                    weight: '20%',
                  ),
                  _healthComponentCard(
                    title: 'Диверсификация',
                    value: health.diversificationScore,
                    weight: '20%',
                  ),
                  _healthComponentCard(
                    title: 'Концентрация',
                    value: health.concentrationScore,
                    weight: '15%',
                  ),
                  _healthComponentCard(
                    title: 'Устойчивость',
                    value: health.riskScore,
                    weight: '15%',
                  ),
                ],
              ),
              if (health.insights.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Portfolio Insights',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ...health.insights.take(6).map(_buildHealthInsight),
              ],
              if (!recommendations.isEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Что можно изменить',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ...recommendations.recommendations
                    .take(5)
                    .map(_buildPortfolioRecommendation),
              ],
              if (result.positions.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      color: Color(0xFF20D3C2),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Симулятор ребаланса',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Виртуальный расчёт. Реальные позиции портфеля не меняются.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 14),
                if (optimization.hasRecommendation) ...[
                  _buildOptimalRebalanceCard(optimization, maxSimulationTarget),
                  const SizedBox(height: 12),
                ],
                if (!optimizationCurve.isEmpty) ...[
                  PortfolioOptimizationCurveWidget(
                    curve: optimizationCurve,
                    currentWeightPercent: result.largestPositionWeightPercent,
                    currentHealthScore: health.score,
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Рейтинг сценариев InvestMind',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Сравниваем лучшие найденные изменения по всем '
                        'позициям. Текущий Health: '
                        '${portfolioScenarioRanking.currentHealthScore}.',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...portfolioScenarioRanking.items.asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key;
                        final item = entry.value;
                        final scenario = item.bestScenario;

                        return Container(
                          margin: EdgeInsets.only(
                            bottom:
                                index ==
                                    portfolioScenarioRanking.items.length - 1
                                ? 0
                                : 8,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    color: index == 0 && item.hasImprovement
                                        ? const Color(0xFF20D3C2)
                                        : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.symbol,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      scenario == null
                                          ? 'Улучшение Health не найдено'
                                          : '${item.currentWeightPercent.toStringAsFixed(1)}% '
                                                '→ ${scenario.targetWeightPercent.toStringAsFixed(1)}% '
                                                '• Health '
                                                '${item.currentHealthScore} '
                                                '→ ${scenario.afterHealth.score}',
                                      style: TextStyle(
                                        color: scenario == null
                                            ? Colors.white54
                                            : const Color(0xFF94A3B8),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (scenario != null)
                                Text(
                                  '+${item.healthDelta}',
                                  style: const TextStyle(
                                    color: Color(0xFF20D3C2),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else
                                const Text(
                                  '0',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              if (scenario != null)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _simulationSymbol = item.symbol;
                                      _simulationTargetWeightPercent =
                                          scenario.targetWeightPercent;
                                    });
                                  },
                                  child: const Text('Открыть'),
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Text(
                        'Проверено сценариев: '
                        '${portfolioScenarioRanking.totalTestedScenarios}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Позиция для симуляции',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Выбери позицию, долю которой хочешь виртуально изменить.',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: result.positions.map((item) {
                          final symbol = item.position.symbol;
                          final selected = symbol == selectedSimulationSymbol;

                          return ChoiceChip(
                            label: Text(
                              '$symbol  '
                              '${item.weightPercent.toStringAsFixed(1)}%',
                            ),
                            selected: selected,
                            onSelected: (_) {
                              final newMax = item.weightPercent > 70.0
                                  ? 70.0
                                  : (item.weightPercent - 0.5).clamp(
                                      minSimulationTarget,
                                      70.0,
                                    );

                              setState(() {
                                _simulationSymbol = symbol;
                                _simulationTargetWeightPercent =
                                    (item.weightPercent * 0.7).clamp(
                                      minSimulationTarget,
                                      newMax,
                                    );
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: selectedPositionOptimization.hasImprovement
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Лучший сценарий для выбранной позиции',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${selectedPositionOptimization.symbol}: '
                              '${selectedPositionOptimization.currentWeightPercent.toStringAsFixed(1)}% '
                              '→ '
                              '${selectedPositionOptimization.bestScenario!.targetWeightPercent.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Color(0xFF20D3C2),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Health '
                              '${selectedPositionOptimization.currentHealthScore} '
                              '→ '
                              '${selectedPositionOptimization.bestScenario!.afterHealth.score} '
                              '(+${selectedPositionOptimization.healthImprovement})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Проверено сценариев: '
                              '${selectedPositionOptimization.testedScenarios}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _simulationTargetWeightPercent =
                                        selectedPositionOptimization
                                            .bestScenario!
                                            .targetWeightPercent;
                                  });
                                },
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: const Text('Поставить на ползунок'),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Лучший сценарий для выбранной позиции',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Изменение ${selectedPositionOptimization.symbol} '
                              'не улучшает Portfolio Health.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              selectedPositionOptimization.testedScenarios > 0
                                  ? 'Проверено сценариев: '
                                        '${selectedPositionOptimization.testedScenarios}'
                                  : 'Недостаточно диапазона для расчёта.',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Целевая доля $selectedSimulationSymbol',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${effectiveSimulationTarget.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Color(0xFF20D3C2),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Сейчас: '
                        '${selectedSimulationWeight.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      Slider(
                        value: effectiveSimulationTarget,
                        min: minSimulationTarget,
                        max: maxSimulationTarget,
                        divisions:
                            ((maxSimulationTarget - minSimulationTarget)
                                    .round())
                                .clamp(1, 69),
                        label:
                            '${effectiveSimulationTarget.toStringAsFixed(0)}%',
                        onChanged: (value) {
                          setState(() {
                            _simulationTargetWeightPercent = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (simulations.isEmpty)
                  const Text(
                    'Для выбранной позиции при этой целевой доле '
                    'сценарий не может быть рассчитан.',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  )
                else
                  ...simulations.map(_buildSimulationCard),
              ],
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 18),
              const Text(
                'Базовые показатели',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _portfolioScoreCard(
                    title: 'InvestMind',
                    value: '${result.investMindScore}/100',
                  ),
                  _portfolioScoreCard(
                    title: 'Opportunity',
                    value: '${result.opportunityScore}/100',
                    highlight: true,
                  ),
                  _portfolioScoreCard(
                    title: 'Market Context',
                    value: '${result.marketContextScore}/100',
                  ),
                  _portfolioScoreCard(
                    title: 'Confidence',
                    value: '${result.confidenceScore}%',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (result.largestPositionSymbol != null)
                Text(
                  'Крупнейшая позиция: '
                  '${result.largestPositionSymbol} • '
                  '${result.largestPositionWeightPercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (result.positions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Структура портфеля',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ...result.positions
                    .take(5)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 58,
                              child: Text(
                                item.position.symbol,
                                style: const TextStyle(
                                  color: Color(0xFF20D3C2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: (item.weightPercent / 100).clamp(
                                  0.0,
                                  1.0,
                                ),
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 54,
                              child: Text(
                                '${item.weightPercent.toStringAsFixed(1)}%',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
              if (result.warnings.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Что требует внимания',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...result.warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      '• $warning',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartialAnalyticsState(PortfolioAnalyticsResult result) {
    final failedText = result.failedSymbols.isEmpty
        ? 'Неизвестные позиции'
        : result.failedSymbols.join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Аналитика портфеля неполная',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Получены данные по '
            '${result.loadedPositionCount} из '
            '${result.requestedPositionCount} позиций.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),

          const SizedBox(height: 6),

          Text(
            'Не удалось загрузить: $failedText.',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Portfolio Health, рекомендации и симулятор '
            'временно не рассчитываются, чтобы не показывать '
            'искажённый результат.',
            style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.45),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              TextButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),

              const SizedBox(width: 8),

              Text(
                '${result.completionPercent.toStringAsFixed(0)}% данных',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioHealthHero(PortfolioHealthResult health) {
    final accent = _healthAccentColor(health.level);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.health_and_safety_outlined,
              color: accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Portfolio Health',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${health.score}/100',
                  style: TextStyle(
                    color: accent,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  health.label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthComponentCard({
    required String title,
    required int value,
    required String weight,
  }) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            '$value/100',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            'Вес $weight',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInsight(PortfolioHealthInsight insight) {
    final icon = switch (insight.type) {
      PortfolioInsightType.strength => Icons.check_circle_outline,
      PortfolioInsightType.risk => Icons.warning_amber_rounded,
      PortfolioInsightType.improvement => Icons.tune,
    };

    final color = switch (insight.type) {
      PortfolioInsightType.strength => const Color(0xFF20D3C2),
      PortfolioInsightType.risk => Colors.orangeAccent,
      PortfolioInsightType.improvement => Colors.lightBlueAccent,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimalRebalanceCard(
    PortfolioRebalanceOptimizationResult optimization,
    double maxSimulationTarget,
  ) {
    final best = optimization.bestOverall;

    if (best == null) {
      return const SizedBox.shrink();
    }

    final improvement = optimization.healthImprovement;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF20D3C2).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF20D3C2).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF20D3C2), size: 20),
              SizedBox(width: 8),
              Text(
                'Оптимальный ребаланс InvestMind',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Лучший найденный вариант: '
            '${best.symbol} → '
            '${best.targetWeightPercent.toStringAsFixed(0)}%.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _simulationMetric(
                'Health',
                '${optimization.currentHealth.score} → '
                    '${best.afterHealth.score}',
                highlight: improvement > 0,
              ),
              _simulationMetric(
                'Диверсификация',
                '${optimization.currentHealth.diversificationScore} → '
                    '${best.afterHealth.diversificationScore}',
              ),
              _simulationMetric(
                'Концентрация',
                '${optimization.currentHealth.concentrationScore} → '
                    '${best.afterHealth.concentrationScore}',
              ),
              _simulationMetric(
                'Opportunity',
                '${optimization.currentHealth.opportunityScore} → '
                    '${best.afterHealth.opportunityScore}',
              ),
              _simulationMetric(
                'Устойчивость',
                '${optimization.currentHealth.riskScore} → '
                    '${best.afterHealth.riskScore}',
              ),
              _simulationMetric('Объём', _formatMoney(best.requiredAmount)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  optimization.testedScenarios > 0
                      ? 'Проверено сценариев: '
                            '${optimization.testedScenarios}'
                      : 'Оптимизация недоступна.',
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _simulationSymbol = best.symbol;
                    _simulationTargetWeightPercent = best.targetWeightPercent
                        .clamp(1.0, maxSimulationTarget);
                  });
                },
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Поставить на ползунок'),
              ),
            ],
          ),
          if (improvement <= 0) ...[
            const SizedBox(height: 4),
            const Text(
              'Оптимизатор не нашёл сценарий с более высоким Health Score. '
              'Показан лучший из проверенных вариантов.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 9,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimulationCard(PortfolioSimulationResult simulation) {
    final healthImproved = simulation.healthDelta >= 0;

    final IconData scenarioIcon;

    switch (simulation.type) {
      case PortfolioSimulationType.reduceLargestPosition:
        scenarioIcon = Icons.trending_down;

      case PortfolioSimulationType.addOutsideLargestPosition:
        scenarioIcon = Icons.add_chart;

      case PortfolioSimulationType.rebalanceSelectedPosition:
        scenarioIcon = Icons.swap_horiz_rounded;
    }

    final isRebalance =
        simulation.type == PortfolioSimulationType.rebalanceSelectedPosition;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRebalance
              ? const Color(0xFF20D3C2).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF20D3C2).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  scenarioIcon,
                  color: const Color(0xFF20D3C2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      simulation.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      simulation.description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isRebalance) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF20D3C2).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 14,
                    color: Color(0xFF20D3C2),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Общая стоимость портфеля не меняется',
                    style: TextStyle(
                      color: Color(0xFF20D3C2),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _simulationMetric(
                isRebalance ? 'Перераспределить' : 'Сумма',
                _formatMoney(simulation.requiredAmount),
              ),
              _simulationMetric(
                'Вес ${simulation.symbol}',
                '${simulation.beforeWeightPercent.toStringAsFixed(1)}% → '
                    '${simulation.afterWeightPercent.toStringAsFixed(1)}%',
              ),
              _simulationMetric(
                'Health',
                '${simulation.beforeHealth.score} → '
                    '${simulation.afterHealth.score}',
                highlight: healthImproved,
              ),
              _simulationMetric(
                'Диверсификация',
                '${simulation.beforeHealth.diversificationScore} → '
                    '${simulation.afterHealth.diversificationScore}',
              ),
              _simulationMetric(
                'Концентрация',
                '${simulation.beforeHealth.concentrationScore} → '
                    '${simulation.afterHealth.concentrationScore}',
              ),
              _simulationMetric(
                'Opportunity',
                '${simulation.beforeHealth.opportunityScore} → '
                    '${simulation.afterHealth.opportunityScore}',
              ),
              _simulationMetric(
                'Устойчивость',
                '${simulation.beforeHealth.riskScore} → '
                    '${simulation.afterHealth.riskScore}',
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            simulation.healthDelta == 0
                ? 'Health Score не изменился.'
                : simulation.healthDelta > 0
                ? 'Health Score: +${simulation.healthDelta} пунктов.'
                : 'Health Score: ${simulation.healthDelta} пунктов.',
            style: TextStyle(
              color: simulation.healthDelta > 0
                  ? const Color(0xFF20D3C2)
                  : simulation.healthDelta < 0
                  ? Colors.orangeAccent
                  : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Для показателя «Устойчивость» больше = лучше.',
            style: TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _simulationMetric(
    String title,
    String value, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF20D3C2).withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFF20D3C2) : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioRecommendation(PortfolioRecommendation recommendation) {
    final color = _recommendationColor(recommendation.priority);
    final icon = _recommendationIcon(recommendation.type);

    final extraLines = <String>[];

    if (recommendation.reduceByValue != null &&
        recommendation.reduceByValue! > 1) {
      extraLines.add(
        'Сценарий A: уменьшить позицию примерно на '
        '${_formatMoney(recommendation.reduceByValue!)}.',
      );
    }

    if (recommendation.addOutsidePositionValue != null &&
        recommendation.addOutsidePositionValue! > 1) {
      extraLines.add(
        'Сценарий B: добавить вне этой позиции примерно '
        '${_formatMoney(recommendation.addOutsidePositionValue!)}.',
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recommendation.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _recommendationPriorityBadge(recommendation.priority),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  recommendation.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                if (extraLines.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  ...extraLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],
                if (recommendation.targetWeightPercent != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Целевая доля: '
                    '${recommendation.targetWeightPercent!.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendationPriorityBadge(
    PortfolioRecommendationPriority priority,
  ) {
    final color = _recommendationColor(priority);

    final label = switch (priority) {
      PortfolioRecommendationPriority.high => 'Высокий',
      PortfolioRecommendationPriority.medium => 'Средний',
      PortfolioRecommendationPriority.low => 'Низкий',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _recommendationColor(PortfolioRecommendationPriority priority) {
    switch (priority) {
      case PortfolioRecommendationPriority.high:
        return Colors.orangeAccent;
      case PortfolioRecommendationPriority.medium:
        return Colors.lightBlueAccent;
      case PortfolioRecommendationPriority.low:
        return const Color(0xFF20D3C2);
    }
  }

  IconData _recommendationIcon(PortfolioRecommendationType type) {
    switch (type) {
      case PortfolioRecommendationType.concentration:
        return Icons.compress_outlined;
      case PortfolioRecommendationType.diversification:
        return Icons.hub_outlined;
      case PortfolioRecommendationType.review:
        return Icons.manage_search_outlined;
      case PortfolioRecommendationType.opportunity:
        return Icons.trending_up;
    }
  }

  Color _healthAccentColor(PortfolioHealthLevel level) {
    switch (level) {
      case PortfolioHealthLevel.excellent:
      case PortfolioHealthLevel.strong:
        return const Color(0xFF20D3C2);
      case PortfolioHealthLevel.balanced:
        return Colors.lightBlueAccent;
      case PortfolioHealthLevel.elevatedRisk:
        return Colors.orangeAccent;
      case PortfolioHealthLevel.highRisk:
        return Colors.redAccent;
    }
  }

  Widget _portfolioScoreCard({
    required String title,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF20D3C2).withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? const Color(0xFF20D3C2).withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFF20D3C2) : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Портфель'),
        actions: [
          IconButton(
            onPressed: _refreshData,
            tooltip: 'Обновить данные',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPositionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: ValueListenableBuilder<List<PortfolioPosition>>(
        valueListenable: PortfolioService.instance.positions,
        builder: (context, positions, _) {
          if (positions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 72,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Портфель пока пуст',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Добавь первую позицию или покупку '
                      'со страницы компании.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showPositionDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить позицию'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refreshData();
            },
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                FutureBuilder<_PortfolioSummary>(
                  future: _loadSummary(positions),
                  builder: (context, snapshot) {
                    final summary = snapshot.data;

                    if (summary == null) {
                      return const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final profit = summary.currentValue - summary.invested;

                    final profitPercent = summary.invested == 0
                        ? 0.0
                        : profit / summary.invested * 100;

                    final isPositive = profit >= 0;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Стоимость портфеля',
                            style: TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatMoney(summary.currentValue),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${isPositive ? '+' : '-'}'
                            '${_formatMoney(profit.abs())} '
                            '(${isPositive ? '+' : '-'}'
                            '${profitPercent.abs().toStringAsFixed(2)}%)',
                            style: TextStyle(
                              color: isPositive
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Вложено: '
                            '${_formatMoney(summary.invested)}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _buildPortfolioAnalyticsBlock(positions),
                const SizedBox(height: 24),
                const Text(
                  'Мои позиции',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...positions.map(
                  (position) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: FutureBuilder<StockQuote>(
                      future: _quoteFor(position.symbol),
                      builder: (context, snapshot) {
                        final quote = snapshot.data;

                        final currentPrice =
                            quote?.currentPrice ?? position.averagePrice;

                        final currentValue = currentPrice * position.quantity;

                        final profit = currentValue - position.investedAmount;

                        final isPositive = profit >= 0;

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CompanyScreen(
                                        company: position.symbol,
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            position.company,
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${position.symbol} • '
                                            '${_formatQuantity(position.quantity)} шт.',
                                            style: const TextStyle(
                                              color: Colors.white60,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatMoney(currentValue),
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${isPositive ? '+' : '-'}'
                                          '${_formatMoney(profit.abs())}',
                                          style: TextStyle(
                                            color: isPositive
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              _buildAnalytics(position),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        _showSellDialog(
                                          position: position,
                                          currentPrice: currentPrice,
                                        );
                                      },
                                      icon: const Icon(Icons.sell_outlined),
                                      label: const Text('Продать'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    onPressed: () {
                                      _showPositionDialog(position: position);
                                    },
                                    tooltip: 'Редактировать',
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _confirmDelete(position);
                                    },
                                    tooltip: 'Удалить',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PortfolioSummary {
  final double invested;
  final double currentValue;

  const _PortfolioSummary({required this.invested, required this.currentValue});
}

class _PortfolioAnalytics {
  final CompanyComparison comparison;
  final List<MarketSignal> marketSignals;
  final OpportunityScoreResult opportunity;

  const _PortfolioAnalytics({
    required this.comparison,
    required this.marketSignals,
    required this.opportunity,
  });
}
