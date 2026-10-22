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

  group('Enterprise Pillars - Streaming & Telemetry Tests', () {
    test('AiStreamMetrics computes TTFT, duration, and speed', () async {
      final metrics = AiStreamMetrics();
      await Future.delayed(const Duration(milliseconds: 10));
      metrics.recordChunk('Hello ');
      metrics.recordChunk('world! ');
      metrics.recordChunk('Flutter AI Copilot.');
      metrics.finish();

      expect(metrics.totalChunks, 3);
      expect(metrics.totalCharacters, greaterThan(20));
      expect(metrics.timeToFirstToken, isNotNull);
      expect(metrics.timeToFirstToken!.inMicroseconds, greaterThan(0));
      expect(metrics.totalTokens, greaterThan(0));
      expect(metrics.tokensPerSecond, greaterThan(0.0));
    });

    test('FrameSyncedStreamBuffer batches chunks and flushes on close',
        () async {
      String latestAccumulated = '';
      AiStreamMetrics? finalMetrics;

      final buffer = FrameSyncedStreamBuffer(
        frameInterval: const Duration(milliseconds: 20),
        onUpdate: (accumulated, delta, metrics) {
          latestAccumulated = accumulated;
        },
        onDone: (metrics) {
          finalMetrics = metrics;
        },
      );

      buffer.add('Part 1, ');
      buffer.add('Part 2, ');
      buffer.add('Part 3.');
      buffer.close();

      expect(latestAccumulated, 'Part 1, Part 2, Part 3.');
      expect(finalMetrics, isNotNull);
      expect(finalMetrics!.totalChunks, 3);
    });
  });

  group('Enterprise Pillars - Screen Context & Action Bus Tests', () {
    test('AiScreenContext serializes and formats prompt context', () {
      const context = AiScreenContext(
        routeName: '/checkout',
        title: 'Cart Checkout Screen',
        properties: {'cartTotal': 149.99, 'itemsCount': 3},
        visibleContent: ['Promo Code applied: SAVE10', 'Shipping: Free'],
        screenSpecificTools: ['apply_discount', 'place_order'],
      );

      final prompt = context.toPromptContext();
      expect(prompt, contains('[ACTIVE SCREEN CONTEXT]'));
      expect(prompt, contains('Route: /checkout'));
      expect(prompt, contains('Cart Checkout Screen'));
      expect(prompt, contains('cartTotal'));
      expect(prompt, contains('SAVE10'));
      expect(prompt, contains('apply_discount'));

      final json = context.toJson();
      final decoded = AiScreenContext.fromJson(json);
      expect(decoded.routeName, '/checkout');
      expect(decoded.title, 'Cart Checkout Screen');
      expect(decoded.properties['cartTotal'], 149.99);
      expect(decoded.visibleContent.length, 2);
    });

    test('AiActionBus dispatches navigation and custom app intents', () async {
      final bus = AiActionBus.instance;
      AiAppIntent? receivedIntent;

      final sub = bus.stream.listen((intent) {
        receivedIntent = intent;
      });

      bus.dispatch(
          NavigationIntent(routeName: '/profile', arguments: const {'id': 42}));
      await Future.delayed(Duration.zero);
      expect(receivedIntent, isA<NavigationIntent>());
      final nav = receivedIntent as NavigationIntent;
      expect(nav.routeName, '/profile');
      expect(nav.arguments?['id'], 42);

      bus.dispatch(CustomAppIntent(
        action: 'refresh_cart',
        payload: const {'reason': 'ai_applied_coupon'},
      ));
      await Future.delayed(Duration.zero);
      expect(receivedIntent, isA<CustomAppIntent>());
      final custom = receivedIntent as CustomAppIntent;
      expect(custom.action, 'refresh_cart');
      expect(custom.payload['reason'], 'ai_applied_coupon');

      sub.cancel();
    });
  });

  group('Enterprise Pillars - Human-in-the-Loop Security & Storage Tests', () {
    test('Controller pauses on sensitive tool and resumes on approval',
        () async {
      bool transferExecuted = false;

      final sensitiveTool = AiTool(
        name: 'transfer_funds',
        description: 'Transfers money between accounts',
        executionMode: AiToolExecutionMode.requiresApproval,
        riskLevel: AiToolRiskLevel.high,
        confirmationMessage: (args) =>
            'Transfer \$${args['amount']} to ${args['recipient']}?',
        parameters: {
          'type': 'object',
          'properties': {
            'amount': {'type': 'number'},
            'recipient': {'type': 'string'},
          },
          'required': ['amount', 'recipient'],
        },
        handler: (args) async {
          transferExecuted = true;
          return {'success': true, 'txId': 'TX_998811'};
        },
      );

      final controller = AiChatController(
        provider: MockAiProvider(tokenDelay: const Duration(milliseconds: 1)),
        tools: [sensitiveTool],
      );

      // Simulate a tool call message directly
      final pendingCall = AiToolCall(
        id: 'call_tx_1',
        name: 'transfer_funds',
        arguments: {'amount': 500, 'recipient': 'Alice'},
        status: AiToolCallStatus.pendingApproval,
        riskLevel: 'high',
      );
      final assistantMsg = AiMessage(
        role: AiRole.assistant,
        content: 'I need your permission to proceed with this transfer.',
        toolCalls: [pendingCall],
      );

      controller.addMessage(assistantMsg);
      expect(controller.hasPendingApproval, true);
      expect(transferExecuted, false);

      // Approve call
      await controller.approveToolCall('call_tx_1');
      expect(transferExecuted, true);
      expect(pendingCall.status, AiToolCallStatus.completed);
      expect(controller.hasPendingApproval, false);
      expect(controller.messages.any((m) => m.role == AiRole.tool), true);
    });

    test('Controller handles user rejection with reason', () async {
      final sensitiveTool = AiTool(
        name: 'delete_account',
        description: 'Deletes user account permanently',
        executionMode: AiToolExecutionMode.requiresApproval,
        riskLevel: AiToolRiskLevel.high,
        parameters: {},
        handler: (args) async => {'deleted': true},
      );

      final controller = AiChatController(
        provider: MockAiProvider(tokenDelay: const Duration(milliseconds: 1)),
        tools: [sensitiveTool],
      );

      final pendingCall = AiToolCall(
        id: 'call_del_1',
        name: 'delete_account',
        arguments: {},
        status: AiToolCallStatus.pendingApproval,
      );
      final assistantMsg = AiMessage(
        role: AiRole.assistant,
        content: 'Are you sure you want to delete your account?',
        toolCalls: [pendingCall],
      );

      controller.addMessage(assistantMsg);
      expect(controller.hasPendingApproval, true);

      // Reject call
      await controller.rejectToolCall('call_del_1',
          reason: 'User cancelled operation');
      expect(pendingCall.status, AiToolCallStatus.rejected);
      expect(pendingCall.rejectionReason, 'User cancelled operation');
      expect(controller.hasPendingApproval, false);
    });

    test('InMemoryStorageEngine manages multi-turn sessions', () async {
      final storage = InMemoryStorageEngine();
      final session = AiChatSession(
        id: 'test_session_1',
        title: 'Enterprise Architecture Consultation',
        messages: [
          AiMessage.user('Explain zero-jank frame-synced streaming'),
          AiMessage.assistant('It uses a 60/120 FPS batching buffer...'),
        ],
      );

      await storage.saveSession(session);
      final loaded = await storage.loadSession('test_session_1');
      expect(loaded, isNotNull);
      expect(loaded!.title, 'Enterprise Architecture Consultation');
      expect(loaded.messages.length, 2);

      final list = await storage.listSessions();
      expect(list.length, 1);
      expect(list.first.id, 'test_session_1');

      await storage.deleteSession('test_session_1');
      final afterDelete = await storage.loadSession('test_session_1');
      expect(afterDelete, isNull);
    });
  });
}
