import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/ai_tool.dart';

/// Base event representation of an intent dispatched by the AI Copilot.
abstract class AiAppIntent {
  final String action;
  final DateTime timestamp;

  AiAppIntent({required this.action, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

/// Dispatched when the AI requests navigating to a specific screen/route.
class NavigationIntent extends AiAppIntent {
  final String routeName;
  final Map<String, dynamic>? arguments;

  NavigationIntent({
    required this.routeName,
    this.arguments,
  }) : super(action: 'navigation');
}

/// Dispatched when the AI executes an arbitrary app command.
class CustomAppIntent extends AiAppIntent {
  final Map<String, dynamic> payload;

  CustomAppIntent({
    required super.action,
    required this.payload,
  });
}

/// Central bi-directional event bus bridging AI tool calls to Flutter app state & navigation.
class AiActionBus {
  static final AiActionBus _instance = AiActionBus._internal();
  static AiActionBus get instance => _instance;

  AiActionBus._internal();

  final StreamController<AiAppIntent> _controller =
      StreamController<AiAppIntent>.broadcast();

  /// Stream of all incoming intents.
  Stream<AiAppIntent> get stream => _controller.stream;

  /// Dispatches an intent to all active listeners.
  void dispatch(AiAppIntent intent) {
    if (!_controller.isClosed) {
      _controller.add(intent);
    }
  }

  /// Listens specifically for intents of type [T].
  StreamSubscription<T> on<T extends AiAppIntent>(
      void Function(T event) onData) {
    return _controller.stream.where((e) => e is T).cast<T>().listen(onData);
  }

  /// Helper factory creating a ready-to-use navigation tool connected to your app's [NavigatorState].
  static AiTool createNavigationTool(GlobalKey<NavigatorState> navigatorKey) {
    return AiTool(
      name: 'navigate_to_screen',
      description:
          'Navigates the user to another screen or route in the application.',
      parameters: const {
        'type': 'object',
        'properties': {
          'routeName': {
            'type': 'string',
            'description': 'Target route name, e.g. /settings, /cart, /profile',
          },
        },
        'required': ['routeName'],
      },
      handler: (arguments) async {
        final route = arguments['routeName'] as String?;
        if (route == null)
          return {'success': false, 'error': 'Missing routeName'};

        final nav = navigatorKey.currentState;
        if (nav != null) {
          nav.pushNamed(route);
          instance.dispatch(NavigationIntent(routeName: route));
          return {'success': true, 'destination': route};
        } else {
          return {'success': false, 'error': 'Navigator state not available'};
        }
      },
    );
  }
}
