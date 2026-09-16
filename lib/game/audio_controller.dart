import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../data/repositories.dart';

class AudioController {
  final SettingsRepository settings;
  AudioController(this.settings);
  final engine = SoLoud.instance;
  final sources = <String, AudioSource>{};
  SoundHandle? music, wind;
  double _windVolume = 0;
  bool ready = false, paused = false, disposed = false;
  String? error;
  double _stepTime = 0;
  Future<void> initialize() async {
    if (ready || disposed) return;
    try {
      await engine.init();
      if (disposed) {
        await engine.deinitAsync();
        return;
      }
      engine.setMaxActiveVoiceCount(16);
      for (final name in [
        'skyway',
        'wind',
        'step',
        'jump',
        'land',
        'slide',
        'coin',
        'powerup',
        'hit',
        'button',
        'gameover',
      ]) {
        final source = await engine.loadAsset('assets/audio/$name.wav');
        if (disposed) return;
        sources[name] = source;
      }
      ready = true;
    } catch (e) {
      if (disposed) return;
      error = 'Audio is unavailable on this device.';
      debugPrint('Audio initialization: $e');
    }
  }

  void startMusic() {
    if (!ready) return;
    music ??= engine.play(
      sources['skyway']!,
      volume: settings.settings.music,
      looping: true,
    );
    wind ??= engine.play(sources['wind']!, volume: 0, looping: true);
    pause(false);
    applySettings();
  }

  void applySettings() {
    if (ready && music != null) {
      engine.setVolume(music!, settings.settings.music);
      if (wind != null) {
        engine.setVolume(wind!, _windVolume * settings.settings.sfx);
      }
    }
  }

  void play(String name) {
    if (!ready || paused || settings.settings.sfx == 0) return;
    final source = sources[name];
    if (source != null) {
      engine.play(
        source,
        volume: settings.settings.sfx * (name == 'step' ? .18 : .6),
      );
    }
  }

  void pause(bool value) {
    paused = value;
    if (!ready) return;
    for (final source in sources.values) {
      for (final handle in source.handles) {
        if (engine.getIsValidVoiceHandle(handle)) {
          engine.setPause(handle, value);
        }
      }
    }
  }

  void step(double dt, bool running, {double speed = 12}) {
    _windVolume = running ? .12 + (speed - 12).clamp(0, 10) * .015 : 0;
    if (ready && wind != null) {
      engine.setVolume(wind!, _windVolume * settings.settings.sfx);
    }
    if (!running) {
      _stepTime = 0;
      return;
    }
    _stepTime += dt;
    if (_stepTime > .35 * 12 / speed) {
      _stepTime = 0;
      play('step');
    }
  }

  void haptic(String event) {
    if (!settings.settings.haptics) return;
    switch (event) {
      case 'hit':
        unawaited(HapticFeedback.heavyImpact());
      case 'stumble':
      case 'shield':
        unawaited(HapticFeedback.mediumImpact());
      case 'powerup':
        unawaited(HapticFeedback.lightImpact());
    }
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    if (engine.isInitialized) unawaited(engine.deinitAsync());
    ready = false;
    sources.clear();
  }
}
