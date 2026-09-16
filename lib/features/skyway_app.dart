import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;

import '../app/app_controller.dart';
import '../data/repositories.dart';
import '../game/runner_game.dart';
import 'power_up_icon.dart';

const ink = Color(0xff0b1925),
    panel = Color(0xff162a37),
    mint = Color(0xff7cecc8),
    muted = Color(0xff91aab9),
    gold = Color(0xffffc26c);

class SkywayApp extends StatelessWidget {
  const SkywayApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Skyway Courier',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        brightness: Brightness.dark,
        primary: mint,
        surface: panel,
      ),
      fontFamily: 'Roboto',
      useMaterial3: true,
      sliderTheme: const SliderThemeData(
        activeTrackColor: mint,
        thumbColor: mint,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: mint,
          foregroundColor: ink,
          minimumSize: const Size(48, 56),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    ),
    home: const SkywayScreen(),
  );
}

class SkywayScreen extends StatefulWidget {
  const SkywayScreen({
    super.key,
    this.controller,
    this.observeLifecycle = true,
  });
  final bool observeLifecycle;
  final AppController? controller;
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
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              if (!app.ready) return _loading();
              final home = app.page == AppPage.home,
                  character = app.page == AppPage.characters,
                  game = app.page == AppPage.game;
              return LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xff173d49), ink],
                          stops: [0, .75],
                        ),
                      ),
                    ),
                    Positioned(
                      top: game
                          ? 0
                          : character
                          ? 155
                          : 205,
                      bottom: game
                          ? 0
                          : character
                          ? 240
                          : 280,
                      left: 0,
                      right: 0,
                      child: Offstage(
                        offstage: !(home || character || game),
                        child: SceneView(
                          app.view.scene,
                          cameraBuilder: (_) =>
                              app.view.camera(showcase: !game),
                          onTick: (_, dt) => app.tick(dt),
                        ),
                      ),
                    ),
                    if (home || character)
                      Positioned(
                        top: game
                            ? 0
                            : character
                            ? 150
                            : 200,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xff17333e), Color(0x0017333e)],
                              ),
                            ),
                          ),
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
                        AppPage.home => _home(),
                        AppPage.game => ValueListenableBuilder<HudSnapshot>(
                          valueListenable: app.hud,
                          builder: (_, snapshot, _) => _game(snapshot),
                        ),
                        AppPage.characters => _characters(),
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
              );
            },
          ),
        ),
      ),
    ),
  );
  Widget _loading() => Center(
    child: Padding(
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
              fontWeight: FontWeight.w900,
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
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
      color: color,
    ),
  );
  Widget wallet() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xff233b42),
      border: Border.all(color: gold.withValues(alpha: .22)),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hexagon_rounded, color: gold, size: 16),
        const SizedBox(width: 7),
        Text(
          '${app.progress.snapshot.wallet}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: gold,
          ),
        ),
      ],
    ),
  );
  Widget circleButton(IconData icon, String tooltip, VoidCallback onTap) =>
      IconButton.filledTonal(
        onPressed: onTap,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: panel.withValues(alpha: .85),
          minimumSize: const Size(46, 46),
        ),
        icon: Icon(icon, size: 21),
      );
  Widget _home() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route_rounded, color: mint, size: 23),
            const SizedBox(width: 9),
            eyebrow('SKYWAY COURIER', color: Colors.white),
            const Spacer(),
            wallet(),
          ],
        ),
        const SizedBox(height: 25),
        eyebrow('THE CITY IS YOUR RUNWAY', color: mint),
        const SizedBox(height: 8),
        const Text(
          'SPECIAL DELIVERY.\nENDLESS POSSIBILITY.',
          style: TextStyle(
            fontSize: 29,
            height: 1.06,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'One courier. A whole sky of possibilities.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: mint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  eyebrow('01 / SKYWAY DISTRICT', color: mint),
                  const Spacer(),
                  eyebrow('OFFLINE • READY'),
                ],
              ),
            ),
          ),
        ),
        _card(
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: gold, size: 27),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    eyebrow('PERSONAL BEST'),
                    const SizedBox(height: 5),
                    Text(
                      '${app.progress.snapshot.highScore}',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  eyebrow('LONGEST RUN'),
                  const SizedBox(height: 7),
                  Text(
                    '${app.progress.snapshot.maximumDistance.floor()} m',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          height: 62,
          child: FilledButton(
            onPressed: () => app.startRun(),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, size: 27),
                SizedBox(width: 9),
                Text('LET’S RUN'),
                SizedBox(width: 9),
                Icon(Icons.east_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 17),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _nav(Icons.smart_toy_outlined, 'Couriers', AppPage.characters),
            _nav(Icons.flag_outlined, 'Missions', AppPage.missions),
            _nav(Icons.bolt_outlined, 'Upgrades', AppPage.upgrades),
            _nav(Icons.tune_rounded, 'Settings', AppPage.settings),
          ],
        ),
      ],
    ),
  );
  Widget _nav(IconData icon, String label, AppPage page) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: () => app.navigate(page),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: muted, size: 23),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ),
    ),
  );
  Widget _card(Widget child, {Color? color}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color ?? panel.withValues(alpha: .93),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
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
            fontWeight: FontWeight.w800,
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
          top: 16,
          left: 20,
          right: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    eyebrow('SCORE', color: mint),
                    Text(
                      '${g.score.floor()}'.padLeft(6, '0'),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${g.distance.floor()} m  /  ${g.biome}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _pill(PowerUp.coins, '${g.coins}', gold, balance: true),
                  const SizedBox(height: 7),
                  Text(
                    '${g.baseMultiplier * (g.powers.containsKey(PowerUp.score) ? 2 : 1)}×',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: mint,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              circleButton(Icons.pause_rounded, 'Pause', app.pause),
            ],
          ),
        ),
        if (g.powers.isNotEmpty)
          Positioned(
            top: 125,
            left: 20,
            right: 20,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in g.powers.entries)
                  _pill(
                    p.key,
                    '${powerName(p.key)} ${p.value.ceil()}s',
                    powerColor(p.key),
                  ),
              ],
            ),
          ),
        if (g.tutorialStep >= 0)
          Positioned(
            left: 24,
            right: 24,
            top: 140,
            child: _card(
              Column(
                children: [
                  eyebrow('COURIER TRAINING', color: mint),
                  const SizedBox(height: 14),
                  Icon(
                    [
                      Icons.swipe_left_rounded,
                      Icons.swipe_right_rounded,
                      Icons.swipe_up_rounded,
                      Icons.swipe_down_rounded,
                      Icons.hexagon_rounded,
                    ][g.tutorialStep],
                    color: mint,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    [
                      'SWIPE LEFT',
                      'SWIPE RIGHT',
                      'SWIPE UP TO JUMP',
                      'SWIPE DOWN TO SLIDE',
                      'FOLLOW THE COINS',
                    ][g.tutorialStep],
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${g.tutorialStep + 1} OF 5   •   Arrow keys work too',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        if (g.phase == RunPhase.running && g.tutorialStep < 0)
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Center(
              child: eyebrow(
                g.pursuitRecovery > 0
                    ? 'PATROL CLOSE · STAY CLEAR ${g.pursuitRecovery.ceil()}s'
                    : 'SWIPE TO MOVE · UP TO JUMP · DOWN TO SLIDE',
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
                  color: mint,
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
                    fontWeight: FontWeight.w900,
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
      color: ink.withValues(alpha: .85),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: .2)),
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
    color: ink.withValues(alpha: .91),
    alignment: Alignment.center,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: child,
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
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
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
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 20),
      Text(
        '${app.game.score.floor()}',
        style: const TextStyle(
          fontSize: 67,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
        ),
      ),
      eyebrow(app.game.captured ? 'CAUGHT BY PATROL' : 'DELIVERY INTERRUPTED'),
      eyebrow('BEST ${app.progress.snapshot.highScore}'),
      const SizedBox(height: 26),
      _card(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat('${app.game.distance.floor()} m', 'DISTANCE'),
            _stat('+${app.game.coins}', 'COINS', color: gold),
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
  Widget _stat(String value, String label, {Color color = Colors.white}) =>
      Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 25,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          eyebrow(label),
        ],
      );
  Widget _characters() {
    final c = CharacterDefinition.all.firstWhere(
      (c) => c.id == app.previewCharacter,
    );
    final owned = app.progress.snapshot.unlocked.contains(c.id),
        selected = app.progress.snapshot.selected == c.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        children: [
          _header('Your crew'),
          const SizedBox(height: 21),
          eyebrow('SAME SKILLS. DIFFERENT SPIRIT.', color: mint),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final candidate in CharacterDefinition.all)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: InkWell(
                    onTap: () => app.preview(candidate.id),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 78,
                      height: 67,
                      decoration: BoxDecoration(
                        color: panel,
                        border: Border.all(
                          color: c.id == candidate.id
                              ? Color(candidate.color)
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.smart_toy_outlined,
                            color: Color(candidate.color),
                            size: 25,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            candidate.name,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            c.name,
            style: TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.w900,
              color: Color(c.color),
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 5),
          eyebrow(c.role),
          const SizedBox(height: 21),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  (!owned && app.progress.snapshot.wallet < c.price) || selected
                  ? null
                  : () {
                      app.unlockOrSelect();
                    },
              child: Text(
                selected
                    ? 'YOUR ACTIVE COURIER'
                    : owned
                    ? 'SELECT COURIER'
                    : 'UNLOCK • ${c.price} COINS',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(String title, List<Widget> children) => Container(
    color: ink.withValues(alpha: .95),
    child: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        children: [_header(title), const SizedBox(height: 30), ...children],
      ),
    ),
  );
  Widget _missions() => _page('Missions', [
    eyebrow('A LITTLE FURTHER, EVERY RUN.', color: mint),
    const SizedBox(height: 12),
    const Text(
      'Make every\ndelivery count.',
      style: TextStyle(
        fontSize: 33,
        fontWeight: FontWeight.w900,
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
                  backgroundColor: Colors.white10,
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
        fontWeight: FontWeight.w900,
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
                            fontWeight: FontWeight.w800,
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
                      fontWeight: FontWeight.w800,
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
                              : Colors.white10,
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
                      minimumSize: const Size(135, 43),
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
          const Divider(color: Colors.white10),
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
        child: Text(app.audio.error!, style: const TextStyle(color: gold)),
      ),
    const SizedBox(height: 30),
    Center(child: eyebrow('SKYWAY COURIER / 1.0.0')),
    const SizedBox(height: 8),
    const Center(
      child: Text(
        'Original world. Yours to explore.',
        style: TextStyle(color: muted, fontSize: 11),
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
  PowerUp.magnet => const Color(0xffb4a1ff),
  PowerUp.shield => mint,
  PowerUp.score => const Color(0xff80c7ff),
  PowerUp.coins => gold,
};
