import 'dart:async';
import 'dart:ui';

import 'package:simulator/features/session/services/session_service.dart';

/// Tells every app the simulator shows that its window is hidden, as a
/// desktop app is told of its own: hidden, it draws no frames for nobody;
/// shown again, it is resumed and draws a fresh frame. An app an agent
/// drives stays resumed for [inUseFor] after, so what the agent did draws.
final class WindowVisibility {
  WindowVisibility({
    required SessionService sessions,
    this.inUseFor = const Duration(seconds: 10),
  }) : _sessions = sessions {
    _sessions.addListener(_apply);
  }

  final SessionService _sessions;

  /// How long after an agent's last action its app stays resumed.
  final Duration inUseFor;

  var _windowShown = true;

  /// What each client's app was last told; resumed until then, as the
  /// runner starts it.
  final _told = Expando<String>('told lifecycle');

  final _inUse = <String, Timer>{};

  /// The window's own lifecycle changed.
  void windowChanged(AppLifecycleState state) {
    final shown = switch (state) {
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => false,
      AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    };
    if (shown == _windowShown) return;
    _windowShown = shown;
    _apply();
  }

  /// An agent acts on the app named [name]: it stays resumed for
  /// [inUseFor].
  void use(String name) {
    _inUse.remove(name)?.cancel();
    _inUse[name] = Timer(inUseFor, () {
      _inUse.remove(name);
      _apply();
    });
    _apply();
  }

  void _apply() {
    for (final session in _sessions.sessions) {
      final wanted = switch (_windowShown || _inUse.containsKey(session.name)) {
        true => 'resumed',
        false => 'hidden',
      };
      if (wanted == (_told[session.client] ?? 'resumed')) continue;
      _told[session.client] = wanted;
      session.client.setLifecycle(wanted);
    }
  }

  void dispose() {
    _sessions.removeListener(_apply);
    for (final timer in _inUse.values) {
      timer.cancel();
    }
    _inUse.clear();
  }
}
