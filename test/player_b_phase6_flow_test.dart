import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/features/recording/domain/microphone_permission_gateway.dart';
import 'package:reverse_vibe/features/recording/domain/player_a_recording_audio.dart';
import 'package:reverse_vibe/features/recording/domain/player_b_imitation_result.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_b_listening_controller.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_b_reconstructed_controller.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/player_a_confirmation_screen.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/player_b_final_reveal_screen.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/player_b_imitation_recording_screen.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/player_b_listening_screen.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/player_b_reconstructed_screen.dart';
import 'package:reverse_vibe/navigation/app_router.dart';
import 'package:reverse_vibe/theme/app_theme.dart';

void main() {
  testWidgets(
    'imitation recording screen hides reference controls and retains clips',
    (WidgetTester tester) async {
      final original = _wavClip([100, 200, 300, 400, 500, 600, 700, 800]);
      final imitation = _wavClip([11, 12, 13, 14, 15, 16, 17, 18]);
      final originalBytes = original.data;
      final audio = _FakeAudio(imitation: imitation);
      final controller = _listeningController(original, audio);

      await tester.pumpWidget(_listeningApp(original, controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('player-b-start-imitation')));
      await tester.pumpAndSettle();

      expect(find.text('Make your imitation'), findsOneWidget);
      expect(find.text('Player A’s sound, reversed'), findsNothing);
      expect(
        find.byKey(const ValueKey('player-b-reversed-playback-toggle')),
        findsNothing,
      );
      expect(controller.originalClip.data, originalBytes);
      expect(controller.reversedClip, isNotNull);
      expect(_samples(controller.reversedClip!), [
        800,
        700,
        600,
        500,
        400,
        300,
        200,
        100,
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('confirmed imitation reversal preserves audio and duration', () async {
    final original = _wavClip([100, 200, 300, 400, 500, 600, 700, 800]);
    final reversedOriginal = _wavClip([800, 700, 600, 500, 400, 300, 200, 100]);
    final imitation = _wavClip([10, 20, 30, 40, 50, 60, 70, 80]);
    final imitationBytes = imitation.data;
    final controller = PlayerBReconstructedController(
      result: PlayerBImitationResult(
        originalClip: original,
        reversedClip: reversedOriginal,
        imitationClip: imitation,
      ),
      audio: _FakeAudio(imitation: imitation),
    );

    await controller.prepare();

    expect(_samples(controller.reconstructedClip!), [
      80,
      70,
      60,
      50,
      40,
      30,
      20,
      10,
    ]);
    expect(controller.reconstructedClip!.duration, imitation.duration);
    expect(controller.result.imitationClip.data, imitationBytes);
    expect(controller.result.originalClip.data, original.data);
    await controller.close();
  });

  test(
    'invalid confirmed imitation fails reversal without losing source',
    () async {
      final original = _wavClip([1, 2, 3, 4]);
      final invalid = AudioClip(
        data: Uint8List.fromList([1, 2, 3, 4]),
        duration: const Duration(seconds: 1),
        mimeType: 'audio/wav',
        sampleRate: 44100,
        channelCount: 1,
      );
      final source = invalid.data;
      final controller = PlayerBReconstructedController(
        result: PlayerBImitationResult(
          originalClip: original,
          reversedClip: _wavClip([4, 3, 2, 1]),
          imitationClip: invalid,
        ),
        audio: _FakeAudio(imitation: original),
      );

      await controller.prepare();

      expect(controller.reconstructedClip, isNull);
      expect(controller.errorMessage, contains('Could not reverse'));
      expect(controller.result.imitationClip.data, source);
      await controller.close();

      final emptyWav = Uint8List(44)..setRange(0, 44, _wavClip([1]).data);
      final emptyHeader = ByteData.sublistView(emptyWav);
      emptyHeader.setUint32(4, 36, Endian.little);
      emptyHeader.setUint32(40, 0, Endian.little);
      final emptyClip = AudioClip(
        data: emptyWav,
        duration: const Duration(seconds: 1),
        mimeType: 'audio/wav',
        sampleRate: 4,
        channelCount: 1,
      );
      final emptyController = PlayerBReconstructedController(
        result: PlayerBImitationResult(
          originalClip: original,
          reversedClip: _wavClip([4, 3, 2, 1]),
          imitationClip: emptyClip,
        ),
        audio: _FakeAudio(imitation: original),
      );
      await emptyController.prepare();
      expect(emptyController.reconstructedClip, isNull);
      expect(emptyController.errorMessage, contains('no audio frames'));
      await emptyController.close();
    },
  );

  testWidgets(
    'Player A confirmation reveals the original and switching clips never overlaps',
    (WidgetTester tester) async {
      final original = _wavClip([100, 200, 300, 400, 500, 600, 700, 800]);
      final reversedOriginal = _wavClip([
        800,
        700,
        600,
        500,
        400,
        300,
        200,
        100,
      ]);
      final imitation = _wavClip([10, 20, 30, 40, 50, 60, 70, 80]);
      final audio = _FakeAudio(imitation: imitation);
      final controller = PlayerBReconstructedController(
        result: PlayerBImitationResult(
          originalClip: original,
          reversedClip: reversedOriginal,
          imitationClip: imitation,
        ),
        audio: audio,
      );

      await tester.pumpWidget(_phase6App(controller));
      await tester.pumpAndSettle();
      expect(find.text('Player B’s reconstructed sound'), findsOneWidget);
      expect(find.text('Player A’s original recording'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('ask-player-a-confirmation')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('player-b-reconstructed-playback-toggle')),
      );
      await tester.pumpAndSettle();
      audio.completePlayback();
      await tester.pumpAndSettle();
      expect(controller.hasListenedToReconstructed, isTrue);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('player-b-reconstructed-playback-remaining'),
              ),
            )
            .data,
        '00:00',
      );
      await tester.tap(
        find.byKey(const ValueKey('player-b-reconstructed-playback-toggle')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('player-b-reconstructed-playback-remaining'),
              ),
            )
            .data,
        '00:02',
      );
      audio.completePlayback();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ask-player-a-confirmation')));
      await tester.pumpAndSettle();
      expect(find.text('Is this what you said?'), findsOneWidget);
      expect(find.text('Player A’s original recording'), findsNothing);
      expect(
        find.byKey(const ValueKey('player-a-original-playback-toggle')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('player-a-confirm-reveal')));
      await tester.pumpAndSettle();
      expect(find.text('Player A’s original recording'), findsOneWidget);
      expect(find.text('Player B’s reconstructed sound'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('player-b-reconstructed-playback-toggle')),
      );
      await tester.pumpAndSettle();
      expect(audio.isPlaying, isTrue);
      await tester.tap(
        find.byKey(const ValueKey('player-a-original-playback-toggle')),
      );
      await tester.pumpAndSettle();

      expect(audio.playedClips, [
        controller.reconstructedClip,
        controller.reconstructedClip,
        controller.reconstructedClip,
        original,
      ]);
      expect(audio.isPlaying, isTrue);
      expect(audio.playbackEvents, [
        'play',
        'play',
        'stop',
        'play',
        'stop',
        'play',
      ]);

      audio.emitPosition(const Duration(seconds: 1));
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('player-a-original-playback-remaining'),
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
                const ValueKey('player-a-original-playback-remaining'),
              ),
            )
            .data,
        '00:00',
      );
      expect(audio.isPlaying, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

PlayerBListeningController _listeningController(
  AudioClip original,
  _FakeAudio audio,
) {
  return PlayerBListeningController(
    originalClip: original,
    audio: audio,
    permissionGateway: _FakePermissionGateway(),
  );
}

Widget _listeningApp(
  AudioClip original,
  PlayerBListeningController controller,
) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: PlayerBListeningScreen(
      originalClip: original,
      controller: controller,
    ),
    onGenerateRoute: (settings) {
      final arguments = settings.arguments;
      if (arguments is PlayerBListeningController) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              PlayerBImitationRecordingScreen(controller: arguments),
        );
      }
      return null;
    },
  );
}

Widget _phase6App(PlayerBReconstructedController controller) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: PlayerBReconstructedScreen(controller: controller),
    onGenerateRoute: (settings) {
      final arguments = settings.arguments;
      if (arguments is PlayerBReconstructedController) {
        if (settings.name == AppRouter.playerAConfirmation) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => PlayerAConfirmationScreen(controller: arguments),
          );
        }
        if (settings.name == AppRouter.playerBFinalReveal) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => PlayerBFinalRevealScreen(controller: arguments),
          );
        }
      }
      return null;
    },
  );
}

AudioClip _wavClip(List<int> samples) {
  const sampleRate = 4;
  const channels = 1;
  const blockAlign = channels * 2;
  final pcm = Uint8List(samples.length * blockAlign);
  final pcmData = ByteData.sublistView(pcm);
  for (var index = 0; index < samples.length; index++) {
    pcmData.setInt16(index * blockAlign, samples[index], Endian.little);
  }
  final wav = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(wav);
  wav.setRange(0, 4, ascii.encode('RIFF'));
  header.setUint32(4, wav.length - 8, Endian.little);
  wav.setRange(8, 12, ascii.encode('WAVE'));
  wav.setRange(12, 16, ascii.encode('fmt '));
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * blockAlign, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, 16, Endian.little);
  wav.setRange(36, 40, ascii.encode('data'));
  header.setUint32(40, pcm.length, Endian.little);
  wav.setRange(44, wav.length, pcm);
  return AudioClip(
    data: wav,
    duration: Duration(
      microseconds:
          samples.length * Duration.microsecondsPerSecond ~/ sampleRate,
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
  @override
  Future<MicrophonePermissionResult> request() async =>
      MicrophonePermissionResult.granted;

  @override
  Future<bool> openAppSettings() async => true;
}

class _FakeAudio implements PlayerARecordingAudio {
  _FakeAudio({required this.imitation});

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
  final List<String> playbackEvents = [];
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

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

  @override
  Future<void> startRecording() async {}

  @override
  Future<AudioClip> stopRecording() async {
    return imitation;
  }

  @override
  Future<void> play(AudioClip clip) async {
    if (_isPlaying) {
      throw StateError('Playback overlapped.');
    }
    playedClips.add(clip);
    playbackEvents.add('play');
    _isPlaying = true;
    _playbackController.add(true);
  }

  @override
  Future<void> pausePlayback() async {
    _isPlaying = false;
    _playbackController.add(false);
  }

  @override
  Future<void> resumePlayback() async {
    _isPlaying = true;
    _playbackController.add(true);
  }

  @override
  Future<void> stopPlayback() async {
    playbackEvents.add('stop');
    _isPlaying = false;
    _playbackController.add(false);
  }

  void emitPosition(Duration position) => _positionController.add(position);

  void completePlayback() {
    _positionController.add(const Duration(seconds: 2));
    _completionController.add(null);
    _isPlaying = false;
    _playbackController.add(false);
  }

  @override
  Future<void> dispose() async {
    _isPlaying = false;
    await _playbackController.close();
    await _positionController.close();
    await _completionController.close();
    await _amplitudeController.close();
    await _interruptedController.close();
  }
}
