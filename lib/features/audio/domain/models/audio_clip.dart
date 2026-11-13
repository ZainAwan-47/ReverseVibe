import 'dart:typed_data';

/// Audio bytes and playback metadata held in memory without a file reference.
class AudioClip {
  AudioClip({
    required Uint8List data,
    required this.duration,
    required this.mimeType,
    required this.sampleRate,
    required this.channelCount,
  }) : _data = Uint8List.fromList(data) {
    if (_data.isEmpty) {
      throw ArgumentError.value(data, 'data', 'Must not be empty.');
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Must be greater than zero.',
      );
    }
    if (mimeType.trim().isEmpty) {
      throw ArgumentError.value(mimeType, 'mimeType', 'Must not be empty.');
    }
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be positive.');
    }
    if (channelCount <= 0) {
      throw ArgumentError.value(
        channelCount,
        'channelCount',
        'Must be positive.',
      );
    }
  }

  final Uint8List _data;

  Uint8List get data => Uint8List.fromList(_data);

  final Duration duration;
  final String mimeType;
  final int sampleRate;
  final int channelCount;
}
