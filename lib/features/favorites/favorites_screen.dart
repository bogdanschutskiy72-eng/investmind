import 'package:flutter/material.dart';

import '../../company/company_screen.dart';
import '../../services/favorites_service.dart';
import '../../services/historical_price_service.dart';
import '../../services/stock_service.dart';
import '../comparison/company_comparison.dart';
import '../comparison/comparison_service.dart';
import '../market/market_catalog.dart';
import '../market/market_company.dart';
import '../market/market_signal.dart';
import '../market/market_signal_service.dart';
import '../market/opportunity_score_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final StockService _stockService = StockService();
  final ComparisonService _comparisonService = ComparisonService();
  final HistoricalPriceService _historicalPriceService =
      HistoricalPriceService();
  final MarketSignalService _marketSignalService = const MarketSignalService();
  final OpportunityScoreService _opportunityScoreService =
      const OpportunityScoreService();

  final Map<String, Future<StockQuote>> _quoteFutures =
      <String, Future<StockQuote>>{};

  final Map<String, Future<_FavoriteAnalytics>> _analyticsFutures =
      <String, Future<_FavoriteAnalytics>>{};

  MarketCompany? _catalogCompanyFor(String value) {
    final normalized = value.trim().toUpperCase();

    for (final company in marketCompanies) {
      if (company.symbol.toUpperCase() == normalized ||
          company.name.toUpperCase() == normalized) {
        return company;
      }
    }

    return null;
  }

  String _symbolForCompany(String company) {
    final catalogCompany = _catalogCompanyFor(company);

    if (catalogCompany != null) {
      return catalogCompany.symbol;
    }

    switch (company.toUpperCase()) {
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
        return company.trim().toUpperCase();
    }
  }

  String _displayNameForCompany(String company) {
    return _catalogCompanyFor(company)?.name ?? company;
  }

  Future<StockQuote> _quoteForCompany(String company) {
    final symbol = _symbolForCompany(company);

    return _quoteFutures.putIfAbsent(
      symbol,
      () => _stockService.fetchQuote(symbol),
    );
  }

  Future<_FavoriteAnalytics> _analyticsForCompany(String company) {
    final symbol = _symbolForCompany(company);

    return _analyticsFutures.putIfAbsent(symbol, () => _loadAnalytics(symbol));
  }

  Future<_FavoriteAnalytics> _loadAnalytics(String symbol) async {
    final quoteFuture = _quoteFutures.putIfAbsent(
      symbol,
      () => _stockService.fetchQuote(symbol),
    );

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

    return _FavoriteAnalytics(
      comparison: comparison,
      marketSignals: marketSignals,
      opportunity: opportunity,
    );
  }

  void _refreshAll() {
    setState(() {
      _quoteFutures.clear();
      _analyticsFutures.clear();
    });
  }

  void _refreshCompany(String company) {
    final symbol = _symbolForCompany(company);

    setState(() {
      _quoteFutures[symbol] = _stockService.fetchQuote(
        symbol,
        forceRefresh: true,
      );

      _analyticsFutures.remove(symbol);
    });
  }

  Future<void> _removeCompany(String company) async {
    final symbol = _symbolForCompany(company);

    await FavoritesService.instance.remove(company);

    if (!mounted) {
      return;
    }

    setState(() {
      _quoteFutures.remove(symbol);
      _analyticsFutures.remove(symbol);
    });
  }

  void _openCompany(String company) {
    final symbol = _symbolForCompany(company);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CompanyScreen(company: symbol)),
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

  Widget _buildAnalytics(String company) {
    return FutureBuilder<_FavoriteAnalytics>(
      future: _analyticsForCompany(company),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _analyticsBadge(
                'InvestMind '
                '${data.comparison.investMindScore}',
              ),
              _analyticsBadge(
                'Opportunity '
                '${data.opportunity.score}',
                highlight: true,
              ),
              _analyticsBadge(
                'Context '
                '${data.opportunity.marketContextScore}',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompanyCard(String company) {
    final symbol = _symbolForCompany(company);
    final displayName = _displayNameForCompany(company);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: () => _openCompany(company),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x3320D3C2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      symbol.length > 6 ? symbol.substring(0, 6) : symbol,
                      style: const TextStyle(
                        color: Color(0xFF20D3C2),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          symbol,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 105,
                    child: FutureBuilder<StockQuote>(
                      future: _quoteForCompany(company),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        if (snapshot.hasError || snapshot.data == null) {
                          return IconButton(
                            onPressed: () {
                              _refreshCompany(company);
                            },
                            tooltip: 'Повторить',
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.redAccent,
                            ),
                          );
                        }

                        final quote = snapshot.data!;
                        final isPositive = quote.percentChange >= 0;
                        final sign = isPositive ? '+' : '';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${quote.currentPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '$sign'
                              '${quote.percentChange.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: isPositive
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _removeCompany(company);
                    },
                    tooltip: 'Удалить из избранного',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              _buildAnalytics(company),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            tooltip: 'Обновить данные',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: FavoritesService.instance.favorites,
        builder: (context, favorites, _) {
          final companies = favorites.toList()..sort();

          if (companies.isEmpty) {
            return const Center(
              child: Text(
                'Пока нет избранных компаний',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refreshAll();
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Мои компании',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'В избранном: '
                  '${companies.length}',
                  style: const TextStyle(color: Colors.white60, fontSize: 15),
                ),
                const SizedBox(height: 24),
                ...companies.map(_buildCompanyCard),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FavoriteAnalytics {
  final CompanyComparison comparison;
  final List<MarketSignal> marketSignals;
  final OpportunityScoreResult opportunity;

  const _FavoriteAnalytics({
    required this.comparison,
    required this.marketSignals,
    required this.opportunity,
  });
}
