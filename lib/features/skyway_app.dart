import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;

import '../app/app_controller.dart';
import '../game/runner_game.dart';
import 'power_up_icon.dart';
import 'courier_ui.dart';
import 'lobby_screen.dart';

class SkywayApp extends StatelessWidget {
  const SkywayApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Skyway Courier',
    debugShowCheckedModeBanner: false,
    theme: courierTheme(),
    home: const SkywayScreen(),
  );
}

class SkywayScreen extends StatefulWidget {
  const SkywayScreen({
    super.key,
    this.controller,
    this.observeLifecycle = true,
    this.sceneBuilder,
  });
  final bool observeLifecycle;
  final AppController? controller;

  /// Allows layout tests to run without a GPU; production uses SceneView.
  final Widget Function(AppController app, bool showcase)? sceneBuilder;
  @override
  State<SkywayScreen> createState() => _SkywayScreenState();
}

class _SkywayScreenState extends State<SkywayScreen>
    with WidgetsBindingObserver {
  late final AppController app;
  final focus = FocusNode();
  Offset? swipeStart;
  @override
  void initState() {
    super.initState();
    if (widget.observeLifecycle) WidgetsBinding.instance.addObserver(this);
    app = widget.controller ?? AppController();
    if (!app.ready) unawaited(app.initialize());
    focus.requestFocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) app.background();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    focus.dispose();
    app.dispose();
    super.dispose();
  }

  void key(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final command = {
      LogicalKeyboardKey.arrowLeft: InputCommand.left,
      LogicalKeyboardKey.keyA: InputCommand.left,
      LogicalKeyboardKey.arrowRight: InputCommand.right,
      LogicalKeyboardKey.keyD: InputCommand.right,
      LogicalKeyboardKey.arrowUp: InputCommand.jump,
      LogicalKeyboardKey.keyW: InputCommand.jump,
      LogicalKeyboardKey.arrowDown: InputCommand.slide,
      LogicalKeyboardKey.keyS: InputCommand.slide,
    }[event.logicalKey];
    if (command != null) app.game.submit(command);
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.keyP) {
      if (app.game.phase == RunPhase.paused) {
        app.resume();
      } else {
        app.pause();
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (app.game.phase == RunPhase.dead || app.page == AppPage.home) {
        app.startRun();
      }
    }
    if ((!kReleaseMode || const bool.fromEnvironment('SKYWAY_DEBUG')) &&
        event.logicalKey == LogicalKeyboardKey.f3) {
      setState(() => app.debug = !app.debug);
    }
    if ((!kReleaseMode || const bool.fromEnvironment('SKYWAY_DEBUG')) &&
        event.logicalKey == LogicalKeyboardKey.f4) {
      app.view.debugColliders = !app.view.debugColliders;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: KeyboardListener(
      focusNode: focus,
      onKeyEvent: key,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              if (!app.ready) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const LobbyBackdrop(),
                    SafeArea(child: _loading()),
                  ],
                );
              }
              final game = app.page == AppPage.game;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: game
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    children: [
                      const Positioned.fill(child: LobbyBackdrop()),
                      if (game)
                        Positioned.fill(
                          child: ColoredBox(
                            color: const Color(0xff173d49),
                            child: _scene(false),
                          ),
                        ),
                      if (game)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (e) => swipeStart = e.localPosition,
                            onPanCancel: () => swipeStart = null,
                            onPanEnd: (_) => swipeStart = null,
                            onPanUpdate: (e) {
                              if (swipeStart == null) return;
                              final delta = e.localPosition - swipeStart!;
                              if (delta.distance < 24) return;
                              app.game.submit(
                                delta.dx.abs() > delta.dy.abs()
                                    ? (delta.dx < 0
                                          ? InputCommand.left
                                          : InputCommand.right)
                                    : (delta.dy < 0
                                          ? InputCommand.jump
                                          : InputCommand.slide),
                              );
                              swipeStart = null;
                            },
                          ),
                        ),
                      SafeArea(
                        child: switch (app.page) {
                          AppPage.home => LobbyScreen(
                            app: app,
                            showcase: _showcase(),
                          ),
                          AppPage.game => ValueListenableBuilder<HudSnapshot>(
                            valueListenable: app.hud,
                            builder: (_, snapshot, _) => _game(snapshot),
                          ),
                          AppPage.characters => LobbyScreen(
                            app: app,
                            showcase: _showcase(),
                            characters: true,
                          ),
                          AppPage.missions => _missions(),
                          AppPage.upgrades => _upgrades(),
                          AppPage.settings => _settings(),
                        },
                      ),
                      if (app.progress.saveError != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 8,
                          child: Material(
                            color: panel,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                app.progress.saveError!,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: TextButton(
                                onPressed: app.progress.retrySave,
                                child: const Text('Retry'),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  Widget _loading() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 58, color: mint),
          const SizedBox(height: 24),
          const Text(
            'SKYWAY COURIER',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            app.error ?? 'Preparing your next adventure…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          if (app.error == null)
            const SizedBox(
              width: 140,
              child: LinearProgressIndicator(color: mint),
            )
          else
            FilledButton(
              onPressed: app.initialize,
              child: const Text('TRY AGAIN'),
            ),
        ],
      ),
    ),
  );
  Widget eyebrow(String text, {Color color = muted}) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: color,
    ),
  );
  Widget wallet() => CoinCounter(app.progress.snapshot.wallet);
  Widget circleButton(IconData icon, String tooltip, VoidCallback onTap) =>
      CourierIconButton(icon: icon, label: tooltip, onPressed: onTap);
  Widget _showcase() => _scene(true);
  Widget _scene(bool showcase) =>
      widget.sceneBuilder?.call(app, showcase) ??
      SceneView(
        app.view.scene,
        cameraBuilder: (_) => app.view.camera(showcase: showcase),
        onTick: (_, dt) => app.tick(dt),
      );
  Widget _card(Widget child, {Color? color}) =>
      CourierPanel(color: color ?? panel, child: child);
  Widget _header(String title) => Row(
    children: [
      circleButton(
        Icons.arrow_back_rounded,
        'Back',
        () => app.navigate(AppPage.home),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
          ),
        ),
      ),
      wallet(),
    ],
  );
  Widget _game(HudSnapshot g) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CourierPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SCORE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                          Text(
                            '${g.score.floor()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${g.distance.floor()} m • ${g.baseMultiplier * (g.powers.containsKey(PowerUp.score) ? 2 : 1)}×',
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      fit: FlexFit.tight,
                      child: _pill(
                        PowerUp.coins,
                        '${g.coins}',
                        const Color(0xff956309),
                        balance: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    circleButton(Icons.pause_rounded, 'Pause', app.pause),
                  ],
                ),
              ),
              if (g.powers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in g.powers.entries)
                        Semantics(
                          label:
                              '${powerName(p.key)}, ${p.value.ceil()} seconds remaining',
                          child: _pill(
                            p.key,
                            '${p.value.ceil()}s',
                            powerColor(p.key),
                          ),
                        ),
                    ],
                  ),
                ),
              if (g.tutorialStep >= 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: IgnorePointer(
                    child: CourierPanel(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(
                            [
                              Icons.swipe_left_rounded,
                              Icons.swipe_right_rounded,
                              Icons.swipe_up_rounded,
                              Icons.swipe_down_rounded,
                              Icons.monetization_on_rounded,
                            ][g.tutorialStep],
                            color: mint,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    'SWIPE LEFT',
                                    'SWIPE RIGHT',
                                    'SWIPE UP TO JUMP',
                                    'SWIPE DOWN TO SLIDE',
                                    'FOLLOW THE COINS',
                                  ][g.tutorialStep],
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Training ${g.tutorialStep + 1}/5 • Arrow keys work too',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (g.phase == RunPhase.running && g.tutorialStep < 0)
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: panel.withValues(alpha: .95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  g.pursuitRecovery > 0
                      ? 'PATROL CLOSE · STAY CLEAR ${g.pursuitRecovery.ceil()}s'
                      : 'SWIPE TO MOVE · UP TO JUMP · DOWN TO SLIDE',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ink, fontSize: 10),
                ),
              ),
            ),
          ),
        if (app.debug)
          Positioned(
            left: 12,
            bottom: 48,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(8),
              child: Text(
                '${app.fps.toStringAsFixed(1)} FPS / ${app.frameMs.toStringAsFixed(2)} ms\nXYZ ${g.x.toStringAsFixed(2)}, ${g.y.toStringAsFixed(2)}, 0\n${g.playerState.name} • ${g.speed.toStringAsFixed(2)} m/s\nseed ${g.seed} • tick ${g.tick}\nchunk ${g.nextChunk} • pooled ${g.objectCount}\nF4: collider overlay',
                style: const TextStyle(
                  color: panel,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ),
        if (g.phase == RunPhase.paused) _overlay(_pause()),
        if (g.phase == RunPhase.dead) _overlay(_gameOver()),
        if (g.phase == RunPhase.reviving)
          _overlay(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                eyebrow('BACK ON ROUTE', color: mint),
                Text(
                  '${g.phaseTime.ceil()}',
                  style: const TextStyle(
                    fontSize: 112,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'A clear path. A fresh chance.',
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pill(
    PowerUp power,
    String text,
    Color color, {
    bool balance = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: panel.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: ink.withValues(alpha: .6), width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        balance
            ? Icon(Icons.monetization_on_outlined, color: color, size: 18)
            : PowerUpIcon(power, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
  Widget _overlay(Widget child) => Container(
    color: const Color(0xff4a977b).withValues(alpha: .95),
    alignment: Alignment.center,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: _card(child),
    ),
  );
  Widget _pause() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.pause_circle_outline_rounded, size: 55, color: mint),
      const SizedBox(height: 20),
      const Text(
        'TAKE A BREATHER.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      const Text(
        'Your route will be right here.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: app.resume,
          child: const Text('KEEP RUNNING'),
        ),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => app.navigate(AppPage.home),
        child: const Text('Finish run & return home'),
      ),
    ],
  );
  Widget _gameOver() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.route_rounded, size: 45, color: mint),
      const SizedBox(height: 14),
      eyebrow('DELIVERY COMPLETE', color: mint),
      const SizedBox(height: 12),
      const Text(
        'WHAT A RUN.',
        style: TextStyle(
          fontSize: 37,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 20),
      Text(
        '${app.game.score.floor()}',
        style: const TextStyle(
          fontSize: 67,
          fontWeight: FontWeight.w700,
          letterSpacing: -2,
        ),
      ),
      eyebrow(app.game.captured ? 'CAUGHT BY PATROL' : 'DELIVERY INTERRUPTED'),
      eyebrow('BEST ${app.progress.snapshot.highScore}'),
      const SizedBox(height: 26),
      _card(
        Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 20,
          runSpacing: 12,
          children: [
            _stat('${app.game.distance.floor()} m', 'DISTANCE'),
            _stat('+${app.game.coins}', 'COINS', color: ink),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            eyebrow('MISSION PROGRESS'),
            const SizedBox(height: 10),
            for (final m in app.progress.snapshot.missions)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.label,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                    Text(
                      '${(app.progress.snapshot.missionProgress[m.id] ?? 0).floor()}/${m.target.floor()}',
                      style: const TextStyle(fontSize: 12, color: mint),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => app.startRun(),
          child: const Text('RUN AGAIN'),
        ),
      ),
      if (!app.game.revived)
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: OutlinedButton(
            onPressed: app.canRevive ? app.revive : null,
            child: Text(
              app.canRevive
                  ? 'CONTINUE ROUTE • 100 COINS'
                  : 'REVIVE NEEDS 100 PRE-RUN COINS',
            ),
          ),
        ),
      TextButton(
        onPressed: () => app.navigate(AppPage.home),
        child: const Text('Back to home'),
      ),
    ],
  );
  Widget _stat(String value, String label, {Color color = ink}) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 25,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      eyebrow(label),
    ],
  );
  Widget _page(String title, List<Widget> children) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [_header(title), const SizedBox(height: 20), ...children],
        ),
      ),
      LobbyNavigation(app: app),
    ],
  );
  Widget _missions() => _page('Missions', [
    eyebrow('A LITTLE FURTHER, EVERY RUN.', color: mint),
    const SizedBox(height: 12),
    const Text(
      'Make every\ndelivery count.',
      style: TextStyle(
        fontSize: 33,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -1,
      ),
    ),
    const SizedBox(height: 15),
    Text(
      'Complete all three to earn 300 coins and improve your score multiplier. Current: ${app.progress.snapshot.multiplier}×',
      style: const TextStyle(color: muted, height: 1.6),
    ),
    const SizedBox(height: 25),
    for (final m in app.progress.snapshot.missions)
      Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    (app.progress.snapshot.missionProgress[m.id] ?? 0) >=
                            m.target
                        ? Icons.check_circle_rounded
                        : Icons.flag_outlined,
                    color: mint,
                    size: 23,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${(app.progress.snapshot.missionProgress[m.id] ?? 0).floor()} / ${m.target.floor()}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                  value:
                      ((app.progress.snapshot.missionProgress[m.id] ?? 0) /
                              m.target)
                          .clamp(0, 1),
                  minHeight: 5,
                  color: mint,
                  backgroundColor: const Color(0xffaac59b),
                ),
              ),
            ],
          ),
        ),
      ),
    const SizedBox(height: 12),
    FilledButton(
      onPressed: app.progress.canClaim
          ? () {
              app.progress.claimMissions();
              app.audio.play('powerup');
            }
          : null,
      child: const Text('CLAIM 300 COINS + NEXT SET'),
    ),
  ]);
  Widget _upgrades() => _page('Power station', [
    eyebrow('A BOOST FOR THE ROAD AHEAD', color: mint),
    const SizedBox(height: 12),
    const Text(
      'Small upgrades.\nLonger adventures.',
      style: TextStyle(
        fontSize: 33,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -1,
      ),
    ),
    const SizedBox(height: 25),
    for (final p in PowerUp.values)
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: powerColor(p).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: PowerUpIcon(p, color: powerColor(p), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          powerName(p),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          powerDescription(p),
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'LV ${app.progress.snapshot.levels[p.name]}',
                    style: TextStyle(
                      color: powerColor(p),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: Container(
                        height: 5,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: i < app.progress.snapshot.levels[p.name]!
                              ? powerColor(p)
                              : const Color(0xffaac59b),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${8 + (app.progress.snapshot.levels[p.name]! - 1) * 2}s active',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  FilledButton(
                    onPressed:
                        app.progress.upgradeCost(p) != null &&
                            app.progress.snapshot.wallet >=
                                app.progress.upgradeCost(p)!
                        ? () {
                            app.progress.upgrade(p);
                            app.audio.play('powerup');
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 48),
                    ),
                    child: Text(
                      app.progress.upgradeCost(p) == null
                          ? 'MAX LEVEL'
                          : '↑ ${app.progress.upgradeCost(p)} COINS',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
  ]);
  Widget _settings() => _page('Settings', [
    eyebrow('MAKE YOURSELF AT HOME', color: mint),
    const SizedBox(height: 22),
    _card(
      Column(
        children: [
          _volume(
            'Music',
            Icons.music_note_outlined,
            app.settings.settings.music,
            (v) => app.settings.update(music: v),
          ),
          const Divider(color: Color(0xffaac59b)),
          _volume(
            'Sound effects',
            Icons.graphic_eq_rounded,
            app.settings.settings.sfx,
            (v) => app.settings.update(sfx: v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Haptic feedback'),
            subtitle: const Text(
              'Feel pickups and impacts',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            value: app.settings.settings.haptics,
            onChanged: (v) => app.settings.update(haptics: v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce camera motion'),
            subtitle: const Text(
              'Steady framing, no speed zoom',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            value: app.settings.settings.reduceMotion,
            onChanged: (v) => app.settings.update(reduceMotion: v),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          eyebrow('HOW TO PLAY', color: mint),
          const SizedBox(height: 14),
          const Text(
            '← →  Change lanes\n↑       Jump over barriers and gaps\n↓       Slide under overhead obstacles',
            style: TextStyle(height: 2, color: muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          const Text(
            'Keyboard: arrows or WASD. P pauses.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          TextButton(
            onPressed: () => app.startRun(replayTutorial: true),
            child: const Text('Replay courier training →'),
          ),
        ],
      ),
    ),
    if (app.audio.error != null)
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(app.audio.error!, style: const TextStyle(color: ink)),
      ),
    const SizedBox(height: 30),
    Center(child: eyebrow('SKYWAY COURIER / 1.0.0', color: panel)),
    const SizedBox(height: 8),
    const Center(
      child: Text(
        'Original world. Yours to explore.',
        style: TextStyle(color: panel, fontSize: 11),
      ),
    ),
  ]);
  Widget _volume(
    String label,
    IconData icon,
    double value,
    ValueChanged<double> changed,
  ) => Column(
    children: [
      Row(
        children: [
          Icon(icon, color: mint, size: 21),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
      Slider(value: value, onChanged: changed),
    ],
  );
}

String powerName(PowerUp p) => switch (p) {
  PowerUp.magnet => 'Magnet',
  PowerUp.shield => 'Shield',
  PowerUp.score => 'Double score',
  PowerUp.coins => 'Double coins',
};
String powerDescription(PowerUp p) => switch (p) {
  PowerUp.magnet => 'Draw nearby coins toward you',
  PowerUp.shield => 'One hit protection, including gaps',
  PowerUp.score => 'Every meter is worth twice as much',
  PowerUp.coins => 'Twice the coins in every pickup',
};
Color powerColor(PowerUp p) => switch (p) {
  PowerUp.magnet => const Color(0xff7545b5),
  PowerUp.shield => mint,
  PowerUp.score => const Color(0xff236f9c),
  PowerUp.coins => const Color(0xff956309),
};
