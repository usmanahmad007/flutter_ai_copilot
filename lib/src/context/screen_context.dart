import 'dart:convert';
import 'package:flutter/widgets.dart';

/// Captures the runtime screen context, route, active state, and semantics
/// of the current Flutter screen to feed real-time context to the LLM.
class AiScreenContext {
  /// The current active route name, e.g. `/cart`, `/product/123`, `CheckoutScreen`.
  final String routeName;

  /// Human-readable screen title or description.
  final String? title;

  /// Key-value properties representing active screen state, form values, or data models.
  final Map<String, dynamic> properties;

  /// Text snippets or visible strings present on the screen.
  final List<String> visibleContent;

  /// Specific tool names that are only relevant or allowed on this screen.
  final List<String>? screenSpecificTools;

  const AiScreenContext({
    required this.routeName,
    this.title,
    this.properties = const {},
    this.visibleContent = const [],
    this.screenSpecificTools,
  });

  /// Creates a copy with optionally updated fields.
  AiScreenContext copyWith({
    String? routeName,
    String? title,
    Map<String, dynamic>? properties,
    List<String>? visibleContent,
    List<String>? screenSpecificTools,
  }) {
    return AiScreenContext(
      routeName: routeName ?? this.routeName,
      title: title ?? this.title,
      properties: properties ?? this.properties,
      visibleContent: visibleContent ?? this.visibleContent,
      screenSpecificTools: screenSpecificTools ?? this.screenSpecificTools,
    );
  }

  /// Formats this screen context into a markdown prompt block for the LLM system prompt.
  String toPromptContext() {
    final buffer = StringBuffer();
    buffer.writeln('[ACTIVE SCREEN CONTEXT]');
    buffer.writeln('- Route: $routeName');
    if (title != null && title!.isNotEmpty) {
      buffer.writeln('- Title: $title');
    }
    if (properties.isNotEmpty) {
      buffer.writeln('- Screen State: ${jsonEncode(properties)}');
    }
    if (visibleContent.isNotEmpty) {
      buffer.writeln('- Visible Elements: ${visibleContent.join(', ')}');
    }
    if (screenSpecificTools != null && screenSpecificTools!.isNotEmpty) {
      buffer
          .writeln('- Active Screen Tools: ${screenSpecificTools!.join(', ')}');
    }
    buffer.writeln('----------------------------------------');
    return buffer.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'routeName': routeName,
        if (title != null) 'title': title,
        if (properties.isNotEmpty) 'properties': properties,
        if (visibleContent.isNotEmpty) 'visibleContent': visibleContent,
        if (screenSpecificTools != null)
          'screenSpecificTools': screenSpecificTools,
      };

  factory AiScreenContext.fromJson(Map<String, dynamic> json) =>
      AiScreenContext(
        routeName: json['routeName'] as String? ?? 'unknown',
        title: json['title'] as String?,
        properties: (json['properties'] as Map<String, dynamic>?) ?? {},
        visibleContent:
            (json['visibleContent'] as List<dynamic>?)?.cast<String>() ?? [],
        screenSpecificTools:
            (json['screenSpecificTools'] as List<dynamic>?)?.cast<String>(),
      );

  static AiScreenContext? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AiContextScope>();
    return scope?.screenContext;
  }
}

/// InheritedWidget that provides [AiScreenContext] to descendent widgets.
class AiContextScope extends InheritedWidget {
  final AiScreenContext screenContext;

  const AiContextScope({
    super.key,
    required this.screenContext,
    required super.child,
  });

  @override
  bool updateShouldNotify(AiContextScope oldWidget) {
    return screenContext != oldWidget.screenContext;
  }
}

/// A NavigatorObserver that automatically tracks route transitions and notifies
/// the given callback or controller of the active route name.
class AiCopilotNavigatorObserver extends NavigatorObserver {
  final void Function(String routeName, Map<String, dynamic>? arguments)?
      onRouteChanged;

  AiCopilotNavigatorObserver({this.onRouteChanged});

  void _notify(Route<dynamic>? route) {
    if (route != null && route.settings.name != null) {
      final args = route.settings.arguments is Map<String, dynamic>
          ? route.settings.arguments as Map<String, dynamic>
          : null;
      onRouteChanged?.call(route.settings.name!, args);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _notify(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _notify(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _notify(newRoute);
  }
}
