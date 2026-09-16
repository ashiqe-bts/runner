import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

// Original periodic noise spectrum: exact integer frequencies make a seamless
// offline loop, with no samples or runtime synthesis dependency.
void main() {
  const rate = 22050, seconds = 4, count = rate * seconds;
  final bytes = ByteData(44 + count * 2);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 36 + count * 2, Endian.little);
  text(8, 'WAVEfmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, count * 2, Endian.little);
  final random = math.Random(9371);
  final frequencies = List.generate(96, (_) => 100 + random.nextInt(1800));
  final phases = List.generate(96, (_) => random.nextDouble() * math.pi * 2);
  for (var i = 0; i < count; i++) {
    var value = 0.0;
    for (var n = 0; n < frequencies.length; n++) {
      value +=
          math.sin(i / rate * math.pi * 2 * frequencies[n] + phases[n]) /
          math.sqrt(frequencies[n] / 100);
    }
    bytes.setInt16(
      44 + i * 2,
      (value * 1800).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  File('assets/audio/wind.wav').writeAsBytesSync(bytes.buffer.asUint8List());
}
