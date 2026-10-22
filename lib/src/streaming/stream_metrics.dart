/// Telemetry and real-time performance tracking for token streaming.
class AiStreamMetrics {
  final DateTime startTime;
  DateTime? firstTokenTime;
  DateTime? endTime;
  int totalCharacters = 0;
  int totalChunks = 0;

  AiStreamMetrics({DateTime? startTime})
      : startTime = startTime ?? DateTime.now();

  /// Records the receipt of a token chunk.
  void recordChunk(String chunk) {
    if (totalChunks == 0) {
      firstTokenTime = DateTime.now();
    }
    totalChunks++;
    totalCharacters += chunk.length;
  }

  /// Finalizes the stream session.
  void finish() {
    endTime = DateTime.now();
  }

  /// Time to First Token (TTFT) in milliseconds.
  Duration? get timeToFirstToken {
    if (firstTokenTime == null) return null;
    return firstTokenTime!.difference(startTime);
  }

  /// Total streaming duration.
  Duration get totalDuration {
    final finishTime = endTime ?? DateTime.now();
    return finishTime.difference(startTime);
  }

  /// Estimated tokens generated (heuristic: ~4 characters per token).
  int get estimatedTokens => (totalCharacters / 4).ceil();

  /// Total tokens alias.
  int get totalTokens => estimatedTokens;

  /// Speed in estimated tokens per second.
  double get tokensPerSecond {
    final duration = totalDuration;
    if (duration.inMilliseconds == 0) return 0.0;
    final seconds = duration.inMilliseconds / 1000.0;
    return estimatedTokens / seconds;
  }

  /// Speed in characters per second.
  double get charactersPerSecond {
    final duration = totalDuration;
    if (duration.inMilliseconds == 0) return 0.0;
    final seconds = duration.inMilliseconds / 1000.0;
    return totalCharacters / seconds;
  }

  /// Human-readable performance badge.
  String formatSummary() {
    final ttftMs = timeToFirstToken?.inMilliseconds ?? 0;
    final tps = tokensPerSecond.toStringAsFixed(1);
    final tokens = estimatedTokens;
    return '⚡ $tps tokens/s • TTFT: ${ttftMs}ms • $tokens tokens';
  }

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'firstTokenTime': firstTokenTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'timeToFirstTokenMs': timeToFirstToken?.inMilliseconds,
        'totalDurationMs': totalDuration.inMilliseconds,
        'totalCharacters': totalCharacters,
        'estimatedTokens': estimatedTokens,
        'tokensPerSecond': tokensPerSecond,
      };
}
