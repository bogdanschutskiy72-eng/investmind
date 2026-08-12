import 'package:flutter/material.dart';

import '../../services/combined_score_service.dart';
import '../../services/fundamental_score_service.dart';
import '../../services/fundamental_service.dart';
import '../../services/ai_analysis_service.dart';
import '../../services/company_profile_service.dart';
import '../../services/historical_price_service.dart';
import '../../services/investmind_score_service.dart';
import '../../services/stock_service.dart';
import '../../shared/widgets/historical_price_chart.dart';

class CompanyAnalysisScreen extends StatefulWidget {
  const CompanyAnalysisScreen({super.key});

  @override
  State<CompanyAnalysisScreen> createState() => _CompanyAnalysisScreenState();
}

class _CompanyAnalysisScreenState extends State<CompanyAnalysisScreen> {
  final StockService _stockService = StockService();

  final FundamentalService _fundamentalService = FundamentalService();

  final CombinedScoreService _combinedScoreService =
      const CombinedScoreService();

  final CompanyProfileService _profileService = CompanyProfileService();

  final HistoricalPriceService _historicalPriceService =
      HistoricalPriceService();

  final InvestMindScoreService _scoreService = const InvestMindScoreService();

  final FundamentalScoreService _fundamentalScoreService =
      const FundamentalScoreService();

  final TextEditingController _symbolController = TextEditingController();

  final AiAnalysisService _aiAnalysisService = const AiAnalysisService();

  Future<_CompanyAnalysisData>? _analysisFuture;

  AiStructuredAnalysis? _aiAnalysis;
  bool _isAiLoading = false;

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  void _analyzeCompany() {
    final String symbol = _symbolController.text.trim().toUpperCase();

    if (symbol.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _analysisFuture = _loadAnalysis(symbol);
    });
  }

  Future<_CompanyAnalysisData> _loadAnalysis(String symbol) async {
    final StockQuote quote = await _stockService.fetchQuote(
      symbol,
      forceRefresh: true,
    );

    final CompanyProfile profile = await _profileService.fetchProfile(symbol);

    HistoricalPriceAnalysis? historical;
    FundamentalData? fundamentals;

    try {
      historical = await _historicalPriceService.fetchAnalysis(
        symbol,
        days: 90,
      );
    } catch (error) {
      debugPrint('История цены для $symbol недоступна: $error');
    }

    try {
      fundamentals = await _fundamentalService.fetchFundamentals(symbol);
    } catch (error) {
      debugPrint(
        'Фундаментальные данные для $symbol '
        'недоступны: $error',
      );
    }

    return _CompanyAnalysisData(
      quote: quote,
      profile: profile,
      historical: historical,
      fundamentals: fundamentals,
    );
  }

  String _formatMoney(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatPercent(double value) {
    final String sign = value > 0 ? '+' : '';

    return '$sign${value.toStringAsFixed(2)}%';
  }

  String _formatDrawdown(double value) {
    if (value <= 0.0) {
      return '0.00%';
    }

    return '-${value.toStringAsFixed(2)}%';
  }

  String _formatMarketCap(double value, String currency) {
    if (value <= 0.0) {
      return 'Нет данных';
    }

    final double absoluteValue = value * 1000000.0;

    if (absoluteValue >= 1000000000000.0) {
      return '${(absoluteValue / 1000000000000.0).toStringAsFixed(2)} '
          'трлн $currency';
    }

    if (absoluteValue >= 1000000000.0) {
      return '${(absoluteValue / 1000000000.0).toStringAsFixed(2)} '
          'млрд $currency';
    }

    if (absoluteValue >= 1000000.0) {
      return '${(absoluteValue / 1000000.0).toStringAsFixed(2)} '
          'млн $currency';
    }

    return '${absoluteValue.toStringAsFixed(0)} $currency';
  }

  String _formatShares(double value) {
    if (value <= 0.0) {
      return 'Нет данных';
    }

    final double absoluteValue = value * 1000000.0;

    if (absoluteValue >= 1000000000.0) {
      return '${(absoluteValue / 1000000000.0).toStringAsFixed(2)} млрд';
    }

    if (absoluteValue >= 1000000.0) {
      return '${(absoluteValue / 1000000.0).toStringAsFixed(2)} млн';
    }

    return absoluteValue.toStringAsFixed(0);
  }

  String _buildPriceSummary(StockQuote quote) {
    if (quote.percentChange > 2.0) {
      return 'Акция показывает заметный рост в текущем '
          'торговом периоде.';
    }

    if (quote.percentChange > 0.0) {
      return 'Цена находится в умеренно положительной зоне.';
    }

    if (quote.percentChange < -2.0) {
      return 'Акция показывает заметное снижение. '
          'Стоит изучить причины движения цены.';
    }

    if (quote.percentChange < 0.0) {
      return 'Цена находится в умеренно отрицательной зоне.';
    }

    return 'Цена практически не изменилась.';
  }

  String _buildRangeSummary(StockQuote quote) {
    final double range = quote.high - quote.low;

    if (range <= 0.0 || quote.currentPrice <= 0.0) {
      return 'Недостаточно данных для оценки диапазона.';
    }

    final double rangePercent = range / quote.currentPrice * 100.0;

    if (rangePercent >= 5.0) {
      return 'Внутридневной диапазон высокий — '
          'движение цены сегодня достаточно активное.';
    }

    if (rangePercent >= 2.0) {
      return 'Наблюдается умеренная внутридневная '
          'волатильность.';
    }

    return 'Внутридневной диапазон относительно спокойный.';
  }

  String _buildTrendSummary(HistoricalPriceAnalysis historical) {
    final double change = historical.periodChangePercent;

    if (change >= 20.0) {
      return 'За последние 90 торговых дней акция '
          'показала сильный восходящий тренд.';
    }

    if (change >= 5.0) {
      return 'За последние 90 торговых дней наблюдается '
          'умеренный восходящий тренд.';
    }

    if (change <= -20.0) {
      return 'За последние 90 торговых дней акция '
          'показала сильное снижение.';
    }

    if (change <= -5.0) {
      return 'За последние 90 торговых дней наблюдается '
          'умеренный нисходящий тренд.';
    }

    return 'За последние 90 торговых дней цена '
        'двигалась преимущественно в боковом диапазоне.';
  }

  String _buildDrawdownSummary(HistoricalPriceAnalysis historical) {
    final double drawdown = historical.drawdownFromHighPercent.abs();

    if (drawdown < 3.0) {
      return 'Текущая цена находится близко к максимуму '
          'рассматриваемого периода.';
    }

    if (drawdown < 10.0) {
      return 'Цена находится примерно на '
          '${drawdown.toStringAsFixed(1)}% ниже максимума периода.';
    }

    if (drawdown < 20.0) {
      return 'Акция находится в заметной просадке — примерно '
          '${drawdown.toStringAsFixed(1)}% от максимума периода.';
    }

    return 'Цена находится в глубокой просадке — примерно '
        '${drawdown.toStringAsFixed(1)}% ниже максимума периода.';
  }

  String _buildVolatilitySummary(HistoricalPriceAnalysis historical) {
    final double volatility = historical.annualizedVolatilityPercent;

    if (volatility < 20.0) {
      return 'Историческая волатильность относительно низкая — '
          '${volatility.toStringAsFixed(1)}% годовых.';
    }

    if (volatility < 35.0) {
      return 'Историческая волатильность умеренная — '
          '${volatility.toStringAsFixed(1)}% годовых.';
    }

    if (volatility < 50.0) {
      return 'Историческая волатильность повышенная — '
          '${volatility.toStringAsFixed(1)}% годовых.';
    }

    return 'Историческая волатильность высокая — '
        '${volatility.toStringAsFixed(1)}% годовых. '
        'Цена может совершать значительные движения.';
  }

  String _buildMovingAverageSummary(HistoricalPriceAnalysis historical) {
    final double price = historical.lastPrice;

    final double ma20 = historical.movingAverage20;

    final double ma50 = historical.movingAverage50;

    if (price > ma20 && price > ma50) {
      return 'Цена находится выше средних MA20 и MA50. '
          'Это указывает на положительную среднесрочную структуру цены.';
    }

    if (price < ma20 && price < ma50) {
      return 'Цена находится ниже MA20 и MA50. '
          'Среднесрочная структура сейчас выглядит слабее.';
    }

    if (price > ma20 && price < ma50) {
      return 'Цена выше MA20, но пока ниже MA50. '
          'Краткосрочное восстановление ещё не подтверждено '
          'более длинным трендом.';
    }

    return 'Цена ниже MA20, но остаётся выше MA50. '
        'Возможна краткосрочная коррекция внутри более '
        'устойчивого среднесрочного движения.';
  }

  String _buildTrendStrengthSummary(HistoricalPriceAnalysis historical) {
    final double strength = historical.trendStrengthPercent;

    final double slope = historical.trendSlopePercentPerDay;

    final String direction;

    if (slope > 0.02) {
      direction = 'восходящего';
    } else if (slope < -0.02) {
      direction = 'нисходящего';
    } else {
      direction = 'бокового';
    }

    if (strength >= 70.0) {
      return 'Статистическая сила $direction тренда высокая — '
          '${strength.toStringAsFixed(1)}%. '
          'Цена достаточно последовательно движется '
          'в выбранном направлении.';
    }

    if (strength >= 40.0) {
      return 'Сила $direction тренда умеренная — '
          '${strength.toStringAsFixed(1)}%.';
    }

    if (strength >= 20.0) {
      return 'Сила тренда невысокая — '
          '${strength.toStringAsFixed(1)}%. '
          'В движении присутствует заметный рыночный шум.';
    }

    return 'Выраженного устойчивого тренда сейчас нет. '
        'Статистическая сила составляет только '
        '${strength.toStringAsFixed(1)}%.';
  }

  String _buildRiskSummary(HistoricalPriceAnalysis historical) {
    final double volatility = historical.annualizedVolatilityPercent;

    final double drawdown = historical.maxDrawdownPercent;

    if (volatility >= 50.0 && drawdown >= 20.0) {
      return 'Риск движения цены высокий: одновременно наблюдаются '
          'высокая волатильность и значительная максимальная просадка.';
    }

    if (volatility >= 35.0 || drawdown >= 20.0) {
      return 'Риск движения цены повышенный. '
          'При анализе позиции стоит учитывать возможность '
          'существенных колебаний.';
    }

    if (volatility < 25.0 && drawdown < 10.0) {
      return 'По историческому движению риск выглядит относительно '
          'умеренным, хотя это не исключает будущих резких движений.';
    }

    return 'Исторический риск находится в среднем диапазоне. '
        'Важно учитывать волатильность вместе с размером позиции.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Анализ компании')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Анализ компании',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Рыночные данные, профиль бизнеса, '
                  'история цены и количественный анализ.',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _symbolController,
                        textCapitalization: TextCapitalization.characters,
                        onSubmitted: (_) => _analyzeCompany(),
                        decoration: InputDecoration(
                          hintText: 'Например: NVDA',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _ErrorCard(message: snapshot.error.toString());
                      }

                      final _CompanyAnalysisData? data = snapshot.data;

                      if (data == null) {
                        return const SizedBox.shrink();
                      }

                      final StockQuote quote = data.quote;

                      final CompanyProfile profile = data.profile;

                      final HistoricalPriceAnalysis? historical =
                          data.historical;
                      final FundamentalData? fundamentals = data.fundamentals;
                      FundamentalScoreResult? fundamentalScore;

                      if (fundamentals != null && fundamentals.hasAnyData) {
                        fundamentalScore = _fundamentalScoreService.calculate(
                          fundamentals,
                        );
                      }
                      if (historical == null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orangeAccent,
                                    size: 32,
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'Исторические данные недоступны',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Цена и профиль компании доступны, '
                                    'но Twelve Data не вернул историю цены '
                                    'для этого тикера.',

                                    style: TextStyle(
                                      color: Colors.white70,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      final InvestMindScoreResult scoreResult = _scoreService
                          .calculate(
                            currentPrice: quote.currentPrice,
                            movingAverage20: historical.movingAverage20,
                            movingAverage50: historical.movingAverage50,
                            volatilityPercent:
                                historical.annualizedVolatilityPercent,
                            maxDrawdownPercent: historical.maxDrawdownPercent,
                            trendStrengthPercent:
                                historical.trendStrengthPercent,
                            trendSlopePercentPerDay:
                                historical.trendSlopePercentPerDay,
                          );
                      CombinedScoreResult? combinedScore;

                      if (fundamentalScore != null) {
                        combinedScore = _combinedScoreService.calculate(
                          technical: scoreResult,
                          fundamental: fundamentalScore,
                        );
                      }

                      final AiCompanyAnalysisInput aiInput = _aiAnalysisService
                          .buildCompanyInput(
                            quote: quote,
                            profile: profile,
                            historical: historical,
                            fundamentals: fundamentals!,
                            technicalScore: scoreResult,
                            fundamentalScore: fundamentalScore!,
                            combinedScore: combinedScore!,
                          );

                      final bool positive = quote.percentChange >= 0.0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  _formatMoney(quote.currentPrice),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatPercent(quote.percentChange),
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
                                value: _formatMoney(quote.open),
                              ),
                              _MetricCard(
                                title: 'Максимум',
                                value: _formatMoney(quote.high),
                              ),
                              _MetricCard(
                                title: 'Минимум',
                                value: _formatMoney(quote.low),
                              ),
                              _MetricCard(
                                title: 'Пред. закрытие',
                                value: _formatMoney(quote.previousClose),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          const Text(
                            'История цены · 90 дней',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 14),

                          HistoricalPriceChart(prices: historical.prices),

                          const SizedBox(height: 18),

                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _MetricCard(
                                title: 'Изменение периода',
                                value: _formatPercent(
                                  historical.periodChangePercent,
                                ),
                              ),
                              _MetricCard(
                                title: 'Максимум периода',
                                value: _formatMoney(historical.highestPrice),
                              ),
                              _MetricCard(
                                title: 'Минимум периода',
                                value: _formatMoney(historical.lowestPrice),
                              ),
                              _MetricCard(
                                title: 'От максимума',
                                value: _formatPercent(
                                  historical.drawdownFromHighPercent,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          const Text(
                            'Количественный анализ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _MetricCard(
                                title: 'Волатильность',
                                value:
                                    '${historical.annualizedVolatilityPercent.toStringAsFixed(2)}%',
                              ),
                              _MetricCard(
                                title: 'Макс. просадка',
                                value: _formatDrawdown(
                                  historical.maxDrawdownPercent,
                                ),
                              ),
                              _MetricCard(
                                title: 'MA20',
                                value: _formatMoney(historical.movingAverage20),
                              ),
                              _MetricCard(
                                title: 'MA50',
                                value: _formatMoney(historical.movingAverage50),
                              ),
                              _MetricCard(
                                title: 'Сила тренда',
                                value:
                                    '${historical.trendStrengthPercent.toStringAsFixed(1)}%',
                              ),
                              _MetricCard(
                                title: 'Тренд / день',
                                value: _formatPercent(
                                  historical.trendSlopePercentPerDay,
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
                            children: [
                              _MetricCard(
                                title: 'Капитализация',
                                value: _formatMarketCap(
                                  profile.marketCapitalization,
                                  profile.currency,
                                ),
                              ),
                              _MetricCard(
                                title: 'Акций в обращении',
                                value: _formatShares(profile.shareOutstanding),
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
                          ...[
                            const SizedBox(height: 24),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fundamental Score',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${fundamentalScore.score}',
                                        style: const TextStyle(
                                          fontSize: 46,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF20D3C2),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          left: 6,
                                          bottom: 7,
                                        ),
                                        child: Text(
                                          '/ 100',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    fundamentalScore.rating,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _MetricCard(
                                        title: 'Рост',
                                        value:
                                            '${fundamentalScore.growthScore}/100',
                                      ),
                                      _MetricCard(
                                        title: 'Прибыльность',
                                        value:
                                            '${fundamentalScore.profitabilityScore}/100',
                                      ),
                                      _MetricCard(
                                        title: 'Оценка',
                                        value:
                                            '${fundamentalScore.valuationScore}/100',
                                      ),
                                      _MetricCard(
                                        title: 'Фин. здоровье',
                                        value:
                                            '${fundamentalScore.financialHealthScore}/100',
                                      ),
                                      _MetricCard(
                                        title: 'Риск',
                                        value:
                                            '${fundamentalScore.riskScore}/100',
                                      ),
                                    ],
                                  ),

                                  if (fundamentalScore
                                      .strengths
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Сильные стороны',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...fundamentalScore.strengths.map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          '✓ $item',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],

                                  if (fundamentalScore.warnings.isNotEmpty) ...[
                                    const SizedBox(height: 18),
                                    const Text(
                                      'Риски',
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...fundamentalScore.warnings.map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          '⚠ $item',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const Text(
                            'InvestMind Score',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 30),

                          const Text(
                            'Фундаментальный анализ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 14),

                          if (fundamentals.hasAnyData)
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _MetricCard(
                                  title: 'P/E',
                                  value: fundamentals.pe > 0
                                      ? fundamentals.pe.toStringAsFixed(2)
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: 'Forward P/E',
                                  value: fundamentals.forwardPe > 0
                                      ? fundamentals.forwardPe.toStringAsFixed(
                                          2,
                                        )
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: 'P/S',
                                  value: fundamentals.priceToSales > 0
                                      ? fundamentals.priceToSales
                                            .toStringAsFixed(2)
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: 'EPS',
                                  value: fundamentals.hasEps
                                      ? fundamentals.eps.toStringAsFixed(2)
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: 'Рост EPS',
                                  value: fundamentals.epsGrowthPercent != 0
                                      ? '${fundamentals.epsGrowthPercent.toStringAsFixed(2)}%'
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: 'Рост выручки',
                                  value: fundamentals.revenueGrowthPercent != 0
                                      ? '${fundamentals.revenueGrowthPercent.toStringAsFixed(2)}%'
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: 'Валовая маржа',
                                  value: fundamentals.grossMarginPercent != 0
                                      ? '${fundamentals.grossMarginPercent.toStringAsFixed(2)}%'
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: 'Чистая маржа',
                                  value: fundamentals.netMarginPercent != 0
                                      ? '${fundamentals.netMarginPercent.toStringAsFixed(2)}%'
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: 'ROE',
                                  value: fundamentals.roePercent != 0
                                      ? '${fundamentals.roePercent.toStringAsFixed(2)}%'
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: 'Current Ratio',
                                  value: fundamentals.currentRatio > 0
                                      ? fundamentals.currentRatio
                                            .toStringAsFixed(2)
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: 'Beta',
                                  value: fundamentals.beta != 0
                                      ? fundamentals.beta.toStringAsFixed(2)
                                      : 'Нет данных',
                                ),
                                _MetricCard(
                                  title: '52W High',
                                  value: fundamentals.week52High > 0
                                      ? _formatMoney(fundamentals.week52High)
                                      : 'Нет данных',
                                ),
                              ],
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Text(
                                'Фундаментальные данные для этой компании недоступны.',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ),
                          const SizedBox(height: 14),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${scoreResult.score}',
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF20D3C2),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 6,
                                        bottom: 7,
                                      ),
                                      child: Text(
                                        '/ 100',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                Text(
                                  combinedScore.rating,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _MetricCard(
                                      title: 'Technical',
                                      value:
                                          '${combinedScore.technicalScore}/100',
                                    ),
                                    _MetricCard(
                                      title: 'Fundamental',
                                      value:
                                          '${combinedScore.fundamentalScore}/100',
                                    ),
                                    _MetricCard(
                                      title: 'Вес Technical',
                                      value:
                                          '${(combinedScore.technicalWeight * 100).toStringAsFixed(0)}%',
                                    ),
                                    _MetricCard(
                                      title: 'Вес Fundamental',
                                      value:
                                          '${(combinedScore.fundamentalWeight * 100).toStringAsFixed(0)}%',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                ElevatedButton.icon(
                                  onPressed: _isAiLoading
                                      ? null
                                      : () async {
                                          setState(() {
                                            _isAiLoading = true;
                                            _aiAnalysis = null;
                                          });

                                          try {
                                            final response =
                                                await _aiAnalysisService
                                                    .sendToBackend(aiInput);

                                            if (!context.mounted) {
                                              return;
                                            }

                                            setState(() {
                                              _aiAnalysis = response.analysis;
                                            });
                                          } catch (error) {
                                            if (!context.mounted) {
                                              return;
                                            }

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Ошибка AI: $error',
                                                ),
                                              ),
                                            );
                                          } finally {
                                            if (context.mounted) {
                                              setState(() {
                                                _isAiLoading = false;
                                              });
                                            }
                                          }
                                        },
                                  icon: _isAiLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome_outlined),
                                  label: Text(
                                    _isAiLoading
                                        ? 'InvestMind анализирует...'
                                        : 'Получить AI-анализ',
                                  ),
                                ),
                                if (_aiAnalysis != null) ...[
                                  const SizedBox(height: 16),

                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.auto_awesome,
                                              color: Color(0xFF20D3C2),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'InvestMind AI',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 18),

                                        Text(
                                          _aiAnalysis!.summary,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            height: 1.5,
                                            fontSize: 15,
                                          ),
                                        ),

                                        if (_aiAnalysis!
                                            .strengths
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 18),
                                          const Text(
                                            'Сильные стороны',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.greenAccent,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ..._aiAnalysis!.strengths.map(
                                            (item) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Text(
                                                '✓ $item',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],

                                        if (_aiAnalysis!.risks.isNotEmpty) ...[
                                          const SizedBox(height: 18),
                                          const Text(
                                            'Риски',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orangeAccent,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ..._aiAnalysis!.risks.map(
                                            (item) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Text(
                                                '⚠ $item',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],

                                        if (_aiAnalysis!.watch.isNotEmpty) ...[
                                          const SizedBox(height: 18),
                                          const Text(
                                            'На что обратить внимание',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.lightBlueAccent,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ..._aiAnalysis!.watch.map(
                                            (item) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Text(
                                                '• $item',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],

                                        const SizedBox(height: 18),

                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Уверенность анализа',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '${_aiAnalysis!.confidence}%',
                                                  style: const TextStyle(
                                                    color: Color(0xFF20D3C2),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 10),

                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: LinearProgressIndicator(
                                                value:
                                                    _aiAnalysis!.confidence /
                                                    100,
                                                minHeight: 8,
                                                backgroundColor: Colors.white12,
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                      Color
                                                    >(Color(0xFF20D3C2)),
                                              ),
                                            ),

                                            const SizedBox(height: 8),

                                            Text(
                                              _aiAnalysis!.confidence >= 75
                                                  ? 'Высокая уверенность в техническом сигнале'
                                                  : _aiAnalysis!.confidence >=
                                                        50
                                                  ? 'Средняя уверенность — сигналы неоднозначны'
                                                  : 'Низкая уверенность — требуется осторожная интерпретация',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),

                                if (scoreResult.strengths.isNotEmpty) ...[
                                  const Text(
                                    'Сильные стороны',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...scoreResult.strengths.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        '✓ $item',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                if (scoreResult.warnings.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Риски',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...scoreResult.warnings.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        '⚠ $item',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
                            title: 'Сегодняшнее движение',
                            text: _buildPriceSummary(quote),
                          ),

                          const SizedBox(height: 12),

                          _InsightCard(
                            icon: Icons.show_chart_outlined,
                            title: 'Волатильность сегодня',
                            text: _buildRangeSummary(quote),
                          ),

                          const SizedBox(height: 12),

                          _InsightCard(
                            icon: Icons.timeline,
                            title: 'Среднесрочный тренд',
                            text: _buildTrendSummary(historical),
                          ),

                          const SizedBox(height: 12),

                          _InsightCard(
                            icon: Icons.south_east_outlined,
                            title: 'Положение относительно максимума',
                            text: _buildDrawdownSummary(historical),
                          ),

                          const SizedBox(height: 12),

                          _InsightCard(
                            icon: Icons.speed_outlined,
                            title: 'Историческая волатильность',
                            text: _buildVolatilitySummary(historical),
                          ),

                          const SizedBox(height: 12),

                          _InsightCard(
                            icon: Icons.moving_outlined,
                            title: 'MA20 / MA50',
                            text: _buildMovingAverageSummary(historical),
                          ),

                          const SizedBox(height: 12),

                          _InsightCard(
                            icon: Icons.query_stats_outlined,
                            title: 'Сила тренда',
                            text: _buildTrendStrengthSummary(historical),
                          ),

                          const SizedBox(height: 12),

                          _InsightCard(
                            icon: Icons.shield_outlined,
                            title: 'Риск движения цены',
                            text: _buildRiskSummary(historical),
                          ),

                          const SizedBox(height: 12),

                          _InsightCard(
                            icon: Icons.business_outlined,
                            title: 'Компания',
                            text: profile.industry.isNotEmpty
                                ? '${profile.name} относится к отрасли '
                                      '${profile.industry}. '
                                      'Капитализация составляет примерно '
                                      '${_formatMarketCap(profile.marketCapitalization, profile.currency)}.'
                                : 'Профиль компании загружен, '
                                      'но отраслевые данные отсутствуют.',
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'InvestMind Score пока оценивает техническое '
                            'состояние цены и исторический риск. '
                            'Фундаментальная оценка бизнеса будет '
                            'добавлена отдельно.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),

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

class _CompanyAnalysisData {
  final StockQuote quote;
  final CompanyProfile profile;
  final HistoricalPriceAnalysis? historical;
  final FundamentalData? fundamentals;

  const _CompanyAnalysisData({
    required this.quote,
    required this.profile,
    this.historical,
    this.fundamentals,
  });

  bool get hasHistoricalData =>
      historical != null && historical!.prices.length >= 2;

  bool get hasFundamentalData =>
      fundamentals != null && fundamentals!.hasAnyData;
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
          Icon(Icons.analytics_outlined, size: 60, color: Colors.white38),
          SizedBox(height: 16),
          Text(
            'Выбери компанию для анализа',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

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
          const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text(
            'Не удалось получить данные',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          Icon(icon, color: const Color(0xFF20D3C2)),
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
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
