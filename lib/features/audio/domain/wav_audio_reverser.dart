import 'dart:typed_data';

import 'models/audio_clip.dart';

abstract final class WavAudioReverser {
  static AudioClip reverse(AudioClip clip) {
    final source = clip.data;
    if (source.length < 44 ||
        !_matches(source, 0, 'RIFF') ||
        !_matches(source, 8, 'WAVE')) {
      throw FormatException('The recording is not a valid WAV file.');
    }

    final header = ByteData.sublistView(source);
    final riffEnd = header.getUint32(4, Endian.little) + 8;
    if (riffEnd > source.length || riffEnd < 12) {
      throw FormatException('The WAV file has an invalid RIFF length.');
    }

    int? format;
    int? channelCount;
    int? sampleRate;
    int? byteRate;
    int? blockAlign;
    int? bitsPerSample;
    int? dataOffset;
    int? dataLength;

    var offset = 12;
    while (offset + 8 <= riffEnd) {
      final chunkLength = header.getUint32(offset + 4, Endian.little);
      final chunkStart = offset + 8;
      final chunkEnd = chunkStart + chunkLength;
      if (chunkEnd > riffEnd) {
        throw FormatException('The WAV file contains an incomplete chunk.');
      }

      if (_matches(source, offset, 'fmt ')) {
        if (format != null) {
          throw FormatException('Multiple WAV format chunks are unsupported.');
        }
        if (chunkLength < 16) {
          throw FormatException('The WAV format chunk is incomplete.');
        }
        format = header.getUint16(chunkStart, Endian.little);
        channelCount = header.getUint16(chunkStart + 2, Endian.little);
        sampleRate = header.getUint32(chunkStart + 4, Endian.little);
        byteRate = header.getUint32(chunkStart + 8, Endian.little);
        blockAlign = header.getUint16(chunkStart + 12, Endian.little);
        bitsPerSample = header.getUint16(chunkStart + 14, Endian.little);
      } else if (_matches(source, offset, 'data')) {
        if (dataOffset != null) {
          throw FormatException('Multiple WAV data chunks are unsupported.');
        }
        dataOffset = chunkStart;
        dataLength = chunkLength;
      }

      offset = chunkEnd + (chunkLength.isOdd ? 1 : 0);
      if (offset > riffEnd) {
        throw FormatException('The WAV file is missing a chunk padding byte.');
      }
    }
    if (offset != riffEnd) {
      throw FormatException(
        'The WAV file contains an incomplete chunk header.',
      );
    }

    if (format != 1 ||
        channelCount == null ||
        channelCount <= 0 ||
        sampleRate == null ||
        sampleRate <= 0 ||
        byteRate == null ||
        blockAlign == null ||
        blockAlign <= 0 ||
        bitsPerSample != 16 ||
        dataOffset == null ||
        dataLength == null ||
        channelCount != clip.channelCount ||
        sampleRate != clip.sampleRate ||
        byteRate != sampleRate * blockAlign ||
        blockAlign != channelCount * 2 ||
        dataLength % blockAlign != 0) {
      throw FormatException(
        'Only matching, uncompressed 16-bit PCM WAV recordings can be reversed.',
      );
    }

    final frameCount = dataLength ~/ blockAlign;
    if (frameCount == 0) {
      throw FormatException('The WAV recording contains no audio frames.');
    }

    final reversedData = Uint8List.fromList(source);
    if (dataOffset.isOdd) {
      throw FormatException('The WAV audio data is not properly aligned.');
    }
    final samplesPerChannel = Int16List.view(
      reversedData.buffer,
      reversedData.offsetInBytes + dataOffset,
      frameCount * channelCount,
    );
    for (var firstFrame = 0; firstFrame < frameCount ~/ 2; firstFrame++) {
      final lastFrame = frameCount - firstFrame - 1;
      for (var channel = 0; channel < channelCount; channel++) {
        final firstIndex = firstFrame * channelCount + channel;
        final lastIndex = lastFrame * channelCount + channel;
        final firstSample = samplesPerChannel[firstIndex];
        samplesPerChannel[firstIndex] = samplesPerChannel[lastIndex];
        samplesPerChannel[lastIndex] = firstSample;
      }
    }

    final duration = Duration(
      microseconds:
          dataLength *
          Duration.microsecondsPerSecond ~/
          (sampleRate * blockAlign),
    );
    if (duration <= Duration.zero) {
      throw FormatException('The WAV recording is too short to reverse.');
    }

    return AudioClip(
      data: reversedData,
      duration: duration,
      mimeType: clip.mimeType,
      sampleRate: sampleRate,
      channelCount: channelCount,
    );
  }

  static bool _matches(Uint8List bytes, int offset, String value) {
    if (offset < 0 || offset + value.length > bytes.length) {
      return false;
    }
    for (var index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) {
        return false;
      }
    }
    return true;
  }
}
