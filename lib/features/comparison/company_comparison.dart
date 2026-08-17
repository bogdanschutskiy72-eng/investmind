class CompanyComparison {
  final String symbol;
  final String companyName;
  final String industry;

  final int investMindScore;
  final int technicalScore;
  final int fundamentalScore;

  final int growthScore;
  final int profitabilityScore;
  final int valuationScore;
  final int financialHealthScore;
  final int riskScore;

  final int confidenceScore;
  final int dataCompletenessPercent;

  const CompanyComparison({
    required this.symbol,
    required this.companyName,
    required this.industry,
    required this.investMindScore,
    required this.technicalScore,
    required this.fundamentalScore,
    required this.growthScore,
    required this.profitabilityScore,
    required this.valuationScore,
    required this.financialHealthScore,
    required this.riskScore,
    required this.confidenceScore,
    required this.dataCompletenessPercent,
  });
}
