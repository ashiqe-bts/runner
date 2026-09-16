// Original Skyway Courier assets. No external models, samples, or authoring tools.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'generate_brand.dart';

class Glb {
  final bytes = BytesBuilder();
  final views = <Map<String, dynamic>>[];
  final accessors = <Map<String, dynamic>>[];
  final nodes = <Map<String, dynamic>>[];
  final meshes = <Map<String, dynamic>>[];
  final animations = <Map<String, dynamic>>[];
  final materials = <Map<String, dynamic>>[];
  final skins = <Map<String, dynamic>>[];
  int accessor(
    List<num> values,
    int components, {
    bool indices = false,
    bool joints = false,
  }) {
    while (bytes.length % 4 != 0) {
      bytes.addByte(0);
    }
    final short = indices || joints;
    final data = ByteData(values.length * (short ? 2 : 4));
    for (var i = 0; i < values.length; i++) {
      if (short) {
        data.setUint16(i * 2, values[i].toInt(), Endian.little);
      } else {
        data.setFloat32(i * 4, values[i].toDouble(), Endian.little);
      }
    }
    views.add({
      'buffer': 0,
      'byteOffset': bytes.length,
      'byteLength': data.lengthInBytes,
    });
    bytes.add(data.buffer.asUint8List());
    accessors.add({
      'bufferView': views.length - 1,
      'componentType': short ? 5123 : 5126,
      'count': values.length ~/ components,
      'type': components == 16
          ? 'MAT4'
          : components == 1
          ? 'SCALAR'
          : 'VEC$components',
      if (!joints && components <= 3)
        'min': List.generate(
          components,
          (a) => List.generate(
            values.length ~/ components,
            (i) => values[i * components + a],
          ).reduce((a, b) => a < b ? a : b),
        ),
      if (!joints && components <= 3)
        'max': List.generate(
          components,
          (a) => List.generate(
            values.length ~/ components,
            (i) => values[i * components + a],
          ).reduce((a, b) => a > b ? a : b),
        ),
    });
    return accessors.length - 1;
  }

  int material(List<double> rgb, {bool glow = false}) {
    materials.add({
      'name': 'Skyway ${materials.length}',
      'pbrMetallicRoughness': {
        'baseColorFactor': [...rgb, 1],
        'metallicFactor': 0.25,
        'roughnessFactor': 0.65,
      },
      if (glow) 'emissiveFactor': rgb,
    });
    return materials.length - 1;
  }

  Map<String, dynamic> box(
    List<double> c,
    List<double> s,
    int mat, {
    int? bone,
  }) {
    final positions = <double>[], normals = <double>[], weights = <double>[];
    final indices = <int>[], joints = <int>[];
    const faces = [
      [
        [1, 0, 0],
        [1, -1, -1],
        [1, 1, -1],
        [1, 1, 1],
        [1, -1, 1],
      ],
      [
        [-1, 0, 0],
        [-1, -1, 1],
        [-1, 1, 1],
        [-1, 1, -1],
        [-1, -1, -1],
      ],
      [
        [0, 1, 0],
        [-1, 1, -1],
        [-1, 1, 1],
        [1, 1, 1],
        [1, 1, -1],
      ],
      [
        [0, -1, 0],
        [-1, -1, 1],
        [-1, -1, -1],
        [1, -1, -1],
        [1, -1, 1],
      ],
      [
        [0, 0, 1],
        [-1, -1, 1],
        [1, -1, 1],
        [1, 1, 1],
        [-1, 1, 1],
      ],
      [
        [0, 0, -1],
        [1, -1, -1],
        [-1, -1, -1],
        [-1, 1, -1],
        [1, 1, -1],
      ],
    ];
    for (final face in faces) {
      final start = positions.length ~/ 3;
      for (final p in face.skip(1)) {
        for (var k = 0; k < 3; k++) {
          positions.add(c[k] + p[k] * s[k] / 2);
          normals.add(face[0][k].toDouble());
        }
        joints.addAll([bone ?? 0, 0, 0, 0]);
        weights.addAll([1, 0, 0, 0]);
      }
      indices.addAll([
        start,
        start + 1,
        start + 2,
        start,
        start + 2,
        start + 3,
      ]);
    }
    return {
      'attributes': {
        'POSITION': accessor(positions, 3),
        'NORMAL': accessor(normals, 3),
        if (bone != null) 'JOINTS_0': accessor(joints, 4, joints: true),
        if (bone != null) 'WEIGHTS_0': accessor(weights, 4),
      },
      'indices': accessor(indices, 1, indices: true),
      'material': mat,
    };
  }

  void save(String path, List<int> roots) {
    final bin = bytes.takeBytes();
    List<int> json = utf8.encode(
      jsonEncode({
        'asset': {
          'version': '2.0',
          'generator': 'Skyway original Dart asset generator',
        },
        'scene': 0,
        'scenes': [
          {'nodes': roots},
        ],
        'nodes': nodes,
        'meshes': meshes,
        'materials': materials,
        'accessors': accessors,
        'bufferViews': views,
        'buffers': [
          {'byteLength': bin.length},
        ],
        if (skins.isNotEmpty) 'skins': skins,
        if (animations.isNotEmpty) 'animations': animations,
      }),
    );
    while (json.length % 4 != 0) {
      json = [...json, 32];
    }
    final length = 12 + 8 + json.length + 8 + ((bin.length + 3) ~/ 4) * 4;
    final out = ByteData(length)
      ..setUint32(0, 0x46546c67, Endian.little)
      ..setUint32(4, 2, Endian.little)
      ..setUint32(8, length, Endian.little)
      ..setUint32(12, json.length, Endian.little)
      ..setUint32(16, 0x4e4f534a, Endian.little);
    final raw = out.buffer.asUint8List();
    raw.setRange(20, 20 + json.length, json);
    out.setUint32(20 + json.length, ((bin.length + 3) ~/ 4) * 4, Endian.little);
    out.setUint32(24 + json.length, 0x004e4942, Endian.little);
    raw.setRange(28 + json.length, 28 + json.length + bin.length, bin);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(raw);
  }
}

void runner(String name, List<double> color, int style) {
  final g = Glb();
  final paint = g.material(color),
      dark = g.material([0.035, 0.075, 0.12]),
      white = g.material([0.8, 0.89, 0.91]),
      glow = g.material([0.15, 0.95, 0.84], glow: true),
      gold = g.material([1, 0.57, 0.13]);
  // Six independently animated joints with actual skin weights and inverse binds.
  final pivots = <List<double>>[
    [0, 0, 0],
    [0, 1.52, 0],
    [-0.48, 1.35, 0],
    [0.48, 1.35, 0],
    [-0.23, 0.77, 0],
    [0.23, 0.77, 0],
  ];
  final names = ['Root', 'Head', 'LeftArm', 'RightArm', 'LeftLeg', 'RightLeg'];
  for (var i = 0; i < 6; i++) {
    g.nodes.add({
      'name': names[i],
      'translation': pivots[i],
      if (i == 0) 'children': [1, 2, 3, 4, 5],
    });
  }
  final inverse = <double>[];
  for (final p in pivots) {
    inverse.addAll([
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      -p[0],
      -p[1],
      -p[2],
      1,
    ]);
  }
  g.skins.add({
    'joints': [0, 1, 2, 3, 4, 5],
    'skeleton': 0,
    'inverseBindMatrices': g.accessor(inverse, 16),
  });
  final parts = <Map<String, dynamic>>[];
  void box(List<double> p, List<double> s, int m, int j) =>
      parts.add(g.box(p, s, m, bone: j));
  box([0, 1.12, 0], [0.8, 0.72, 0.48], paint, 0);
  box([0, 1.22, -0.27], [0.48, 0.3, 0.12], white, 0);
  box([0, 1.25, -0.34], [0.13, 0.14, 0.04], gold, 0);
  box([0, 1.09, 0.32], [0.55, 0.53, 0.22], dark, 0); // courier battery pack
  box([0, 1.72, 0], [0.73, 0.52, 0.56], white, 1);
  box([0, 1.73, -0.3], [0.59, 0.23, 0.05], dark, 1);
  for (final x in [-0.16, 0.16]) {
    box([x, 1.74, -0.34], [0.11, 0.08, 0.04], glow, 1);
  }
  box([0.25, 2.07, 0], [0.06, 0.23, 0.06], gold, 1);
  for (var side = 0; side < 2; side++) {
    final x = side == 0 ? -1.0 : 1.0;
    box([x * 0.52, 1.03, 0], [0.25, 0.66, 0.29], paint, side + 2);
    box([x * 0.52, 0.71, 0], [0.28, 0.19, 0.32], dark, side + 2);
    box([x * 0.23, 0.46, 0], [0.29, 0.64, 0.32], dark, side + 4);
    box([x * 0.23, 0.12, -0.1], [0.34, 0.23, 0.54], paint, side + 4);
    if (style > 0) {
      box([x * 0.46, 1.48, 0], [0.33 + style * 0.06, 0.13, 0.43], gold, 0);
    }
  }
  g.meshes.add({'name': name, 'primitives': parts});
  g.nodes.add({'name': 'CourierSkin', 'mesh': 0, 'skin': 0});
  for (final clip in [
    'Idle',
    'Run',
    'Jump',
    'Fall',
    'Land',
    'Slide',
    'Hit',
    'Death',
  ]) {
    final duration = clip == 'Run'
        ? 0.64
        : clip == 'Slide'
        ? 0.75
        : clip == 'Death'
        ? 0.8
        : 1.0;
    final samplers = <Map<String, dynamic>>[],
        channels = <Map<String, dynamic>>[];
    final times = List.generate(9, (i) => i * duration / 8);
    final input = g.accessor(times, 1);
    for (var joint = 0; joint < 6; joint++) {
      final rotations = <double>[];
      for (var i = 0; i < 9; i++) {
        final t = i / 8, wave = math.sin(t * math.pi * 2);
        double angle = 0;
        if (clip == 'Run' && joint >= 2) {
          angle = wave * (joint.isEven ? 1 : -1) * (joint >= 4 ? 0.65 : 0.5);
        }
        if (clip == 'Idle' && joint == 1) angle = wave * 0.05;
        if (clip == 'Jump') {
          angle = joint >= 4
              ? -0.65
              : joint >= 2
              ? 1.2
              : 0.05;
        }
        if (clip == 'Fall') angle = joint >= 2 ? 0.4 : 0.1;
        if (clip == 'Land') {
          angle = joint >= 4 ? -0.25 * math.sin(t * math.pi) : 0;
        }
        if (clip == 'Slide') {
          angle = joint == 0
              ? -1.05
              : joint >= 4
              ? 0.7
              : 0;
        }
        if (clip == 'Hit') angle = joint == 0 ? -t * 0.4 : 0;
        if (clip == 'Death') {
          angle = joint == 0 ? -math.min(1, t * 2) * 1.48 : 0;
        }
        rotations.addAll([math.sin(angle / 2), 0, 0, math.cos(angle / 2)]);
      }
      samplers.add({
        'input': input,
        'output': g.accessor(rotations, 4),
        'interpolation': 'LINEAR',
      });
      channels.add({
        'sampler': samplers.length - 1,
        'target': {'node': joint, 'path': 'rotation'},
      });
    }
    g.animations.add({
      'name': clip,
      'samplers': samplers,
      'channels': channels,
    });
  }
  g.save('assets/models/$name.glb', [0, 6]);
}

void wav(String name, double seconds, double frequency, {bool music = false}) {
  const rate = 22050;
  final count = (seconds * rate).round();
  final data = ByteData(44 + count * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + count * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, count * 2, Endian.little);
  const notes = [220.0, 277.18, 329.63, 440.0, 369.99, 329.63, 277.18, 246.94];
  for (var i = 0; i < count; i++) {
    final t = i / rate;
    final f = music
        ? notes[(t * 4).floor() % notes.length]
        : frequency * (1 + t * 0.6);
    final env = music
        ? 0.45 * math.pow(math.sin(math.pi * (t % .25) / .25), 2)
        : math.pow(1 - t / seconds, 2).toDouble();
    var v = math.sin(2 * math.pi * f * (music ? t % .25 : t)) * env * 0.3;
    if (music) {
      v +=
          math.sin(2 * math.pi * 55 * t) * 0.1 +
          math.sin(2 * math.pi * (70 - 30 * ((t * 2) % 1)) * t) *
              math.exp(-18 * ((t * 2) % 1)) *
              0.2;
    }
    data.setInt16(
      44 + i * 2,
      (v * 24000).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  File('assets/audio/$name.wav')
    ..createSync(recursive: true)
    ..writeAsBytesSync(data.buffer.asUint8List());
}

void main() {
  generateBrand();
  runner('pip', [0.05, 0.67, 0.6], 0);
  runner('volt', [0.95, 0.48, 0.12], 1);
  runner('nova', [0.48, 0.33, 0.85], 2);
  for (final entry in {
    'track': [6.0, 0.4, 24.0],
    'blocker': [1.5, 2.4, 1.3],
    'barrier': [1.7, 0.7, 0.4],
    'overhead': [1.8, 0.5, 0.5],
    'coin': [0.3, 0.3, 0.1],
  }.entries) {
    final g = Glb();
    final m = g.material([0.1, 0.4, 0.45]);
    g.meshes.add({
      'primitives': [
        g.box([0, 0, 0], entry.value, m),
      ],
    });
    g.nodes.add({'mesh': 0});
    g.save('assets/models/${entry.key}.glb', [0]);
  }
  for (final e in {
    'jump': 400.0,
    'land': 120.0,
    'slide': 180.0,
    'coin': 980.0,
    'powerup': 660.0,
    'hit': 65.0,
    'button': 540.0,
    'gameover': 110.0,
    'step': 90.0,
  }.entries) {
    wav(e.key, e.key == 'gameover' ? 0.8 : 0.16, e.value);
  }
  wav('skyway', 16, 220, music: true);
  stdout.writeln('Generated 8 original GLBs (3 skinned couriers) and 10 WAVs.');
}
