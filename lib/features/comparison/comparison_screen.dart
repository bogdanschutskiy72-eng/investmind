import 'package:flutter/material.dart';

import 'ai_comparison_service.dart';
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

  final AiComparisonService _aiComparisonService = const AiComparisonService();

  final List<TextEditingController> _controllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isLoading = false;
  bool _isAiLoading = false;

  String? _error;
  String? _aiError;

  List<CompanyComparison> _companies = [];
  AiComparisonResult? _aiComparison;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _addCompanyField() {
    if (_controllers.length >= 4) {
      return;
    }

    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removeCompanyField(int index) {
    if (_controllers.length <= 2) {
      return;
    }

    if (index < 2) {
      return;
    }

    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);

      _companies = [];
      _aiComparison = null;
      _aiError = null;
      _error = null;
    });
  }

  Future<void> _compare() async {
    final List<String> symbols = _controllers
        .map((controller) => controller.text.trim().toUpperCase())
        .where((symbol) => symbol.isNotEmpty)
        .toList();

    if (symbols.length < 2) {
      setState(() {
        _error = 'Укажи минимум две компании для сравнения.';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _error = null;

      _aiComparison = null;
      _aiError = null;

      _companies = [];
    });

    try {
      final List<CompanyComparison> result = await _comparisonService
          .compareCompanies(symbols);

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
        _error = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestAiComparison() async {
    if (_companies.length < 2) {
      return;
    }

    setState(() {
      _isAiLoading = true;
      _aiError = null;
      _aiComparison = null;
    });

    try {
      final AiComparisonBackendResponse response = await _aiComparisonService
          .compareCompanies(_companies);

      if (!mounted) {
        return;
      }

      setState(() {
        _aiComparison = response.comparison;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _aiError = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
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
                    'Сравни от 2 до 4 компаний '
                    'по ключевым показателям InvestMind.',
                    style: TextStyle(fontSize: 17, color: Colors.white70),
                  ),

                  const SizedBox(height: 24),

                  _buildSearchPanel(),

                  const SizedBox(height: 20),

                  if (_error != null) _buildErrorCard(_error!),

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
          LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxWidth < 800;

              if (compact) {
                return Column(
                  children: List.generate(
                    _controllers.length,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _controllers.length - 1 ? 0 : 12,
                      ),
                      child: _buildCompanyInput(index),
                    ),
                  ),
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(
                  _controllers.length,
                  (index) => SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: _buildCompanyInput(index),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              if (_controllers.length < 4)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _addCompanyField,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить компанию'),
                  ),
                ),

              if (_controllers.length < 4) const SizedBox(width: 12),

              Expanded(
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
        ],
      ),
    );
  }

  Widget _buildCompanyInput(int index) {
    final bool removable = index >= 2 && _controllers.length > 2;

    return TextField(
      controller: _controllers[index],
      textCapitalization: TextCapitalization.characters,
      onSubmitted: (_) => _compare(),
      decoration: InputDecoration(
        hintText: 'Компания ${index + 1}, например ${_exampleTicker(index)}',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: removable
            ? IconButton(
                tooltip: 'Убрать компанию',
                onPressed: _isLoading ? null : () => _removeCompanyField(index),
                icon: const Icon(Icons.close),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  String _exampleTicker(int index) {
    const examples = ['NVDA', 'AMD', 'INTC', 'PLTR'];

    return examples[index];
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: const TextStyle(color: Colors.redAccent)),
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
              'Выбери компании',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 10),

            Text(
              'Можно сравнить '
              'от 2 до 4 компаний.',
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
          values: _companies.map((company) => company.investMindScore).toList(),
        ),

        _buildScoreRow(
          title: 'Technical',
          values: _companies.map((company) => company.technicalScore).toList(),
        ),

        _buildScoreRow(
          title: 'Fundamental',
          values: _companies
              .map((company) => company.fundamentalScore)
              .toList(),
        ),

        _buildScoreRow(
          title: 'Growth',
          values: _companies.map((company) => company.growthScore).toList(),
        ),

        _buildScoreRow(
          title: 'Profitability',
          values: _companies
              .map((company) => company.profitabilityScore)
              .toList(),
        ),

        _buildScoreRow(
          title: 'Valuation',
          values: _companies.map((company) => company.valuationScore).toList(),
        ),

        _buildScoreRow(
          title: 'Financial Health',
          values: _companies
              .map((company) => company.financialHealthScore)
              .toList(),
        ),

        _buildScoreRow(
          title: 'Risk',
          values: _companies.map((company) => company.riskScore).toList(),
        ),

        _buildPercentRow(
          title: 'Confidence',
          values: _companies.map((company) => company.confidenceScore).toList(),
        ),

        _buildPercentRow(
          title: 'Полнота данных',
          values: _companies
              .map((company) => company.dataCompletenessPercent)
              .toList(),
        ),

        const SizedBox(height: 16),

        _buildInsightCard(),

        const SizedBox(height: 16),

        _buildAiActionCard(),

        if (_aiError != null) ...[
          const SizedBox(height: 16),
          _buildErrorCard(_aiError!),
        ],

        if (_aiComparison != null) ...[
          const SizedBox(height: 16),
          _buildAiComparisonCard(_aiComparison!),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCompanyHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Expanded(flex: 2, child: SizedBox()),

          ..._companies.map(
            (company) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildCompanyCard(company),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(CompanyComparison company) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF20D3C2),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            company.companyName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),

          const SizedBox(height: 6),

          Text(
            company.industry,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow({required String title, required List<int> values}) {
    return _buildMetricRow(title: title, values: values, suffix: '/100');
  }

  Widget _buildPercentRow({required String title, required List<int> values}) {
    return _buildMetricRow(title: title, values: values, suffix: '%');
  }

  Widget _buildMetricRow({
    required String title,
    required List<int> values,
    required String suffix,
  }) {
    final int bestValue = values.reduce(
      (current, next) => current > next ? current : next,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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

          ...List.generate(
            values.length,
            (index) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildValue(
                  '${values[index]}$suffix',
                  highlighted: values[index] == bestValue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValue(String value, {required bool highlighted}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: highlighted ? const Color(0xFF20D3C2) : Colors.white,
        ),
      ),
    );
  }

  Widget _buildInsightCard() {
    final String summary = _insightService.buildSummary(_companies);

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

  Widget _buildAiActionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI-сравнение',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            'AI объяснит различия между компаниями '
            'на основе уже рассчитанных показателей InvestMind.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isAiLoading ? null : _requestAiComparison,
              icon: _isAiLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology),
              label: Text(
                _isAiLoading ? 'AI анализирует...' : 'Получить AI-сравнение',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiComparisonCard(AiComparisonResult result) {
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
              Icon(Icons.psychology, color: Color(0xFF20D3C2)),
              SizedBox(width: 10),
              Text(
                'InvestMind AI Comparison',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _buildAiSectionTitle('Общий вывод'),

          const SizedBox(height: 8),

          Text(
            result.summary,
            style: const TextStyle(color: Colors.white70, height: 1.55),
          ),

          const SizedBox(height: 20),

          _buildAiSectionTitle('Лидер'),

          const SizedBox(height: 8),

          Text(
            result.leader,
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF20D3C2),
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            result.leaderReason,
            style: const TextStyle(color: Colors.white70, height: 1.55),
          ),

          if (result.tradeoffs.isNotEmpty) ...[
            const SizedBox(height: 20),

            _buildAiSectionTitle('Ключевые компромиссы'),

            const SizedBox(height: 8),

            ...result.tradeoffs.map((item) => _buildBullet(item)),
          ],

          if (result.companyInsights.isNotEmpty) ...[
            const SizedBox(height: 20),

            _buildAiSectionTitle('По компаниям'),

            const SizedBox(height: 10),

            ...result.companyInsights.map(_buildCompanyInsight),
          ],

          if (result.watch.isNotEmpty) ...[
            const SizedBox(height: 20),

            _buildAiSectionTitle('Что отслеживать'),

            const SizedBox(height: 8),

            ...result.watch.map((item) => _buildBullet(item)),
          ],

          const SizedBox(height: 16),

          const Text(
            'AI не пересчитывает InvestMind Score '
            'и не является инвестиционной рекомендацией.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Color(0xFF20D3C2)),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInsight(AiComparisonCompanyInsight item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.symbol,
            style: const TextStyle(
              color: Color(0xFF20D3C2),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            item.insight,
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }
}
