import 'package:flutter/material.dart';

import 'dart:async';
import '../market/market_data_cache.dart';
import '../../services/portfolio_analytics_service.dart';
import '../../services/portfolio_service.dart';
import '../portfolio/portfolio_health_service.dart';
import 'market_pulse_service.dart';
import 'pulse_event.dart';
import 'pulse_service.dart';

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  final PortfolioAnalyticsService _analyticsService =
      PortfolioAnalyticsService();

  final PortfolioHealthService _healthService = const PortfolioHealthService();

  final PulseService _pulseService = const PulseService();

  final MarketPulseService _marketPulseService = MarketPulseService();

  final MarketDataCache _marketDataCache = MarketDataCache.instance;

  bool _isLoading = true;
  String? _error;

  PortfolioHealthResult? _health;

  List<PulseEvent> _events = const [];

  @override
  void initState() {
    super.initState();

    PortfolioService.instance.positions.addListener(_handlePortfolioChanged);

    _marketDataCache.addListener(_handleMarketDataChanged);

    _loadPulse();
  }

  @override
  void dispose() {
    PortfolioService.instance.positions.removeListener(_handlePortfolioChanged);

    _marketDataCache.removeListener(_handleMarketDataChanged);

    super.dispose();
  }

  void _handlePortfolioChanged() {
    _loadPulse();
  }

  void _handleMarketDataChanged() {
    _loadMarketPulse();
  }

  Future<void> _loadPulse() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final positions = PortfolioService.instance.positions.value;

      PortfolioHealthResult? health;
      final portfolioEvents = <PulseEvent>[];

      if (positions.isNotEmpty) {
        final analytics = await _analyticsService.analyze(positions);

        health = _healthService.calculate(analytics);

        portfolioEvents.addAll(
          _pulseService.buildPortfolioEvents(
            analytics: analytics,
            health: health,
          ),
        );
      }

      portfolioEvents.sort(_compareEvents);

      if (!mounted) {
        return;
      }

      setState(() {
        _health = health;
        _events = portfolioEvents;
        _isLoading = false;
      });

      _loadMarketPulse();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMarketPulse() async {
    try {
      final marketEvents = await _marketPulseService.buildMarketEvents(
        companyLimit: 12,
        eventLimit: 10,
      );

      if (!mounted) {
        return;
      }

      final portfolioEvents = _events
          .where(
            (event) =>
                event.type != PulseEventType.marketSignal &&
                !(event.type == PulseEventType.opportunity &&
                    event.symbol != null),
          )
          .toList();

      final allEvents = <PulseEvent>[...portfolioEvents, ...marketEvents];

      allEvents.sort(_compareEvents);

      setState(() {
        _events = allEvents;
      });
    } catch (_) {
      // Ошибка Market Pulse не должна ломать Portfolio Pulse.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'InvestMind Pulse',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadPulse,
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      color: const Color(0xFF20D3C2),
      backgroundColor: const Color(0xFF1E293B),
      onRefresh: _loadPulse,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildHeader(),

          const SizedBox(height: 16),

          if (_health != null)
            _buildPortfolioSummary(_health!)
          else
            _buildEmptyPortfolioCard(),

          const SizedBox(height: 22),

          Row(
            children: [
              const Text(
                'Требует внимания',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${_events.length}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'События портфеля и рынка, отсортированные по важности.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
          ),

          const SizedBox(height: 12),

          if (_events.isEmpty)
            _buildNoEventsState()
          else
            ..._events.map(_buildPulseCard),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF20D3C2)),
            SizedBox(height: 16),
            Text(
              'Pulse анализирует портфель и рынок...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Row(
        children: [
          ContainerIcon(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pulse',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Главное, что сейчас требует внимания '
                  'в портфеле и на рынке.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
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

  Widget _buildPortfolioSummary(PortfolioHealthResult health) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFF94A3B8),
                size: 15,
              ),
              SizedBox(width: 6),
              Text(
                'Портфель',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              _summaryScore('Health', health.score),
              _summaryScore('Opportunity', health.opportunityScore),
              _summaryScore('Устойчивость', health.riskScore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPortfolioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: Color(0xFF94A3B8),
            size: 25,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Портфель пока пуст',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Рыночные события Pulse продолжат работать. '
                  'После добавления позиций здесь появится '
                  'Portfolio Health.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
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

  Widget _summaryScore(String label, int score) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$score',
            style: const TextStyle(
              color: Color(0xFF20D3C2),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseCard(PulseEvent event) {
    final accent = _priorityColor(event.priority);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_eventIcon(event.type), color: accent, size: 19),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (event.symbol != null) ...[
                      Text(
                        event.symbol!,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _eventTypeLabel(event.type),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  event.description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),

                if (event.currentScore != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    'Score: ${event.currentScore}',
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                Row(
                  children: [
                    Text(
                      _priorityLabel(event.priority),
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '•',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 9),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _freshnessText(event.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF20D3C2),
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            'Значимых событий нет',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 5),
          Text(
            'Pulse не нашёл событий, которые сейчас '
            'проходят заданные пороги важности.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.orangeAccent,
              size: 42,
            ),

            const SizedBox(height: 14),

            const Text(
              'Не удалось обновить Pulse',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 7),

            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),

            const SizedBox(height: 14),

            FilledButton(
              onPressed: _loadPulse,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF20D3C2),
                foregroundColor: const Color(0xFF111827),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  String _freshnessText(DateTime createdAt) {
    final now = DateTime.now();

    final difference = now.difference(createdAt);

    if (difference.isNegative) {
      return 'только что';
    }

    if (difference.inSeconds < 60) {
      return 'только что';
    }

    if (difference.inMinutes < 60) {
      return 'обновлено ${difference.inMinutes} мин назад';
    }

    if (difference.inHours < 24) {
      return 'обновлено ${difference.inHours} ч назад';
    }

    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');

    return 'обновлено $day.$month в $hour:$minute';
  }

  int _compareEvents(PulseEvent a, PulseEvent b) {
    final priorityComparison = _priorityValue(
      b.priority,
    ).compareTo(_priorityValue(a.priority));

    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final bScore = b.currentScore ?? 0;
    final aScore = a.currentScore ?? 0;

    final scoreComparison = bScore.compareTo(aScore);

    if (scoreComparison != 0) {
      return scoreComparison;
    }

    return b.createdAt.compareTo(a.createdAt);
  }

  int _priorityValue(PulsePriority priority) {
    switch (priority) {
      case PulsePriority.low:
        return 1;

      case PulsePriority.medium:
        return 2;

      case PulsePriority.high:
        return 3;

      case PulsePriority.critical:
        return 4;
    }
  }

  Color _priorityColor(PulsePriority priority) {
    switch (priority) {
      case PulsePriority.low:
        return Colors.blueGrey;

      case PulsePriority.medium:
        return const Color(0xFF20D3C2);

      case PulsePriority.high:
        return Colors.orangeAccent;

      case PulsePriority.critical:
        return Colors.redAccent;
    }
  }

  String _priorityLabel(PulsePriority priority) {
    switch (priority) {
      case PulsePriority.low:
        return 'НИЗКИЙ ПРИОРИТЕТ';

      case PulsePriority.medium:
        return 'СРЕДНИЙ ПРИОРИТЕТ';

      case PulsePriority.high:
        return 'ВЫСОКИЙ ПРИОРИТЕТ';

      case PulsePriority.critical:
        return 'КРИТИЧЕСКИЙ ПРИОРИТЕТ';
    }
  }

  String _eventTypeLabel(PulseEventType type) {
    switch (type) {
      case PulseEventType.portfolio:
        return 'ПОРТФЕЛЬ';

      case PulseEventType.opportunity:
        return 'OPPORTUNITY';

      case PulseEventType.marketSignal:
        return 'РЫНОК';

      case PulseEventType.concentration:
        return 'КОНЦЕНТРАЦИЯ';

      case PulseEventType.risk:
        return 'УСТОЙЧИВОСТЬ';
    }
  }

  IconData _eventIcon(PulseEventType type) {
    switch (type) {
      case PulseEventType.portfolio:
        return Icons.account_balance_wallet_outlined;

      case PulseEventType.opportunity:
        return Icons.trending_up_rounded;

      case PulseEventType.marketSignal:
        return Icons.show_chart_rounded;

      case PulseEventType.concentration:
        return Icons.donut_large_rounded;

      case PulseEventType.risk:
        return Icons.shield_outlined;
    }
  }
}

class ContainerIcon extends StatelessWidget {
  const ContainerIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF20D3C2).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(Icons.bolt_rounded, color: Color(0xFF20D3C2), size: 26),
    );
  }
}
