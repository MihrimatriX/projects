import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/barcode_batch_export.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/file_output.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/qr_export.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/features/scan/presentation/scan_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dosya seçici yerine sabit bir görsel döndürür.
class _FakePicker extends FilePicker {
  _FakePicker(this.bytes);

  Uint8List? bytes;
  FileType? lastType;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    lastType = type;
    final b = bytes;
    if (b == null) return null;
    return FilePickerResult([PlatformFile(name: 'kod.png', size: b.length, bytes: b)]);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'camera_hint_shown_v1': true});
  });

  // Kamerası olmayan masaüstü: canlı tarama yerine dosyadan okuma.
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  Future<void> pumpScan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: Scaffold(body: ScanScreen()))),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('kamera yokken çökmez; seçilen görseldeki QR okunur', (tester) async {
    final png = (await tester.runAsync(
      () => QrExport.renderPng(
        data: 'WIFI:T:WPA;S:Ofis;P:gizli123;;',
        size: 400,
        foreground: Colors.black,
        background: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
    ))!;
    final picker = _FakePicker(png);
    FilePicker.platform = picker;

    await pumpScan(tester);
    expect(find.textContaining('canlı kamera yok'), findsOneWidget);
    expect(find.text('Görsel dosyası seç'), findsOneWidget);

    await tester.tap(find.text('Görsel dosyası seç'));
    await settle(tester);

    expect(picker.lastType, FileType.image);
    expect(find.text('BAŞARILI OKUMA'), findsOneWidget);
    expect(find.text('QRCODE'), findsOneWidget);
    // Wi-Fi şifresi varsayılan olarak maskelenir; ağ adı görünür.
    expect(find.textContaining('Ofis'), findsOneWidget);
    expect(find.textContaining('gizli123'), findsNothing);
  }, variant: windows);

  testWidgets('kod içermeyen görselde anlaşılır mesaj', (tester) async {
    final blank = (await tester.runAsync(
      () => QrExport.renderPng(
        data: 'x',
        size: 64,
        foreground: Colors.white,
        background: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      ),
    ))!;
    FilePicker.platform = _FakePicker(blank);
    await pumpScan(tester);
    await tester.tap(find.text('Görsel dosyası seç'));
    await settle(tester);
    expect(find.text('Görselde QR kod veya barkod bulunamadı'), findsOneWidget);
    expect(find.text('BAŞARILI OKUMA'), findsNothing);
  }, variant: windows);

  testWidgets('Ctrl+V panodaki metni sonuç olarak gösterir', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'https://ornek.com'};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    FilePicker.platform = _FakePicker(null);
    await pumpScan(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);

    expect(find.text('https://ornek.com'), findsOneWidget);
    expect(find.text('Tarayıcıda aç'), findsOneWidget);
  }, variant: windows);

  test('geçerli satırı olmayan toplu barkod ZIP üretmez', () async {
    final r = await BarcodeBatchExport.shareSvgZip(
      lines: ['abc', '12'],
      type: BarcodeBatchType.ean13,
    );
    expect(r.count, 0);
    expect(r.path, isNull);
  });

  test('kaydedilen dosya baytları diske yazılır', () async {
    final dir = await Directory.systemTemp.createTemp('qr_kaydet');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}qr_kod.png';
    await File(path).writeAsBytes([9, 9, 9, 9]); // aynı uzunlukta eski dosya
    await FileOutput.writeBytes(path, Uint8List.fromList([1, 2, 3, 4]));
    expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
  });
}
