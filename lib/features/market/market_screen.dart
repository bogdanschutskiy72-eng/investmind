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
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchTimer;

  bool _isSearching = false;
  String? _searchError;
  List<StockSearchResult> _searchResults = [];

  String _selectedSector = 'Все';
  _MarketSortMode _sortMode = _MarketSortMode.changeDescending;

  final List<_MarketCompany> _companies = const [
    _MarketCompany(name: 'NVIDIA', symbol: 'NVDA', sector: 'Полупроводники'),
    _MarketCompany(
      name: 'ASML',
      symbol: 'ASML',
      sector: 'Оборудование для чипов',
    ),
    _MarketCompany(name: 'TSMC', symbol: 'TSM', sector: 'Производство чипов'),
    _MarketCompany(name: 'AMD', symbol: 'AMD', sector: 'Полупроводники'),
    _MarketCompany(
      name: 'Microsoft',
      symbol: 'MSFT',
      sector: 'Программное обеспечение',
    ),
    _MarketCompany(name: 'Apple', symbol: 'AAPL', sector: 'Электроника'),
    _MarketCompany(
      name: 'Amazon',
      symbol: 'AMZN',
      sector: 'Электронная коммерция',
    ),
    _MarketCompany(name: 'Meta', symbol: 'META', sector: 'Интернет и реклама'),
    _MarketCompany(name: 'Tesla', symbol: 'TSLA', sector: 'Автомобили'),
  ];

  Map<String, Future<StockQuote>> _quoteFutures = {};

  Future<List<_MarketQuoteRow>>? _scannerFuture;

  bool get _hasSearchQuery {
    return _searchController.text.trim().isNotEmpty;
  }

  List<String> get _sectors {
    final sectors = _companies.map((company) => company.sector).toSet().toList()
      ..sort();

    return ['Все', ...sectors];
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
        company.symbol: _stockService.fetchQuote(company.symbol),
    };

    _scannerFuture = _buildScannerRows();
  }

  Future<List<_MarketQuoteRow>> _buildScannerRows() async {
    final List<_MarketQuoteRow> rows = [];

    for (final company in _companies) {
      final future = _quoteFutures[company.symbol];

      if (future == null) {
        continue;
      }

      try {
        final quote = await future;

        rows.add(_MarketQuoteRow(company: company, quote: quote));
      } catch (_) {
        // Ошибка одной компании не должна ломать весь scanner.
      }
    }

    return rows;
  }

  void _refreshAll() {
    setState(() {
      _loadQuotes();
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

    _searchTimer = Timer(const Duration(milliseconds: 600), () {
      _searchCompanies(query);
    });
  }

  Future<void> _searchCompanies(String query) async {
    try {
      final results = await _stockService.searchSymbols(query);

      if (!mounted) {
        return;
      }

      if (_searchController.text.trim() != query) {
        return;
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
        _searchError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

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
      MaterialPageRoute(builder: (_) => CompanyScreen(company: company.name)),
    );
  }

  void _openSearchResult(StockSearchResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CompanyScreen(company: result.symbol)),
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
          borderSide: const BorderSide(color: Color(0xFF20D3C2), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildScannerHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.radar, color: Color(0xFF20D3C2)),
            SizedBox(width: 10),
            Text(
              'Market Scanner',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 8),

        const Text(
          'Быстрый обзор движения компаний без лишнего рыночного шума.',
          style: TextStyle(color: Colors.white60, fontSize: 15),
        ),

        const SizedBox(height: 18),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _sectors.map((sector) {
              final selected = sector == _selectedSector;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(sector),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedSector = sector;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 14),

        Align(
          alignment: Alignment.centerRight,
          child: DropdownButton<_MarketSortMode>(
            value: _sortMode,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(
                value: _MarketSortMode.changeDescending,
                child: Text('Сначала рост'),
              ),
              DropdownMenuItem(
                value: _MarketSortMode.changeAscending,
                child: Text('Сначала падение'),
              ),
              DropdownMenuItem(
                value: _MarketSortMode.priceDescending,
                child: Text('Цена: выше'),
              ),
              DropdownMenuItem(
                value: _MarketSortMode.name,
                child: Text('По названию'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _sortMode = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScanner() {
    final future = _scannerFuture;

    if (future == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<_MarketQuoteRow>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allRows = snapshot.data ?? const [];

        if (allRows.isEmpty) {
          return _buildScannerError();
        }

        final rows = allRows.where((row) {
          if (_selectedSector == 'Все') {
            return true;
          }

          return row.company.sector == _selectedSector;
        }).toList();

        _sortRows(rows);

        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'В выбранном секторе нет компаний.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          );
        }

        final strongest = rows.reduce(
          (current, next) =>
              current.quote.percentChange > next.quote.percentChange
              ? current
              : next,
        );

        final weakest = rows.reduce(
          (current, next) =>
              current.quote.percentChange < next.quote.percentChange
              ? current
              : next,
        );

        final averageChange =
            rows.fold<double>(0, (sum, row) => sum + row.quote.percentChange) /
            rows.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScannerSummary(
              strongest: strongest,
              weakest: weakest,
              averageChange: averageChange,
            ),

            const SizedBox(height: 22),

            Text(
              'Scanner • ${rows.length} компаний',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            ...rows.map(_buildScannerCompanyCard),
          ],
        );
      },
    );
  }

  void _sortRows(List<_MarketQuoteRow> rows) {
    switch (_sortMode) {
      case _MarketSortMode.changeDescending:
        rows.sort(
          (a, b) => b.quote.percentChange.compareTo(a.quote.percentChange),
        );

      case _MarketSortMode.changeAscending:
        rows.sort(
          (a, b) => a.quote.percentChange.compareTo(b.quote.percentChange),
        );

      case _MarketSortMode.priceDescending:
        rows.sort(
          (a, b) => b.quote.currentPrice.compareTo(a.quote.currentPrice),
        );

      case _MarketSortMode.name:
        rows.sort((a, b) => a.company.name.compareTo(b.company.name));
    }
  }

  Widget _buildScannerSummary({
    required _MarketQuoteRow strongest,
    required _MarketQuoteRow weakest,
    required double averageChange,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 750;

        final cards = [
          _buildSummaryCard(
            icon: Icons.trending_up,
            title: 'Лидер роста',
            value: strongest.company.symbol,
            detail: '${_percentText(strongest.quote.percentChange)} сегодня',
          ),
          _buildSummaryCard(
            icon: Icons.trending_down,
            title: 'Слабее рынка',
            value: weakest.company.symbol,
            detail: '${_percentText(weakest.quote.percentChange)} сегодня',
          ),
          _buildSummaryCard(
            icon: Icons.analytics_outlined,
            title: 'Среднее движение',
            value: _percentText(averageChange),
            detail: _selectedSector == 'Все'
                ? 'Выбранная группа'
                : _selectedSector,
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (final card in cards) ...[card, const SizedBox(height: 10)],
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
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF20D3C2).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF20D3C2)),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),

                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerCompanyCard(_MarketQuoteRow row) {
    final company = row.company;
    final quote = row.quote;

    final positive = quote.percentChange >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: () => _openCompany(company),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF20D3C2).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  company.symbol,
                  style: const TextStyle(
                    color: Color(0xFF20D3C2),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      company.sector,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${quote.currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    _percentText(quote.percentChange),
                    style: TextStyle(
                      color: positive ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 10),

              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  String _percentText(double value) {
    final sign = value >= 0 ? '+' : '';

    return '$sign${value.toStringAsFixed(2)}%';
  }

  Widget _buildScannerError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off, color: Colors.redAccent, size: 44),

            const SizedBox(height: 14),

            const Text(
              'Не удалось загрузить Market Scanner',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            ElevatedButton.icon(
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(StockSearchResult result) {
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF20D3C2).withValues(alpha: 0.12),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 44, color: Colors.redAccent),

            const SizedBox(height: 14),

            const Text(
              'Не удалось выполнить поиск',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              _searchError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
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
              Icon(Icons.search_off, size: 46, color: Colors.white38),

              SizedBox(height: 14),

              Text(
                'Ничего не найдено',
                style: TextStyle(color: Colors.white60, fontSize: 17),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Результаты: ${_searchResults.length}',
          style: const TextStyle(color: Colors.white60, fontSize: 14),
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
        _buildScannerHeader(),

        const SizedBox(height: 20),

        _buildScanner(),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
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
        ),
      ),
    );
  }
}

enum _MarketSortMode {
  changeDescending,
  changeAscending,
  priceDescending,
  name,
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

class _MarketQuoteRow {
  final _MarketCompany company;
  final StockQuote quote;

  const _MarketQuoteRow({required this.company, required this.quote});
}
