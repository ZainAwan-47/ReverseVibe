import 'dart:math' as math;
import 'dart:typed_data';

abstract final class Pcm16AudioMeter {
  static double normalizedRms(Uint8List pcm) {
    final sampleCount = pcm.length ~/ 2;
    if (sampleCount == 0) {
      return 0;
    }

    final samples = ByteData.sublistView(pcm);
    var sumOfSquares = 0.0;
    for (var index = 0; index < sampleCount; index++) {
      final sample = samples.getInt16(index * 2, Endian.little) / 32768;
      sumOfSquares += sample * sample;
    }
    return math.sqrt(sumOfSquares / sampleCount).clamp(0, 1).toDouble();
  }
}
