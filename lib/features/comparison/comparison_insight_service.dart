import 'company_comparison.dart';

class ComparisonInsightService {
  const ComparisonInsightService();

  String buildSummary(CompanyComparison first, CompanyComparison second) {
    final CompanyComparison overallWinner =
        first.investMindScore >= second.investMindScore ? first : second;

    final CompanyComparison other = identical(overallWinner, first)
        ? second
        : first;

    final int scoreGap = (first.investMindScore - second.investMindScore).abs();

    final List<String> paragraphs = [];

    paragraphs.add(
      _buildOpening(winner: overallWinner, other: other, scoreGap: scoreGap),
    );

    final String qualityParagraph = _buildQualityComparison(first, second);

    if (qualityParagraph.isNotEmpty) {
      paragraphs.add(qualityParagraph);
    }

    final String valuationParagraph = _buildValuationTradeOff(first, second);

    if (valuationParagraph.isNotEmpty) {
      paragraphs.add(valuationParagraph);
    }

    final String riskParagraph = _buildRiskComparison(first, second);

    if (riskParagraph.isNotEmpty) {
      paragraphs.add(riskParagraph);
    }

    final String finalParagraph = _buildFinalTakeaway(
      first: first,
      second: second,
      winner: overallWinner,
      other: other,
      scoreGap: scoreGap,
    );

    if (finalParagraph.isNotEmpty) {
      paragraphs.add(finalParagraph);
    }

    return paragraphs.join('\n\n');
  }

  String _buildOpening({
    required CompanyComparison winner,
    required CompanyComparison other,
    required int scoreGap,
  }) {
    if (scoreGap <= 3) {
      return '${winner.symbol} имеет небольшое преимущество по общей оценке '
          'InvestMind — ${winner.investMindScore}/100 против '
          '${other.investMindScore}/100. Разрыв небольшой, поэтому итог '
          'сравнения определяется скорее различиями внутри отдельных блоков, '
          'чем явным превосходством одной компании.';
    }

    if (scoreGap <= 10) {
      return '${winner.symbol} выглядит сильнее в этом сравнении: '
          'InvestMind Score составляет ${winner.investMindScore}/100 против '
          '${other.investMindScore}/100. Преимущество заметное, но не настолько '
          'большое, чтобы игнорировать сильные стороны ${other.symbol}.';
    }

    return '${winner.symbol} заметно опережает ${other.symbol} по общей оценке '
        'InvestMind — ${winner.investMindScore}/100 против '
        '${other.investMindScore}/100. Разрыв достаточно большой и отражает '
        'существенные различия в качестве текущей фундаментальной и рыночной '
        'картины.';
  }

  String _buildQualityComparison(
    CompanyComparison first,
    CompanyComparison second,
  ) {
    final List<String> firstAdvantages = [];
    final List<String> secondAdvantages = [];

    _addAdvantage(
      firstAdvantages,
      secondAdvantages,
      first.growthScore,
      second.growthScore,
      'росту',
    );

    _addAdvantage(
      firstAdvantages,
      secondAdvantages,
      first.profitabilityScore,
      second.profitabilityScore,
      'прибыльности',
    );

    _addAdvantage(
      firstAdvantages,
      secondAdvantages,
      first.financialHealthScore,
      second.financialHealthScore,
      'финансовому здоровью',
    );

    _addAdvantage(
      firstAdvantages,
      secondAdvantages,
      first.fundamentalScore,
      second.fundamentalScore,
      'фундаментальной картине',
    );

    final bool firstHasMore = firstAdvantages.length > secondAdvantages.length;

    final bool secondHasMore = secondAdvantages.length > firstAdvantages.length;

    if (!firstHasMore && !secondHasMore) {
      if (first.technicalScore == second.technicalScore) {
        return '';
      }

      final CompanyComparison technicalWinner =
          first.technicalScore > second.technicalScore ? first : second;

      return 'По качественным блокам компании выглядят достаточно близко, '
          'но техническая картина сейчас лучше у '
          '${technicalWinner.symbol}.';
    }

    final CompanyComparison qualityWinner = firstHasMore ? first : second;

    final List<String> advantages = firstHasMore
        ? firstAdvantages
        : secondAdvantages;

    final CompanyComparison qualityOther = firstHasMore ? second : first;

    final String metrics = _joinMetrics(advantages);

    String result = '${qualityWinner.symbol} имеет преимущество по $metrics.';

    if (qualityWinner.technicalScore > qualityOther.technicalScore + 5) {
      result +=
          ' Техническая картина также сильнее у '
          '${qualityWinner.symbol}.';
    } else if (qualityOther.technicalScore > qualityWinner.technicalScore + 5) {
      result +=
          ' При этом технически сейчас сильнее выглядит '
          '${qualityOther.symbol}.';
    }

    return result;
  }

  String _buildValuationTradeOff(
    CompanyComparison first,
    CompanyComparison second,
  ) {
    final int gap = (first.valuationScore - second.valuationScore).abs();

    if (gap < 5) {
      return 'По оценке компании находятся примерно на сопоставимом уровне, '
          'поэтому Valuation не даёт одной из них явного преимущества.';
    }

    final CompanyComparison valuationWinner =
        first.valuationScore > second.valuationScore ? first : second;

    final CompanyComparison valuationOther = identical(valuationWinner, first)
        ? second
        : first;

    final bool valuationConflictsWithOverall =
        valuationWinner.investMindScore < valuationOther.investMindScore;

    if (valuationConflictsWithOverall) {
      return '${valuationWinner.symbol} выглядит привлекательнее по оценке. '
          'Это важный компромисс: ${valuationOther.symbol} сильнее по общей '
          'картине, но рынок оценивает его требовательнее.';
    }

    return '${valuationWinner.symbol} имеет преимущество и по Valuation, '
        'то есть его общая сила не сопровождается более слабой оценкой '
        'относительно ${valuationOther.symbol}.';
  }

  String _buildRiskComparison(
    CompanyComparison first,
    CompanyComparison second,
  ) {
    final int riskGap = (first.riskScore - second.riskScore).abs();

    final int confidenceGap = (first.confidenceScore - second.confidenceScore)
        .abs();

    final List<String> parts = [];

    if (riskGap >= 5) {
      final CompanyComparison riskWinner = first.riskScore > second.riskScore
          ? first
          : second;

      parts.add(
        '${riskWinner.symbol} имеет более благоприятный профиль риска.',
      );
    }

    if (confidenceGap >= 5) {
      final CompanyComparison confidenceWinner =
          first.confidenceScore > second.confidenceScore ? first : second;

      parts.add(
        'Достоверность анализа заметно выше у '
        '${confidenceWinner.symbol}.',
      );
    } else if (confidenceGap > 0) {
      parts.add(
        'Уровень Confidence у компаний близкий, поэтому разница '
        'в достоверности анализа не является определяющей.',
      );
    }

    return parts.join(' ');
  }

  String _buildFinalTakeaway({
    required CompanyComparison first,
    required CompanyComparison second,
    required CompanyComparison winner,
    required CompanyComparison other,
    required int scoreGap,
  }) {
    final bool otherWinsValuation =
        other.valuationScore > winner.valuationScore + 5;

    final bool otherWinsTechnical =
        other.technicalScore > winner.technicalScore + 5;

    if (scoreGap <= 3) {
      return 'Итог близкий: ${winner.symbol} немного впереди по общей оценке, '
          'но выбор между компаниями сильнее зависит от того, что важнее — '
          'рост, прибыльность, оценка или текущая техническая картина.';
    }

    if (otherWinsValuation && !otherWinsTechnical) {
      return 'В итоге ${winner.symbol} выглядит сильнее по совокупности '
          'показателей, тогда как главное преимущество ${other.symbol} — '
          'более привлекательная оценка.';
    }

    if (otherWinsTechnical && !otherWinsValuation) {
      return 'В итоге ${winner.symbol} сильнее по общей картине, но '
          '${other.symbol} сейчас имеет более сильную техническую структуру.';
    }

    if (otherWinsValuation && otherWinsTechnical) {
      return '${winner.symbol} остаётся лидером по общей оценке, но '
          '${other.symbol} компенсирует отставание более привлекательной '
          'оценкой и более сильной текущей технической картиной.';
    }

    return 'По совокупности текущих показателей преимущество остаётся за '
        '${winner.symbol}. ${other.symbol} уступает по общей оценке и не имеет '
        'достаточно сильного встречного преимущества, чтобы изменить итог '
        'сравнения.';
  }

  void _addAdvantage(
    List<String> firstAdvantages,
    List<String> secondAdvantages,
    int firstScore,
    int secondScore,
    String metric,
  ) {
    final int difference = (firstScore - secondScore).abs();

    if (difference < 5) {
      return;
    }

    if (firstScore > secondScore) {
      firstAdvantages.add(metric);
    } else {
      secondAdvantages.add(metric);
    }
  }

  String _joinMetrics(List<String> metrics) {
    if (metrics.isEmpty) {
      return '';
    }

    if (metrics.length == 1) {
      return metrics.first;
    }

    if (metrics.length == 2) {
      return '${metrics[0]} и ${metrics[1]}';
    }

    final String beginning = metrics.sublist(0, metrics.length - 1).join(', ');

    return '$beginning и ${metrics.last}';
  }
}
