import 'dart:async';

import 'package:flutter/material.dart';

import '../features/comparison/company_comparison.dart';
import '../features/comparison/comparison_service.dart';
import '../features/market/market_catalog.dart';
import '../features/market/market_company.dart';
import '../features/market/market_signal.dart';
import '../features/market/market_signal_service.dart';
import '../features/market/opportunity_score_service.dart';
import '../services/favorites_service.dart';
import '../services/historical_price_service.dart';
import '../services/portfolio_service.dart';
import '../services/stock_service.dart';
import '../shared/widgets/info_card.dart';
import '../shared/widgets/price_chart.dart';

class CompanyScreen extends StatefulWidget {
  final String company;

  const CompanyScreen({super.key, required this.company});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final StockService _stockService = StockService();
  final ComparisonService _comparisonService = ComparisonService();
  final HistoricalPriceService _historicalPriceService =
      HistoricalPriceService();
  final MarketSignalService _marketSignalService = const MarketSignalService();
  final OpportunityScoreService _opportunityScoreService =
      const OpportunityScoreService();

  late Future<StockQuote> _quoteFuture;
  late Future<_CompanyInvestMindData> _investMindFuture;
  Timer? _refreshTimer;

  MarketCompany? get _catalogCompany {
    final normalized = widget.company.trim().toUpperCase();

    for (final company in marketCompanies) {
      if (company.symbol.toUpperCase() == normalized ||
          company.name.toUpperCase() == normalized) {
        return company;
      }
    }

    return null;
  }

  String get _symbol {
    final company = _catalogCompany;
    if (company != null) {
      return company.symbol;
    }

    switch (widget.company.toUpperCase()) {
      case 'NVIDIA':
        return 'NVDA';
      case 'ASML':
        return 'ASML';
      case 'TSMC':
        return 'TSM';
      case 'AMD':
        return 'AMD';
      case 'MICROSOFT':
        return 'MSFT';
      case 'APPLE':
        return 'AAPL';
      case 'AMAZON':
        return 'AMZN';
      case 'META':
        return 'META';
      case 'TESLA':
        return 'TSLA';
      default:
        return widget.company.trim().toUpperCase();
    }
  }

  String get _displayName => _catalogCompany?.name ?? widget.company;

  String get _sector {
    final company = _catalogCompany;
    if (company != null) {
      return company.sector;
    }

    return 'Сектор не определён';
  }

  @override
  void initState() {
    super.initState();

    _quoteFuture = _stockService.fetchQuote(_symbol);
    _investMindFuture = _loadInvestMind(_quoteFuture);

    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshQuoteOnly(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<_CompanyInvestMindData> _loadInvestMind(
    Future<StockQuote> quoteFuture,
  ) async {
    final quote = await quoteFuture;

    final comparisonFuture = _comparisonService.loadCompany(_symbol);
    final historicalFuture = _historicalPriceService.fetchAnalysis(
      _symbol,
      days: 90,
    );

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

    return _CompanyInvestMindData(
      comparison: comparison,
      marketSignals: marketSignals,
      opportunity: opportunity,
    );
  }

  void _refreshQuoteOnly() {
    if (!mounted) {
      return;
    }

    setState(() {
      _quoteFuture = _stockService.fetchQuote(_symbol);
    });
  }

  void _refreshAllData() {
    if (!mounted) {
      return;
    }

    setState(() {
      _quoteFuture = _stockService.fetchQuote(_symbol, forceRefresh: true);
      _investMindFuture = _loadInvestMind(_quoteFuture);
    });
  }

  String _formatPrice(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatUpdatedAt(DateTime? value) {
    if (value == null) {
      return 'нет данных';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day.$month в $hour:$minute';
  }

  double? _parseNumber(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  Future<void> _showPurchaseDialog({
    required String symbol,
    required double currentPrice,
  }) async {
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController(
      text: currentPrice.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();
    final existingPosition = PortfolioService.instance.findPosition(symbol);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Добавить покупку'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_displayName • $symbol',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (existingPosition != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Сейчас в портфеле: '
                        '${existingPosition.quantity} акц.\n'
                        'Средняя цена: '
                        '${_formatPrice(existingPosition.averagePrice)}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Количество акций',
                        hintText: 'Например, 1.5',
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
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Цена покупки',
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
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                await PortfolioService.instance.addPurchase(
                  company: _displayName,
                  symbol: symbol,
                  quantity: _parseNumber(quantityController.text)!,
                  purchasePrice: _parseNumber(priceController.text)!,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );

    quantityController.dispose();
    priceController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$symbol добавлен в портфель'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildScoreCard({
    required String title,
    required String value,
    required String detail,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF20D3C2),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $score',
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }

  Widget _buildInvestMindSection() {
    return FutureBuilder<_CompanyInvestMindData>(
      future: _investMindFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text(
                  'Рассчитываем InvestMind и Opportunity...',
                  style: TextStyle(color: Colors.white60),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
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
                  'Аналитика InvestMind временно недоступна',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _refreshAllData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return const SizedBox.shrink();
        }

        final comparison = data.comparison;
        final opportunity = data.opportunity;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'InvestMind',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 700;

                final cards = [
                  _buildScoreCard(
                    title: 'InvestMind Score',
                    value: '${comparison.investMindScore}/100',
                    detail: 'Качество компании',
                  ),
                  _buildScoreCard(
                    title: 'Opportunity Score',
                    value: '${opportunity.score}/100',
                    detail: opportunity.label,
                  ),
                  _buildScoreCard(
                    title: 'Market Context',
                    value: '${opportunity.marketContextScore}/100',
                    detail: 'Текущий рыночный контекст',
                  ),
                ];

                if (compact) {
                  return Column(
                    children: [
                      for (final card in cards) ...[
                        card,
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      Expanded(child: cards[index]),
                      if (index < cards.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildBadge('Tech', comparison.technicalScore),
                _buildBadge('Fund', comparison.fundamentalScore),
                _buildBadge('Growth', comparison.growthScore),
                _buildBadge('Value', comparison.valuationScore),
                _buildBadge('Risk', comparison.riskScore),
                _buildBadge('Conf', comparison.confidenceScore),
              ],
            ),
            const SizedBox(height: 16),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ExpansionTile(
                  title: Text(
                    'Почему Opportunity ${opportunity.score}/100?',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    opportunity.label,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _contribution(
                      'InvestMind ${comparison.investMindScore} × 70%',
                      opportunity.investMindContribution,
                    ),
                    const SizedBox(height: 8),
                    _contribution(
                      'Market Context ${opportunity.marketContextScore} × 20%',
                      opportunity.marketContextContribution,
                    ),
                    const SizedBox(height: 8),
                    _contribution(
                      'Confidence ${comparison.confidenceScore} × 10%',
                      opportunity.confidenceContribution,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Итого до округления',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                        Text(
                          opportunity.rawScore.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFF20D3C2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: opportunity.reasons.map((reason) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              reason,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (data.marketSignals.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Market Signals',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.marketSignals.map((signal) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20D3C2).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      signal.title,
                      style: const TextStyle(
                        color: Color(0xFF20D3C2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _contribution(String label, double value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
        Text(
          '+${value.toStringAsFixed(1)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbol = _symbol;

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName),
        actions: [
          ValueListenableBuilder<Set<String>>(
            valueListenable: FavoritesService.instance.favorites,
            builder: (context, favorites, _) {
              final isFavorite = favorites.contains(widget.company);

              return IconButton(
                onPressed: () async {
                  await FavoritesService.instance.toggleFavorite(
                    widget.company,
                  );
                },
                tooltip: isFavorite
                    ? 'Удалить из избранного'
                    : 'Добавить в избранное',
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? const Color(0xFF20D3C2) : Colors.white,
                ),
              );
            },
          ),
          IconButton(
            onPressed: _refreshAllData,
            tooltip: 'Обновить данные',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<StockQuote>(
        future: _quoteFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Не удалось загрузить котировку',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refreshAllData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final quote = snapshot.data;

          if (quote == null) {
            return const Center(child: Text('Котировка не получена'));
          }

          final isPositive = quote.percentChange >= 0;
          final changeColor = isPositive
              ? Colors.greenAccent
              : Colors.redAccent;
          final changeSign = isPositive ? '+' : '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$symbol • $_sector',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
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
                            'Текущая цена',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _formatPrice(quote.currentPrice),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$changeSign'
                            '${quote.percentChange.toStringAsFixed(2)}%'
                            '  •  '
                            '$changeSign'
                            '\$${quote.change.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: changeColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Обновлено: ${_formatUpdatedAt(quote.updatedAt)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _showPurchaseDialog(
                                  symbol: symbol,
                                  currentPrice: quote.currentPrice,
                                );
                              },
                              icon: const Icon(Icons.add_shopping_cart),
                              label: const Text('Добавить покупку в портфель'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    PriceChart(symbol: symbol),
                    const SizedBox(height: 24),
                    const Text(
                      'Данные за торговый день',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        InfoCard(
                          title: 'Открытие',
                          value: _formatPrice(quote.open),
                        ),
                        const SizedBox(width: 16),
                        InfoCard(
                          title: 'Максимум',
                          value: _formatPrice(quote.high),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        InfoCard(
                          title: 'Минимум',
                          value: _formatPrice(quote.low),
                        ),
                        const SizedBox(width: 16),
                        InfoCard(
                          title: 'Пред. закрытие',
                          value: _formatPrice(quote.previousClose),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _buildInvestMindSection(),
                    const SizedBox(height: 30),
                    const Text(
                      'Краткий анализ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'InvestMind Score оценивает качество компании, '
                      'а Opportunity Score добавляет текущий рыночный '
                      'контекст и уверенность данных.',
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompanyInvestMindData {
  final CompanyComparison comparison;
  final List<MarketSignal> marketSignals;
  final OpportunityScoreResult opportunity;

  const _CompanyInvestMindData({
    required this.comparison,
    required this.marketSignals,
    required this.opportunity,
  });
}
