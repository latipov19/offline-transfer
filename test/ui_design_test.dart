import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:offline_transfer/core/constants/app_constants.dart';
import 'package:offline_transfer/models/transfer_item.dart';
import 'package:offline_transfer/models/pairing_info.dart';
import 'package:offline_transfer/screens/home_screen.dart';
import 'package:offline_transfer/screens/send_screen.dart';
import 'package:offline_transfer/screens/history_screen.dart';
import 'package:offline_transfer/screens/settings_screen.dart';
import 'package:offline_transfer/services/storage_service.dart';
import 'package:offline_transfer/theme/app_theme.dart';
import 'package:offline_transfer/widgets/common_widgets.dart';
import 'package:offline_transfer/widgets/transfer_panels.dart';

void main() {
  late Directory directory;
  late Box<TransferItem> transfers;

  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((entry) => entry['name'] == 'flutter');
    final flutterRoot = configFile.uri.resolve(flutter['rootUri'] as String);
    final fontRoot = Uri.directory(Directory.fromUri(flutterRoot).path)
        .resolve('../../bin/cache/artifacts/material_fonts/');
    for (final entry in {
      'Roboto': ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf'],
      'MaterialIcons': ['materialicons-regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final font in entry.value) {
        final bytes = await File.fromUri(fontRoot.resolve(font)).readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
    directory = await Directory.systemTemp.createTemp('offline-transfer-ui-');
    Hive.init(directory.path);
    Hive.registerAdapter(TransferStatusAdapter());
    Hive.registerAdapter(TransferItemAdapter());
    transfers = await Hive.openBox<TransferItem>(AppConstants.transferBox);
    await Hive.openBox<String>(AppConstants.settingsBox);
    await StorageService.instance.init();
    await StorageService.instance.setDeviceName('Pixel 9 Pro');
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool light = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(key: const ValueKey('screenshot'), child: child),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('screenshot')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(pixels, isNotNull);
      final bytes = pixels!.buffer.asUint8List();
      final colors = <int>{};
      for (var i = 0; i < bytes.length; i += 4 * 23) {
        colors.add((bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2]);
      }
      expect(
        colors.length,
        greaterThan(12),
        reason: 'Screen must not be blank',
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('build/ui-preview');
      await folder.create(recursive: true);
      await File('${folder.path}/$name.png')
          .writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  final qr = PairingInfo.generate(
    sessionId: 'design-preview',
    deviceId: 'test-phone',
    deviceName: 'Pixel 9 Pro',
  ).toQrString();

  Widget transfer({VoidCallback? pause, VoidCallback? cancel}) => Scaffold(
    appBar: AppBar(title: const Text('Sending file')),
    body: TransferPanel(
      fileName: 'Summer memories and an exceptionally long video filename.mp4',
      bytesLabel: '428.0 MB / 1.20 GB',
      speed: '12.4 MB/s',
      eta: '1m 04s',
      peer: 'To Pixel 9 Pro with an exceptionally long device name',
      status: 'Transferring',
      fraction: 0.356,
      paused: false,
      queueLabel: 'File 2 of 5',
      onPause: pause ?? () {},
      onCancel: cancel ?? () {},
    ),
  );

  final sizes = [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 600),
    const Size(568, 320),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('Responsive screens $size scale $scale', (tester) async {
        final pages = <Widget>[
          const HomeScreen(),
          const SendScreen(),
          const SettingsScreen(),
          Scaffold(
            body: ReceivePanel(
              qrData: qr,
              status: 'Advertising... Ready to pair',
            ),
          ),
          transfer(),
          Scaffold(
            body: TransferResultPanel(
              completed: true,
              fileName: 'A very long received filename.zip',
              onHome: () {},
              onOpen: () {},
            ),
          ),
          Scaffold(
            body: TransferResultPanel(
              completed: false,
              fileName: 'file.zip',
              savedLabel: '428.0 MB transferred',
              fraction: 0.35,
              onHome: () {},
              onRetry: () {},
            ),
          ),
          const HistoryScreen(),
        ];
        for (final page in pages) {
          await show(tester, page, size: size, scale: scale);
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -1000));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: page.runtimeType.toString(),
            );
          }
        }
      });
    }
  }

  testWidgets('Idle home does not animate and history opens', (tester) async {
    await show(tester, const HomeScreen());
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.text('Transfer history'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Loading and disabled buttons cannot invoke action', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Column(
            children: [
              GlowButton(label: 'Busy', isLoading: true, onTap: () => calls++),
              const GlowButton(label: 'Disabled'),
              GlowButton(label: 'Enabled', onTap: () => calls++),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Busy'));
    await tester.tap(find.text('Disabled'));
    expect(calls, 0);
    await tester.tap(find.text('Enabled'));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Transfer pause and cancel controls preserve callbacks', (
    tester,
  ) async {
    var pauses = 0;
    var cancels = 0;
    await show(
      tester,
      transfer(pause: () => pauses++, cancel: () => cancels++),
    );
    await tester.ensureVisible(find.text('Pause'));
    await tester.tap(find.text('Pause'));
    await tester.tap(find.byTooltip('Cancel transfer'));
    expect(pauses, 1);
    expect(cancels, 1);
  });

  testWidgets('Settings editing preserves device name', (tester) async {
    await show(tester, const SettingsScreen());
    await tester.tap(find.byTooltip('Edit device name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'My transfer phone');
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Save device name'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(await StorageService.instance.getDeviceName(), 'My transfer phone');
    expect(find.text('My transfer phone'), findsOneWidget);
  });

  testWidgets('History long names and every status fit small screen', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final status in TransferStatus.values) {
        await transfers.put(
          status.name,
          TransferItem(
            transferId: status.name,
            fileName: 'A very long archive filename for sharing.zip',
            fileSize: 1280000000,
            totalChunks: 1000,
            status: status,
            sourcePath: 'test.zip',
            peerDeviceName: 'Extremely long device name for a test phone',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isSender: true,
          ),
        );
      }
    });
    await show(
      tester,
      const HistoryScreen(),
      size: const Size(320, 568),
      scale: 2,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => transfers.clear());
  });

  testWidgets('Screenshots have rendered pixels in both themes', (
    tester,
  ) async {
    for (final light in [false, true]) {
      final suffix = light ? 'light' : 'dark';
      await show(tester, const HomeScreen(), light: light);
      await snapshot(tester, 'home-$suffix');
      await show(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('Receive files')),
          body: ReceivePanel(
            qrData: qr,
            status: 'Advertising... Ready to pair',
          ),
        ),
        light: light,
      );
      await snapshot(tester, 'receive-$suffix');
      await show(tester, transfer(), light: light);
      await snapshot(tester, 'transfer-$suffix');
      await show(tester, const SettingsScreen(), light: light);
      await snapshot(tester, 'settings-$suffix');
    }
    await show(tester, const HomeScreen(), size: const Size(320, 568));
    await snapshot(tester, 'home-small');
    await show(tester, const HomeScreen(), size: const Size(800, 600));
    await snapshot(tester, 'home-tablet');
  });
}
