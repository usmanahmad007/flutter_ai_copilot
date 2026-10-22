import 'dart:async';
import 'stream_metrics.dart';

/// A frame-synchronized (60/120 FPS) token batching buffer that prevents UI jank
/// during high-speed LLM text generation by coalescing rapid chunks into single display updates.
class FrameSyncedStreamBuffer {
  final Duration frameInterval;
  final void Function(
      String accumulatedText, String delta, AiStreamMetrics metrics) onUpdate;
  final void Function(AiStreamMetrics metrics)? onDone;

  final StringBuffer _accumulatedBuffer = StringBuffer();
  final StringBuffer _frameDeltaBuffer = StringBuffer();
  Timer? _flushTimer;
  bool _isClosed = false;

  late final AiStreamMetrics _metrics;

  FrameSyncedStreamBuffer({
    this.frameInterval = const Duration(milliseconds: 16), // ~60fps smooth sync
    required this.onUpdate,
    this.onDone,
  }) {
    _metrics = AiStreamMetrics();
  }

  /// Current metrics for this streaming session.
  AiStreamMetrics get metrics => _metrics;

  /// Current full accumulated text.
  String get currentText => _accumulatedBuffer.toString();

  /// Ingests a new incoming token chunk.
  void add(String chunk) {
    if (_isClosed || chunk.isEmpty) return;

    _metrics.recordChunk(chunk);
    _accumulatedBuffer.write(chunk);
    _frameDeltaBuffer.write(chunk);

    // Schedule flush on the next display frame if not already scheduled
    _flushTimer ??= Timer(frameInterval, _flush);
  }

  /// Flushes buffered frame delta immediately to the UI listener.
  void _flush() {
    _flushTimer = null;
    if (_frameDeltaBuffer.isEmpty) return;

    final delta = _frameDeltaBuffer.toString();
    _frameDeltaBuffer.clear();

    onUpdate(_accumulatedBuffer.toString(), delta, _metrics);
  }

  /// Closes the buffer, immediately flushes any pending tokens, and triggers [onDone].
  void close() {
    if (_isClosed) return;
    _isClosed = true;

    _flushTimer?.cancel();
    _flushTimer = null;

    if (_frameDeltaBuffer.isNotEmpty) {
      _flush();
    }

    _metrics.finish();
    onDone?.call(_metrics);
  }

  /// Cancels generation and stops timers.
  void cancel() {
    _isClosed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    _frameDeltaBuffer.clear();
  }
}
