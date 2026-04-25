import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';

class SentinelState {
  final int blockedTransactions;
  final List<Map<String, dynamic>> alerts;

  const SentinelState({
    required this.blockedTransactions,
    required this.alerts,
  });

  SentinelState copyWith({
    int? blockedTransactions,
    List<Map<String, dynamic>>? alerts,
  }) {
    return SentinelState(
      blockedTransactions: blockedTransactions ?? this.blockedTransactions,
      alerts: alerts ?? this.alerts,
    );
  }
}

class AppStateNotifier extends StateNotifier<SentinelState> {
  AppStateNotifier() : super(const SentinelState(blockedTransactions: 0, alerts: []));

  void processAlerts(List<Map<String, dynamic>> alerts) {
    int blocks = 0;
    List<Map<String, dynamic>> fullAlerts = [];
    for (var alert in alerts) {
      if (alert['type'] == 'MULE_NETWORK_DETECTED' || alert.containsKey('verdict')) {
        blocks++;
        fullAlerts.add(alert);
      }
    }
    state = state.copyWith(blockedTransactions: blocks, alerts: fullAlerts);
  }
  
  // For local testing without firebase
  void injectMockAlert() {
    final mockId = 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    
    // Randomize whether it's a PTR Breach or Bot Jitter
    final isBot = DateTime.now().second % 2 == 0;
    
    final mockAlert = {
      'txn_id': mockId,
      'amount': isBot ? 14500.0 : 95000.0,
      'verdict': isBot ? 'BOT' : 'CRITICAL_MULE',
      'confidence': isBot ? 0.89 : 1.00,
      'timestamp': DateTime.now().toIso8601String(),
    };

    state = state.copyWith(
      blockedTransactions: state.blockedTransactions + 1,
      alerts: [mockAlert, ...state.alerts],
    );
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, SentinelState>((ref) {
  final notifier = AppStateNotifier();
  
  // Listen to firestore stream and update state
  ref.listen<AsyncValue<List<Map<String, dynamic>>>>(alertsStreamProvider, (previous, next) {
     next.whenData((alerts) {
       notifier.processAlerts(alerts);
     });
  });

  return notifier;
});
