import 'fundamental_score_service.dart';
import 'investmind_score_service.dart';

class CombinedScoreResult {
  final int score;
  final int technicalScore;
  final int fundamentalScore;

  final double technicalWeight;
  final double fundamentalWeight;

  final String rating;

  const CombinedScoreResult({
    required this.score,
    required this.technicalScore,
    required this.fundamentalScore,
    required this.technicalWeight,
    required this.fundamentalWeight,
    required this.rating,
  });
}

class CombinedScoreService {
  const CombinedScoreService();

  CombinedScoreResult calculate({
    required InvestMindScoreResult technical,
    required FundamentalScoreResult fundamental,
  }) {
    const double technicalWeight = 0.40;
    const double fundamentalWeight = 0.60;

    final double weightedScore =
        technical.score * technicalWeight +
        fundamental.score * fundamentalWeight;

    final int score =
        weightedScore.round().clamp(0, 100);

    return CombinedScoreResult(
      score: score,
      technicalScore: technical.score,
      fundamentalScore: fundamental.score,
      technicalWeight: technicalWeight,
      fundamentalWeight: fundamentalWeight,
      rating: _ratingFor(score),
    );
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