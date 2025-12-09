// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'UVC IR 相机预览';

  @override
  String get initializingCamera => '正在初始化相机...';

  @override
  String get cameraNotInitialized => '相机未初始化';

  @override
  String get noDevicesFound => '未找到可用的相机设备';

  @override
  String get selectDevice => '选择相机设备：';

  @override
  String get refresh => '刷新';

  @override
  String get retry => '重试';

  @override
  String get stopPreview => '停止预览';

  @override
  String get restart => '重新启动';

  @override
  String get previewArea => '预览区域';

  @override
  String get cameraSettings => '相机设置';

  @override
  String get brightness => '亮度';

  @override
  String get contrast => '对比度';

  @override
  String get takePhoto => '拍照';

  @override
  String get recordVideo => '录像';

  @override
  String get deviceDisconnected => '设备已断开连接';

  @override
  String get deviceNotAvailable => '设备不可用';

  @override
  String get deviceConnected => '已连接';

  @override
  String get deviceAvailable => '可用';

  @override
  String get deviceStatus => '设备状态';

  @override
  String get checkingDeviceStatus => '正在检查设备状态...';

  @override
  String get errorMessage => '错误信息：';
}
