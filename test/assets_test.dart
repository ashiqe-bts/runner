import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('portable checkout contains every required runtime asset', () {
    final required = <String>[
      'pubspec.lock',
      '.metadata',
      '.fvmrc',
      'assets/rive/skyway.riv',
      'assets/audio/wind.wav',
      for (final name in [
        'barrier',
        'coins',
        'courier',
        'drone',
        'magnet',
        'nova',
        'officer',
        'overhead',
        'pip',
        'pod',
        'score',
        'shield',
        'skyway',
        'station',
        'track',
        'transit',
        'tunnel',
        'volt',
      ])
        'assets/native_models/$name.glb',
    ];
    for (final path in required) {
      expect(File(path).existsSync(), isTrue, reason: '$path must be committed');
      expect(File(path).lengthSync(), greaterThan(0), reason: '$path must not be empty');
    }
  });

  test('human couriers and officer have normalized blended skins and articulated clips', () {
    for (final id in ['pip', 'volt', 'nova', 'officer']) {
      final bytes = File('assets/native_models/$id.glb').readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      final length = header.getUint32(12, Endian.little);
      final doc =
          jsonDecode(utf8.decode(bytes.sublist(20, 20 + length))) as Map;
      expect(doc['skins'][0]['joints'].length, 20);
      expect(
        (doc['nodes'] as List).map((n) => n['name']),
        containsAll([
          'Spine',
          'LeftElbow',
          'LeftKnee',
          'RightAnkle',
          'Bag',
          'Cap',
        ]),
      );
      expect(
        (doc['animations'] as List).map((a) => a['name']),
        containsAll([
          'Idle',
          'Run',
          'Jump',
          'Fall',
          'Land',
          'Slide',
          'Stumble',
          'Crash',
          'Pursuit',
          'Capture',
        ]),
      );
      final attributes = doc['meshes'][0]['primitives'][0]['attributes'];
      final accessor = doc['accessors'][attributes['WEIGHTS_0']];
      final view = doc['bufferViews'][accessor['bufferView']];
      final offset = 28 + length + (view['byteOffset'] as int? ?? 0);
      var blended = 0;
      for (var i = 0; i < accessor['count']; i++) {
        var sum = 0.0;
        for (var j = 0; j < 4; j++) {
          final weight = header.getFloat32(
            offset + i * 16 + j * 4,
            Endian.little,
          );
          expect(weight, inInclusiveRange(0, 1));
          sum += weight;
          if (j == 1 && weight > 0) blended++;
        }
        expect(sum, closeTo(1, 1e-6));
      }
      expect(
        blended,
        greaterThan(100),
        reason: 'Articulation must deform skin, not just move rigid blocks',
      );
    }
  });
  test('every original courier has a real skin and all eight clips', () {
    for (final id in ['pip', 'volt', 'nova']) {
      final bytes = File('assets/models/$id.glb').readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      expect(header.getUint32(0, Endian.little), 0x46546c67);
      expect(header.getUint32(8, Endian.little), bytes.length);
      final length = header.getUint32(12, Endian.little);
      final doc =
          jsonDecode(utf8.decode(bytes.sublist(20, 20 + length))) as Map;
      expect((doc['skins'] as List).single['joints'].length, 6);
      expect(
        (doc['animations'] as List).map((c) => c['name']),
        containsAll([
          'Idle',
          'Run',
          'Jump',
          'Fall',
          'Land',
          'Slide',
          'Hit',
          'Death',
        ]),
      );
      for (final primitive in doc['meshes'][0]['primitives']) {
        expect(primitive['attributes']['JOINTS_0'], isNotNull);
        expect(primitive['attributes']['WEIGHTS_0'], isNotNull);
      }
      expect(bytes.length, lessThan(200000));
    }
  });
  test('audio WAVs have consistent PCM headers and nonempty samples', () {
    for (final file in Directory('assets/audio').listSync().whereType<File>()) {
      final bytes = file.readAsBytesSync();
      expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
      expect(bytes.length, greaterThan(1000));
    }
  });
}
