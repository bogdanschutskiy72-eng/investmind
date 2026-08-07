import 'package:flutter/material.dart';

import '../../services/stock_service.dart';

class CompanyAnalysisScreen extends StatefulWidget {
  const CompanyAnalysisScreen({super.key});

  @override
  State<CompanyAnalysisScreen> createState() =>
      _CompanyAnalysisScreenState();
}

class _CompanyAnalysisScreenState
    extends State<CompanyAnalysisScreen> {
  final StockService _stockService = StockService();

  final TextEditingController _symbolController =
      TextEditingController();

  Future<StockQuote>? _quoteFuture;

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  void _analyzeCompany() {
    final symbol =
        _symbolController.text.trim().toUpperCase();

    if (symbol.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _quoteFuture = _stockService.fetchQuote(
        symbol,
        forceRefresh: true,
      );
    });
  }

  String _formatMoney(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _buildPriceSummary(StockQuote quote) {
    if (quote.percentChange > 2) {
      return 'Акция показывает заметный рост в текущем '
          'торговом периоде.';
    }

    if (quote.percentChange > 0) {
      return 'Цена находится в умеренно положительной зоне.';
    }

    if (quote.percentChange < -2) {
      return 'Акция показывает заметное снижение. '
          'Стоит изучить причины движения цены.';
    }

    if (quote.percentChange < 0) {
      return 'Цена находится в умеренно отрицательной зоне.';
    }

    return 'Цена практически не изменилась.';
  }

  String _buildRangeSummary(StockQuote quote) {
    final range = quote.high - quote.low;

    if (range <= 0 || quote.currentPrice <= 0) {
      return 'Недостаточно данных для оценки диапазона.';
    }

    final rangePercent =
        range / quote.currentPrice * 100;

    if (rangePercent >= 5) {
      return 'Внутридневной диапазон высокий — '
          'движение цены сегодня достаточно активное.';
    }

    if (rangePercent >= 2) {
      return 'Наблюдается умеренная внутридневная '
          'волатильность.';
    }

    return 'Внутридневной диапазон относительно спокойный.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Анализ компании'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1100,
            ),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Анализ компании',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Введите тикер компании. InvestMind '
                  'загрузит актуальные рыночные данные.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _symbolController,
                        textCapitalization:
                            TextCapitalization.characters,
                        onSubmitted: (_) =>
                            _analyzeCompany(),
                        decoration: InputDecoration(
                          hintText: 'Например: NVDA',
                          prefixIcon:
                              const Icon(Icons.search),
                          filled: true,
                          fillColor:
                              const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(18),borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _analyzeCompany,
                      icon: const Icon(Icons.analytics),
                      label: const Text('Анализировать'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (_quoteFuture == null)
                  const _EmptyAnalysis()
                else
                  FutureBuilder<StockQuote>(
                    future: _quoteFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child:
                                CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1E293B),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 42,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Не удалось получить данные',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                textAlign:
                                    TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final quote = snapshot.data;

                      if (quote == null) {
                        return const SizedBox.shrink();
                      }

                      final positive =
                          quote.percentChange >= 0;

                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF1E293B),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _symbolController.text.trim()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _formatMoney(
                                    quote.currentPrice,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${positive ? '+' : ''}'
                                  '${quote.percentChange.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.bold,
                                    color: positive
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _MetricCard(
                                title: 'Открытие',
                                value: _formatMoney(
                                  quote.open,
                                ),
                              ),
                              _MetricCard(
                                title: 'Максимум',
                                value: _formatMoney(
                                  quote.high,
                                ),
                              ),
                              _MetricCard(
                                title: 'Минимум',
                                value: _formatMoney(
                                  quote.low,
                                ),
                              ),
                              _MetricCard(
                                title: 'Пред. закрытие',
                                value: _formatMoney(
                                  quote.previousClose,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Вывод InvestMind',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _InsightCard(
                            icon:
                                Icons.trending_up_outlined,
                            title: 'Движение цены',
                            text:
                                _buildPriceSummary(quote),
                          ),
                          const SizedBox(height: 12),
                          _InsightCard(
                            icon:
                                Icons.show_chart_outlined,
                            title: 'Волатильность',
                            text:
                                _buildRangeSummary(quote),),
                          const SizedBox(height: 20),
                          const Text(
                            'Это аналитическая информация, '
                            'а не рекомендация покупать или '
                            'продавать актив.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAnalysis extends StatelessWidget {
  const _EmptyAnalysis();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 60,
            color: Colors.white38,
          ),
          SizedBox(height: 16),
          Text(
            'Выбери компанию для анализа',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
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
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF20D3C2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}