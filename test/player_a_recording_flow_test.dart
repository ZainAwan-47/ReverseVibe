import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/features/home/presentation/screens/home_screen.dart';
import 'package:reverse_vibe/features/recording/domain/microphone_permission_gateway.dart';
import 'package:reverse_vibe/features/recording/domain/player_a_recording_audio.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_a_recording_controller.dart';
import 'package:reverse_vibe/features/recording/presentation/screens/original_ready_screen.dart';
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

    expect(find.text('Original recording ready'), findsOneWidget);
    expect(
      find.textContaining('Reversing the audio will be available'),
      findsOneWidget,
    );
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
  }) : _clip = AudioClip(
         data: Uint8List(46),
         duration: recordingDuration,
         mimeType: 'audio/wav',
         sampleRate: 44100,
         channelCount: 1,
       );

  final AudioClip _clip;
  final Object? stopError;
  final StreamController<bool> _playbackController =
      StreamController<bool>.broadcast(sync: true);
  int startCount = 0;
  int stopCount = 0;
  int playCount = 0;
  int pauseCount = 0;
  bool disposed = false;
  bool _recording = false;

  @override
  Stream<bool> get playbackState => _playbackController.stream;

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
  }
}
