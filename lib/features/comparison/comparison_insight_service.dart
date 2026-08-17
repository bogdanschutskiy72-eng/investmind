import 'company_comparison.dart';

class ComparisonInsightService {
  const ComparisonInsightService();

  String buildSummary(List<CompanyComparison> companies) {
    if (companies.length < 2) {
      return 'Для сравнительного вывода нужно минимум две компании.';
    }

    final ranked = [...companies]
      ..sort((a, b) => b.investMindScore.compareTo(a.investMindScore));

    final leader = ranked.first;
    final second = ranked[1];
    final last = ranked.last;

    final paragraphs = <String>[
      _buildOverallParagraph(ranked, leader, second),
      _buildLeaderStrengths(leader, companies),
    ];

    final otherHighlights = _buildOtherHighlights(leader, companies);

    if (otherHighlights.isNotEmpty) {
      paragraphs.add(otherHighlights);
    }

    if (companies.length >= 3) {
      paragraphs.add(_buildLastPlaceParagraph(last, companies));
    }

    paragraphs.add(_buildConclusion(ranked));

    return paragraphs.where((text) => text.trim().isNotEmpty).join('\n\n');
  }

  String _buildOverallParagraph(
    List<CompanyComparison> ranked,
    CompanyComparison leader,
    CompanyComparison second,
  ) {
    final int difference = leader.investMindScore - second.investMindScore;

    final String ranking = ranked
        .map((company) => '${company.symbol} — ${company.investMindScore}/100')
        .join(', ');

    String advantageText;

    if (difference == 0) {
      advantageText =
          '${leader.symbol} и ${second.symbol} делят лидерство по общей оценке.';
    } else if (difference >= 15) {
      advantageText =
          '${leader.symbol} имеет заметное преимущество над ближайшим конкурентом.';
    } else if (difference >= 7) {
      advantageText =
          '${leader.symbol} удерживает достаточно уверенное преимущество.';
    } else if (difference >= 3) {
      advantageText = 'Разрыв между лидерами сравнительно небольшой.';
    } else {
      advantageText = 'Лидеры находятся очень близко по общей оценке.';
    }

    return '${leader.symbol} занимает первое место по общей оценке '
        'InvestMind — ${leader.investMindScore}/100. '
        '$advantageText '
        'Текущий рейтинг группы: $ranking.';
  }

  String _buildLeaderStrengths(
    CompanyComparison leader,
    List<CompanyComparison> companies,
  ) {
    final uniqueStrengths = <String>[];
    final sharedStrengths = <String>[];

    _collectLeaderMetric(
      company: leader,
      companies: companies,
      valueSelector: (c) => c.fundamentalScore,
      uniqueLabel: 'фундаментальной картине',
      sharedLabel: 'фундаментальной картине',
      uniqueStrengths: uniqueStrengths,
      sharedStrengths: sharedStrengths,
    );

    _collectLeaderMetric(
      company: leader,
      companies: companies,
      valueSelector: (c) => c.technicalScore,
      uniqueLabel: 'технической картине',
      sharedLabel: 'технической картине',
      uniqueStrengths: uniqueStrengths,
      sharedStrengths: sharedStrengths,
    );

    _collectLeaderMetric(
      company: leader,
      companies: companies,
      valueSelector: (c) => c.growthScore,
      uniqueLabel: 'росту',
      sharedLabel: 'росту',
      uniqueStrengths: uniqueStrengths,
      sharedStrengths: sharedStrengths,
    );

    _collectLeaderMetric(
      company: leader,
      companies: companies,
      valueSelector: (c) => c.profitabilityScore,
      uniqueLabel: 'прибыльности',
      sharedLabel: 'прибыльности',
      uniqueStrengths: uniqueStrengths,
      sharedStrengths: sharedStrengths,
    );

    _collectLeaderMetric(
      company: leader,
      companies: companies,
      valueSelector: (c) => c.valuationScore,
      uniqueLabel: 'оценке',
      sharedLabel: 'оценке',
      uniqueStrengths: uniqueStrengths,
      sharedStrengths: sharedStrengths,
    );

    _collectLeaderMetric(
      company: leader,
      companies: companies,
      valueSelector: (c) => c.financialHealthScore,
      uniqueLabel: 'финансовому здоровью',
      sharedLabel: 'финансовому здоровью',
      uniqueStrengths: uniqueStrengths,
      sharedStrengths: sharedStrengths,
    );

    _collectLeaderMetric(
      company: leader,
      companies: companies,
      valueSelector: (c) => c.riskScore,
      uniqueLabel: 'профилю риска',
      sharedLabel: 'профилю риска',
      uniqueStrengths: uniqueStrengths,
      sharedStrengths: sharedStrengths,
    );

    if (uniqueStrengths.isEmpty && sharedStrengths.isEmpty) {
      return '${leader.symbol} лидирует по совокупной оценке, '
          'хотя не занимает первое место по отдельным ключевым категориям. '
          'Преимущество формируется за счёт более сбалансированного '
          'сочетания показателей.';
    }

    final parts = <String>[];

    if (uniqueStrengths.isNotEmpty) {
      parts.add(
        '${leader.symbol} единолично лидирует по '
        '${_joinRussian(uniqueStrengths)}.',
      );
    }

    if (sharedStrengths.isNotEmpty) {
      parts.add(
        'Также ${leader.symbol} делит лидерство по '
        '${_joinRussian(sharedStrengths)}.',
      );
    }

    parts.add(
      'Это поддерживает высокую позицию компании '
      'по совокупной оценке InvestMind.',
    );

    return parts.join(' ');
  }

  String _buildOtherHighlights(
    CompanyComparison leader,
    List<CompanyComparison> companies,
  ) {
    final parts = <String>[];

    for (final company in companies) {
      if (identical(company, leader)) {
        continue;
      }

      final uniqueHighlights = <String>[];
      final sharedHighlights = <String>[];

      _collectOtherMetric(
        company: company,
        companies: companies,
        valueSelector: (c) => c.technicalScore,
        uniqueLabel: 'лучшей технической картиной',
        sharedLabel: 'лидерство по технической картине',
        uniqueHighlights: uniqueHighlights,
        sharedHighlights: sharedHighlights,
      );

      _collectOtherMetric(
        company: company,
        companies: companies,
        valueSelector: (c) => c.fundamentalScore,
        uniqueLabel: 'сильнейшей фундаментальной картиной',
        sharedLabel: 'лидерство по фундаментальной картине',
        uniqueHighlights: uniqueHighlights,
        sharedHighlights: sharedHighlights,
      );

      _collectOtherMetric(
        company: company,
        companies: companies,
        valueSelector: (c) => c.growthScore,
        uniqueLabel: 'наиболее сильным ростом',
        sharedLabel: 'лидерство по росту',
        uniqueHighlights: uniqueHighlights,
        sharedHighlights: sharedHighlights,
      );

      _collectOtherMetric(
        company: company,
        companies: companies,
        valueSelector: (c) => c.profitabilityScore,
        uniqueLabel: 'лучшей прибыльностью',
        sharedLabel: 'лидерство по прибыльности',
        uniqueHighlights: uniqueHighlights,
        sharedHighlights: sharedHighlights,
      );

      _collectOtherMetric(
        company: company,
        companies: companies,
        valueSelector: (c) => c.valuationScore,
        uniqueLabel: 'наиболее привлекательной оценкой',
        sharedLabel: 'лидерство по оценке',
        uniqueHighlights: uniqueHighlights,
        sharedHighlights: sharedHighlights,
      );

      _collectOtherMetric(
        company: company,
        companies: companies,
        valueSelector: (c) => c.financialHealthScore,
        uniqueLabel: 'лучшим финансовым здоровьем',
        sharedLabel: 'лидерство по финансовому здоровью',
        uniqueHighlights: uniqueHighlights,
        sharedHighlights: sharedHighlights,
      );

      _collectOtherMetric(
        company: company,
        companies: companies,
        valueSelector: (c) => c.riskScore,
        uniqueLabel: 'наиболее благоприятным профилем риска',
        sharedLabel: 'лидерство по профилю риска',
        uniqueHighlights: uniqueHighlights,
        sharedHighlights: sharedHighlights,
      );

      _collectOtherMetric(
        company: company,
        companies: companies,
        valueSelector: (c) => c.confidenceScore,
        uniqueLabel: 'наивысшей достоверностью анализа',
        sharedLabel: 'лидерство по достоверности анализа',
        uniqueHighlights: uniqueHighlights,
        sharedHighlights: sharedHighlights,
      );

      final companyParts = <String>[];

      if (uniqueHighlights.isNotEmpty) {
        companyParts.add(
          '${company.symbol} выделяется '
          '${_joinRussian(uniqueHighlights)}.',
        );
      }

      if (sharedHighlights.isNotEmpty) {
        companyParts.add(
          '${company.symbol} также делит '
          '${_joinRussian(sharedHighlights)}.',
        );
      }

      if (companyParts.isNotEmpty) {
        parts.add(companyParts.join(' '));
      }
    }

    return parts.join(' ');
  }

  String _buildLastPlaceParagraph(
    CompanyComparison last,
    List<CompanyComparison> companies,
  ) {
    final strengths = <String>[];

    if (_isBest(last.valuationScore, companies.map((e) => e.valuationScore))) {
      strengths.add('оценка');
    }

    if (_isBest(last.technicalScore, companies.map((e) => e.technicalScore))) {
      strengths.add('техническая картина');
    }

    if (_isBest(
      last.financialHealthScore,
      companies.map((e) => e.financialHealthScore),
    )) {
      strengths.add('финансовое здоровье');
    }

    if (strengths.isEmpty) {
      return '${last.symbol} занимает последнее место по совокупной '
          'оценке InvestMind — ${last.investMindScore}/100. '
          'В рамках текущего сравнения компания уступает конкурентам '
          'по балансу рассматриваемых показателей.';
    }

    return '${last.symbol} занимает последнее место по общей оценке '
        'InvestMind — ${last.investMindScore}/100, '
        'однако её сильной стороной остаётся '
        '${_joinRussian(strengths)}.';
  }

  String _buildConclusion(List<CompanyComparison> ranked) {
    final leader = ranked.first;

    if (ranked.length == 2) {
      final second = ranked[1];

      final gap = leader.investMindScore - second.investMindScore;

      if (gap <= 3) {
        return 'В итоге ${leader.symbol} и ${second.symbol} '
            'находятся достаточно близко по общей оценке. '
            'Итог сравнения сильнее зависит от приоритетов между '
            'ростом, прибыльностью, оценкой и риском.';
      }

      return 'В итоге ${leader.symbol} выглядит сильнее '
          '${second.symbol} по совокупности текущих показателей InvestMind, '
          'хотя отдельные категории могут давать преимущество '
          '${second.symbol}.';
    }

    final second = ranked[1];

    if (ranked.length == 3) {
      return 'В итоге ${leader.symbol} выглядит наиболее '
          'сбалансированной компанией в этой группе. '
          '${second.symbol} является ближайшим конкурентом, '
          'а различия между компаниями лучше оценивать не только '
          'по итоговому баллу, но и по отдельным категориям.';
    }

    final third = ranked[2];
    final fourth = ranked[3];

    return 'В итоге ${leader.symbol} выглядит наиболее сильной компанией '
        'по совокупности текущих показателей. '
        '${second.symbol} занимает второе место, '
        '${third.symbol} — третье, '
        '${fourth.symbol} — четвёртое. '
        'При выборе между ними важно учитывать, за счёт каких именно '
        'категорий сформировалась итоговая оценка.';
  }

  void _collectLeaderMetric({
    required CompanyComparison company,
    required List<CompanyComparison> companies,
    required int Function(CompanyComparison) valueSelector,
    required String uniqueLabel,
    required String sharedLabel,
    required List<String> uniqueStrengths,
    required List<String> sharedStrengths,
  }) {
    final values = companies.map(valueSelector).toList();

    final companyValue = valueSelector(company);

    final maxValue = values.reduce((a, b) => a > b ? a : b);

    if (companyValue != maxValue) {
      return;
    }

    final winners = values.where((value) => value == maxValue).length;

    if (winners == 1) {
      uniqueStrengths.add(uniqueLabel);
    } else {
      sharedStrengths.add(sharedLabel);
    }
  }

  void _collectOtherMetric({
    required CompanyComparison company,
    required List<CompanyComparison> companies,
    required int Function(CompanyComparison) valueSelector,
    required String uniqueLabel,
    required String sharedLabel,
    required List<String> uniqueHighlights,
    required List<String> sharedHighlights,
  }) {
    final values = companies.map(valueSelector).toList();

    final companyValue = valueSelector(company);

    final maxValue = values.reduce((a, b) => a > b ? a : b);

    if (companyValue != maxValue) {
      return;
    }

    final winners = values.where((value) => value == maxValue).length;

    if (winners == 1) {
      uniqueHighlights.add(uniqueLabel);
    } else {
      sharedHighlights.add(sharedLabel);
    }
  }

  bool _isBest(int value, Iterable<int> values) {
    final maxValue = values.reduce(
      (current, next) => current > next ? current : next,
    );

    return value == maxValue;
  }

  String _joinRussian(List<String> values) {
    if (values.isEmpty) {
      return '';
    }

    if (values.length == 1) {
      return values.first;
    }

    if (values.length == 2) {
      return '${values[0]} и ${values[1]}';
    }

    return '${values.sublist(0, values.length - 1).join(', ')} '
        'и ${values.last}';
  }
}
