import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uvc_ir_viewer/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Integration Tests', () {
    testWidgets('App launch test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 验证应用标题
      expect(find.text('UVC IR Camera Preview'), findsOneWidget);
    });

    testWidgets('Camera initialization test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 验证初始化状态
      expect(find.text('正在初始化相机...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 等待初始化完成
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('Device list test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // 验证设备列表显示
      if (find.text('选择相机设备：').evaluate().isNotEmpty) {
        expect(find.text('选择相机设备：'), findsOneWidget);
        expect(find.byType(Card), findsWidgets);
        expect(find.byType(ListTile), findsWidgets);
      }
    });

    testWidgets('Camera preview test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // 如果有可用设备，测试预览功能
      if (find.text('停止预览').evaluate().isNotEmpty) {
        // 测试停止预览
        await tester.tap(find.text('停止预览'));
        await tester.pumpAndSettle();
        expect(find.text('重新启动'), findsOneWidget);

        // 测试重新启动
        await tester.tap(find.text('重新启动'));
        await tester.pumpAndSettle();
        expect(find.text('停止预览'), findsOneWidget);
      }
    });

    testWidgets('Settings panel test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // 如果设置面板可见
      if (find.text('相机设置').evaluate().isNotEmpty) {
        expect(find.text('相机设置'), findsOneWidget);
        expect(find.text('亮度'), findsOneWidget);
        expect(find.text('对比度'), findsOneWidget);

        // 测试滑块操作
        final brightnessSlider = find.byType(Slider).first;
        await tester.drag(brightnessSlider, const Offset(20.0, 0.0));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Error handling test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // 如果出现错误状态
      if (find.byIcon(Icons.error_outline).evaluate().isNotEmpty) {
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);

        // 测试重试功能
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();
        expect(find.text('正在初始化相机...'), findsOneWidget);
      }
    });
  });
}
