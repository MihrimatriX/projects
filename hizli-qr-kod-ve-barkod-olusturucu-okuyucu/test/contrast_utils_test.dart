import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/contrast_utils.dart';

void main() {
  test('black on white passes contrast', () {
    expect(
      ContrastUtils.hasReadableQrContrast(Colors.black, Colors.white),
      isTrue,
    );
  });

  test('low contrast pair fails', () {
    expect(
      ContrastUtils.hasReadableQrContrast(
        const Color(0xFFCCCCCC),
        Colors.white,
      ),
      isFalse,
    );
  });
}
