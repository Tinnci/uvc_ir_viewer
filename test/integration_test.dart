import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uvc_ir_viewer/main.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('Test app launch and initial state',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 验证应用是否成功启动
      expect(find.text('UVC IR Camera Preview'), findsOneWidget);

      // 验证初始化状态
      expect(find.text('正在初始化相机...'), findsOneWidget);
    });

    testWidgets('Test camera initialization flow', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 等待初始化完成
      await tester.pump(const Duration(seconds: 2));

      // 如果没有找到相机，应该显示相应提示
      if (find.text('未找到可用的相机设备').evaluate().isNotEmpty) {
        expect(find.text('刷新'), findsOneWidget);

        // 测试刷新按钮
        await tester.tap(find.text('刷新'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Test settings panel', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 等待初始化
      await tester.pump(const Duration(seconds: 2));

      // 如果有相机并且已经选择，测试设置面板
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        // 验证设置面板内容
        expect(find.text('相机设置'), findsOneWidget);
        expect(find.text('亮度'), findsOneWidget);
        expect(find.text('对比度'), findsOneWidget);
      }
    });

    testWidgets('Test camera controls', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 等待初始化
      await tester.pump(const Duration(seconds: 2));

      // 如果有相机设备列表
      if (find.text('选择相机设备：').evaluate().isNotEmpty) {
        // 选择第一个相机
        final cameraListTile = find.byType(ListTile).first;
        if (cameraListTile.evaluate().isNotEmpty) {
          await tester.tap(cameraListTile);
          await tester.pumpAndSettle();

          // 验证预览控制按钮
          expect(find.text('停止预览'), findsOneWidget);
          expect(find.text('重新启动'), findsOneWidget);

          // 测试停止预览
          await tester.tap(find.text('停止预览'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Test error handling', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 如果出现错误状态
      if (find.byIcon(Icons.error_outline).evaluate().isNotEmpty) {
        expect(find.text('重试'), findsOneWidget);

        // 测试重试按钮
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();
      }
    });
  });
}
