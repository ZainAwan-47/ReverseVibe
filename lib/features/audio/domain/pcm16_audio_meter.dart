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

  static List<double> waveform(Uint8List pcm, {int binCount = 48}) {
    if (binCount <= 0) {
      throw ArgumentError.value(binCount, 'binCount', 'Must be positive.');
    }

    final sampleCount = pcm.length ~/ 2;
    if (sampleCount == 0) {
      return List<double>.filled(binCount, 0);
    }

    final samples = ByteData.sublistView(pcm);
    return List<double>.generate(binCount, (bin) {
      final start = bin * sampleCount ~/ binCount;
      final end = (bin + 1) * sampleCount ~/ binCount;
      if (start == end) {
        return 0;
      }

      var sumOfSquares = 0.0;
      for (var index = start; index < end; index++) {
        final sample = samples.getInt16(index * 2, Endian.little) / 32768;
        sumOfSquares += sample * sample;
      }
      return math.sqrt(sumOfSquares / (end - start)).clamp(0, 1).toDouble();
    }, growable: false);
  }
}
