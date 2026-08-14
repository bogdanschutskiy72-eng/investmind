import 'fundamental_score_service.dart';
import 'fundamental_service.dart';
import 'investmind_score_service.dart';

class CombinedScoreResult {
  final int score;

  final int technicalScore;
  final int fundamentalScore;

  final double technicalWeight;
  final double fundamentalWeight;

  final int fundamentalDataCompleteness;

  final String rating;

  const CombinedScoreResult({
    required this.score,
    required this.technicalScore,
    required this.fundamentalScore,
    required this.technicalWeight,
    required this.fundamentalWeight,
    required this.fundamentalDataCompleteness,
    required this.rating,
  });
}

class CombinedScoreService {
  const CombinedScoreService();

  CombinedScoreResult calculate({
    required InvestMindScoreResult technical,
    required FundamentalScoreResult fundamental,
    required FundamentalData fundamentalData,
  }) {
    final int completeness = fundamentalData.dataCompletenessPercent;

    final double fundamentalWeight = _fundamentalWeightFor(completeness);

    final double technicalWeight = 1.0 - fundamentalWeight;

    final double weightedScore =
        technical.score * technicalWeight +
        fundamental.score * fundamentalWeight;

    final int score = weightedScore.round().clamp(0, 100);

    return CombinedScoreResult(
      score: score,
      technicalScore: technical.score,
      fundamentalScore: fundamental.score,
      technicalWeight: technicalWeight,
      fundamentalWeight: fundamentalWeight,
      fundamentalDataCompleteness: completeness,
      rating: _ratingFor(score),
    );
  }

  double _fundamentalWeightFor(int completeness) {
    if (completeness >= 85) {
      return 0.60;
    }

    if (completeness >= 70) {
      return 0.57;
    }

    if (completeness >= 55) {
      return 0.53;
    }

    if (completeness >= 40) {
      return 0.50;
    }

    return 0.45;
  }

  String _ratingFor(int score) {
    if (score >= 80) {
      return 'Сильная общая картина';
    }

    if (score >= 65) {
      return 'Выше среднего';
    }

    if (score >= 50) {
      return 'Нейтральная картина';
    }

    if (score >= 35) {
      return 'Ниже среднего';
    }

    return 'Повышенный риск';
  }
}
