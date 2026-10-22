import 'package:flutter/material.dart';
import 'package:flutter_ai_copilot/flutter_ai_copilot.dart';

void main() {
  runApp(const AiCopilotDemoApp());
}

class AiCopilotDemoApp extends StatefulWidget {
  const AiCopilotDemoApp({super.key});

  @override
  State<AiCopilotDemoApp> createState() => _AiCopilotDemoAppState();
}

class _AiCopilotDemoAppState extends State<AiCopilotDemoApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter AI Copilot Demo',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorSchemeSeed: const Color(0xFF6366F1),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorSchemeSeed: const Color(0xFF7C4DFF),
        useMaterial3: true,
      ),
      home: DemoHomeScreen(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class DemoHomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const DemoHomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  int _selectedTab = 0;
  late AiChatController _controller;
  String _currentProvider = 'mock';

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = AiChatController(
      provider: MockAiProvider(tokenDelay: const Duration(milliseconds: 30)),
      config: const AiModelConfig(
        modelName: 'gpt-4o',
        systemPrompt:
            'You are an intelligent in-app AI Copilot and assistant for Flutter apps.',
      ),
      tools: [
        // 1. Weather Tool
        AiTool(
          name: 'check_weather',
          description: 'Gets current weather conditions for a specified city.',
          parameters: {
            'type': 'object',
            'properties': {
              'city': {
                'type': 'string',
                'description':
                    'The name of the city, e.g. San Francisco or Tokyo',
              },
            },
            'required': ['city'],
          },
          handler: (args) async {
            final city = args['city'] ?? 'San Francisco';
            await Future.delayed(const Duration(milliseconds: 600));
            return {
              'city': city,
              'temperature': '21°C',
              'condition': 'Partly Cloudy',
              'humidity': '62%',
              'wind': '14 km/h',
            };
          },
        ),

        // 2. Flight Tool
        AiTool(
          name: 'search_flights',
          description: 'Searches available flights to a target destination.',
          parameters: {
            'type': 'object',
            'properties': {
              'destination': {
                'type': 'string',
                'description': 'Destination city code or name',
              },
            },
            'required': ['destination'],
          },
          handler: (args) async {
            final dest = args['destination'] ?? 'Tokyo';
            await Future.delayed(const Duration(milliseconds: 700));
            return {
              'destination': dest,
              'flightNumber': 'AC-782',
              'airline': 'SkyWings Express',
              'price': '\$480',
              'departure': '10:30 AM Tomorrow',
              'duration': '11h 20m Non-stop',
            };
          },
        ),

        // 3. Sensitive Financial Transfer Tool (Human-in-the-Loop Approval)
        AiTool(
          name: 'execute_secure_transfer',
          description:
              'Executes an authorized funds transfer to a designated contact.',
          executionMode: AiToolExecutionMode.requiresApproval,
          riskLevel: AiToolRiskLevel.high,
          confirmationMessage: (args) =>
              'Authorize transfer of \$${args['amount'] ?? 250} to recipient "${args['recipient'] ?? 'Alex Morgan'}"?',
          parameters: {
            'type': 'object',
            'properties': {
              'amount': {
                'type': 'number',
                'description': 'Transfer amount in USD',
              },
              'recipient': {
                'type': 'string',
                'description': 'Recipient name or account ID',
              },
            },
            'required': ['amount', 'recipient'],
          },
          handler: (args) async {
            await Future.delayed(const Duration(milliseconds: 900));
            return {
              'status': 'SUCCESSFUL',
              'transactionId': 'TX-94810284',
              'amount': args['amount'] ?? 250,
              'recipient': args['recipient'] ?? 'Alex Morgan',
              'timestamp': DateTime.now().toIso8601String(),
              'fee': '\$0.00 (Fee waived)',
            };
          },
        ),
      ],
    );

    // Register Generative UI for execute_secure_transfer
    _controller.registerGenerativeUi('execute_secure_transfer',
        (context, data) {
      final map = data is Map ? data : <String, dynamic>{};
      final txId = map['transactionId'] ?? 'TX-94810284';
      final amount = map['amount']?.toString() ?? '250';
      final recipient = map['recipient'] ?? 'Alex Morgan';

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF064E3B).withAlpha(140),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.greenAccent.withAlpha(160)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: Colors.greenAccent, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Transfer Confirmed: \$$amount',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Recipient: $recipient • Tx ID: $txId',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );
    });

    // Register Generative UI for check_weather
    _controller.registerGenerativeUi('check_weather', (context, data) {
      final map = data is Map ? data : <String, dynamic>{};
      final city = map['city'] ?? 'San Francisco';
      final temp = map['temperature'] ?? '20°C';
      final condition = map['condition'] ?? 'Clear';
      final humidity = map['humidity'] ?? '50%';
      final wind = map['wind'] ?? '10 km/h';

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withAlpha(80),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$city Live Weather',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      condition,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.wb_cloudy_rounded,
                  color: Colors.amberAccent,
                  size: 36,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  temp,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.water_drop_outlined,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(humidity,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.air, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(wind,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    });

    // Register Generative UI for search_flights
    _controller.registerGenerativeUi('search_flights', (context, data) {
      final map = data is Map ? data : <String, dynamic>{};
      final dest = map['destination'] ?? 'Tokyo';
      final flight = map['flightNumber'] ?? 'FL-101';
      final price = map['price'] ?? '\$450';
      final time = map['departure'] ?? 'Tomorrow';

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flight_takeoff,
                        color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Flight to $dest ($flight)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    price,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Departure: $time',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    });
  }

  void _switchProvider(String providerName) {
    setState(() => _currentProvider = providerName);

    if (providerName == 'mock') {
      _controller.setProvider(
        MockAiProvider(tokenDelay: const Duration(milliseconds: 30)),
      );
    } else if (providerName == 'gemini') {
      _showApiKeyDialog(
        title: 'Google Gemini Setup',
        hint: 'Enter your Google Gemini API Key',
        onSubmitted: (key) {
          _controller.setProvider(GeminiAiProvider(apiKey: key));
        },
      );
    } else if (providerName == 'openai') {
      _showApiKeyDialog(
        title: 'OpenAI Setup',
        hint: 'Enter your OpenAI API Key',
        onSubmitted: (key) {
          _controller.setProvider(OpenAiProvider(apiKey: key));
        },
      );
    } else if (providerName == 'ollama') {
      _controller.setProvider(
        OllamaAiProvider(modelName: 'llama3.2'),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switched to Local Ollama (http://localhost:11434)'),
        ),
      );
    }
  }

  void _showApiKeyDialog({
    required String title,
    required String hint,
    required ValueChanged<String> onSubmitted,
  }) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final key = textController.text.trim();
              if (key.isNotEmpty) {
                onSubmitted(key);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF7C4DFF), size: 22),
            SizedBox(width: 8),
            Text(
              'Flutter AI Copilot',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Provider Selector Dropdown
          DropdownButton<String>(
            value: _currentProvider,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'mock', child: Text('Mock LLM (Free)')),
              DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
              DropdownMenuItem(value: 'openai', child: Text('OpenAI GPT-4o')),
              DropdownMenuItem(value: 'ollama', child: Text('Local Ollama')),
            ],
            onChanged: (val) {
              if (val != null) _switchProvider(val);
            },
          ),
          IconButton(
            icon: Icon(
              widget.isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: _selectedTab == 0 ? _buildFullChatTab() : _buildDashboardAppTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (idx) => setState(() => _selectedTab = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Full Chatbot',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'In-App Copilot Demo',
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 1
          ? AiCopilotFab(
              controller: _controller,
              suggestedPrompts: const [
                'Transfer \$250 to Alex Morgan',
                'Check weather in Tokyo',
                'Search flights to London',
                'Summarize this dashboard',
              ],
            )
          : null,
    );
  }

  Widget _buildFullChatTab() {
    return AiContextScope(
      screenContext: const AiScreenContext(
        routeName: '/chat',
        title: 'Full Copilot Assistant',
        properties: {'user': 'Developer', 'tier': 'Enterprise'},
        visibleContent: [
          'Active LLM Engine: Multi-Provider',
          'Security: HITL Active'
        ],
        screenSpecificTools: [
          'execute_secure_transfer',
          'check_weather',
          'search_flights',
        ],
      ),
      child: AiChatView(
        controller: _controller,
        title: 'Flutter AI Copilot',
        showStreamMetrics: true,
        showScreenContextBanner: true,
        suggestedPrompts: const [
          'Transfer \$250 to Alex Morgan',
          'Check weather in San Francisco',
          'Search flights to Tokyo',
          'Write a Flutter counter in Dart',
        ],
      ),
    );
  }

  Widget _buildDashboardAppTab() {
    return AiContextScope(
      screenContext: const AiScreenContext(
        routeName: '/dashboard',
        title: 'Enterprise Financial Dashboard',
        properties: {
          'user': 'Usman Dev',
          'totalBalance': '\$12,450.00',
          'spendingLimit': '\$5,000.00',
        },
        visibleContent: [
          'Account Status: Active',
          'Total Balance: \$12,450.00',
          'Security Mode: Enterprise Protected',
        ],
        screenSpecificTools: [
          'execute_secure_transfer',
          'check_weather',
          'search_flights',
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Daily App Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap the pulsing AI Copilot button in the bottom right corner to summon your assistant from anywhere in your app!',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetricCard(
                  'Active Users',
                  '24,590',
                  '+14%',
                  Icons.people,
                  Colors.blue,
                ),
                const SizedBox(width: 14),
                _buildMetricCard(
                  'Total Revenue',
                  '\$82,400',
                  '+22%',
                  Icons.attach_money,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Enterprise Copilot Pillars Enabled',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildCapabilityTile(
              Icons.shield_rounded,
              'Human-in-the-Loop Security (HITL)',
              'Sensitive tools request interactive authorization before running.',
            ),
            _buildCapabilityTile(
              Icons.speed_rounded,
              'Zero-Jank 60/120 FPS Streaming',
              'Frame-synced batching buffer eliminates UI freezes on fast tokens.',
            ),
            _buildCapabilityTile(
              Icons.layers_rounded,
              'Screen-Aware Context Introspection',
              'Automatically passes active route, state, and visible metadata.',
            ),
            _buildCapabilityTile(
              Icons.widgets,
              'Autonomous Tools & Generative UI Cards',
              'Renders custom rich interactive Flutter widgets on tool completion.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String change,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E2433) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isDark
                ? const Color(0xFF2E384D)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    change,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityTile(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF181C28) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              widget.isDark ? const Color(0xFF262D3D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF7C4DFF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
