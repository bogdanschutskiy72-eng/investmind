import 'dart:async';

import 'package:http/http.dart' as http;

class FinnhubHttpClient {
  FinnhubHttpClient._();

  static final FinnhubHttpClient instance = FinnhubHttpClient._();

  static const Duration _minimumRequestInterval = Duration(milliseconds: 1200);

  static const Duration _requestTimeout = Duration(seconds: 15);

  static const int _maxAttempts = 2;

  DateTime? _lastRequestAt;

  Future<void> _requestQueue = Future<void>.value();

  Future<http.Response> get(Uri uri) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await _rateLimitedGet(uri);

        final temporaryError =
            response.statusCode == 429 || response.statusCode >= 500;

        if (temporaryError && attempt < _maxAttempts) {
          final delay = response.statusCode == 429
              ? const Duration(seconds: 4)
              : const Duration(seconds: 2);

          await Future<void>.delayed(delay);

          continue;
        }

        return response;
      } on TimeoutException catch (error) {
        lastError = error;

        if (attempt < _maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 2));

          continue;
        }
      } on http.ClientException catch (error) {
        lastError = error;

        if (attempt < _maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 2));

          continue;
        }
      }
    }

    if (lastError is TimeoutException) {
      throw lastError;
    }

    if (lastError is http.ClientException) {
      throw lastError;
    }

    throw Exception('Не удалось получить данные Finnhub.');
  }

  Future<http.Response> _rateLimitedGet(Uri uri) {
    final completer = Completer<http.Response>();

    _requestQueue = _requestQueue
        .then((_) async {
          try {
            final lastRequest = _lastRequestAt;

            if (lastRequest != null) {
              final elapsed = DateTime.now().difference(lastRequest);

              final remaining = _minimumRequestInterval - elapsed;

              if (remaining > Duration.zero) {
                await Future<void>.delayed(remaining);
              }
            }

            _lastRequestAt = DateTime.now();

            final response = await http.get(uri).timeout(_requestTimeout);

            completer.complete(response);
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        })
        .catchError((_) {
          // Ошибка одного запроса не должна
          // ломать очередь следующих запросов.
        });

    return completer.future;
  }
}
