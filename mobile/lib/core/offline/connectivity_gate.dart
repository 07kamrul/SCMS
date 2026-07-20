import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around `connectivity_plus` used to decide when the offline
/// retry queues should attempt to replay. "Online" here means the device
/// reports at least one non-`none` connectivity result (Wi-Fi or mobile) —
/// it is a link-layer check, not a guarantee the backend is reachable.
class ConnectivityGate {
  ConnectivityGate({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Emits the current online/offline status whenever connectivity changes.
  Stream<bool> get onlineStatus =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  /// One-shot check for an immediate "are we online right now" decision,
  /// e.g. before enqueueing vs. attempting a submission directly.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
