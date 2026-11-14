import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/features/home/presentation/screens/home_screen.dart';
import 'package:reverse_vibe/features/recording/domain/microphone_permission_gateway.dart';
import 'package:reverse_vibe/features/recording/domain/player_a_recording_audio.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_b_listening_controller.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_a_recording_controller.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/original_ready_screen.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/player_b_listening_screen.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/player_a_recording_screen.dart';
import 'package:reverse_vibe/navigation/app_router.dart';
import 'package:reverse_vibe/theme/app_theme.dart';

void main() {
  testWidgets('recording screen renders and requests microphone permission', (
    WidgetTester tester,
  ) async {
    final audio = _FakeRecordingAudio();
    final permission = _FakePermissionGateway();
    await tester.pumpWidget(_recordingApp(audio, permission));

    expect(find.text('PLAYER A'), findsOneWidget);
    expect(find.text('Record the original'), findsOneWidget);
    expect(find.byKey(const ValueKey('recording-start')), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(audio.startCount, 0);

    await tester.tap(find.byKey(const ValueKey('recording-start')));
    await tester.pumpAndSettle();

    expect(permission.requestCount, 1);
    expect(audio.startCount, 1);
    expect(find.text('Recording in progress'), findsOneWidget);
  });

  testWidgets('permission denial and permanent denial are explained', (
    WidgetTester tester,
  ) async {
    final deniedAudio = _FakeRecordingAudio();
    await tester.pumpWidget(
      _recordingApp(
        deniedAudio,
        _FakePermissionGateway(result: MicrophonePermissionResult.denied),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('recording-start')));
    await tester.pumpAndSettle();

    expect(find.text('Microphone access is needed'), findsOneWidget);
    expect(deniedAudio.startCount, 0);

    final permanentAudio = _FakeRecordingAudio();
    final permanentPermission = _FakePermissionGateway(
      result: MicrophonePermissionResult.permanentlyDenied,
    );
    await tester.pumpWidget(_recordingApp(permanentAudio, permanentPermission));
    await tester.tap(find.byKey(const ValueKey('recording-start')));
    await tester.pumpAndSettle();

    expect(find.text('Microphone access is turned off'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(permanentAudio.startCount, 0);
    await tester.tap(find.text('Open Settings'));
    await tester.pump();
    expect(permanentPermission.settingsCount, 1);
  });

  testWidgets('start, timer, stop, playback, and pause work', (
    WidgetTester tester,
  ) async {
    final audio = _FakeRecordingAudio();
    await tester.pumpWidget(_recordingApp(audio, _FakePermissionGateway()));

    await tester.tap(find.byKey(const ValueKey('recording-start')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('recording-duration')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recording-stop')));
    await tester.pumpAndSettle();
    expect(find.text('Original recording'), findsOneWidget);
    expect(find.byKey(const ValueKey('recording-confirm')), findsOneWidget);
    expect(find.byKey(const ValueKey('recording-duration')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recording-playback-toggle')));
    await tester.pumpAndSettle();
    expect(audio.playCount, 1);
    expect(find.byTooltip('Pause recording'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recording-playback-toggle')));
    await tester.pumpAndSettle();
    expect(audio.pauseCount, 1);
    expect(find.byTooltip('Play recording'), findsOneWidget);
  });

  testWidgets('playback countdown follows position and completes at zero', (
    WidgetTester tester,
  ) async {
    final audio = _FakeRecordingAudio();
    await tester.pumpWidget(_recordingApp(audio, _FakePermissionGateway()));
    await _recordAndStop(tester);

    expect(
      find.byKey(const ValueKey('recording-playback-remaining')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('recording-playback-remaining')),
          )
          .data,
      '00:02',
    );

    await tester.tap(find.byKey(const ValueKey('recording-playback-toggle')));
    await tester.pump();
    audio.emitPosition(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('recording-playback-remaining')),
          )
          .data,
      '00:01',
    );

    audio.completePlayback();
    await tester.pump();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('recording-playback-remaining')),
          )
          .data,
      '00:00',
    );
    expect(find.byTooltip('Play recording'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recording-playback-toggle')));
    await tester.pump();
    expect(audio.playCount, 2);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('recording-playback-remaining')),
          )
          .data,
      '00:02',
    );
  });

  testWidgets(
    'playback waveform follows real PCM position and returns idle when stopped',
    (WidgetTester tester) async {
      final audio = _FakeRecordingAudio();
      final controller = PlayerARecordingController(
        audio: audio,
        permissionGateway: _FakePermissionGateway(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: PlayerARecordingScreen(controller: controller),
        ),
      );
      await _recordAndStop(tester);

      expect(controller.playbackWaveform, hasLength(48));
      expect(controller.playbackWaveform.any((level) => level > 0), isTrue);
      expect(controller.playbackWaveformProgress, 0);
      expect(
        find.byKey(const ValueKey('recording-playback-visualizer')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('recording-playback-toggle')));
      await tester.pump();
      audio.emitPosition(const Duration(seconds: 1));
      await tester.pump();
      expect(controller.playbackWaveformProgress, closeTo(0.5, 0.01));

      await tester.tap(find.byKey(const ValueKey('recording-playback-toggle')));
      await tester.pump();
      expect(controller.playbackWaveformProgress, 0);

      audio.completePlayback();
      await tester.pump();
      expect(controller.playbackPosition, controller.clip!.duration);
      expect(controller.playbackWaveformProgress, 0);

      await tester.tap(find.byKey(const ValueKey('recording-playback-toggle')));
      await tester.pump();
      expect(controller.playbackWaveformProgress, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('re-record discards the previous clip and starts a new take', (
    WidgetTester tester,
  ) async {
    final audio = _FakeRecordingAudio();
    await tester.pumpWidget(_recordingApp(audio, _FakePermissionGateway()));
    await _recordAndStop(tester);

    await tester.tap(find.byKey(const ValueKey('recording-re-record')));
    await tester.pumpAndSettle();

    expect(audio.startCount, 2);
    expect(find.byKey(const ValueKey('recording-stop')), findsOneWidget);
    expect(find.byKey(const ValueKey('recording-confirm')), findsNothing);
    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('empty recording is rejected and cannot be confirmed', (
    WidgetTester tester,
  ) async {
    final audio = _FakeRecordingAudio(
      stopError: StateError('No audio was captured.'),
    );
    await tester.pumpWidget(_recordingApp(audio, _FakePermissionGateway()));
    await tester.tap(find.byKey(const ValueKey('recording-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recording-stop')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No usable audio was captured'), findsOneWidget);
    expect(find.byKey(const ValueKey('recording-confirm')), findsNothing);
  });

  testWidgets('recording stops automatically at the 60-second limit', (
    WidgetTester tester,
  ) async {
    final audio = _FakeRecordingAudio(
      recordingDuration: const Duration(seconds: 60),
    );
    await tester.pumpWidget(_recordingApp(audio, _FakePermissionGateway()));
    await tester.tap(find.byKey(const ValueKey('recording-start')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();

    expect(audio.stopCount, 1);
    expect(find.byKey(const ValueKey('recording-duration')), findsOneWidget);
    expect(find.byKey(const ValueKey('recording-confirm')), findsOneWidget);
  });

  testWidgets('valid recording confirmation opens the next-stage placeholder', (
    WidgetTester tester,
  ) async {
    final audio = _FakeRecordingAudio();
    await tester.pumpWidget(_recordingApp(audio, _FakePermissionGateway()));
    await _recordAndStop(tester);

    await tester.tap(find.byKey(const ValueKey('recording-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Pass the sound to Player B'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('continue-to-player-b')));
    await tester.pumpAndSettle();
    expect(find.text('PLAYER B'), findsOneWidget);
    expect(find.text('Player A’s sound, reversed'), findsOneWidget);
  });

  testWidgets('Home Start Challenge opens Player A recording', (
    WidgetTester tester,
  ) async {
    final audio = _FakeRecordingAudio();
    final permission = _FakePermissionGateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const HomeScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.playerARecording) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => PlayerARecordingScreen(
                controller: PlayerARecordingController(
                  audio: audio,
                  permissionGateway: permission,
                ),
              ),
            );
          }
          return AppRouter.onGenerateRoute(settings);
        },
      ),
    );
    await tester.ensureVisible(find.text('Start Challenge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Challenge'));
    await tester.pumpAndSettle();

    expect(find.text('PLAYER A'), findsOneWidget);
    expect(find.text('Record the original'), findsOneWidget);
    expect(permission.requestCount, 0);
  });

  test(
    'closing the controller disposes audio and ends an active recording',
    () async {
      final audio = _FakeRecordingAudio();
      final controller = PlayerARecordingController(
        audio: audio,
        permissionGateway: _FakePermissionGateway(),
      );

      await controller.startRecording();
      await controller.close();

      expect(audio.disposed, isTrue);
      expect(audio.stopCount, 1);
    },
  );

  testWidgets('recording controls fit a compact phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final audio = _FakeRecordingAudio();
    await tester.pumpWidget(_recordingApp(audio, _FakePermissionGateway()));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('recording-start')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('recording-stop')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _recordAndStop(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('recording-start')));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
  await tester.tap(find.byKey(const ValueKey('recording-stop')));
  await tester.pumpAndSettle();
}

Widget _recordingApp(
  _FakeRecordingAudio audio,
  _FakePermissionGateway permission,
) {
  final controller = PlayerARecordingController(
    audio: audio,
    permissionGateway: permission,
  );
  return MaterialApp(
    theme: AppTheme.dark,
    home: PlayerARecordingScreen(
      key: ObjectKey(controller),
      controller: controller,
    ),
    onGenerateRoute: (settings) {
      final arguments = settings.arguments;
      if (settings.name == AppRouter.originalReady && arguments is AudioClip) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => OriginalReadyScreen(clip: arguments),
        );
      }
      if (settings.name == AppRouter.playerBListening &&
          arguments is AudioClip) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => PlayerBListeningScreen(
            originalClip: arguments,
            controller: PlayerBListeningController(
              originalClip: arguments,
              audio: _FakeRecordingAudio(),
              permissionGateway: _FakePermissionGateway(),
            ),
          ),
        );
      }
      return AppRouter.onGenerateRoute(settings);
    },
  );
}

class _FakePermissionGateway implements MicrophonePermissionGateway {
  _FakePermissionGateway({this.result = MicrophonePermissionResult.granted});

  final MicrophonePermissionResult result;
  int requestCount = 0;
  int settingsCount = 0;

  @override
  Future<MicrophonePermissionResult> request() async {
    requestCount++;
    return result;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsCount++;
    return true;
  }
}

class _FakeRecordingAudio implements PlayerARecordingAudio {
  _FakeRecordingAudio({
    this.stopError,
    Duration recordingDuration = const Duration(seconds: 2),
  }) : _clip = _makeWavClip(recordingDuration);

  final AudioClip _clip;
  final Object? stopError;
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
  int startCount = 0;
  int stopCount = 0;
  int playCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  bool disposed = false;
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

  void completePlayback() {
    _positionController.add(_clip.duration);
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
      throw StateError('There is no active recording.');
    }
    _recording = false;
    stopCount++;
    if (stopError case final error?) {
      throw error;
    }
    return _clip;
  }

  @override
  Future<void> play(AudioClip clip) async {
    playCount++;
    _playbackController.add(true);
  }

  @override
  Future<void> pausePlayback() async {
    pauseCount++;
    _playbackController.add(false);
  }

  @override
  Future<void> resumePlayback() async {
    resumeCount++;
    _playbackController.add(true);
  }

  @override
  Future<void> stopPlayback() async {
    _playbackController.add(false);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    if (_recording) {
      _recording = false;
      stopCount++;
    }
    await _playbackController.close();
    await _positionController.close();
    await _completionController.close();
    await _amplitudeController.close();
    await _interruptedController.close();
  }
}

AudioClip _makeWavClip(Duration duration) {
  const sampleRate = 4;
  const channels = 1;
  const bytesPerSample = 2;
  final pcmLength =
      duration.inMicroseconds *
      sampleRate *
      channels *
      bytesPerSample ~/
      Duration.microsecondsPerSecond;
  final wav = Uint8List(44 + pcmLength);
  final header = ByteData.sublistView(wav);
  wav.setRange(0, 4, [82, 73, 70, 70]);
  header.setUint32(4, wav.length - 8, Endian.little);
  wav.setRange(8, 12, [87, 65, 86, 69]);
  wav.setRange(12, 16, [102, 109, 116, 32]);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  header.setUint16(32, channels * bytesPerSample, Endian.little);
  header.setUint16(34, 16, Endian.little);
  wav.setRange(36, 40, [100, 97, 116, 97]);
  header.setUint32(40, pcmLength, Endian.little);
  for (var index = 0; index < pcmLength ~/ 2; index++) {
    header.setInt16(44 + index * 2, ((index % 8) + 1) * 3000, Endian.little);
  }
  return AudioClip(
    data: wav,
    duration: duration,
    mimeType: 'audio/wav',
    sampleRate: sampleRate,
    channelCount: channels,
  );
}
