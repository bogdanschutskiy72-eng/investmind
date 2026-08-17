import '../../services/combined_score_service.dart';
import '../../services/company_profile_service.dart';
import '../../services/confidence_score_service.dart';
import '../../services/fundamental_score_service.dart';
import '../../services/fundamental_service.dart';
import '../../services/historical_price_service.dart';
import '../../services/investmind_score_service.dart';
import '../../services/stock_service.dart';

import 'company_comparison.dart';

class ComparisonService {
  final StockService _stockService;
  final CompanyProfileService _profileService;
  final HistoricalPriceService _historicalPriceService;
  final FundamentalService _fundamentalService;

  final InvestMindScoreService _technicalScoreService;
  final FundamentalScoreService _fundamentalScoreService;
  final CombinedScoreService _combinedScoreService;
  final ConfidenceScoreService _confidenceScoreService;

  ComparisonService({
    StockService? stockService,
    CompanyProfileService? profileService,
    HistoricalPriceService? historicalPriceService,
    FundamentalService? fundamentalService,
    InvestMindScoreService? technicalScoreService,
    FundamentalScoreService? fundamentalScoreService,
    CombinedScoreService? combinedScoreService,
    ConfidenceScoreService? confidenceScoreService,
  }) : _stockService = stockService ?? StockService(),
       _profileService = profileService ?? CompanyProfileService(),
       _historicalPriceService =
           historicalPriceService ?? HistoricalPriceService(),
       _fundamentalService = fundamentalService ?? FundamentalService(),
       _technicalScoreService =
           technicalScoreService ?? const InvestMindScoreService(),
       _fundamentalScoreService =
           fundamentalScoreService ?? const FundamentalScoreService(),
       _combinedScoreService =
           combinedScoreService ?? const CombinedScoreService(),
       _confidenceScoreService =
           confidenceScoreService ?? const ConfidenceScoreService();

  Future<CompanyComparison> loadCompany(String symbol) async {
    final String ticker = symbol.trim().toUpperCase();

    if (ticker.isEmpty) {
      throw ArgumentError('Тикер компании не указан.');
    }

    final StockQuote quote = await _stockService.fetchQuote(
      ticker,
      forceRefresh: true,
    );

    final CompanyProfile profile = await _profileService.fetchProfile(ticker);

    final HistoricalPriceAnalysis historical = await _historicalPriceService
        .fetchAnalysis(ticker, days: 90);

    final FundamentalData fundamentals = await _fundamentalService
        .fetchFundamentals(ticker);

    final InvestMindScoreResult technicalScore = _technicalScoreService
        .calculate(
          currentPrice: quote.currentPrice,
          movingAverage20: historical.movingAverage20,
          movingAverage50: historical.movingAverage50,
          volatilityPercent: historical.annualizedVolatilityPercent,
          maxDrawdownPercent: historical.maxDrawdownPercent,
          trendStrengthPercent: historical.trendStrengthPercent,
          trendSlopePercentPerDay: historical.trendSlopePercentPerDay,
        );

    final FundamentalScoreResult fundamentalScore = _fundamentalScoreService
        .calculate(fundamentals, industry: profile.industry);

    final CombinedScoreResult combinedScore = _combinedScoreService.calculate(
      technical: technicalScore,
      fundamental: fundamentalScore,
      fundamentalData: fundamentals,
    );

    final ConfidenceScoreResult confidenceScore = _confidenceScoreService
        .calculate(
          fundamentals: fundamentals,
          historical: historical,
          combinedScore: combinedScore,
        );

    return CompanyComparison(
      symbol: ticker,
      companyName: profile.name,
      industry: profile.industry,
      investMindScore: combinedScore.score,
      technicalScore: technicalScore.score,
      fundamentalScore: fundamentalScore.score,
      growthScore: fundamentalScore.growthScore,
      profitabilityScore: fundamentalScore.profitabilityScore,
      valuationScore: fundamentalScore.valuationScore,
      financialHealthScore: fundamentalScore.financialHealthScore,
      riskScore: fundamentalScore.riskScore,
      confidenceScore: confidenceScore.score,
      dataCompletenessPercent: fundamentals.dataCompletenessPercent,
    );
  }

  Future<List<CompanyComparison>> compareCompanies(List<String> symbols) async {
    final List<String> normalizedSymbols = symbols
        .map((symbol) => symbol.trim().toUpperCase())
        .where((symbol) => symbol.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedSymbols.length < 2) {
      throw ArgumentError(
        'Для сравнения нужно выбрать '
        'минимум 2 компании.',
      );
    }

    if (normalizedSymbols.length > 4) {
      throw ArgumentError(
        'Одновременно можно сравнивать '
        'не более 4 компаний.',
      );
    }

    final List<CompanyComparison> result = [];

    // Загружаем последовательно, чтобы не создавать
    // резкий пакет запросов к Finnhub.
    for (final String symbol in normalizedSymbols) {
      final CompanyComparison company = await loadCompany(symbol);

      result.add(company);
    }

    return result;
  }
}
