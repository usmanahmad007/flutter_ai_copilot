/// Model configuration parameters.
class AiModelConfig {
  /// The LLM model name (e.g. `gemini-1.5-flash`, `gpt-4o`, `llama3`).
  final String modelName;

  /// Sampling temperature (0.0 = deterministic, 1.0 = creative).
  final double temperature;

  /// Top-p nucleus sampling.
  final double? topP;

  /// Maximum tokens to generate.
  final int? maxTokens;

  /// System instructions defining assistant personality, domain rules, and boundaries.
  final String? systemPrompt;

  /// Additional custom provider options.
  final Map<String, dynamic> extra;

  const AiModelConfig({
    required this.modelName,
    this.temperature = 0.7,
    this.topP,
    this.maxTokens = 2048,
    this.systemPrompt,
    this.extra = const {},
  });

  AiModelConfig copyWith({
    String? modelName,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? systemPrompt,
    Map<String, dynamic>? extra,
  }) =>
      AiModelConfig(
        modelName: modelName ?? this.modelName,
        temperature: temperature ?? this.temperature,
        topP: topP ?? this.topP,
        maxTokens: maxTokens ?? this.maxTokens,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        extra: extra ?? this.extra,
      );
}

/// Unified response from an AI provider.
class AiResponse {
  final String content;
  final List<dynamic> toolCalls;
  final Map<String, dynamic>? usage;

  const AiResponse({
    required this.content,
    this.toolCalls = const [],
    this.usage,
  });
}
