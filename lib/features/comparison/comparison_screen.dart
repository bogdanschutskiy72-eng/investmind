import 'package:flutter/material.dart';

import 'company_comparison.dart';
import 'comparison_insight_service.dart';
import 'comparison_service.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  final ComparisonService _comparisonService = ComparisonService();

  final ComparisonInsightService _insightService =
      const ComparisonInsightService();

  final TextEditingController _firstController = TextEditingController();

  final TextEditingController _secondController = TextEditingController();

  bool _isLoading = false;

  String? _error;

  List<CompanyComparison> _companies = [];

  @override
  void dispose() {
    _firstController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  Future<void> _compare() async {
    final String first = _firstController.text.trim().toUpperCase();

    final String second = _secondController.text.trim().toUpperCase();

    if (first.isEmpty || second.isEmpty) {
      setState(() {
        _error = 'Укажи тикеры двух компаний для сравнения.';
      });

      return;
    }

    if (first == second) {
      setState(() {
        _error = 'Для сравнения нужны две разные компании.';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _error = null;
      _companies = [];
    });

    try {
      final List<CompanyComparison> result = await _comparisonService
          .compareCompanies([first, second]);

      if (!mounted) {
        return;
      }

      setState(() {
        _companies = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Invalid argument(s): ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Сравнение компаний',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Сравни компании по ключевым '
                    'показателям InvestMind.',
                    style: TextStyle(fontSize: 17, color: Colors.white70),
                  ),

                  const SizedBox(height: 24),

                  _buildSearchPanel(),

                  const SizedBox(height: 20),

                  if (_error != null) _buildErrorCard(),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(color: Color(0xFF20D3C2)),
                    ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: _companies.isEmpty
                        ? _buildEmptyState()
                        : _buildComparison(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _firstController,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _compare(),
                  decoration: _inputDecoration(
                    'Первая компания, например NVDA',
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller: _secondController,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _compare(),
                  decoration: _inputDecoration('Вторая компания, например AMD'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _compare,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.compare_arrows),
              label: Text(_isLoading ? 'Сравниваем...' : 'Сравнить'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search),
      filled: true,
      fillColor: const Color(0xFF111827),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.compare_arrows, size: 64, color: Color(0xFF20D3C2)),

            SizedBox(height: 16),

            Text(
              'Выбери две компании',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 10),

            Text(
              'Например: NVDA и AMD, '
              'KO и PEP, JPM и BAC.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparison() {
    return ListView(
      children: [
        _buildCompanyHeader(),
        const SizedBox(height: 16),

        _buildScoreRow(
          title: 'InvestMind Score',
          first: _companies[0].investMindScore,
          second: _companies[1].investMindScore,
        ),

        _buildScoreRow(
          title: 'Technical',
          first: _companies[0].technicalScore,
          second: _companies[1].technicalScore,
        ),

        _buildScoreRow(
          title: 'Fundamental',
          first: _companies[0].fundamentalScore,
          second: _companies[1].fundamentalScore,
        ),

        _buildScoreRow(
          title: 'Growth',
          first: _companies[0].growthScore,
          second: _companies[1].growthScore,
        ),

        _buildScoreRow(
          title: 'Profitability',
          first: _companies[0].profitabilityScore,
          second: _companies[1].profitabilityScore,
        ),

        _buildScoreRow(
          title: 'Valuation',
          first: _companies[0].valuationScore,
          second: _companies[1].valuationScore,
        ),

        _buildScoreRow(
          title: 'Financial Health',
          first: _companies[0].financialHealthScore,
          second: _companies[1].financialHealthScore,
        ),

        _buildScoreRow(
          title: 'Risk',
          first: _companies[0].riskScore,
          second: _companies[1].riskScore,
        ),

        _buildPercentRow(
          title: 'Confidence',
          first: _companies[0].confidenceScore,
          second: _companies[1].confidenceScore,
        ),

        _buildPercentRow(
          title: 'Полнота данных',
          first: _companies[0].dataCompletenessPercent,
          second: _companies[1].dataCompletenessPercent,
        ),

        const SizedBox(height: 16),

        _buildInsightCard(),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInsightCard() {
    final String summary = _insightService.buildSummary(
      _companies[0],
      _companies[1],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFF20D3C2)),

              SizedBox(width: 10),

              Text(
                'Вывод InvestMind',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            summary,
            style: const TextStyle(
              fontSize: 15,
              height: 1.55,
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Вывод основан только на рассчитанных '
            'показателях InvestMind и не является '
            'рекомендацией купить или продать актив.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return Row(
      children: [
        const Expanded(flex: 2, child: SizedBox()),

        Expanded(child: _buildCompanyCard(_companies[0])),

        const SizedBox(width: 12),

        Expanded(child: _buildCompanyCard(_companies[1])),
      ],
    );
  }

  Widget _buildCompanyCard(CompanyComparison company) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            company.symbol,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF20D3C2),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            company.companyName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 6),

          Text(
            company.industry,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow({
    required String title,
    required int first,
    required int second,
  }) {
    return _buildMetricRow(
      title: title,
      first: '$first/100',
      second: '$second/100',
      firstWins: first > second,
      secondWins: second > first,
    );
  }

  Widget _buildPercentRow({
    required String title,
    required int first,
    required int second,
  }) {
    return _buildMetricRow(
      title: title,
      first: '$first%',
      second: '$second%',
      firstWins: first > second,
      secondWins: second > first,
    );
  }

  Widget _buildMetricRow({
    required String title,
    required String first,
    required String second,
    required bool firstWins,
    required bool secondWins,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(child: _buildValue(first, highlighted: firstWins)),

          const SizedBox(width: 12),

          Expanded(child: _buildValue(second, highlighted: secondWins)),
        ],
      ),
    );
  }

  Widget _buildValue(String value, {required bool highlighted}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFF20D3C2).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: highlighted ? const Color(0xFF20D3C2) : Colors.white,
        ),
      ),
    );
  }
}
