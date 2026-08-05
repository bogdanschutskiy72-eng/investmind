import 'package:flutter/material.dart';

import '../../company/company_screen.dart';
import '../../services/favorites_service.dart';
import '../../services/stock_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final StockService _stockService = StockService();

  final Map<String, Future<StockQuote>> _quoteFutures = {};

  String _symbolForCompany(String company) {
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
        return company.toUpperCase();
    }
  }

  Future<StockQuote> _quoteForCompany(String company) {
    final symbol = _symbolForCompany(company);

    return _quoteFutures.putIfAbsent(
      symbol,
      () => _stockService.fetchQuote(symbol),
    );
  }

  void _refreshAll() {
    setState(() {
      _quoteFutures.clear();
    });
  }

  void _refreshCompany(String company) {
    final symbol = _symbolForCompany(company);

    setState(() {
      _quoteFutures[symbol] =
          _stockService.fetchQuote(symbol);
    });
  }

  Future<void> _removeCompany(String company) async {
    final symbol = _symbolForCompany(company);

    await FavoritesService.instance.remove(company);

    _quoteFutures.remove(symbol);
  }

  void _openCompany(String company) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyScreen(
          company: company,
        ),
      ),
    );
  }

  Widget _buildCompanyCard(String company) {
    final symbol = _symbolForCompany(company);

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
          child: Row(
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
                  symbol.length > 6
                      ? symbol.substring(0, 6)
                      : symbol,
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      company,
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
                child: FutureBuilder<StockQuote>(future: _quoteForCompany(company),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError ||
                        snapshot.data == null) {
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
                    final isPositive =
                        quote.percentChange >= 0;
                    final sign = isPositive ? '+' : '';

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
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
            tooltip: 'Обновить котировки',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable:
            FavoritesService.instance.favorites,
        builder: (context, favorites, _) {
          final companies = favorites.toList()..sort();

          if (companies.isEmpty) {
            return const Center(
              child: Text(
                'Пока нет избранных компаний',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Мои компании',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('В избранном: ${companies.length}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),
              ...companies.map(_buildCompanyCard),
            ],
          );
        },
      ),
    );
  }
}