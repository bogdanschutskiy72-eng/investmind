import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../company/company_screen.dart';
import '../../services/stock_service.dart';
import '../comparison/company_comparison.dart';
import '../comparison/comparison_service.dart';
import 'market_catalog.dart';
import 'market_company.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final StockService _stockService = StockService();
  final ComparisonService _comparisonService = ComparisonService();

  final TextEditingController _searchController = TextEditingController();

  final ScrollController _sectorScrollController = ScrollController();
  final ScrollController _investMindFilterScrollController = ScrollController();

  Timer? _searchTimer;

  bool _isSearching = false;
  String? _searchError;
  List<StockSearchResult> _searchResults = [];

  String _selectedSector = 'Все';
  _MarketSortMode _sortMode = _MarketSortMode.changeDescending;

  bool _isInvestMindScanning = false;
  String? _investMindScanError;
  List<_InvestMindScanRow> _investMindRows = [];

  _InvestMindFilter _investMindFilter = _InvestMindFilter.all;

  final List<MarketCompany> _companies = marketCompanies;

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

  List<MarketCompany> get _selectedCompanies {
    if (_selectedSector == 'Все') {
      return List<MarketCompany>.from(_companies);
    }

    return _companies
        .where((company) => company.sector == _selectedSector)
        .toList();
  }

  List<_InvestMindScanRow> get _filteredInvestMindRows {
    return _investMindRows
        .where((row) => _matchesInvestMindFilter(row, _investMindFilter))
        .toList();
  }

  bool _matchesInvestMindFilter(
    _InvestMindScanRow row,
    _InvestMindFilter filter,
  ) {
    switch (filter) {
      case _InvestMindFilter.all:
        return true;

      case _InvestMindFilter.strongFundamental:
        return row.signals.any(
          (signal) => signal.type == _InvestMindSignalType.strongFundamental,
        );

      case _InvestMindFilter.strongGrowth:
        return row.signals.any(
          (signal) => signal.type == _InvestMindSignalType.strongGrowth,
        );

      case _InvestMindFilter.technicalStrength:
        return row.signals.any(
          (signal) => signal.type == _InvestMindSignalType.technicalStrength,
        );

      case _InvestMindFilter.attractiveValuation:
        return row.signals.any(
          (signal) => signal.type == _InvestMindSignalType.attractiveValuation,
        );

      case _InvestMindFilter.elevatedRisk:
        return row.signals.any(
          (signal) => signal.type == _InvestMindSignalType.elevatedRisk,
        );

      case _InvestMindFilter.divergences:
        return row.signals.any(
          (signal) =>
              signal.type == _InvestMindSignalType.fundamentalTechnicalGap ||
              signal.type == _InvestMindSignalType.growthValuationGap,
        );
    }
  }

  int _investMindFilterCount(_InvestMindFilter filter) {
    return _investMindRows
        .where((row) => _matchesInvestMindFilter(row, filter))
        .length;
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
    _sectorScrollController.dispose();
    _investMindFilterScrollController.dispose();
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
        // Ошибка одной компании не ломает весь Scanner.
      }
    }

    return rows;
  }

  void _refreshAll() {
    setState(() {
      _investMindRows = [];
      _investMindScanError = null;
      _investMindFilter = _InvestMindFilter.all;

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
        _searchError = _cleanError(error);
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

  void _openCompany(MarketCompany company) {
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

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  Future<void> _runInvestMindScanner() async {
    if (_isInvestMindScanning) {
      return;
    }

    final companies = _selectedCompanies;

    if (companies.isEmpty) {
      setState(() {
        _investMindScanError =
            'В выбранном секторе пока нет компаний для анализа.';
      });

      return;
    }

    setState(() {
      _isInvestMindScanning = true;
      _investMindScanError = null;
      _investMindRows = [];
      _investMindFilter = _InvestMindFilter.all;
    });

    final List<_InvestMindScanRow> result = [];
    final List<String> failedSymbols = [];

    for (final company in companies) {
      try {
        final analysis = await _comparisonService.loadCompany(company.symbol);

        result.add(
          _InvestMindScanRow(
            company: company,
            analysis: analysis,
            signals: _buildSignals(analysis),
          ),
        );

        if (mounted) {
          setState(() {
            _investMindRows = List<_InvestMindScanRow>.from(result);
          });
        }
      } catch (_) {
        failedSymbols.add(company.symbol);
      }
    }

    result.sort(
      (a, b) =>
          b.analysis.investMindScore.compareTo(a.analysis.investMindScore),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _investMindRows = result;
      _isInvestMindScanning = false;

      if (result.isEmpty) {
        _investMindScanError = 'Не удалось выполнить InvestMind Scanner.';
      } else if (failedSymbols.isNotEmpty) {
        _investMindScanError =
            'Часть компаний не удалось проанализировать: '
            '${failedSymbols.join(', ')}.';
      }
    });
  }

  List<_InvestMindSignal> _buildSignals(CompanyComparison company) {
    final List<_InvestMindSignal> signals = [];

    if (company.fundamentalScore >= 70) {
      signals.add(
        const _InvestMindSignal(
          type: _InvestMindSignalType.strongFundamental,
          label: 'Сильный фундаментал',
          icon: Icons.account_balance,
        ),
      );
    }

    if (company.growthScore >= 75) {
      signals.add(
        const _InvestMindSignal(
          type: _InvestMindSignalType.strongGrowth,
          label: 'Сильный рост',
          icon: Icons.trending_up,
        ),
      );
    }

    if (company.valuationScore >= 70) {
      signals.add(
        const _InvestMindSignal(
          type: _InvestMindSignalType.attractiveValuation,
          label: 'Сильная оценка',
          icon: Icons.sell_outlined,
        ),
      );
    }

    if (company.technicalScore >= 70) {
      signals.add(
        const _InvestMindSignal(
          type: _InvestMindSignalType.technicalStrength,
          label: 'Техническая сила',
          icon: Icons.show_chart,
        ),
      );
    }

    if (company.riskScore <= 35) {
      signals.add(
        const _InvestMindSignal(
          type: _InvestMindSignalType.elevatedRisk,
          label: 'Повышенный риск',
          icon: Icons.warning_amber_rounded,
        ),
      );
    }

    if (company.confidenceScore < 70) {
      signals.add(
        const _InvestMindSignal(
          type: _InvestMindSignalType.lowConfidence,
          label: 'Низкая уверенность данных',
          icon: Icons.help_outline,
        ),
      );
    }

    final scoreGap = company.fundamentalScore - company.technicalScore;

    if (scoreGap >= 20) {
      signals.add(
        const _InvestMindSignal(
          type: _InvestMindSignalType.fundamentalTechnicalGap,
          label: 'Фундаментал сильнее техники',
          icon: Icons.compare_arrows,
        ),
      );
    }

    final growthValuationGap = company.growthScore - company.valuationScore;

    if (growthValuationGap >= 30) {
      signals.add(
        const _InvestMindSignal(
          type: _InvestMindSignalType.growthValuationGap,
          label: 'Рост дороже оценки',
          icon: Icons.balance,
        ),
      );
    }

    return signals;
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

        SizedBox(
          height: 46,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent &&
                  _sectorScrollController.hasClients) {
                GestureBinding.instance.pointerSignalResolver.register(event, (
                  resolvedEvent,
                ) {
                  if (resolvedEvent is! PointerScrollEvent) {
                    return;
                  }

                  final currentOffset = _sectorScrollController.offset;

                  final maxOffset =
                      _sectorScrollController.position.maxScrollExtent;

                  final targetOffset =
                      currentOffset + resolvedEvent.scrollDelta.dy;

                  _sectorScrollController.jumpTo(
                    targetOffset.clamp(0.0, maxOffset),
                  );
                });
              }
            },
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: SingleChildScrollView(
                controller: _sectorScrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
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

                            _investMindRows = [];
                            _investMindScanError = null;
                            _investMindFilter = _InvestMindFilter.all;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
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

        final allRows = snapshot.data ?? const <_MarketQuoteRow>[];

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
                'В выбранном секторе пока нет компаний.',
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

  Widget _buildInvestMindScanner() {
    final filteredRows = _filteredInvestMindRows;

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
              Icon(Icons.psychology_outlined, color: Color(0xFF20D3C2)),
              SizedBox(width: 10),
              Text(
                'InvestMind Scanner',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            _selectedSector == 'Все'
                ? 'Проанализировать текущую группу компаний '
                      'по рассчитанным показателям InvestMind.'
                : 'Проанализировать сектор '
                      '«$_selectedSector» по показателям InvestMind.',
            style: const TextStyle(color: Colors.white60, height: 1.45),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isInvestMindScanning ? null : _runInvestMindScanner,
              icon: _isInvestMindScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.radar),
              label: Text(
                _isInvestMindScanning
                    ? 'Сканируем...'
                    : 'Запустить InvestMind Scanner',
              ),
            ),
          ),

          if (_isInvestMindScanning) ...[
            const SizedBox(height: 14),

            const LinearProgressIndicator(color: Color(0xFF20D3C2)),

            const SizedBox(height: 10),

            Text(
              'Обработано: ${_investMindRows.length} '
              'из ${_selectedCompanies.length}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],

          if (_investMindScanError != null) ...[
            const SizedBox(height: 14),

            Text(
              _investMindScanError!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ],

          if (_investMindRows.isNotEmpty) ...[
            const SizedBox(height: 22),

            _buildInvestMindSummary(),

            const SizedBox(height: 18),

            _buildInvestMindFilters(),

            const SizedBox(height: 18),

            if (filteredRows.isEmpty)
              _buildNoFilteredResults()
            else
              ...filteredRows.map(_buildInvestMindResultCard),
          ],
        ],
      ),
    );
  }

  Widget _buildInvestMindSummary() {
    final rows = List<_InvestMindScanRow>.from(_investMindRows);

    rows.sort(
      (a, b) =>
          b.analysis.investMindScore.compareTo(a.analysis.investMindScore),
    );

    final leader = rows.first;

    final highestFundamental = rows.reduce(
      (current, next) =>
          current.analysis.fundamentalScore > next.analysis.fundamentalScore
          ? current
          : next,
    );

    final highestTechnical = rows.reduce(
      (current, next) =>
          current.analysis.technicalScore > next.analysis.technicalScore
          ? current
          : next,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 750;

        final cards = [
          _buildInvestMindSummaryCard(
            title: 'Лучший InvestMind Score',
            symbol: leader.company.symbol,
            value: '${leader.analysis.investMindScore}/100',
          ),
          _buildInvestMindSummaryCard(
            title: 'Лучший фундаментал в группе',
            symbol: highestFundamental.company.symbol,
            value: '${highestFundamental.analysis.fundamentalScore}/100',
          ),
          _buildInvestMindSummaryCard(
            title: 'Лучшая техника в группе',
            symbol: highestTechnical.company.symbol,
            value: '${highestTechnical.analysis.technicalScore}/100',
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
              if (index < cards.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildInvestMindFilters() {
    final filters = [
      _InvestMindFilter.all,
      _InvestMindFilter.strongFundamental,
      _InvestMindFilter.strongGrowth,
      _InvestMindFilter.technicalStrength,
      _InvestMindFilter.attractiveValuation,
      _InvestMindFilter.elevatedRisk,
      _InvestMindFilter.divergences,
    ];

    return SizedBox(
      height: 46,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent &&
              _investMindFilterScrollController.hasClients) {
            GestureBinding.instance.pointerSignalResolver.register(event, (
              resolvedEvent,
            ) {
              if (resolvedEvent is! PointerScrollEvent) {
                return;
              }

              final currentOffset = _investMindFilterScrollController.offset;

              final maxOffset =
                  _investMindFilterScrollController.position.maxScrollExtent;

              final targetOffset = currentOffset + resolvedEvent.scrollDelta.dy;

              _investMindFilterScrollController.jumpTo(
                targetOffset.clamp(0.0, maxOffset),
              );
            });
          }
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: SingleChildScrollView(
            controller: _investMindFilterScrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: filters.map((filter) {
                final selected = _investMindFilter == filter;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '${_investMindFilterLabel(filter)} '
                      '(${_investMindFilterCount(filter)})',
                    ),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _investMindFilter = filter;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _investMindFilterLabel(_InvestMindFilter filter) {
    switch (filter) {
      case _InvestMindFilter.all:
        return 'Все';

      case _InvestMindFilter.strongFundamental:
        return 'Сильный фундаментал';

      case _InvestMindFilter.strongGrowth:
        return 'Сильный рост';

      case _InvestMindFilter.technicalStrength:
        return 'Сильная техника';

      case _InvestMindFilter.attractiveValuation:
        return 'Сильная оценка';

      case _InvestMindFilter.elevatedRisk:
        return 'Повышенный риск';

      case _InvestMindFilter.divergences:
        return 'Расхождения';
    }
  }

  Widget _buildNoFilteredResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.filter_alt_off_outlined, color: Colors.white38, size: 34),
          SizedBox(height: 10),
          Text(
            'Компаний с таким сигналом не найдено.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestMindSummaryCard({
    required String title,
    required String symbol,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
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
            symbol,
            style: const TextStyle(
              color: Color(0xFF20D3C2),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),

          const SizedBox(height: 4),

          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInvestMindResultCard(_InvestMindScanRow row) {
    final analysis = row.analysis;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.company.symbol,
                      style: const TextStyle(
                        color: Color(0xFF20D3C2),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      row.company.name,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF20D3C2).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${analysis.investMindScore}/100',
                  style: const TextStyle(
                    color: Color(0xFF20D3C2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildScoreBadge('Tech', analysis.technicalScore),
              _buildScoreBadge('Fund', analysis.fundamentalScore),
              _buildScoreBadge('Growth', analysis.growthScore),
              _buildScoreBadge('Value', analysis.valuationScore),
              _buildScoreBadge('Risk', analysis.riskScore),
              _buildPercentBadge('Conf', analysis.confidenceScore),
            ],
          ),

          if (row.signals.isNotEmpty) ...[
            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: row.signals.map(_buildSignalChip).toList(),
            ),
          ],

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openCompany(row.company),
              icon: const Icon(Icons.arrow_forward, size: 17),
              label: const Text('Открыть компанию'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(String label, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $score',
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
    );
  }

  Widget _buildPercentBadge(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $value%',
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
    );
  }

  Widget _buildSignalChip(_InvestMindSignal signal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _signalColor(signal.type).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _signalColor(signal.type).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(signal.icon, size: 15, color: _signalColor(signal.type)),

          const SizedBox(width: 6),

          Text(
            signal.label,
            style: TextStyle(
              fontSize: 11,
              color: _signalColor(signal.type),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _signalColor(_InvestMindSignalType type) {
    switch (type) {
      case _InvestMindSignalType.strongFundamental:
      case _InvestMindSignalType.strongGrowth:
      case _InvestMindSignalType.attractiveValuation:
      case _InvestMindSignalType.technicalStrength:
        return const Color(0xFF20D3C2);

      case _InvestMindSignalType.elevatedRisk:
        return Colors.orangeAccent;

      case _InvestMindSignalType.lowConfidence:
        return Colors.amberAccent;

      case _InvestMindSignalType.fundamentalTechnicalGap:
      case _InvestMindSignalType.growthValuationGap:
        return Colors.lightBlueAccent;
    }
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

        const SizedBox(height: 40),

        _buildInvestMindScanner(),

        const SizedBox(height: 24),
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

enum _InvestMindSignalType {
  strongFundamental,
  strongGrowth,
  attractiveValuation,
  technicalStrength,
  elevatedRisk,
  lowConfidence,
  fundamentalTechnicalGap,
  growthValuationGap,
}

enum _InvestMindFilter {
  all,
  strongFundamental,
  strongGrowth,
  technicalStrength,
  attractiveValuation,
  elevatedRisk,
  divergences,
}

class _MarketQuoteRow {
  final MarketCompany company;
  final StockQuote quote;

  const _MarketQuoteRow({required this.company, required this.quote});
}

class _InvestMindSignal {
  final _InvestMindSignalType type;
  final String label;
  final IconData icon;

  const _InvestMindSignal({
    required this.type,
    required this.label,
    required this.icon,
  });
}

class _InvestMindScanRow {
  final MarketCompany company;
  final CompanyComparison analysis;
  final List<_InvestMindSignal> signals;

  const _InvestMindScanRow({
    required this.company,
    required this.analysis,
    required this.signals,
  });
}
