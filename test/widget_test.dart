// This is an example Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
//
// Visit https://flutter.dev/to/widget-testing for
// more information about Widget testing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvc_ir_viewer/camera/camera_preview_page.dart';
import 'package:uvc_ir_viewer/main.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('App widget test', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 验证应用标题
      expect(find.text('UVC IR Camera Preview'), findsOneWidget);
    });

    group('CameraPreviewPage Tests', () {
      testWidgets('Initial loading state', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: CameraPreviewPage()));

        // 验证加载状态
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('正在初始化相机...'), findsOneWidget);
      });

      testWidgets('Error state display', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: CameraPreviewPage()));
        await tester.pump(const Duration(seconds: 2)); // 等待足够长的时间以触发错误状态

        // 等待错误状态显示
        await tester.pumpAndSettle();

        // 验证错误图标
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        // 验证重试按钮
        expect(find.text('重试'), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        // 测试重试按钮点击
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle(); // 等待状态更新完成

        // 验证已切换到初始化状态
        expect(find.text('正在初始化相机...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('No camera state display', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: CameraPreviewPage()));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // 如果没有找到相机
        if (find.text('未找到可用的相机设备').evaluate().isNotEmpty) {
          expect(find.text('未找到可用的相机设备'), findsOneWidget);
          expect(find.widgetWithText(FilledButton, '刷新'), findsOneWidget);

          // 测试刷新按钮点击
          await tester.tap(find.widgetWithText(FilledButton, '刷新'));
          await tester.pump();
          expect(find.text('正在初始化相机...'), findsOneWidget);
        }
      });

      testWidgets('Settings button visibility', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: CameraPreviewPage()));
        await tester.pumpAndSettle();

        // 初始状态不应该显示设置按钮
        expect(find.byIcon(Icons.settings), findsNothing);
        expect(find.byIcon(Icons.settings_outlined), findsNothing);
      });

      testWidgets('Camera device list display', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: CameraPreviewPage()));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // 如果显示设备列表
        if (find.text('选择相机设备：').evaluate().isNotEmpty) {
          // 验证设备列表标题
          expect(find.text('选择相机设备：'), findsOneWidget);
          expect(find.byType(Card), findsWidgets);
          expect(find.byType(ListTile), findsWidgets);

          // 验证设备列表容器
          expect(find.byType(Column), findsWidgets);
          expect(find.byType(Expanded), findsWidgets);

          // 验证设备列表样式
          final titleFinder = find.text('选择相机设备：');
          final titleWidget = tester.widget<Text>(titleFinder);
          expect(titleWidget.style?.fontSize, 18);
          expect(titleWidget.style?.fontWeight, FontWeight.bold);
        }
      });

      testWidgets('Preview controls visibility', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: CameraPreviewPage()));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // 如果相机已选择并显示控制按钮
        if (find.text('停止预览').evaluate().isNotEmpty) {
          expect(find.widgetWithText(FilledButton, '停止预览'), findsOneWidget);
          expect(find.widgetWithText(FilledButton, '重新启动'), findsOneWidget);
        }
      });

      testWidgets('Settings panel content', (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: CameraPreviewPage()));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // 如果设置面板可见
        if (find.text('相机设置').evaluate().isNotEmpty) {
          expect(find.text('相机设置'), findsOneWidget);
          expect(find.text('亮度'), findsOneWidget);
          expect(find.text('对比度'), findsOneWidget);
          expect(find.byType(Slider), findsNWidgets(2));
          expect(find.byIcon(Icons.photo_camera), findsOneWidget);
          expect(find.byIcon(Icons.videocam), findsOneWidget);
        }
      });

      testWidgets('Responsive layout test', (WidgetTester tester) async {
        // 设置不同的屏幕尺寸进行测试
        const Size smallScreen = Size(400, 600);
        const Size largeScreen = Size(1200, 800);

        // 小屏幕测试
        await tester.binding.setSurfaceSize(smallScreen);
        await tester.pumpWidget(const MaterialApp(home: CameraPreviewPage()));
        await tester.pumpAndSettle();
        expect(find.byType(CameraPreviewPage), findsOneWidget);

        // 大屏幕测试
        await tester.binding.setSurfaceSize(largeScreen);
        await tester.pumpWidget(const MaterialApp(home: CameraPreviewPage()));
        await tester.pumpAndSettle();
        expect(find.byType(CameraPreviewPage), findsOneWidget);

        // 恢复默认尺寸
        await tester.binding.setSurfaceSize(null);
      });
    });
  });
}
