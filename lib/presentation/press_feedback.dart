import 'package:flutter/services.dart';

DateTime? _lastImpact;

/// Shared by buttons and tappable controls; disabled callbacks stay disabled.
VoidCallback? withLightImpact(VoidCallback? callback) {
  if (callback == null) return null;
  return () {
    final now = DateTime.now();
    // Composed controls can forward the same press through multiple callbacks.
    if (_lastImpact == null ||
        now.difference(_lastImpact!).inMilliseconds > 50) {
      _lastImpact = now;
      HapticFeedback.lightImpact();
    }
    callback();
  };
}

void Function(T) withSelectionImpact<T>(void Function(T) callback) {
  return (value) => withLightImpact(() => callback(value))!();
}
