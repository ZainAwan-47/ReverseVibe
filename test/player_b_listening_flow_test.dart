import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/features/recording/domain/microphone_permission_gateway.dart';
import 'package:reverse_vibe/features/recording/domain/player_b_imitation_result.dart';
import 'package:reverse_vibe/features/recording/domain/player_a_recording_audio.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_b_listening_controller.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/player_b_imitation_ready_screen.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/player_b_imitation_recording_screen.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/player_b_listening_screen.dart';
import 'package:reverse_vibe/theme/app_theme.dart';

void main() {
  testWidgets(
    'Player B can replay without limit and review with a position countdown',
    (WidgetTester tester) async {
      final original = _wavClip([
        -16000,
        -12000,
        -8000,
        -4000,
        4000,
        8000,
        12000,
        16000,
      ]);
      final imitation = _wavClip([
        1000,
        2000,
        3000,
        4000,
        5000,
        6000,
        7000,
        8000,
      ]);
      final audio = _FakeRecordingAudio(imitation: imitation);
      final controller = _controller(original, audio);
      await tester.pumpWidget(_app(original, controller));
      await tester.pumpAndSettle();

      expect(find.text('Listen closely'), findsOneWidget);
      expect(find.text('Player A’s sound, reversed'), findsOneWidget);
      expect(_samples(controller.reversedClip!), [
        16000,
        12000,
        8000,
        4000,
        -4000,
        -8000,
        -12000,
        -16000,
      ]);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('player-b-reversed-playback-remaining'),
              ),
            )
            .data,
        '00:02',
      );

      for (var replay = 0; replay < 3; replay++) {
        await tester.tap(
          find.byKey(const ValueKey('player-b-reversed-playback-toggle')),
        );
        await tester.pump();
        audio.emitPosition(const Duration(seconds: 1));
        await tester.pump();
        expect(
          tester
              .widget<Text>(
                find.byKey(
                  const ValueKey('player-b-reversed-playback-remaining'),
                ),
              )
              .data,
          '00:01',
        );
        audio.completePlayback();
        await tester.pump();
        expect(
          tester
              .widget<Text>(
                find.byKey(
                  const ValueKey('player-b-reversed-playback-remaining'),
                ),
              )
              .data,
          '00:00',
        );
      }
      expect(audio.playCount, 3);

      await tester.tap(find.byKey(const ValueKey('player-b-start-imitation')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('player-b-recording-start')));
      await tester.pump();
      await tester.pump();
      expect(controller.isRecording, isTrue);
      audio.emitAmplitude(0.8);
      await tester.pump(const Duration(milliseconds: 120));
      final loudLevel = controller.amplitude;
      expect(loudLevel, greaterThan(0));
      expect(controller.amplitudeHistory, isNotEmpty);

      audio.emitAmplitude(0.05);
      await tester.pump(const Duration(milliseconds: 200));
      final quietLevel = controller.amplitude;
      expect(quietLevel, lessThan(loudLevel));
      audio.emitAmplitude(0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.amplitude, lessThan(quietLevel));

      await tester.ensureVisible(
        find.byKey(const ValueKey('player-b-recording-stop')),
      );
      await tester.tap(find.byKey(const ValueKey('player-b-recording-stop')));
      await tester.pumpAndSettle();
      expect(controller.status, PlayerBStatus.recorded);
      expect(find.text('Your imitation'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('player-b-imitation-playback-remaining'),
              ),
            )
            .data,
        '00:02',
      );

      await tester.tap(
        find.byKey(const ValueKey('player-b-imitation-playback-toggle')),
      );
      await tester.pump();
      audio.emitPosition(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('player-b-imitation-playback-remaining'),
              ),
            )
            .data,
        '00:01',
      );
      audio.completePlayback();
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('player-b-imitation-playback-remaining'),
              ),
            )
            .data,
        '00:00',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'discard, re-record, confirm and back navigation preserve the imitation',
    (WidgetTester tester) async {
      final original = _wavClip([1, 2, 3, 4, 5, 6, 7, 8]);
      final imitation = _wavClip([11, 12, 13, 14, 15, 16, 17, 18]);
      final audio = _FakeRecordingAudio(imitation: imitation);
      final controller = _controller(original, audio);
      PlayerBImitationResult? confirmedResult;

      await tester.pumpWidget(
        _app(
          original,
          controller,
          onConfirmed: (result) => confirmedResult = result,
        ),
      );
      await tester.pumpAndSettle();

      await _recordTake(tester);
      await tester.tap(find.byKey(const ValueKey('player-b-recording-again')));
      await tester.pumpAndSettle();
      expect(audio.startCount, 2);
      expect(controller.isRecording, isTrue);
      await tester.tap(find.byKey(const ValueKey('player-b-recording-stop')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('player-b-recording-discard')),
      );
      await tester.pumpAndSettle();
      expect(controller.imitation, isNull);
      expect(
        find.byKey(const ValueKey('player-b-recording-start')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('player-b-recording-start')));
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('player-b-recording-stop')),
      );
      await tester.tap(find.byKey(const ValueKey('player-b-recording-stop')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('player-b-recording-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Imitation confirmed'), findsOneWidget);
      expect(confirmedResult, isNotNull);
      expect(confirmedResult!.imitationClip.data, imitation.data);
      expect(confirmedResult!.originalClip.data, original.data);

      await tester.ensureVisible(
        find.byKey(const ValueKey('return-to-player-b')),
      );
      await tester.tap(find.byKey(const ValueKey('return-to-player-b')));
      await tester.pumpAndSettle();
      expect(find.text('PLAYER B'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player-b-recording-confirm')),
        findsOneWidget,
      );
      expect(controller.imitation!.data, imitation.data);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Player B shows microphone permission denial', (
    WidgetTester tester,
  ) async {
    final original = _wavClip([1, 2, 3, 4, 5, 6, 7, 8]);
    final audio = _FakeRecordingAudio(imitation: original);
    final controller = _controller(
      original,
      audio,
      permission: _FakePermissionGateway(
        result: MicrophonePermissionResult.denied,
      ),
    );
    await tester.pumpWidget(_app(original, controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player-b-start-imitation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-b-recording-start')));
    await tester.pumpAndSettle();
    expect(find.text('Microphone access is needed'), findsOneWidget);
    expect(audio.startCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Player B stops gracefully when microphone capture is interrupted',
    (WidgetTester tester) async {
      final original = _wavClip([1, 2, 3, 4, 5, 6, 7, 8]);
      final audio = _FakeRecordingAudio(imitation: original);
      final controller = _controller(original, audio);
      await tester.pumpWidget(_app(original, controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('player-b-start-imitation')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('player-b-recording-start')));
      await tester.pump();
      await tester.pump();
      audio.interruptRecording();
      await tester.pumpAndSettle();

      expect(controller.isRecording, isFalse);
      expect(find.textContaining('Recording was interrupted'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player-b-recording-confirm')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _recordTake(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('player-b-start-imitation')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('player-b-recording-start')));
  await tester.pump();
  await tester.pump();
  await tester.ensureVisible(
    find.byKey(const ValueKey('player-b-recording-stop')),
  );
  await tester.tap(find.byKey(const ValueKey('player-b-recording-stop')));
  await tester.pumpAndSettle();
}

PlayerBListeningController _controller(
  AudioClip original,
  _FakeRecordingAudio audio, {
  _FakePermissionGateway? permission,
}) {
  return PlayerBListeningController(
    originalClip: original,
    audio: audio,
    permissionGateway: permission ?? _FakePermissionGateway(),
  );
}

Widget _app(
  AudioClip original,
  PlayerBListeningController controller, {
  void Function(PlayerBImitationResult result)? onConfirmed,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: PlayerBListeningScreen(
      originalClip: original,
      controller: controller,
    ),
    onGenerateRoute: (settings) {
      final result = settings.arguments;
      if (result is PlayerBListeningController) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => PlayerBImitationRecordingScreen(controller: result),
        );
      }
      if (result is PlayerBImitationResult) {
        onConfirmed?.call(result);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => PlayerBImitationReadyScreen(result: result),
        );
      }
      return null;
    },
  );
}

AudioClip _wavClip(List<int> sampleValues) {
  const sampleRate = 4;
  const channels = 1;
  const blockAlign = channels * 2;
  final pcm = Uint8List(sampleValues.length * blockAlign);
  final pcmData = ByteData.sublistView(pcm);
  for (var index = 0; index < sampleValues.length; index++) {
    pcmData.setInt16(index * blockAlign, sampleValues[index], Endian.little);
  }

  final wav = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(wav);
  wav.setRange(0, 4, [82, 73, 70, 70]);
  header.setUint32(4, wav.length - 8, Endian.little);
  wav.setRange(8, 12, [87, 65, 86, 69]);
  wav.setRange(12, 16, [102, 109, 116, 32]);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * blockAlign, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, 16, Endian.little);
  wav.setRange(36, 40, [100, 97, 116, 97]);
  header.setUint32(40, pcm.length, Endian.little);
  wav.setRange(44, wav.length, pcm);

  return AudioClip(
    data: wav,
    duration: Duration(
      microseconds:
          sampleValues.length * Duration.microsecondsPerSecond ~/ sampleRate,
    ),
    mimeType: 'audio/wav',
    sampleRate: sampleRate,
    channelCount: channels,
  );
}

List<int> _samples(AudioClip clip) {
  final data = ByteData.sublistView(clip.data);
  return List<int>.generate(
    (clip.data.length - 44) ~/ 2,
    (index) => data.getInt16(44 + index * 2, Endian.little),
  );
}

class _FakePermissionGateway implements MicrophonePermissionGateway {
  _FakePermissionGateway({this.result = MicrophonePermissionResult.granted});

  final MicrophonePermissionResult result;

  @override
  Future<MicrophonePermissionResult> request() async => result;

  @override
  Future<bool> openAppSettings() async => true;
}

class _FakeRecordingAudio implements PlayerARecordingAudio {
  _FakeRecordingAudio({required this.imitation});

  final AudioClip imitation;
  final StreamController<bool> _playbackController =
      StreamController<bool>.broadcast(sync: true);
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast(sync: true);
  final StreamController<void> _completionController =
      StreamController<void>.broadcast(sync: true);
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast(sync: true);
  final StreamController<void> _interruptedController =
      StreamController<void>.broadcast(sync: true);
  final List<AudioClip> playedClips = [];
  int startCount = 0;
  int playCount = 0;
  bool _recording = false;

  @override
  Stream<bool> get playbackState => _playbackController.stream;

  @override
  Stream<Duration> get playbackPosition => _positionController.stream;

  @override
  Stream<void> get playbackComplete => _completionController.stream;

  @override
  Stream<double> get recordingAmplitude => _amplitudeController.stream;

  @override
  Stream<void> get recordingInterrupted => _interruptedController.stream;

  void emitPosition(Duration position) => _positionController.add(position);

  void emitAmplitude(double amplitude) => _amplitudeController.add(amplitude);

  void interruptRecording() {
    _recording = false;
    _interruptedController.add(null);
  }

  void completePlayback() {
    _positionController.add(const Duration(seconds: 2));
    _completionController.add(null);
    _playbackController.add(false);
  }

  @override
  Future<void> startRecording() async {
    if (_recording) {
      throw StateError('A recording is already in progress.');
    }
    _recording = true;
    startCount++;
  }

  @override
  Future<AudioClip> stopRecording() async {
    if (!_recording) {
      throw StateError('Audio capture was interrupted.');
    }
    _recording = false;
    return imitation;
  }

  @override
  Future<void> play(AudioClip clip) async {
    playedClips.add(clip);
    playCount++;
    _playbackController.add(true);
  }

  @override
  Future<void> pausePlayback() async {
    _playbackController.add(false);
  }

  @override
  Future<void> resumePlayback() async {
    _playbackController.add(true);
  }

  @override
  Future<void> stopPlayback() async {
    _playbackController.add(false);
  }

  @override
  Future<void> dispose() async {
    _recording = false;
    await _playbackController.close();
    await _positionController.close();
    await _completionController.close();
    await _amplitudeController.close();
    await _interruptedController.close();
  }
}
