import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uvc_ir_viewer/main.dart';
import 'package:uvc_ir_viewer/camera/camera_preview_page.dart';
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

      // 验证初始化状态或错误状态
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            (widget.data == '正在初始化相机...' || widget.data == '未找到可用的相机设备')),
        findsOneWidget,
      );
    });

    testWidgets('Test camera initialization flow', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 等待初始化完成
      await tester.pump(const Duration(seconds: 2));

      // 验证是否处于以下状态之一：
      // 1. 显示设备列表
      // 2. 显示无设备提示
      // 3. 显示错误状态
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            (widget.data == '选择相机设备：' ||
                widget.data == '未找到可用的相机设备' ||
                widget.data?.contains('error') == true)),
        findsOneWidget,
      );

      // 如果显示刷新按钮，测试其功能
      if (find.text('刷新').evaluate().isNotEmpty) {
        await tester.tap(find.text('刷新'));
        await tester.pumpAndSettle();

        // 验证是否返回到初始化状态
        expect(find.text('正在初始化相机...'), findsOneWidget);
      }
    });

    testWidgets('Test camera device selection', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 2));

      // 如果有相机设备列表
      if (find.byType(ListTile).evaluate().isNotEmpty) {
        final firstCamera = find.byType(ListTile).first;
        await tester.tap(firstCamera);
        await tester.pumpAndSettle();

        // 验证预览状态
        expect(
          find.byWidgetPredicate((widget) =>
              widget is Text &&
              (widget.data == '预览画面' || widget.data == '正在启动预览...')),
          findsOneWidget,
        );
      }
    });

    testWidgets('Test camera controls', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 2));

      // 如果显示相机控制按钮
      if (find.text('停止预览').evaluate().isNotEmpty) {
        // 测试停止预览
        await tester.tap(find.text('停止预览'));
        await tester.pumpAndSettle();

        // 测试重新启动
        if (find.text('重新启动').evaluate().isNotEmpty) {
          await tester.tap(find.text('重新启动'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Test settings panel', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 2));

      // 如果设置按钮可见
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        // 验证设置面板内容
        expect(find.text('相机设置'), findsOneWidget);

        // 测试亮度滑块
        final brightnessSlider = find.byWidgetPredicate((widget) =>
            widget is Slider &&
            find
                .ancestor(of: find.byWidget(widget), matching: find.text('亮度'))
                .evaluate()
                .isNotEmpty);
        if (brightnessSlider.evaluate().isNotEmpty) {
          await tester.drag(brightnessSlider, const Offset(20.0, 0.0));
          await tester.pumpAndSettle();
        }

        // 测试对比度滑块
        final contrastSlider = find.byWidgetPredicate((widget) =>
            widget is Slider &&
            find
                .ancestor(of: find.byWidget(widget), matching: find.text('对比度'))
                .evaluate()
                .isNotEmpty);
        if (contrastSlider.evaluate().isNotEmpty) {
          await tester.drag(contrastSlider, const Offset(20.0, 0.0));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Test error recovery', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 如果出现错误状态
      if (find.byIcon(Icons.error_outline).evaluate().isNotEmpty) {
        expect(find.text('重试'), findsOneWidget);

        // 测试重试功能
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();

        // 验证是否返回到初始化状态
        expect(
          find.byWidgetPredicate((widget) =>
              widget is Text &&
              (widget.data == '正在初始化相机...' || widget.data == '未找到可用的相机设备')),
          findsOneWidget,
        );
      }
    });
  });
}
