import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/runner_game.dart';

class CharacterDefinition {
  final String id, name, role;
  final int price, color;
  const CharacterDefinition(
    this.id,
    this.name,
    this.role,
    this.price,
    this.color,
  );
  String get model => 'assets/models/$id.glb';
  static const all = [
    CharacterDefinition(
      'pip',
      'PIP',
      'NEIGHBORHOOD PIZZA COURIER',
      0,
      0xff57ddc4,
    ),
    CharacterDefinition(
      'volt',
      'VOLT',
      'EXPRESS DELIVERY JACKET',
      1000,
      0xffffb65d,
    ),
    CharacterDefinition(
      'nova',
      'NOVA',
      'MIDNIGHT DELIVERY JACKET',
      3000,
      0xffb4a1ff,
    ),
  ];
}

class MissionDefinition {
  final String id, label, metric;
  final double target;
  final bool best;
  const MissionDefinition(
    this.id,
    this.label,
    this.metric,
    this.target, {
    this.best = false,
  });
  static const catalog = [
    MissionDefinition('distance', 'Travel 1,000 meters', 'distance', 1000),
    MissionDefinition('coins', 'Collect 200 coins', 'coins', 200),
    MissionDefinition('jumps', 'Clear 15 low barriers', 'barriers', 15),
    MissionDefinition('slides', 'Slide 20 times', 'slides', 20),
    MissionDefinition('magnets', 'Find 3 magnets', 'magnets', 3),
    MissionDefinition('score', 'Reach 5,000 score', 'score', 5000, best: true),
    MissionDefinition(
      'clean',
      'Run 750m without a collision',
      'clean',
      750,
      best: true,
    ),
  ];
}

class RunResult {
  final int id, coins, score;
  final double distance;
  final Map<String, double> stats;
  const RunResult({
    required this.id,
    required this.coins,
    required this.score,
    required this.distance,
    required this.stats,
  });
}

abstract interface class SaveStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PreferencesStore implements SaveStore {
  final SharedPreferencesAsync preferences = SharedPreferencesAsync();
  @override
  Future<String?> read(String key) => preferences.getString(key);
  @override
  Future<void> write(String key, String value) =>
      preferences.setString(key, value);
}

class ProgressData {
  int wallet = 0,
      highScore = 0,
      missionSet = 0,
      nextRunId = 1,
      settledRunId = 0,
      creditedCoins = 0;
  double maximumDistance = 0;
  String selected = 'pip';
  Set<String> unlocked = {'pip'};
  bool tutorialCompleted = false, haptics = true, reduceMotion = false;
  double music = .5, sfx = .7;
  Map<String, int> levels = {for (final p in PowerUp.values) p.name: 1};
  Map<String, double> missionProgress = {}, creditedStats = {};
  int get multiplier => math.min(5, 1 + missionSet);
  List<MissionDefinition> get missions => List.generate(
    3,
    (i) =>
        MissionDefinition.catalog[(missionSet * 3 + i) %
            MissionDefinition.catalog.length],
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'wallet': wallet,
    'highScore': highScore,
    'maximumDistance': maximumDistance,
    'selected': selected,
    'unlocked': unlocked.toList(),
    'tutorialCompleted': tutorialCompleted,
    'levels': levels,
    'missionSet': missionSet,
    'missionProgress': missionProgress,
    'nextRunId': nextRunId,
    'settledRunId': settledRunId,
    'creditedCoins': creditedCoins,
    'creditedStats': creditedStats,
    'settings': {
      'haptics': haptics,
      'reduceMotion': reduceMotion,
      'music': music,
      'sfx': sfx,
    },
  };
  static ProgressData fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported save version');
    }
    final p = ProgressData();
    int integer(String key, int fallback) =>
        json[key] is num ? math.max(0, (json[key] as num).toInt()) : fallback;
    p.wallet = integer('wallet', 0);
    p.highScore = integer('highScore', 0);
    p.missionSet = integer('missionSet', 0);
    p.nextRunId = math.max(1, integer('nextRunId', 1));
    p.settledRunId = integer('settledRunId', 0);
    p.creditedCoins = integer('creditedCoins', 0);
    p.maximumDistance = (json['maximumDistance'] as num? ?? 0).toDouble().clamp(
      0,
      1e12,
    );
    p.unlocked = {
      'pip',
      ...((json['unlocked'] as List?) ?? []).whereType<String>().where(
        (id) => CharacterDefinition.all.any((c) => c.id == id),
      ),
    };
    p.selected =
        json['selected'] is String && p.unlocked.contains(json['selected'])
        ? json['selected'] as String
        : 'pip';
    p.tutorialCompleted = json['tutorialCompleted'] == true;
    for (final power in PowerUp.values) {
      p.levels[power.name] =
          ((json['levels'] as Map?)?[power.name] as num? ?? 1).toInt().clamp(
            1,
            5,
          );
    }
    Map<String, double> numbers(dynamic map) => map is Map
        ? {
            for (final e in map.entries)
              if (e.key is String &&
                  e.value is num &&
                  (e.value as num).isFinite)
                e.key as String: math.max(0, (e.value as num).toDouble()),
          }
        : {};
    p.missionProgress = numbers(json['missionProgress']);
    p.creditedStats = numbers(json['creditedStats']);
    final settings = json['settings'] as Map? ?? {};
    p.haptics = settings['haptics'] != false;
    p.reduceMotion = settings['reduceMotion'] == true;
    p.music = (settings['music'] as num? ?? .5).toDouble().clamp(0, 1);
    p.sfx = (settings['sfx'] as num? ?? .7).toDouble().clamp(0, 1);
    return p;
  }
}

/// Cached read model for presentation; callers cannot mutate repository state.
class ProgressSnapshot {
  final int wallet, highScore, multiplier;
  final double maximumDistance;
  final String selected;
  final bool tutorialCompleted;
  final Set<String> unlocked;
  final Map<String, int> levels;
  final Map<String, double> missionProgress;
  final List<MissionDefinition> missions;
  ProgressSnapshot(ProgressData data)
    : wallet = data.wallet,
      highScore = data.highScore,
      multiplier = data.multiplier,
      maximumDistance = data.maximumDistance,
      selected = data.selected,
      tutorialCompleted = data.tutorialCompleted,
      unlocked = Set.unmodifiable(data.unlocked),
      levels = Map.unmodifiable(data.levels),
      missionProgress = Map.unmodifiable(data.missionProgress),
      missions = List.unmodifiable(data.missions);
}

class ProgressRepository extends ChangeNotifier {
  ProgressSnapshot _snapshot = ProgressSnapshot(ProgressData());
  ProgressSnapshot get snapshot => _snapshot;
  SettingsSnapshot _settings = const SettingsSnapshot();
  bool _disposed = false;
  void _notify() {
    _snapshot = ProgressSnapshot(_data);
    _settings = SettingsSnapshot(
      music: _data.music,
      sfx: _data.sfx,
      haptics: _data.haptics,
      reduceMotion: _data.reduceMotion,
    );
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final SaveStore store;
  ProgressRepository(this.store);
  ProgressData _data = ProgressData();
  ProgressData get data => ProgressData.fromJson(_data.toJson());
  Future<void> _writes = Future.value();
  String? _lastGood, saveError;
  bool recovered = false;
  static const key = 'skyway.progress.v1', backupKey = 'skyway.progress.backup';
  Future<void> load() async {
    for (final candidate in [key, backupKey]) {
      try {
        final raw = await store.read(candidate);
        if (raw == null) continue;
        _data = ProgressData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _lastGood = raw;
        recovered = candidate == backupKey;
        _notify();
        return;
      } catch (e) {
        saveError =
            'Saved progress could not be read. A recovery copy was checked.';
      }
    }
    _notify();
  }

  void _changed() {
    final snapshot = jsonEncode(_data.toJson());
    _notify();
    _writes = _writes.then((_) async {
      try {
        if (_lastGood != null) await store.write(backupKey, _lastGood!);
        await store.write(key, snapshot);
        _lastGood = snapshot;
        saveError = null;
      } catch (e) {
        saveError =
            'Progress is held in memory. Saving failed; retry before closing.';
        _notify();
      }
    });
  }

  Future<void> flush() => _writes;
  void retrySave() => _changed();
  int allocateRun() {
    final id = _data.nextRunId++;
    _changed();
    return id;
  }

  void settle(RunResult result) {
    if (result.id < _data.settledRunId) return;
    if (result.id != _data.settledRunId) {
      _data.settledRunId = result.id;
      _data.creditedCoins = 0;
      _data.creditedStats = {};
    }
    final delta = math.max(0, result.coins - _data.creditedCoins);
    _data.wallet += delta;
    _data.creditedCoins = math.max(_data.creditedCoins, result.coins);
    _data.highScore = math.max(_data.highScore, result.score);
    _data.maximumDistance = math.max(_data.maximumDistance, result.distance);
    final stats = {
      ...result.stats,
      'coins': result.coins.toDouble(),
      'distance': result.distance,
      'score': result.score.toDouble(),
    };
    for (final m in _data.missions) {
      final total = stats[m.metric] ?? 0,
          previous = _data.missionProgress[m.id] ?? 0;
      final increment = math.max(
        0,
        total - (_data.creditedStats[m.metric] ?? 0),
      );
      _data.missionProgress[m.id] = math.min(
        m.target,
        m.best ? math.max(previous, total) : previous + increment,
      );
    }
    for (final e in stats.entries) {
      _data.creditedStats[e.key] = math.max(
        _data.creditedStats[e.key] ?? 0,
        e.value,
      );
    }
    _changed();
  }

  bool get canClaim => _data.missions.every(
    (m) => (_data.missionProgress[m.id] ?? 0) >= m.target,
  );
  bool claimMissions() {
    if (!canClaim) return false;
    _data.wallet += 300;
    _data.missionSet++;
    _data.missionProgress = {};
    _changed();
    return true;
  }

  static const upgradeCosts = [250, 500, 1000, 2000];
  int? upgradeCost(PowerUp power) {
    final level = _data.levels[power.name]!;
    return level >= 5 ? null : upgradeCosts[level - 1];
  }

  bool upgrade(PowerUp power) {
    final price = upgradeCost(power);
    if (price == null || _data.wallet < price) return false;
    _data.wallet -= price;
    _data.levels[power.name] = _data.levels[power.name]! + 1;
    _changed();
    return true;
  }

  bool buyCharacter(String id) {
    final character = CharacterDefinition.all
        .where((c) => c.id == id)
        .firstOrNull;
    if (character == null) return false;
    if (_data.unlocked.contains(id)) return true;
    if (_data.wallet < character.price) return false;
    _data.wallet -= character.price;
    _data.unlocked.add(id);
    _changed();
    return true;
  }

  bool selectCharacter(String id) {
    if (!_data.unlocked.contains(id)) return false;
    _data.selected = id;
    _changed();
    return true;
  }

  bool spendRevive({required int bankAtStart}) {
    if (bankAtStart < 100 || _data.wallet < 100) return false;
    _data.wallet -= 100;
    _changed();
    return true;
  }

  void completeTutorial() {
    if (_data.tutorialCompleted) return;
    _data.tutorialCompleted = true;
    _changed();
  }

  void setSettings({
    double? music,
    double? sfx,
    bool? haptics,
    bool? reduceMotion,
  }) {
    if (music != null) _data.music = music.clamp(0, 1);
    if (sfx != null) _data.sfx = sfx.clamp(0, 1);
    if (haptics != null) _data.haptics = haptics;
    if (reduceMotion != null) _data.reduceMotion = reduceMotion;
    _changed();
  }
}

class SettingsSnapshot {
  final double music, sfx;
  final bool haptics, reduceMotion;
  const SettingsSnapshot({
    this.music = .5,
    this.sfx = .7,
    this.haptics = true,
    this.reduceMotion = false,
  });
}

class SettingsRepository {
  final ProgressRepository progress;
  SettingsRepository(this.progress);
  SettingsSnapshot get settings => progress._settings;
  void update({
    double? music,
    double? sfx,
    bool? haptics,
    bool? reduceMotion,
  }) => progress.setSettings(
    music: music,
    sfx: sfx,
    haptics: haptics,
    reduceMotion: reduceMotion,
  );
}

class CharacterRepository {
  final ProgressRepository progress;
  CharacterRepository(this.progress);
  List<CharacterDefinition> get characters => CharacterDefinition.all;
  bool unlock(String id) => progress.buyCharacter(id);
  bool select(String id) => progress.selectCharacter(id);
}
