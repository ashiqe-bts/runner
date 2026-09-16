// Batched, original city meshes and recognizable gameplay props.
import 'dart:math' as math;

import 'generate_couriers.dart';

const navy = [.055, .10, .16],
    metal = [.15, .25, .31],
    mint = [.20, .91, .76],
    amber = [1.0, .63, .19],
    white = [.72, .89, .91];
void main() {
  bind.clear();
  for (final j in joints) {
    final p = j[0].toInt();
    bind.add(
      List.generate(3, (i) => j[i + 1].toDouble() + (p < 0 ? 0 : bind[p][i])),
    );
  }
  final barrier = Mesh();
  barrier.box([0, .45, 0], [1.5, .43, .34], amber);
  for (final side in [-1.0, 1.0]) {
    barrier.box([side * .55, .16, 0], [.14, .32, .34], metal);
    barrier.shape(0, [side * .63, .65, 0], [.09, .07, .08], mint);
  }
  for (final x in [-.5, 0.0, .5]) {
    barrier.box([x, .45, -.176], [.15, .37, .012], navy);
  }
  barrier.save('barrier');
  final overhead = Mesh();
  overhead.box([0, 1.35, 0], [1.5, .55, .5], navy);
  overhead.box([0, 1.075, -.27], [1.48, .05, .04], amber);
  overhead.box([0, 1.8, .15], [.12, .5, .14], metal);
  overhead.box([.45, 2.1, .15], [1.0, .12, .14], metal);
  overhead.shape(0, [0, 1.37, -.27], [.38, .15, .025], mint, square: .5);
  overhead.save('overhead');
  final drone = Mesh();
  drone.shape(0, [0, 1.25, 0], [.57, .5, .48], metal, square: .5);
  drone.shape(0, [0, 1.33, -.45], [.36, .17, .10], navy, square: .5);
  drone.shape(0, [0, 1.34, -.53], [.18, .055, .045], amber, square: .5);
  for (final side in [-1.0, 1.0]) {
    drone.box([side * .53, 1.4, 0], [.4, .09, .12], navy);
    drone.shape(0, [side * .65, 1.45, 0], [.18, .06, .35], mint);
    drone.box([side * .35, .56, 0], [.12, 1.0, .15], metal);
  }
  drone.save('drone');
  final transit = Mesh();
  transit.shape(0, [0, 1.1, 0], [1.72, 1.10, .61], metal, square: .22);
  transit.shape(0, [0, 1.6, -.61], [1.5, .42, .06], navy, square: .3);
  transit.box([0, .75, -.64], [3.4, .15, .04], mint);
  for (final side in [-1.0, 1.0]) {
    transit.shape(0, [side * 1.4, .5, -.65], [.14, .09, .025], amber);
    transit.shape(0, [side * 1.2, .13, 0], [.3, .12, .47], navy, square: .6);
  }
  transit.save('transit');
  for (var biome = 0; biome < 3; biome++) {
    final m = Mesh();
    for (final side in [-1.0, 1.0]) {
      m.box([side * 3.24, -.4, 12], [.4, .8, 24], navy);
      m.box([side * 3.24, .08, 12], [.08, .08, 24], mint);
      for (final z in [2.0, 8.0, 14.0, 20.0]) {
        m.box([side * 3.45, 1.0, z], [.1, 2, .1], metal);
        m.box([side * 3.2, 2.0, z], [.55, .09, .16], white);
      }
      for (var tower = 0; tower < 3; tower++) {
        final z = 4 + tower * 9.0,
            x = side * (9 + tower * 3.0),
            h = 12 + tower * 7.0;
        m.shape(
          0,
          [x, h / 2 - 8, z],
          [2.5, h / 2, 3.4],
          [.09 + tower * .025, .17 + tower * .02, .23 + tower * .03],
          square: .15,
          rings: 4,
          sides: 8,
        );
        m.box([x, h - 8, z], [3, .3, 4], metal);
        m.box([x, h - 6.5, z], [.1, 3, .1], mint);
        for (var f = 0; f < 7; f++) {
          m.box(
            [x - side * 2.52, -5 + f * (h - 3) / 7, z],
            [.035, .13, 5.0],
            f.isEven ? mint : amber,
          );
          m.box([x, -5 + f * (h - 3) / 7, z - 3.42], [3.8, .10, .03], mint);
        }
      }
      if (biome < 2) {
        // Distant hover traffic is batched into the section's shared mesh.
        final z = side < 0 ? 7.0 : 18.0;
        m.shape(
          0,
          [side * 6.5, 1.0, z],
          [.48, .24, 1.0],
          metal,
          square: .4,
          rings: 4,
          sides: 8,
        );
        m.shape(
          0,
          [side * 6.5, 1.24, z],
          [.36, .13, .55],
          navy,
          square: .5,
          rings: 4,
          sides: 8,
        );
        m.box([side * 6.5, .8, z], [.8, .035, 1.5], mint);
        for (final offset in [-.30, .30]) {
          m.box([side * 6.5 + offset, 1.0, z - 1], [.12, .08, .03], amber);
        }
      }
      if (biome == 1) {
        m.box([side * 4.25, .1, 12], [1.25, .35, 24], metal);
        for (final z in [4.0, 12.0, 20.0]) {
          m.box([side * 4.4, 2.5, z], [.28, 5, .28], metal);
          m.shape(
            0,
            [side * 4.2, 1.0, z + 2],
            [.25, .8, .35],
            navy,
            square: .3,
          );
          m.box([side * 4.15, 1.35, z + 1.63], [.3, .4, .03], mint);
        }
      }
      if (biome == 2) {
        m.box([side * 4.0, 2.35, 12], [.4, 4.7, 24], navy);
        for (final y in [.8, 2.0, 3.6]) {
          m.box([side * 3.77, y, 12], [.06, .06, 24], y == 2 ? amber : mint);
        }
        for (final z in [0.0, 6.0, 12.0, 18.0, 24.0]) {
          m.box([side * 3.7, 2.2, z], [.18, 4.4, .22], metal);
        }
      }
    }
    if (biome > 0) {
      m.box([0, 4.8, 12], [8.5, .22, 24], navy);
      for (final z in [0.0, 6.0, 12.0, 18.0, 24.0]) {
        m.box([0, 4.62, z], [7.8, .14, .20], metal);
        m.box([0, 4.52, z], [5, .045, .15], biome == 1 ? mint : amber);
      }
      m.box([0, 3.9, 2], [2.6, .55, .12], metal);
      lettering(m, biome == 1 ? 'EXPRESS' : 'SERVICE', 3.9, 1.92);
    }
    m.save(['skyway', 'station', 'tunnel'][biome]);
  }
  // Model geometry uses the same silhouettes as the UI icons.
  final magnet = Mesh();
  for (var i = 0; i <= 16; i++) {
    final a = math.pi * i / 16;
    magnet.shape(
      0,
      [math.cos(a) * .23, -math.sin(a) * .23, 0],
      [.075, .075, .07],
      [.68, .43, .95],
      rings: 4,
      sides: 6,
    );
  }
  for (final side in [-1.0, 1.0]) {
    magnet.box([side * .23, .12, 0], [.145, .25, .14], [.68, .43, .95]);
    magnet.box([side * .23, .26, 0], [.145, .1, .14], white);
  }
  magnet.save('magnet');
  final shield = Mesh();
  shield.badge(
    [
      [0, -.4],
      [.25, -.16],
      [.30, .25],
      [0, .37],
      [-.30, .25],
      [-.25, -.16],
    ],
    .08,
    mint,
  );
  shield.badge(
    [
      [0, -.26],
      [.13, -.10],
      [.17, .16],
      [0, .24],
      [-.17, .16],
      [-.13, -.10],
    ],
    .085,
    navy,
  );
  shield.save('shield');
  final star = Mesh();
  star.badge(
    [
      for (var i = 0; i < 10; i++)
        [
          math.cos(math.pi / 2 + i * math.pi / 5) * (i.isEven ? .4 : .21),
          math.sin(math.pi / 2 + i * math.pi / 5) * (i.isEven ? .4 : .21),
        ],
    ],
    .08,
    [.30, .66, 1],
  );
  doubleMark(star, .09);
  star.save('score');
  final coins = Mesh();
  coins.shape(0, [-.11, .05, 0], [.22, .25, .07], amber, sides: 12, rings: 6);
  coins.shape(0, [.11, -.05, -.1], [.22, .25, .07], amber, sides: 12, rings: 6);
  doubleMark(coins, .18);
  coins.save('coins');
}

void doubleMark(Mesh mesh, double depth) {
  const glyph = ['1110000', '0010101', '1110010', '1000101', '1110000'];
  for (final side in [-1.0, 1.0]) {
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 7; col++) {
        if (glyph[row][col] == '1') {
          mesh.box(
            [(col - 3) * .037 * side, (2 - row) * .037, depth * side],
            [.034, .034, .012],
            navy,
          );
        }
      }
    }
  }
}

void lettering(Mesh mesh, String text, double y, double z) {
  const font = {
    'E': ['111', '100', '110', '100', '111'],
    'X': ['101', '101', '010', '101', '101'],
    'P': ['110', '101', '110', '100', '100'],
    'R': ['110', '101', '110', '101', '101'],
    'S': ['111', '100', '111', '001', '111'],
    'V': ['101', '101', '101', '101', '010'],
    'I': ['111', '010', '010', '010', '111'],
    'C': ['111', '100', '100', '100', '111'],
  };
  for (var letter = 0; letter < text.length; letter++) {
    final glyph = font[text[letter]]!;
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 3; col++) {
        if (glyph[row][col] == '1') {
          mesh.box(
            [
              -(letter * 4 + col - (text.length * 4 - 2) / 2) * .07,
              y + (2 - row) * .07,
              z,
            ],
            [.055, .055, .025],
            mint,
          );
        }
      }
    }
  }
}
