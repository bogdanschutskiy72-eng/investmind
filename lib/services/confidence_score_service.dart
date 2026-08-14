import 'combined_score_service.dart';
import 'fundamental_service.dart';
import 'historical_price_service.dart';

class ConfidenceScoreResult {
  final int score;
  final String rating;
  final List<String> reasons;

  const ConfidenceScoreResult({
    required this.score,
    required this.rating,
    required this.reasons,
  });
}

class ConfidenceScoreService {
  const ConfidenceScoreService();

  ConfidenceScoreResult calculate({
    required FundamentalData fundamentals,
    required HistoricalPriceAnalysis historical,
    required CombinedScoreResult combinedScore,
  }) {
    int score = 0;

    final List<String> reasons = [];

    // ------------------------------------------------------------
    // 1. Полнота фундаментальных данных
    // Главный фактор Confidence.
    // Максимум: 60 баллов.
    // ------------------------------------------------------------

    final int completeness = fundamentals.dataCompletenessPercent;

    final int completenessPoints = (completeness * 0.60).round();

    score += completenessPoints;

    if (completeness >= 90) {
      reasons.add('Очень высокая полнота фундаментальных данных.');
    } else if (completeness >= 75) {
      reasons.add('Высокая полнота фундаментальных данных.');
    } else if (completeness >= 60) {
      reasons.add('Средняя полнота фундаментальных данных.');
    } else if (completeness >= 40) {
      reasons.add('Фундаментальные данные заметно ограничены.');
    } else {
      reasons.add('Низкая полнота фундаментальных данных.');
    }

    // ------------------------------------------------------------
    // 2. Полнота технической картины
    // Максимум: 20 баллов.
    // ------------------------------------------------------------

    int technicalDataPoints = 0;

    if (historical.movingAverage20 > 0) {
      technicalDataPoints++;
    }

    if (historical.movingAverage50 > 0) {
      technicalDataPoints++;
    }

    if (historical.annualizedVolatilityPercent > 0) {
      technicalDataPoints++;
    }

    if (historical.maxDrawdownPercent >= 0) {
      technicalDataPoints++;
    }

    if (historical.trendStrengthPercent >= 0) {
      technicalDataPoints++;
    }

    // Нулевой slope может быть реальным значением,
    // поэтому считаем его доступным.
    technicalDataPoints++;

    if (technicalDataPoints >= 6) {
      score += 20;

      reasons.add('Техническая картина представлена полностью.');
    } else if (technicalDataPoints >= 5) {
      score += 16;

      reasons.add('Технические данные почти полностью доступны.');
    } else if (technicalDataPoints >= 4) {
      score += 12;

      reasons.add('Большая часть технических данных доступна.');
    } else if (technicalDataPoints >= 2) {
      score += 6;

      reasons.add('Технические данные представлены частично.');
    } else {
      reasons.add('Технических данных недостаточно.');
    }

    // ------------------------------------------------------------
    // 3. Согласованность Technical и Fundamental
    // Максимум: 15 баллов.
    //
    // Согласованность повышает уверенность,
    // но не должна перекрывать недостаток данных.
    // ------------------------------------------------------------

    final int scoreDifference =
        (combinedScore.technicalScore - combinedScore.fundamentalScore).abs();

    if (scoreDifference <= 8) {
      score += 15;

      reasons.add('Technical и Fundamental оценки хорошо согласуются.');
    } else if (scoreDifference <= 15) {
      score += 10;

      reasons.add('Technical и Fundamental оценки в целом согласуются.');
    } else if (scoreDifference <= 25) {
      score += 5;

      reasons.add('Между Technical и Fundamental есть умеренный разрыв.');
    } else {
      reasons.add(
        'Technical и Fundamental оценки заметно противоречат друг другу.',
      );
    } // ------------------------------------------------------------
    // 4. Наличие ключевых метрик
    // Максимум: +5.
    // Штрафы при серьёзных пробелах.
    // ------------------------------------------------------------

    final int missingCount = fundamentals.missingCoreMetrics.length;

    if (missingCount == 0) {
      score += 5;

      reasons.add('Все ключевые фундаментальные показатели доступны.');
    } else if (missingCount <= 2) {
      score += 2;

      reasons.add('Отсутствует небольшая часть ключевых показателей.');
    } else if (missingCount <= 4) {
      reasons.add('Несколько ключевых показателей отсутствуют.');
    } else if (missingCount <= 6) {
      score -= 5;

      reasons.add('Заметная часть ключевых показателей отсутствует.');
    } else {
      score -= 10;

      reasons.add('Многие ключевые показатели отсутствуют.');
    }

    // ------------------------------------------------------------
    // 5. Ограничение максимального Confidence
    // по полноте фундаментальных данных.
    // ------------------------------------------------------------

    final int confidenceCap = _confidenceCapForCompleteness(completeness);

    if (score > confidenceCap) {
      score = confidenceCap;
    }

    score = score.clamp(0, 100);

    return ConfidenceScoreResult(
      score: score,
      rating: _ratingFor(score),
      reasons: reasons,
    );
  }

  int _confidenceCapForCompleteness(int completeness) {
    if (completeness >= 90) {
      return 95;
    }

    if (completeness >= 80) {
      return 88;
    }

    if (completeness >= 70) {
      return 78;
    }

    if (completeness >= 60) {
      return 70;
    }

    if (completeness >= 50) {
      return 62;
    }

    if (completeness >= 40) {
      return 55;
    }

    return 45;
  }

  String _ratingFor(int score) {
    if (score >= 90) {
      return 'Очень высокая достоверность';
    }

    if (score >= 75) {
      return 'Высокая достоверность';
    }

    if (score >= 60) {
      return 'Средняя достоверность';
    }

    if (score >= 45) {
      return 'Ограниченная достоверность';
    }

    return 'Низкая достоверность';
  }
}
