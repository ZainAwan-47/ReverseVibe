enum MicrophonePermissionResult { granted, denied, permanentlyDenied }

abstract interface class MicrophonePermissionGateway {
  Future<MicrophonePermissionResult> request();

  Future<bool> openAppSettings();
}
