import 'package:flutter/material.dart';

import '../../services/company_profile_service.dart';
import '../../services/stock_service.dart';

class CompanyAnalysisScreen extends StatefulWidget {
  const CompanyAnalysisScreen({super.key});

  @override
  State<CompanyAnalysisScreen> createState() =>
      _CompanyAnalysisScreenState();
}

class _CompanyAnalysisScreenState extends State<CompanyAnalysisScreen> {
  final StockService _stockService = StockService();
  final CompanyProfileService _profileService = CompanyProfileService();

  final TextEditingController _symbolController =
      TextEditingController();

  Future<_CompanyAnalysisData>? _analysisFuture;

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  void _analyzeCompany() {
    final symbol = _symbolController.text.trim().toUpperCase();

    if (symbol.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _analysisFuture = _loadAnalysis(symbol);
    });
  }

  Future<_CompanyAnalysisData> _loadAnalysis(
    String symbol,
  ) async {
    final results = await Future.wait([
      _stockService.fetchQuote(
        symbol,
        forceRefresh: true,
      ),
      _profileService.fetchProfile(symbol),
    ]);

    return _CompanyAnalysisData(
      quote: results[0] as StockQuote,
      profile: results[1] as CompanyProfile,
    );
  }

  String _formatMoney(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatMarketCap(
    double value,
    String currency,
  ) {
    if (value <= 0) {
      return 'Нет данных';
    }

    // Finnhub возвращает marketCapitalization в миллионах.
    final absoluteValue = value * 1000000;

    if (absoluteValue >= 1000000000000) {
      return '${(absoluteValue / 1000000000000).toStringAsFixed(2)} '
          'трлн $currency';
    }

    if (absoluteValue >= 1000000000) {
      return '${(absoluteValue / 1000000000).toStringAsFixed(2)} '
          'млрд $currency';
    }

    if (absoluteValue >= 1000000) {
      return '${(absoluteValue / 1000000).toStringAsFixed(2)} '
          'млн $currency';
    }

    return '${absoluteValue.toStringAsFixed(0)} $currency';
  }

  String _formatShares(double value) {
    if (value <= 0) {
      return 'Нет данных';
    }

    // Finnhub возвращает shareOutstanding в миллионах акций.
    final absoluteValue = value * 1000000;

    if (absoluteValue >= 1000000000) {
      return '${(absoluteValue / 1000000000).toStringAsFixed(2)} млрд';
    }

    if (absoluteValue >= 1000000) {
      return '${(absoluteValue / 1000000).toStringAsFixed(2)} млн';
    }

    return absoluteValue.toStringAsFixed(0);
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

    final rangePercent = range / quote.currentPrice * 100;

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
          child: ConstrainedBox(constraints: const BoxConstraints(
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
                  'загрузит рыночные данные и профиль бизнеса.',
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
                        onSubmitted: (_) => _analyzeCompany(),
                        decoration: InputDecoration(
                          hintText: 'Например: NVDA',
                          prefixIcon: const Icon(
                            Icons.search,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(18),
                            borderSide: BorderSide.none,
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

                if (_analysisFuture == null)
                  const _EmptyAnalysis()
                else
                  FutureBuilder<_CompanyAnalysisData>(
                    future: _analysisFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _ErrorCard(
                          message: snapshot.error.toString(),
                        );
                      }

                      final data = snapshot.data;

                      if (data == null) {
                        return const SizedBox.shrink();
                      }

                      final quote = data.quote;
                      final profile = data.profile;

                      final positive =
                          quote.percentChange >= 0;

                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment:CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name.isNotEmpty
                                      ? profile.name
                                      : profile.ticker,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.ticker,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _formatMoney(
                                    quote.currentPrice,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${positive ? '+' : ''}'
                                  '${quote.percentChange.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
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

                          const SizedBox(height: 30),

                          const Text(
                            'Профиль компании',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [_MetricCard(
                                title: 'Капитализация',
                                value: _formatMarketCap(
                                  profile.marketCapitalization,
                                  profile.currency,
                                ),
                              ),
                              _MetricCard(
                                title: 'Акций в обращении',
                                value: _formatShares(
                                  profile.shareOutstanding,
                                ),
                              ),
                              _MetricCard(
                                title: 'Отрасль',
                                value: profile.industry.isNotEmpty
                                    ? profile.industry
                                    : 'Нет данных',
                              ),
                              _MetricCard(
                                title: 'Биржа',
                                value: profile.exchange.isNotEmpty
                                    ? profile.exchange
                                    : 'Нет данных',
                              ),
                              _MetricCard(
                                title: 'Страна',
                                value: profile.country.isNotEmpty
                                    ? profile.country
                                    : 'Нет данных',
                              ),
                              _MetricCard(
                                title: 'IPO',
                                value: profile.ipo.isNotEmpty
                                    ? profile.ipo
                                    : 'Нет данных',
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          const Text(
                            'Вывод InvestMind',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 14),

                          _InsightCard(
                            icon: Icons.trending_up_outlined,
                            title: 'Движение цены',
                            text: _buildPriceSummary(quote),
                          ),

                          const SizedBox(height: 12),

                          _InsightCard(
                            icon: Icons.show_chart_outlined,
                            title: 'Волатильность',
                            text: _buildRangeSummary(quote),
                          ),

                          const SizedBox(height: 12),

                          _InsightCard(
                            icon: Icons.business_outlined,
                            title: 'Компания',
                            text: profile.industry.isNotEmpty
                                ? '${profile.name} относится к отрасли '
                                    '${profile.industry}. '
                                    'Капитализация составляет примерно '
                                    '${_formatMarketCap(
                                      profile.marketCapitalization,
                                      profile.currency,
                                    )}.'
                                : 'Профиль компании загружен, '
                                    'но отраслевые данные отсутствуют.',
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'Это аналитическая информация, '
                            'а не рекомендация покупать или '
                            'продавать актив.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,),
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

class _CompanyAnalysisData {
  final StockQuote quote;
  final CompanyProfile profile;

  const _CompanyAnalysisData({
    required this.quote,
    required this.profile,
  });
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

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
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
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
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
      constraints: const BoxConstraints(
        minHeight: 100,
      ),
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
              fontSize: 18,
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
                  style: const TextStyle(fontSize: 17,
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