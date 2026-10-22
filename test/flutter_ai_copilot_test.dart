import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ai_copilot/flutter_ai_copilot.dart';

void main() {
  group('Models & Serialization Tests', () {
    test('AiMessage serialization and role conversion', () {
      final msg = AiMessage.user('Hello AI!', attachments: [
        AiAttachment(
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      ]);

      expect(msg.role, AiRole.user);
      expect(msg.content, 'Hello AI!');
      expect(msg.attachments.length, 1);
      expect(msg.attachments.first.base64Data, isNotNull);

      final json = msg.toJson();
      expect(json['role'], 'user');
      expect(json['content'], 'Hello AI!');
      expect(json['attachments'], isNotEmpty);

      final decoded = AiMessage.fromJson(json);
      expect(decoded.content, 'Hello AI!');
      expect(decoded.role, AiRole.user);
    });

    test('AiTool schema generation for Gemini and OpenAI', () {
      final tool = AiTool(
        name: 'get_stock_price',
        description: 'Retrieves real-time stock quotes',
        parameters: {
          'type': 'object',
          'properties': {
            'ticker': {
              'type': 'string',
              'description': 'Ticker symbol e.g. AAPL',
            },
            'exchange': {
              'type': 'string',
              'description': 'Exchange code',
            },
          },
          'required': ['ticker'],
        },
        handler: (args) async => {'price': 185.50},
      );

      final openAiFormat = tool.toOpenAiTool();
      expect(openAiFormat['type'], 'function');
      final functionMap = openAiFormat['function'] as Map<String, dynamic>;
      expect(functionMap['name'], 'get_stock_price');
      expect(functionMap['parameters']['required'], contains('ticker'));

      final geminiFormat = tool.toGeminiDeclaration();
      expect(geminiFormat['name'], 'get_stock_price');
      expect(geminiFormat['parameters']['type'], 'object');
    });
  });

  group('Provider & Streaming Tests', () {
    test('MockAiProvider streams tokens properly', () async {
      final provider =
          MockAiProvider(tokenDelay: const Duration(milliseconds: 1));
      final messages = [AiMessage.user('Explain Flutter')];

      final buffer = StringBuffer();
      await for (final token in provider.streamMessage(messages: messages)) {
        buffer.write(token);
      }

      expect(buffer.toString(), isNotEmpty);
      expect(buffer.toString(), contains('Flutter'));
    });

    test('MockAiProvider handles tool calling request', () async {
      final provider =
          MockAiProvider(tokenDelay: const Duration(milliseconds: 1));
      final tool = AiTool(
        name: 'check_weather',
        description: 'Check weather',
        parameters: {},
        handler: (args) async => {'temp': 22},
      );

      final response = await provider.sendMessage(
        messages: [AiMessage.user('What is the weather in SF?')],
        tools: [tool],
      );

      expect(response.toolCalls, isNotNull);
      expect(response.toolCalls.length, 1);
      expect(response.toolCalls.first.name, 'check_weather');
    });
  });

  group('AiChatController Tests', () {
    test('Controller handles user messages and mock streaming', () async {
      final controller = AiChatController(
        provider: MockAiProvider(tokenDelay: const Duration(milliseconds: 1)),
      );

      expect(controller.messages.isEmpty, true);

      final sendFuture = controller.sendMessage('Hello');
      expect(controller.isGenerating, true);

      await sendFuture;
      expect(controller.isGenerating, false);
      expect(controller.messages.length, 2);
      expect(controller.messages.first.role, AiRole.user);
      expect(controller.messages.last.role, AiRole.assistant);
      expect(controller.messages.last.content, isNotEmpty);

      // Test clearing history
      controller.clearHistory();
      expect(controller.messages.isEmpty, true);
    });

    test('Controller executes tool loop autonomously', () async {
      var toolExecuted = false;

      final weatherTool = AiTool(
        name: 'check_weather',
        description: 'Checks current weather',
        parameters: {},
        handler: (args) async {
          toolExecuted = true;
          return {
            'city': 'San Francisco',
            'temperature': '18°C',
            'condition': 'Sunny'
          };
        },
      );

      final controller = AiChatController(
        provider: MockAiProvider(tokenDelay: const Duration(milliseconds: 1)),
        tools: [weatherTool],
      );

      await controller.sendMessage('What is the weather today?');

      expect(toolExecuted, true);
      // Tool message and synthesized follow-up assistant message
      expect(controller.messages.any((m) => m.role == AiRole.tool), true);
    });
  });

  group('Widget & UI Tests', () {
    testWidgets('AiChatView renders empty state and suggested prompts',
        (tester) async {
      final controller = AiChatController(
        provider: MockAiProvider(tokenDelay: const Duration(milliseconds: 1)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiChatView(
              controller: controller,
              title: 'Test Assistant',
              suggestedPrompts: const ['Show Demo', 'Help Me'],
            ),
          ),
        ),
      );

      expect(find.text('Test Assistant'), findsOneWidget);
      expect(find.text('Show Demo'), findsOneWidget);
      expect(find.text('Help Me'), findsOneWidget);
    });

    testWidgets('AiCopilotFab renders and responds to tap', (tester) async {
      final controller = AiChatController(
        provider: MockAiProvider(tokenDelay: const Duration(milliseconds: 1)),
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: AiCopilotFab(
              controller: controller,
              customOnPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(AiCopilotFab), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(tapped, true);
    });

    testWidgets('AiMessageBubble renders markdown with code block',
        (tester) async {
      final message =
          AiMessage.assistant('Hello world\n\n```dart\nint x = 1;\n```\n');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiMessageBubble(
              message: message,
              theme: AiChatTheme.dark(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello world'), findsWidgets);
      expect(find.byType(CodeBlockWidget), findsOneWidget);
      expect(find.textContaining('int x = 1;'), findsWidgets);
      expect(find.text('DART'), findsOneWidget);
    });

    testWidgets(
        'AiMessageBubble renders complex markdown and streaming updates',
        (tester) async {
      final message = AiMessage.assistant(
        'Here is an explanation:\n'
        '- Item 1\n'
        '- Item 2\n\n'
        '```\ngeneric code\n```\n\n'
        'Check `inline code` and [Google](https://google.com).',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiMessageBubble(
                message: message,
                theme: AiChatTheme.dark(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Here is an explanation:'), findsWidgets);
      expect(find.textContaining('generic code'), findsWidgets);
    });
  });
}
