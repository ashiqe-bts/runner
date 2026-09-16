import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../data/repositories.dart';
import 'courier_ui.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({
    super.key,
    required this.app,
    required this.showcase,
    this.characters = false,
  });
  final AppController app;
  final Widget showcase;
  final bool characters;

  void browse(int direction) {
    final all = CharacterDefinition.all;
    final index = all.indexWhere((c) => c.id == app.previewCharacter);
    app.preview(all[(index + direction) % all.length].id);
  }

  @override
  Widget build(BuildContext context) {
    final progress = app.progress.snapshot;
    final outfit = CharacterDefinition.all.firstWhere(
      (c) => c.id == app.previewCharacter,
    );
    final owned = progress.unlocked.contains(outfit.id);
    final selected = progress.selected == outfit.id;
    final completed = progress.missions
        .where((m) => (progress.missionProgress[m.id] ?? 0) >= m.target)
        .length;
    final fraction =
        progress.missions.fold(
          0.0,
          (sum, m) =>
              sum +
              ((progress.missionProgress[m.id] ?? 0) / m.target).clamp(
                0.0,
                1.0,
              ),
        ) /
        progress.missions.length;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final height = math.max(
                constraints.maxHeight,
                520.0 + (scale - 1) * 240,
              );
              return SingleChildScrollView(
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (characters) ...[
                              CourierIconButton(
                                icon: Icons.arrow_back_rounded,
                                label: 'Back',
                                onPressed: () => app.navigate(AppPage.home),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  characters ? 'YOUR CREW' : 'SKYWAY\nCOURIER',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            CoinCounter(progress.wallet),
                            const SizedBox(width: 8),
                            CourierIconButton(
                              icon: Icons.settings_rounded,
                              label: 'Settings',
                              onPressed: () => app.navigate(AppPage.settings),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (!characters)
                          Semantics(
                            button: true,
                            label: 'View mission progress',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => app.navigate(AppPage.missions),
                              child: CourierPanel(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.verified_rounded,
                                          color: mint,
                                          size: 27,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'DELIVERY GOALS',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$completed / 3',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: fraction,
                                        minHeight: 9,
                                        color: mint,
                                        backgroundColor: const Color(
                                          0xffaac59b,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      app.progress.canClaim
                                          ? 'Reward ready! Tap to claim'
                                          : 'Complete the set • 300 coins',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (characters)
                          const Text(
                            'Three looks. One delivery legend.',
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 10),
                        if (!characters)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                color: ink,
                                size: 19,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'BEST ${progress.highScore}  •  ${progress.multiplier}× SCORE',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(child: showcase),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: CourierIconButton(
                                  icon: Icons.chevron_left_rounded,
                                  label: 'Previous courier',
                                  onPressed: () => browse(-1),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: CourierIconButton(
                                  icon: Icons.chevron_right_rounded,
                                  label: 'Next courier',
                                  onPressed: () => browse(1),
                                ),
                              ),
                              if (!characters)
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      backgroundColor: panel,
                                      side: const BorderSide(color: ink),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () =>
                                        app.navigate(AppPage.characters),
                                    icon: const Icon(
                                      Icons.checkroom_rounded,
                                      size: 22,
                                    ),
                                    label: const Text('Couriers'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          outfit.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            color: panel,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          selected
                              ? 'Your active courier'
                              : owned
                              ? 'Owned • select in Couriers'
                              : '${outfit.price} coins • unlock in Couriers',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: panel),
                        ),
                        if (characters) ...[
                          const SizedBox(height: 6),
                          Text(
                            outfit.role,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: panel, fontSize: 12),
                          ),
                          Text(
                            'Longest delivery: ${progress.maximumDistance.floor()} m',
                            style: const TextStyle(color: panel, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: characters
                  ? selected || (!owned && progress.wallet < outfit.price)
                        ? null
                        : () => app.unlockOrSelect()
                  : () => app.startRun(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  characters
                      ? selected
                            ? 'SELECTED'
                            : owned
                            ? 'SELECT COURIER'
                            : 'UNLOCK • ${outfit.price} COINS'
                      : 'PLAY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: characters ? 17 : 27,
                    fontWeight: FontWeight.w700,
                    fontStyle: characters ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!characters) LobbyNavigation(app: app),
      ],
    );
  }
}

class LobbyNavigation extends StatelessWidget {
  const LobbyNavigation({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xff226e55),
      border: Border(top: BorderSide(color: Color(0xffb6e2af), width: 2)),
    ),
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
    child: Row(
      children: [
        for (final item in [
          (AppPage.upgrades, Icons.bolt_rounded, 'Upgrades'),
          (AppPage.home, Icons.home_rounded, 'Home'),
          (AppPage.missions, Icons.emoji_events_rounded, 'Missions'),
        ])
          Expanded(
            child: Semantics(
              selected: app.page == item.$1,
              child: TextButton(
                onPressed: () => app.navigate(item.$1),
                style: TextButton.styleFrom(
                  foregroundColor: app.page == item.$1 ? ink : panel,
                  backgroundColor: app.page == item.$1
                      ? gold
                      : Colors.transparent,
                  minimumSize: const Size(48, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$2, size: 24),
                    Text(
                      item.$3,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
