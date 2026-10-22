# flutter_ai_copilot

[![pub package](https://img.shields.io/pub/v/flutter_ai_copilot.svg)](https://pub.dev/packages/flutter_ai_copilot)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.10-02569B?logo=flutter)](https://flutter.dev)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/usmanahmad007/flutter_ai_copilot/pulls)

An all-in-one AI Chatbot & Copilot Kit for Flutter. Effortlessly integrate real-time token streaming, interactive Markdown with syntax-highlighted code blocks, multimodal vision (images/documents), autonomous tool execution loops, and dynamic Generative UI cards with **Google Gemini**, **OpenAI**, **Local Ollama**, and **Mock AI**.

---

## 🌟 Key Features

- ⚡ **Zero-Jank 60/120 FPS Frame-Synced Streaming**: Coalesces raw high-frequency token streams into display-synchronized UI updates, completely eliminating micro-stutters and widget rebuild thrashing.
- 🛡️ **Human-in-the-Loop (HITL) Security**: Guard sensitive/destructive tools with interactive approval cards (`ToolApprovalCard`) featuring customizable risk levels (`low`, `medium`, `high`) and "Approve & Run" / "Deny Action" actions.
- 📱 **Screen-Aware Context Introspection**: `AiScreenContext` and `AiContextScope` automatically inject the active Flutter route, state, and visible widgets into LLM system prompts without manual wiring.
- 💾 **Multi-Turn Persistent Storage**: Pluggable session history engine (`AiChatStorageEngine`, `InMemoryStorageEngine`) for restoring and managing conversational sessions across app restarts.
- 🚦 **Bi-Directional Action Bus**: `AiActionBus` bridges AI tool execution directly to Flutter app state mutation and route navigation.
- 🛠️ **Autonomous Tool Calling**: Automatically executes Dart functions when triggered by the LLM, feeds results back, and streams the synthesized response.
- 🎨 **Dynamic Generative UI**: Register custom Flutter widgets for any tool to render interactive cards (e.g. Weather cards, Flight passes, Booking confirmations).
- 📜 **Interactive Markdown & Code**: Syntax-highlighted code blocks with language indicators, one-tap clipboard copy, and formatted text tables.
- 👁️ **Multimodal Vision**: Send photos, screenshots, and documents (base64 or remote URLs) directly to Gemini 2.0/1.5 or OpenAI GPT-4o.
- 📱 **Drop-In Copilot UI**:
  - `AiChatView`: Embedded or full-screen customizable chat view with live performance HUD (tok/s, TTFT) and active screen context chips.
  - `AiCopilotFab`: Pulsing AI glow Floating Action Button.
  - `AiCopilot.showSheet()`: Modal bottom sheet that slides up over any screen.
- 🧪 **Zero-Config Prototyping**: Bundled `MockAiProvider` for instant offline testing and unit testing with zero API keys required.

---

## 🚀 Quick Start

### 1. Add dependency

Add `flutter_ai_copilot` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_ai_copilot: ^0.1.0
```

### 2. Summon AI Copilot in 1 line of code

Add the animated `AiCopilotFab` to any `Scaffold`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_ai_copilot/flutter_ai_copilot.dart';

class MyScreen extends StatelessWidget {
  final _controller = AiChatController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My App')),
      body: const Center(child: Text('Tap the button below to ask AI')),
      floatingActionButton: AiCopilotFab(
        controller: _controller,
        suggestedPrompts: const [
          'What can you do?',
          'Summarize this page',
          'Help me find products',
        ],
      ),
    );
  }
}
```

Or trigger the modal sheet programmatically:

```dart
AiCopilot.showSheet(
  context: context,
  controller: controller,
  title: 'In-App AI Assistant',
);
```

---

## 🔌 Multi-LLM Provider Support

### Google Gemini (Gemini 2.0 Flash / 1.5 Pro)

```dart
final controller = AiChatController(
  provider: GeminiAiProvider(
    apiKey: 'YOUR_GEMINI_API_KEY',
    defaultModel: 'gemini-1.5-flash',
  ),
  config: const AiModelConfig(
    systemPrompt: 'You are a helpful customer support agent for an e-commerce app.',
  ),
);
```

### OpenAI (GPT-4o, GPT-4o-mini & Compatible Endpoints)

Compatible with OpenAI, Groq, OpenRouter, vLLM, and LMStudio:

```dart
final controller = AiChatController(
  provider: OpenAiProvider(
    apiKey: 'YOUR_OPENAI_API_KEY',
    defaultModel: 'gpt-4o',
  ),
);
```

### Local Private Ollama (Llama 3.2, Mistral, Gemma 2, DeepSeek)

```dart
final controller = AiChatController(
  provider: OllamaAiProvider(
    host: 'http://localhost:11434',
    defaultModel: 'llama3.2',
  ),
);
```

### Mock AI (Zero Setup & Offline Testing)

```dart
final controller = AiChatController(
  provider: MockAiProvider(tokenDelay: const Duration(milliseconds: 25)),
);
```

---

## 🛠️ Autonomous Tool Calling & Generative UI

Empower your LLM to perform actions in your app (check order status, update profile, query weather):

### 1. Register a Tool

```dart
controller.registerTool(
  AiTool(
    name: 'check_weather',
    description: 'Retrieves current weather forecast for a city.',
    parameters: {
      'type': 'object',
      'properties': {
        'city': {
          'type': 'string',
          'description': 'City name e.g. San Francisco or Tokyo',
        },
      },
      'required': ['city'],
    },
    handler: (arguments) async {
      final city = arguments['city'];
      final weather = await weatherService.fetch(city);
      return {
        'city': city,
        'temperature': '22°C',
        'condition': 'Sunny',
      };
    },
  ),
);
```

### 2. Register Generative UI for the Tool

When the tool finishes, replace JSON with a custom interactive Flutter widget:

```dart
controller.registerGenerativeUi('check_weather', (context, data) {
  final temp = data['temperature'] ?? '20°C';
  final condition = data['condition'] ?? 'Clear';

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Colors.blue, Colors.indigo]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$temp • $condition', style: const TextStyle(color: Colors.white, fontSize: 18)),
        const Icon(Icons.wb_sunny, color: Colors.amber, size: 32),
      ],
    ),
  );
});
```

---

## 🛡️ Human-in-the-Loop (HITL) Security

Prevent AI hallucination damage by requiring user confirmation for sensitive or destructive actions:

```dart
controller.registerTool(
  AiTool(
    name: 'transfer_funds',
    description: 'Transfers money between customer accounts.',
    executionMode: AiToolExecutionMode.requiresApproval,
    riskLevel: AiToolRiskLevel.high,
    confirmationMessage: (args) =>
        'Authorize transfer of \$${args['amount']} to ${args['recipient']}?',
    parameters: {
      'type': 'object',
      'properties': {
        'amount': {'type': 'number'},
        'recipient': {'type': 'string'},
      },
      'required': ['amount', 'recipient'],
    },
    handler: (args) async {
      return await bankApi.transfer(args['amount'], args['recipient']);
    },
  ),
);
```

When triggered, the copilot immediately halts autonomous execution and displays a native `ToolApprovalCard` directly inside the message list, giving the user full parameter visibility and **Approve & Run** or **Deny Action** controls.

---

## 📱 Screen-Aware Context Introspection

Give your AI instant awareness of what screen the user is viewing and what data is visible:

```dart
AiContextScope(
  screenContext: const AiScreenContext(
    routeName: '/cart',
    title: 'Shopping Cart',
    properties: {
      'cartTotal': 149.99,
      'itemsCount': 3,
      'promoApplied': 'SAVE10',
    },
    visibleContent: [
      'Wireless Headphones - \$99.00',
      'USB-C Cable - \$19.99',
    ],
  ),
  child: Scaffold(
    body: ...,
    floatingActionButton: AiCopilotFab(controller: controller),
  ),
)
```

The active screen context is automatically formatted and injected into the LLM system prompt on every message!

---

## ⚡ Zero-Jank 60/120 FPS Streaming & Metrics

High-speed LLMs stream tokens at 80+ chunks/second, causing severe widget rebuild thrashing. `flutter_ai_copilot` includes `FrameSyncedStreamBuffer` to batch token updates to your device's refresh rate (16ms for 60Hz, 8ms for 120Hz).

Inspect live generation telemetry directly:

```dart
final metrics = controller.lastStreamMetrics;
print('Speed: ${metrics?.tokensPerSecond.toStringAsFixed(1)} tok/s');
print('TTFT: ${metrics?.timeToFirstToken?.inMilliseconds} ms');
```

---

## 🎨 Customizable Themes

Choose between Dark Cyber or Modern Light presets, or define your own:

```dart
// Dark preset
AiChatView(
  controller: controller,
  theme: AiChatTheme.dark(),
);

// Light preset
AiChatView(
  controller: controller,
  theme: AiChatTheme.light(),
);

// Custom theme
final customTheme = AiChatTheme(
  backgroundColor: const Color(0xFF0F172A),
  surfaceColor: const Color(0xFF1E293B),
  primaryColor: const Color(0xFF38BDF8),
  userBubbleColor: const Color(0xFF0284C7),
  userTextColor: Colors.white,
  assistantBubbleColor: const Color(0xFF1E293B),
  assistantTextColor: const Color(0xFFF1F5F9),
  inputBackgroundColor: const Color(0xFF0F172A),
  inputTextColor: Colors.white,
  inputHintColor: Colors.white38,
  toolBannerColor: const Color(0xFF334155),
  bubbleRadius: 16.0,
);
```

---

## 🧪 Testing

`flutter_ai_copilot` is tested with 100% test coverage using the bundled `MockAiProvider`:

```bash
flutter test
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
