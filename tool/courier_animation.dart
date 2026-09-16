import 'dart:math' as math;

import 'generate_assets.dart' show Glb;

const courierClips = [
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
];
({List<double> angles, double y, double lean}) courierPose(
  String clip,
  double time,
) {
  final a = List<double>.filled(20, 0),
      cycle = time * math.pi * 2,
      swing = math.sin(cycle);
  var y = 0.0, lean = 0.0;
  switch (clip) {
    case 'Run':
    case 'Pursuit':
      y = .018 * math.cos(cycle * 2);
      lean = .07;
      for (final hip in [12, 15]) {
        final phase = (time + (hip == 12 ? 0 : .5)) % 1;
        final z = phase < .6
            ? .35 - phase / .6 * .7
            : -.35 + (phase - .6) / .4 * .7;
        final fy =
            -.79 +
            (phase < .6 ? 0 : math.sin((phase - .6) / .4 * math.pi) * .23);
        final d = math.sqrt(z * z + fy * fy).clamp(.12, .825);
        a[hip] =
            -math.atan2(z, -fy) -
            math.acos(
              ((.44 * .44 + d * d - .39 * .39) / (2 * .44 * d)).clamp(-1, 1),
            );
        a[hip + 1] =
            math.pi -
            math.acos(
              ((.44 * .44 + .39 * .39 - d * d) / (2 * .44 * .39)).clamp(-1, 1),
            );
        a[hip + 2] = -a[hip] - a[hip + 1];
      }
      a[6] = swing * .6;
      a[9] = -swing * .6;
      a[7] = -.8 - math.max(0, -swing) * .3;
      a[10] = -.8 - math.max(0, swing) * .3;
      a[18] = math.sin(cycle * 2) * .04;
    case 'Jump':
    case 'Fall':
      a[12] = -.7;
      a[13] = 1.1;
      a[15] = .35;
      a[16] = .6;
      a[6] = -1.1;
      a[9] = -.5;
      a[7] = -.6;
      a[10] = -.7;
      lean = -.08;
    case 'Land':
      final weight = 1 - time;
      y = -.13 * weight;
      a[12] = -.5 * weight;
      a[13] = weight;
      a[15] = -.5 * weight;
      a[16] = weight;
      lean = .2 * weight;
    case 'Slide':
      y = -.62;
      lean = -.45;
      a[12] = -1.25;
      a[15] = -1.15;
      a[13] = .1;
      a[16] = .25;
      a[6] = .5;
      a[9] = .4;
      a[7] = -.4;
      a[10] = -.4;
    case 'Stumble':
    case 'Hit':
      lean = .35 * math.sin(time * math.pi);
      a[6] = -1.4;
      a[9] = -1.1;
      a[13] = .4;
      a[16] = .5;
    case 'Crash':
    case 'Death':
      y = -.6 * time;
      lean = 1.3 * time;
      a[6] = -1.3;
      a[9] = -1.3;
      a[13] = .7;
      a[16] = .7;
    case 'Capture':
      a[6] = -1.2;
      a[9] = -1.2;
      a[7] = -.8;
      a[10] = -.8;
      lean = -.06;
    default:
      y = math.sin(cycle) * .008;
  }
  a[0] = lean;
  return (angles: a, y: y, lean: lean);
}

void addCourierClips(Glb g) {
  for (final name in [...courierClips, 'Hit', 'Death']) {
    final duration = switch (name) {
      'Run' || 'Pursuit' => .70,
      'Idle' => 2.0,
      'Jump' => .24,
      'Fall' => .4,
      'Land' => .12,
      'Slide' => .75,
      'Stumble' || 'Hit' => .45,
      'Crash' || 'Death' => .8,
      _ => .6,
    };
    const frames = 40;
    final times = [for (var f = 0; f <= frames; f++) f / frames * duration];
    final t = g.accessor(times, 1),
        samplers = <Map<String, dynamic>>[],
        channels = <Map<String, dynamic>>[];
    for (var bone = 0; bone < 20; bone++) {
      final q = <double>[];
      for (var f = 0; f <= frames; f++) {
        final angle = courierPose(name, f / frames).angles[bone];
        q.addAll([math.sin(angle / 2), 0, 0, math.cos(angle / 2)]);
      }
      samplers.add({
        'input': t,
        'output': g.accessor(q, 4),
        'interpolation': 'LINEAR',
      });
      channels.add({
        'sampler': samplers.length - 1,
        'target': {'node': bone, 'path': 'rotation'},
      });
    }
    final roots = <double>[];
    for (var f = 0; f <= frames; f++) {
      roots.addAll([0, courierPose(name, f / frames).y, 0]);
    }
    samplers.add({
      'input': t,
      'output': g.accessor(roots, 3),
      'interpolation': 'LINEAR',
    });
    channels.add({
      'sampler': samplers.length - 1,
      'target': {'node': 0, 'path': 'translation'},
    });
    g.animations.add({
      'name': name,
      'samplers': samplers,
      'channels': channels,
    });
  }
}
