import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('AI Copilot Demo app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AiCopilotDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('Flutter AI Copilot'), findsWidgets);
    expect(find.text('Full Chatbot'), findsOneWidget);
    expect(find.text('In-App Copilot Demo'), findsOneWidget);
  });
}
