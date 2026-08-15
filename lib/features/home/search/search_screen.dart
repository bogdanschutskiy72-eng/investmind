import 'dart:async';

import '../../analysis/company_analysis_screen.dart';
import 'package:flutter/material.dart';

import '../../../services/stock_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final StockService _stockService = StockService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;

  List<StockSearchResult> _results = [];

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _isLoading = false;
      });

      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _stockService.searchSymbols(query);

      if (!mounted) {
        return;
      }

      if (_searchController.text.trim() != query) {
        return;
      }

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _results = [];
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Поиск компаний',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Найди компанию по названию или биржевому тикеру.',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _onSearchChanged,
                    onSubmitted: (value) {
                      final query = value.trim();

                      if (query.isNotEmpty) {
                        _debounce?.cancel();
                        _search(query);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Например: NVIDIA, NVDA, Intel, PLTR...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Очистить',
                              onPressed: () {
                                _debounce?.cancel();
                                _searchController.clear();

                                setState(() {
                                  _results = [];
                                  _error = null;
                                  _isLoading = false;
                                });
                              },
                              icon: const Icon(Icons.close),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_isLoading)
                    const LinearProgressIndicator(color: Color(0xFF20D3C2)),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Expanded(child: _buildResults()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF20D3C2)),
      );
    }

    if (_results.isEmpty) {
      if (_searchController.text.trim().isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 56, color: Colors.white24),
              SizedBox(height: 16),
              Text(
                'Начни вводить название компании или тикер',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        );
      }

      if (_error == null && !_isLoading) {
        return const Center(
          child: Text(
            'Компании не найдены',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        );
      }

      return const SizedBox.shrink();
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final company = _results[index];

        return Material(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CompanyAnalysisScreen(initialSymbol: company.symbol),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF20D3C2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      company.symbol.isNotEmpty
                          ? company.symbol.characters.first
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF20D3C2),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.symbol,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          company.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  if (company.type.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        company.type,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(width: 8),

                  const Icon(Icons.chevron_right, color: Colors.white38),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
