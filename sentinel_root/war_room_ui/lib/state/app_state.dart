import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_threat_reporter.dart';
import '../services/DemoSimulatorService.dart';

class SentinelState {
  final int blockedTransactions;
  final List<Map<String, dynamic>> alerts;
  final bool isSimulating;
  final List<Map<String, dynamic>> detectedRings; // All detected mule rings

  const SentinelState({
    required this.blockedTransactions,
    required this.alerts,
    required this.isSimulating,
    this.detectedRings = const [],
  });

  SentinelState copyWith({
    int? blockedTransactions,
    List<Map<String, dynamic>>? alerts,
    bool? isSimulating,
    List<Map<String, dynamic>>? detectedRings,
  }) {
    return SentinelState(
      blockedTransactions: blockedTransactions ?? this.blockedTransactions,
      alerts: alerts ?? this.alerts,
      isSimulating: isSimulating ?? this.isSimulating,
      detectedRings: detectedRings ?? this.detectedRings,
    );
  }
}

class AppStateNotifier extends StateNotifier<SentinelState> {
  final GeminiThreatReporter _geminiReporter;
  final DemoSimulatorService _simulator;

  AppStateNotifier() 
      : _geminiReporter = GeminiThreatReporter(),
        _simulator = DemoSimulatorService(),
        super(const SentinelState(blockedTransactions: 0, alerts: [], isSimulating: false));

  void startSimulation() {
    if (state.isSimulating) return;
    
    state = state.copyWith(isSimulating: true);
    
    _simulator.startSimulation((result) {
      bool isBlocked = result['status'] == 'blocked';
      
      var newAlert = Map<String, dynamic>.from(result);
      
      if (isBlocked && !newAlert.containsKey('gemini_report')) {
         newAlert['gemini_report'] = 'Generating AI Threat Report...';
         _fetchGeminiReportForAlert(newAlert);
      }

      // Extract ring detection data from backend response
      List<Map<String, dynamic>> ringsData = state.detectedRings;
      if (result['rings'] != null && result['rings'] is List && (result['rings'] as List).isNotEmpty) {
        ringsData = (result['rings'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
      }
      
      state = state.copyWith(
        blockedTransactions: state.blockedTransactions + (isBlocked ? 1 : 0),
        alerts: [newAlert, ...state.alerts],
        detectedRings: ringsData,
      );
    }).then((_) {
      state = state.copyWith(isSimulating: false);
    });
  }

  Future<void> _fetchGeminiReportForAlert(Map<String, dynamic> alert) async {
    final report = await _geminiReporter.getThreatReport(alert);
    
    final updatedAlerts = state.alerts.map((a) {
      if (a['transaction_id'] == alert['transaction_id']) {
        return {...a, 'gemini_report': report};
      }
      return a;
    }).toList();
    
    state = state.copyWith(alerts: updatedAlerts);
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, SentinelState>((ref) {
  return AppStateNotifier();
});
