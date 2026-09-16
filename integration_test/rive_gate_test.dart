import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart' as rive;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Rive GPU Canvas loads and disposes', (tester) async {
    await rive.RiveNative.init();
    rive.RiveNative.debugRenderTextureLogging = true;
    final file = await rive.File.asset(
      'assets/rive/skyway.riv',
      riveFactory: rive.Factory.rive,
    );
    expect(file, isNotNull);
    final controller = rive.RiveWidgetController(file!);
    final boundaryKey = GlobalKey();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: rive.RiveWidget(
                controller: controller,
                fit: rive.Fit.contain,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(tester.takeException(), isNull);
      final box = tester.renderObject(
        find.byType(rive.RiveArtboardWidget),
      ) as rive.RiveNativeRenderBox;
      for (var i = 0; i < 5; i++) {
        box.paintTexture(1 / 60, forceShouldAdvance: true);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      debugPrint(
        'Rive texture ${box.renderTexture.textureId}, ready=${box.renderTexture.isReady}, size=${box.renderTexture.actualWidth}x${box.renderTexture.actualHeight}, FLUTTER_TEST=${Platform.environment['FLUTTER_TEST']}',
      );
      await tester.runAsync(() async {
        final data = await const MethodChannel('skyway/texture_capture')
            .invokeMethod<Uint8List>('capture', box.renderTexture.textureId);
        final codec = await ui.instantiateImageCodec(data!);
        final image = (await codec.getNextFrame()).image;
        debugPrint("gate image ${image.width}x${image.height}");
        final pixels = (await image.toByteData())!;
        final colors = <int>{};
        for (var i = 0; i < pixels.lengthInBytes; i += 4) {
          colors.add(pixels.getUint32(i));
        }
        debugPrint("gate colors ${colors.length}");
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${Directory.systemTemp.path}/skyway-native-gate.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
        codec.dispose();
        expect(
          colors.length,
          greaterThan(100),
          reason: 'GPU output must contain shaded geometry',
        );
      });
      controller.active = false;
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      file.dispose();
      rive.RiveNative.debugRenderTextureLogging = false;
    }
  }, skip: !const bool.fromEnvironment('SKYWAY_VERIFY_RIVE'));
}
