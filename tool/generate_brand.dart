import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

int crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

void icon(String path, int size) {
  final scan = BytesBuilder();
  for (var y = 0; y < size; y++) {
    scan.addByte(0);
    for (var x = 0; x < size; x++) {
      final u = x / size, v = y / size;
      var c = [11, 25, 37, 255];
      if (u > .15 && u < .85 && v > .27 && v < .78) c = [124, 236, 200, 255];
      if (u > .21 && u < .79 && v > .37 && v < .64) c = [17, 51, 62, 255];
      if (((u > .29 && u < .39) || (u > .61 && u < .71)) &&
          v > .44 &&
          v < .55) {
        c = [124, 236, 200, 255];
      }
      if (u > .60 && u < .67 && v > .13 && v < .27) c = [255, 194, 108, 255];
      if (u > .39 && u < .61 && v > .69 && v < .73) c = [17, 51, 62, 255];
      scan.add(c);
    }
  }
  final out = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String name, List<int> payload) {
    final type = ascii.encode(name);
    final length = ByteData(4)..setUint32(0, payload.length);
    final crc = ByteData(4)..setUint32(0, crc32([...type, ...payload]));
    out
      ..add(length.buffer.asUint8List())
      ..add(type)
      ..add(payload)
      ..add(crc.buffer.asUint8List());
  }

  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibEncoder().convert(scan.takeBytes()));
  chunk('IEND', []);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(out.takeBytes());
}

void generateBrand() {
  for (final platform in ['ios', 'macos']) {
    final root = '$platform/Runner/Assets.xcassets/AppIcon.appiconset';
    final data =
        jsonDecode(File('$root/Contents.json').readAsStringSync()) as Map;
    for (final image in data['images'] as List) {
      if (image['filename'] == null) continue;
      final points = double.parse((image['size'] as String).split('x').first);
      final scale = double.parse(
        (image['scale'] as String).replaceAll('x', ''),
      );
      icon('$root/${image['filename']}', (points * scale).round());
    }
  }
  for (final e in {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  }.entries) {
    icon('android/app/src/main/res/mipmap-${e.key}/ic_launcher.png', e.value);
  }
  for (final size in [192, 512]) {
    icon('web/icons/Icon-$size.png', size);
    icon('web/icons/Icon-maskable-$size.png', size);
  }
  icon('web/favicon.png', 32);
  icon('ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png', 72);
  icon(
    'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png',
    144,
  );
  icon(
    'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png',
    216,
  );
}

void main() => generateBrand();
