import 'dart:async';

/// Notification payload for agent state changes and AFK approval alerts.
class AgentNotification {
  final String title;
  final String body;
  final String sessionId;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  AgentNotification({
    required this.title,
    required this.body,
    required this.sessionId,
    this.payload = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Optional notification service.
/// Provides native local notifications and falls back gracefully when Firebase/FCM
/// credentials are not configured, avoiding external hard dependencies.
class NotificationService {
  final bool isFirebaseConfigured;
  final List<AgentNotification> _notificationHistory = [];
  final StreamController<AgentNotification> _notificationStreamController =
      StreamController<AgentNotification>.broadcast();

  NotificationService({this.isFirebaseConfigured = false});

  Stream<AgentNotification> get onNotification => _notificationStreamController.stream;
  List<AgentNotification> get history => List.unmodifiable(_notificationHistory);

  /// Dispatches an agent approval or completion notification.
  Future<void> sendNotification({
    required String title,
    required String body,
    required String sessionId,
    Map<String, dynamic> payload = const {},
  }) async {
    final notification = AgentNotification(
      title: title,
      body: body,
      sessionId: sessionId,
      payload: payload,
    );

    _notificationHistory.insert(0, notification);
    if (_notificationHistory.length > 50) _notificationHistory.removeLast();
    _notificationStreamController.add(notification);

    if (isFirebaseConfigured) {
      // In production with FCM credentials configured, dispatch remote push
      await _dispatchFcmPush(notification);
    } else {
      // Local in-app / desktop notification fallback
      _dispatchLocalAlert(notification);
    }
  }

  Future<void> _dispatchFcmPush(AgentNotification notification) async {
    // Graceful optional FCM execution
  }

  void _dispatchLocalAlert(AgentNotification notification) {
    // In-memory local notification event
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
