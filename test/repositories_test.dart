import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyway_courier/data/repositories.dart';
import 'package:skyway_courier/game/runner_game.dart';

class MemoryStore implements SaveStore {
  final values = <String, String>{};
  bool fail = false;
  final writes = <String>[];
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('Disk full');
    await Future<void>.delayed(Duration.zero);
    values[key] = value;
    writes.add(key);
  }
}

RunResult result({
  int id = 1,
  int coins = 100,
  int score = 1000,
  double distance = 1000,
  Map<String, double> stats = const {},
}) => RunResult(
  id: id,
  coins: coins,
  score: score,
  distance: distance,
  stats: stats,
);
void main() {
  test(
    'progress snapshots are cached, immutable and refresh after purchases',
    () {
      final repo = ProgressRepository(MemoryStore());
      repo.settle(result(coins: 1500));
      final before = repo.snapshot;
      expect(identical(repo.snapshot, before), isTrue);
      expect(() => before.unlocked.add('nova'), throwsUnsupportedError);
      expect(repo.buyCharacter('volt'), isTrue);
      expect(before.wallet, 1500);
      expect(repo.snapshot.wallet, 500);
      expect(repo.snapshot.unlocked, contains('volt'));
      repo.dispose();
    },
  );

  test(
    'cached settings refresh after save and relaunch without aliasing',
    () async {
      final store = MemoryStore(), progress = ProgressRepository(MemoryStore());
      final settings = SettingsRepository(progress);
      final before = settings.settings;
      settings.update(music: .2, sfx: .3, reduceMotion: true);
      expect(before.music, .5);
      expect(settings.settings.music, .2);
      expect(identical(settings.settings, settings.settings), isTrue);
      final saved = ProgressRepository(store);
      saved.setSettings(music: .1, haptics: false);
      await saved.flush();
      final restored = ProgressRepository(store);
      await restored.load();
      expect(SettingsRepository(restored).settings.music, .1);
      expect(SettingsRepository(restored).settings.haptics, isFalse);
      progress.dispose();
      saved.dispose();
      restored.dispose();
    },
  );

  test('pending failed save does not notify a disposed repository', () async {
    final store = MemoryStore()..fail = true;
    final repo = ProgressRepository(store)..settle(result());
    repo.dispose();
    await repo.flush();
    expect(repo.saveError, isNotNull);
  });
  test(
    'run rewards are credited once, including death after revival',
    () async {
      final s = MemoryStore(), p = ProgressRepository(MemoryStore());
      p.settle(result());
      p.settle(result());
      expect(p.data.wallet, 100);
      p.settle(result(coins: 150));
      expect(p.data.wallet, 150);
      p.settle(result(id: 2, coins: 40));
      expect(p.data.wallet, 190);
      p.settle(result(id: 1, coins: 9999));
      expect(p.data.wallet, 190);
      await p.flush();
      expect(s.values, isEmpty);
    },
  );
  test(
    'saved settlement ledger prevents reward duplication after relaunch',
    () async {
      final s = MemoryStore(), p = ProgressRepository(MemoryStore());
      final first = ProgressRepository(s);
      first.settle(result());
      await first.flush();
      final restored = ProgressRepository(s);
      await restored.load();
      restored.settle(result());
      expect(restored.data.wallet, 100);
      await restored.flush();
      await p.flush();
    },
  );
  test(
    'character economy rejects insufficient funds and unknown ids',
    () async {
      final p = ProgressRepository(MemoryStore());
      expect(p.buyCharacter('volt'), false);
      expect(p.selectCharacter('nova'), false);
      expect(p.buyCharacter('unknown'), false);
      p.settle(result(coins: 1000));
      expect(p.buyCharacter('volt'), true);
      expect(p.data.wallet, 0);
      expect(p.buyCharacter('volt'), true);
      expect(p.selectCharacter('volt'), true);
      expect(p.data.selected, 'volt');
      await p.flush();
    },
  );
  test('upgrade prices and cap are enforced without double spending', () async {
    final p = ProgressRepository(MemoryStore());
    expect(p.upgrade(PowerUp.magnet), false);
    p.settle(result(coins: 5000));
    for (final price in [250, 500, 1000, 2000]) {
      expect(p.upgradeCost(PowerUp.magnet), price);
      expect(p.upgrade(PowerUp.magnet), true);
    }
    expect(p.data.wallet, 1250);
    expect(p.data.levels['magnet'], 5);
    expect(p.upgrade(PowerUp.magnet), false);
    await p.flush();
  });
  test('revive uses pre-run bank, not newly earned coins', () async {
    final p = ProgressRepository(MemoryStore());
    p.settle(result(coins: 300));
    expect(p.spendRevive(bankAtStart: 50), false);
    expect(p.spendRevive(bankAtStart: 100), true);
    expect(p.data.wallet, 200);
    await p.flush();
  });
  test('mission set claims once and raises multiplier', () async {
    final p = ProgressRepository(MemoryStore());
    p.settle(result(coins: 200, stats: {'barriers': 15}));
    expect(p.canClaim, true);
    expect(p.claimMissions(), true);
    expect(p.data.wallet, 500);
    expect(p.data.multiplier, 2);
    expect(p.claimMissions(), false);
    expect(p.data.wallet, 500);
    await p.flush();
  });
  test('best metrics take max, cumulative metrics use deltas', () async {
    final s = MemoryStore();
    final data = ProgressData()..missionSet = 1;
    s.values[ProgressRepository.key] = jsonEncode(data.toJson());
    final p = ProgressRepository(s);
    await p.load();
    p.settle(result(score: 2000, stats: {'slides': 10, 'magnets': 1}));
    p.settle(result(score: 3000, stats: {'slides': 12, 'magnets': 2}));
    expect(p.data.missionProgress['slides'], 12);
    expect(p.data.missionProgress['score'], 3000);
    p.settle(result(id: 2, score: 1000, stats: {'slides': 4, 'magnets': 1}));
    expect(p.data.missionProgress['slides'], 16);
    expect(p.data.missionProgress['score'], 3000);
    await p.flush();
  });
  test(
    'corrupt primary recovers backup and next save repairs primary',
    () async {
      final s = MemoryStore();
      s.values[ProgressRepository.key] = '{bad';
      s.values[ProgressRepository.backupKey] = jsonEncode(
        (ProgressData()..wallet = 42).toJson(),
      );
      final p = ProgressRepository(s);
      await p.load();
      expect(p.recovered, true);
      expect(p.data.wallet, 42);
      p.retrySave();
      await p.flush();
      expect(jsonDecode(s.values[ProgressRepository.key]!)['wallet'], 42);
    },
  );
  test(
    'serialized writes preserve last settings value and recovery copy',
    () async {
      final s = MemoryStore(), p = ProgressRepository(MemoryStore());
      final repo = ProgressRepository(s);
      for (var i = 0; i < 10; i++) {
        repo.setSettings(music: i / 10);
      }
      await repo.flush();
      final restored = ProgressRepository(s);
      await restored.load();
      expect(restored.data.music, .9);
      expect(
        jsonDecode(
          s.values[ProgressRepository.backupKey]!,
        )['settings']['music'],
        .8,
      );
      await p.flush();
    },
  );
  test('save errors are reported, held in memory, and retried', () async {
    final s = MemoryStore()..fail = true;
    final p = ProgressRepository(s);
    p.settle(result());
    await p.flush();
    expect(p.saveError, isNotNull);
    expect(p.data.wallet, 100);
    s.fail = false;
    p.retrySave();
    await p.flush();
    expect(p.saveError, isNull);
    expect(jsonDecode(s.values[ProgressRepository.key]!)['wallet'], 100);
  });
  test('malformed known fields cannot unlock unowned character', () {
    final data = ProgressData.fromJson({
      'version': 1,
      'wallet': -20,
      'selected': 'nova',
      'unlocked': ['bad'],
      'levels': {'magnet': 99},
    });
    expect(data.wallet, 0);
    expect(data.selected, 'pip');
    expect(data.levels['magnet'], 5);
  });
}
