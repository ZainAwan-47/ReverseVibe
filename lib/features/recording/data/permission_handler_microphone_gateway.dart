import 'package:permission_handler/permission_handler.dart' as handler;

import '../domain/microphone_permission_gateway.dart';

class PermissionHandlerMicrophoneGateway
    implements MicrophonePermissionGateway {
  @override
  Future<MicrophonePermissionResult> request() async {
    final permission = handler.Permission.microphone;
    final currentStatus = await permission.status;
    if (currentStatus.isGranted) {
      return MicrophonePermissionResult.granted;
    }

    final requestedStatus = await permission.request();
    if (requestedStatus.isGranted) {
      return MicrophonePermissionResult.granted;
    }
    if (requestedStatus.isPermanentlyDenied) {
      return MicrophonePermissionResult.permanentlyDenied;
    }
    return MicrophonePermissionResult.denied;
  }

  @override
  Future<bool> openAppSettings() => handler.openAppSettings();
}
