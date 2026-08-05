import 'dart:async';

import 'package:flutter/material.dart';

import '../../company/company_screen.dart';
import '../../services/stock_service.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final StockService _stockService = StockService();
  final TextEditingController _searchController =
      TextEditingController();

  Timer? _searchTimer;

  bool _isSearching = false;
  String? _searchError;
  List<StockSearchResult> _searchResults = [];

  final List<_MarketCompany> _companies = const [
    _MarketCompany(
      name: 'NVIDIA',
      symbol: 'NVDA',
      sector: 'Полупроводники',
    ),
    _MarketCompany(
      name: 'ASML',
      symbol: 'ASML',
      sector: 'Оборудование для чипов',
    ),
    _MarketCompany(
      name: 'TSMC',
      symbol: 'TSM',
      sector: 'Производство чипов',
    ),
    _MarketCompany(
      name: 'AMD',
      symbol: 'AMD',
      sector: 'Полупроводники',
    ),
    _MarketCompany(
      name: 'Microsoft',
      symbol: 'MSFT',
      sector: 'Программное обеспечение',
    ),
    _MarketCompany(
      name: 'Apple',
      symbol: 'AAPL',
      sector: 'Электроника',
    ),
    _MarketCompany(
      name: 'Amazon',
      symbol: 'AMZN',
      sector: 'Электронная коммерция',
    ),
    _MarketCompany(
      name: 'Meta',
      symbol: 'META',
      sector: 'Интернет и реклама',
    ),
    _MarketCompany(
      name: 'Tesla',
      symbol: 'TSLA',
      sector: 'Автомобили',
    ),
  ];

  Map<String, Future<StockQuote>> _quoteFutures = {};

  bool get _hasSearchQuery {
    return _searchController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadQuotes() {
    _quoteFutures = {
      for (final company in _companies)
        company.symbol: _stockService.fetchQuote(
          company.symbol,
        ),
    };
  }

  void _refreshAll() {
    setState(() {
      _loadQuotes();
    });
  }

  void _refreshCompany(String symbol) {
    setState(() {
      _quoteFutures[symbol] = _stockService.fetchQuote(
        symbol,
      );
    });
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchError = null;
        _searchResults = [];
      });

      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    _searchTimer = Timer(
      const Duration(milliseconds: 600),
      () {
        _searchCompanies(query);
      },
    );
  }

  Future<void> _searchCompanies(String query) async {
    try {
      final results = await _stockService.searchSymbols(
        query,
      );

      if (!mounted) return;

      if (_searchController.text.trim() != query) {
        return;
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
        _searchError = null;
      });
    } catch (error) {
      if (!mounted) return;

      if (_searchController.text.trim() != query) {
        return;
      }

      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = error.toString();
      });
    }
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();

    setState(() {
      _isSearching = false;
      _searchError = null;
      _searchResults = [];
    });
  }

  void _refreshVisibleData() {
    final query = _searchController.text.trim();

    if (query.isNotEmpty) {
      setState(() {
        _isSearching = true;
        _searchError = null;
      });

      _searchCompanies(query);
      return;
    }

    _refreshAll();
  }

  void _openCompany(_MarketCompany company) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CompanyScreen(
          company: company.name,
        ),
      ),
    );
  }

  void _openSearchResult(StockSearchResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyScreen(
          company: result.symbol,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Название компании или тикер...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _hasSearchQuery
            ? IconButton(
                onPressed: _clearSearch,
                tooltip: 'Очистить поиск',
                icon: const Icon(Icons.close),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF20D3C2),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard(_MarketCompany company) {
    final quoteFuture = _quoteFutures[company.symbol];

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
                  company.symbol,
                  style: const TextStyle(
                    color: Color(0xFF20D3C2),
                    fontSize: 13,
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
                      company.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${company.symbol} • ${company.sector}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: quoteFuture == null
                    ? const Text(
                        'Нет данных',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.redAccent,
                        ),
                      )
                    : FutureBuilder<StockQuote>(
                        future: quoteFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Align(
                              alignment:
                                  Alignment.centerRight,
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError ||
                              snapshot.data == null) {
                            return Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: [
                                const Text(
                                  'Ошибка',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _refreshCompany(
                                      company.symbol,
                                    );
                                  },
                                  tooltip: 'Повторить',
                                  icon: const Icon(
                                    Icons.refresh,
                                    size: 18,
                                  ),
                                ),
                              ],
                            );
                          }

                          final quote = snapshot.data!;
                          final isPositive =
                              quote.percentChange >= 0;
                          final sign =
                              isPositive ? '+' : '';

                          return Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${quote.currentPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.bold,
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
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(
    StockSearchResult result,
  ) {
    final visibleSymbol = result.displaySymbol.isNotEmpty
        ? result.displaySymbol
        : result.symbol;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: () => _openSearchResult(result),
        borderRadius: BorderRadius.circular(18),
        child: Padding(padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x3320D3C2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  visibleSymbol.length > 6
                      ? visibleSymbol.substring(0, 6)
                      : visibleSymbol,
                  textAlign: TextAlign.center,
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
                      result.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.type.isEmpty
                          ? result.symbol
                          : '${result.symbol} • ${result.type}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 17,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off,
              size: 44,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 14),
            const Text(
              'Не удалось выполнить поиск',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshVisibleData,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 46,
                color: Colors.white38,
              ),
              SizedBox(height: 14),
              Text(
                'Ничего не найдено',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Результаты: ${_searchResults.length}',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 14),
        ..._searchResults.map(_buildSearchResultCard),
      ],
    );
  }

  Widget _buildDefaultMarketContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Компании',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Актуальные цены и изменение за торговый день',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 24),
        ..._companies.map(_buildCompanyCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рынок'),
        actions: [
          IconButton(
            onPressed: _refreshVisibleData,
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSearchField(),
          const SizedBox(height: 24),
          if (_hasSearchQuery)
            _buildSearchContent()
          else
            _buildDefaultMarketContent(),
        ],
      ),
    );
  }
}

class _MarketCompany {
  final String name;
  final String symbol;
  final String sector;

  const _MarketCompany({
    required this.name,
    required this.symbol,
    required this.sector,
  });
}