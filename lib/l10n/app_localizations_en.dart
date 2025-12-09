// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'UVC IR Camera Preview';

  @override
  String get initializingCamera => 'Initializing camera...';

  @override
  String get cameraNotInitialized => 'Camera not initialized';

  @override
  String get noDevicesFound => 'No camera devices found';

  @override
  String get selectDevice => 'Select camera device:';

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Retry';

  @override
  String get stopPreview => 'Stop Preview';

  @override
  String get restart => 'Restart';

  @override
  String get previewArea => 'Preview Area';

  @override
  String get cameraSettings => 'Camera Settings';

  @override
  String get brightness => 'Brightness';

  @override
  String get contrast => 'Contrast';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get recordVideo => 'Record Video';

  @override
  String get deviceDisconnected => 'Device disconnected';

  @override
  String get deviceNotAvailable => 'Device not available';

  @override
  String get deviceConnected => 'Connected';

  @override
  String get deviceAvailable => 'Available';

  @override
  String get deviceStatus => 'Device Status';

  @override
  String get checkingDeviceStatus => 'Checking device status...';

  @override
  String get errorMessage => 'Error message:';
}
