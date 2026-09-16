// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings
// Original rounded, weighted courier meshes. Run with the pinned Dart SDK.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';

import 'generate_assets.dart' show Glb;
import 'courier_animation.dart';

const joints = <List<num>>[
  [-1, 0, 0, 0],
  [0, 0, .92, 0],
  [1, 0, .23, 0],
  [2, 0, .23, 0],
  [3, 0, .20, 0],
  [4, 0, .13, 0],
  [3, -.30, 0, 0],
  [6, 0, -.29, 0],
  [7, 0, -.25, 0],
  [3, .30, 0, 0],
  [9, 0, -.29, 0],
  [10, 0, -.25, 0],
  [1, -.15, 0, 0],
  [12, 0, -.44, 0],
  [13, 0, -.39, 0],
  [1, .15, 0, 0],
  [15, 0, -.44, 0],
  [16, 0, -.39, 0],
  [3, 0, -.12, -.28],
  [5, 0, .13, 0],
];
const jointNames = [
  'Root',
  'Pelvis',
  'Spine',
  'Chest',
  'Neck',
  'Head',
  'LeftShoulder',
  'LeftElbow',
  'LeftHand',
  'RightShoulder',
  'RightElbow',
  'RightHand',
  'LeftHip',
  'LeftKnee',
  'LeftAnkle',
  'RightHip',
  'RightKnee',
  'RightAnkle',
  'Bag',
  'Cap',
];
final bind = <List<double>>[];

class Mesh {
  final v = <double>[], indices = <int>[];
  void shape(
    int bone,
    List<double> center,
    List<double> radius,
    List<double> color, {
    double square = 1,
    int material = 0,
    int rings = 8,
    int sides = 12,
    bool blend = false,
  }) {
    final base = v.length ~/ 14;
    double power(double n) => n.sign * math.pow(n.abs(), square).toDouble();
    for (var r = 0; r <= rings; r++) {
      final a = math.pi * r / rings;
      for (var s = 0; s <= sides; s++) {
        final b = math.pi * 2 * s / sides;
        final unit = [
          math.sin(a) * math.cos(b),
          math.cos(a),
          math.sin(a) * math.sin(b),
        ];
        final normal = List.generate(
          3,
          (i) => unit[i].sign * math.pow(unit[i].abs(), 2 - square) / radius[i],
        );
        final length = math.sqrt(normal.fold(0.0, (n, e) => n + e * e));
        final weight = blend ? ((unit[1] - .5) * .55).clamp(0.0, .22) : 0.0;
        v.addAll([
          for (var i = 0; i < 3; i++)
            bind[bone][i] + center[i] + power(unit[i]) * radius[i],
          for (var i = 0; i < 3; i++) normal[i] / length,
          ...color,
          material.toDouble(),
          bone.toDouble(),
          math.max(0, joints[bone][0].toInt()).toDouble(),
          weight,
          0,
        ]);
      }
    }
    for (var r = 0; r < rings; r++) {
      for (var s = 0; s < sides; s++) {
        final a = base + r * (sides + 1) + s, b = a + sides + 1;
        indices.addAll([a, a + 1, b, a + 1, b + 1, b]);
      }
    }
  }

  // Extruded star-shaped outlines, with outward winding on both faces.
  void badge(List<List<double>> points, double depth, List<double> color) {
    for (final sign in [-1.0, 1.0]) {
      final base = v.length ~/ 14;
      for (final p in [
        [0.0, 0.0],
        ...points,
      ]) {
        v.addAll([
          p[0],
          p[1],
          depth * sign,
          0,
          0,
          sign,
          ...color,
          0,
          0,
          0,
          0,
          0,
        ]);
      }
      for (var i = 0; i < points.length; i++) {
        final a = base + 1 + i, b = base + 1 + (i + 1) % points.length;
        indices.addAll(sign > 0 ? [base, a, b] : [base, b, a]);
      }
    }
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length];
      final dx = b[0] - a[0],
          dy = b[1] - a[1],
          length = math.sqrt(dx * dx + dy * dy);
      final base = v.length ~/ 14;
      for (final p in [
        [a[0], a[1], -depth],
        [b[0], b[1], -depth],
        [b[0], b[1], depth],
        [a[0], a[1], depth],
      ]) {
        v.addAll([...p, dy / length, -dx / length, 0, ...color, 0, 0, 0, 0, 0]);
      }
      indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
    }
  }

  void box(List<double> c, List<double> size, List<double> color) {
    for (var axis = 0; axis < 3; axis++) {
      for (final sign in [-1.0, 1.0]) {
        final base = v.length ~/ 14, u = (axis + 1) % 3, w = (axis + 2) % 3;
        for (final corner in [
          [-1.0, -1.0],
          [1.0, -1.0],
          [1.0, 1.0],
          [-1.0, 1.0],
        ]) {
          final p = List<double>.from(c), n = List<double>.filled(3, 0);
          p[axis] += size[axis] * sign / 2;
          p[u] += size[u] * corner[0] / 2;
          p[w] += size[w] * corner[1] / 2;
          n[axis] = sign;
          v.addAll([...p, ...n, ...color, 0, 0, 0, 0, 0]);
        }
        indices.addAll(
          sign > 0
              ? [base, base + 1, base + 2, base, base + 2, base + 3]
              : [base, base + 2, base + 1, base, base + 3, base + 2],
        );
      }
    }
  }

  void save(String name, {bool animated = false, List<double>? outfit}) {
    final data = ByteData(8 + v.length * 4 + indices.length * 2);
    data.setUint32(0, v.length ~/ 14, Endian.little);
    data.setUint32(4, indices.length, Endian.little);
    for (var i = 0; i < v.length; i++) {
      data.setFloat32(8 + i * 4, v[i], Endian.little);
    }
    for (var i = 0; i < indices.length; i++) {
      data.setUint16(8 + v.length * 4 + i * 2, indices[i], Endian.little);
    }
    File('art/skyway/$name.bin').writeAsBytesSync(data.buffer.asUint8List());
    final g = Glb();
    final pos = <double>[],
        normal = <double>[],
        color = <double>[],
        weights = <double>[];
    final bones = <int>[];
    for (var i = 0; i < v.length; i += 14) {
      pos.addAll(v.sublist(i, i + 3));
      normal.addAll(v.sublist(i + 3, i + 6));
      color.addAll(
        v[i + 9] > .5 && outfit != null ? outfit : v.sublist(i + 6, i + 9),
      );
      bones.addAll([
        v[i + 10].toInt(),
        v[i + 12] > 0 ? v[i + 11].toInt() : 0,
        0,
        0,
      ]);
      weights.addAll([1 - v[i + 12], v[i + 12], 0, 0]);
    }
    for (var i = 0; i < joints.length; i++) {
      g.nodes.add({
        'name': jointNames[i],
        'translation': joints[i].sublist(1),
        if (joints.any((j) => j[0] == i))
          'children': [
            for (var j = i + 1; j < joints.length; j++)
              if (joints[j][0] == i) j,
          ],
      });
    }
    final inverse = <double>[];
    for (final p in bind) {
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
    if (animated) {
      g.skins.add({
        'joints': List.generate(joints.length, (i) => i),
        'skeleton': 0,
        'inverseBindMatrices': g.accessor(inverse, 16),
      });
    }
    g.material([1, 1, 1]);
    g.meshes.add({
      'primitives': [
        {
          'material': 0,
          'attributes': {
            'POSITION': g.accessor(pos, 3),
            'NORMAL': g.accessor(normal, 3),
            'COLOR_0': g.accessor(color, 3),
            if (animated) 'JOINTS_0': g.accessor(bones, 4, joints: true),
            if (animated) 'WEIGHTS_0': g.accessor(weights, 4),
          },
          'indices': g.accessor(indices, 1, indices: true),
        },
      ],
    });
    if (!animated) {
      g.nodes.clear();
      g.skins.clear();
    }
    g.nodes.add({'name': name, 'mesh': 0, if (animated) 'skin': 0});
    Directory('art/models').createSync(recursive: true);
    if (animated) addCourierClips(g);
    g.save('art/models/$name.glb', animated ? [0, joints.length] : [0]);
    Directory('assets/native_models').createSync(recursive: true);
    File('art/models/$name.glb').copySync('assets/native_models/$name.glb');
    print(
      '$name: ${v.length ~/ 14} vertices, ${indices.length ~/ 3} triangles, ${joints.length} joints',
    );
  }
}

void main() {
  for (final j in joints) {
    final parent = j[0].toInt();
    bind.add(
      List.generate(
        3,
        (i) => j[i + 1].toDouble() + (parent < 0 ? 0 : bind[parent][i]),
      ),
    );
  }
  Directory('art/skyway').createSync(recursive: true);
  for (final officer in [false, true]) {
    final m = Mesh();
    const skin = [.70, .39, .23],
        hair = [.12, .055, .035],
        pants = [.055, .10, .17],
        sole = [.78, .87, .89],
        white = [.94, .96, .90];
    final jacket = officer ? [.06, .16, .28] : [.10, .70, .60];
    m.shape(1, [0, 0, 0], [.25, .17, .17], pants, square: .65);
    m.shape(
      2,
      [0, .06, 0],
      [.26, .23, .17],
      jacket,
      square: .75,
      material: officer ? 0 : 1,
      blend: true,
    );
    m.shape(
      3,
      [0, -.03, 0],
      [.30, .19, .18],
      jacket,
      square: .8,
      material: officer ? 0 : 1,
      blend: true,
    );
    m.shape(4, [0, .015, 0], [.085, .09, .08], skin);
    m.shape(5, [0, .01, 0], [.165, .20, .15], skin);
    m.shape(5, [0, .095, -.06], [.17, .15, .115], hair);
    m.shape(5, [-.164, .01, 0], [.032, .054, .04], skin);
    m.shape(5, [.164, .01, 0], [.032, .054, .04], skin);
    m.shape(5, [0, .00, .148], [.037, .051, .048], skin);
    for (final side in [-1.0, 1.0]) {
      m.shape(5, [side * .066, .049, .136], [.041, .029, .024], white);
      m.shape(5, [side * .066, .048, .157], [.014, .019, .010], pants);
      m.shape(5, [side * .066, .089, .145], [.043, .009, .012], hair);
    }
    m.shape(5, [0, -.072, .145], [.058, .010, .015], hair);
    m.shape(
      19,
      [0, .012, -.01],
      [.177, .093, .159],
      officer ? pants : jacket,
      square: .65,
      material: officer ? 0 : 1,
    );
    m.shape(
      19,
      [0, -.048, .17],
      [.19, .023, .13],
      officer ? pants : jacket,
      square: .6,
      material: officer ? 0 : 1,
    );
    for (final arm in [6, 9]) {
      m.shape(
        arm,
        [0, -.10, 0],
        [.115, .19, .11],
        jacket,
        material: officer ? 0 : 1,
        blend: true,
      );
      m.shape(
        arm + 1,
        [0, -.115, 0],
        [.078, .155, .077],
        officer ? jacket : skin,
        blend: true,
      );
      m.shape(arm + 2, [0, -.035, .013], [.073, .08, .06], skin);
    }
    for (final leg in [12, 15]) {
      m.shape(leg, [0, -.18, 0], [.13, .25, .14], pants, blend: true);
      m.shape(leg + 1, [0, -.17, -.006], [.095, .23, .10], pants, blend: true);
      m.shape(
        leg + 2,
        [0, -.015, .060],
        [.108, .078, .19],
        officer ? pants : jacket,
        square: .6,
        material: officer ? 0 : 1,
      );
      m.shape(leg + 2, [0, -.066, .065], [.113, .023, .195], sole, square: .5);
      m.shape(leg + 2, [0, .043, .1], [.05, .008, .07], white, square: .5);
    }
    if (officer) {
      m.shape(3, [.12, .01, .183], [.055, .069, .013], [1, .72, .22], sides: 6);
      m.shape(1, [0, .1, .017], [.27, .04, .18], hair, square: .4);
      m.shape(1, [0, .1, .193], [.055, .04, .012], [.7, .75, .8], square: .4);
      m.shape(19, [0, -.006, .145], [.04, .044, .014], [1, .72, .22], sides: 6);
      m.shape(3, [-.19, .08, .14], [.052, .08, .04], pants, square: .4);
    } else {
      m.shape(18, [0, -.03, -.10], [.32, .29, .18], [
        .88,
        .22,
        .10,
      ], square: .33);
      m.shape(18, [0, .245, -.10], [.335, .038, .19], [1, .65, .2], square: .4);
      m.shape(18, [0, -.03, -.284], [.13, .13, .009], [1, .83, .4]);
      for (final x in [-.04, .04]) {
        m.shape(18, [x, -.02, -.296], [.026, .026, .008], [.75, .14, .07]);
      }
      for (final side in [-1.0, 1.0]) {
        m.shape(
          3,
          [side * .19, -.08, .14],
          [.028, .22, .028],
          pants,
          square: .45,
        );
      }
      m.shape(3, [0, .015, .178], [.05, .07, .012], [1, .72, .22], sides: 3);
    }
    m.save(officer ? 'officer' : 'courier', animated: true);
    if (!officer) {
      m.save('pip', animated: true);
      m.save('volt', animated: true, outfit: [.95, .5, .11]);
      m.save('nova', animated: true, outfit: [.5, .32, .85]);
    }
  }
  final floor = Mesh()
    ..shape(0, [0, -.13, 0], [3.4, .12, 12], [.14, .24, .30], square: .08);
  floor.save('track');
  final pod = Mesh()
    ..shape(0, [0, 1.15, 0], [.65, 1.15, .6], [.82, .31, .10], square: .25)
    ..shape(0, [0, 1.2, -.61], [.42, .48, .025], [.055, .14, .19], square: .3)
    ..shape(0, [0, 1.8, -.63], [.4, .025, .025], [.2, .95, .8], square: .25);
  pod.save('pod');
  File('art/models/rig.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'joints': joints,
      'names': jointNames,
      'bind': bind,
      'clips': [
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
      ],
    }),
  );
  File('art/skyway/rig.luau').writeAsStringSync(
    'return {\n' +
        [
          for (var i = 0; i < joints.length; i++)
            '  {${joints[i].join(',')},${bind[i].join(',')}}',
        ].join(',\n') +
        '\n}\n',
  );
}
