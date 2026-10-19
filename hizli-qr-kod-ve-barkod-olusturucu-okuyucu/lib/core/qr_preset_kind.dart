enum QrPresetKind { url, text, wifi, vcard }

extension QrPresetKindX on QrPresetKind {
  String get label => switch (this) {
        QrPresetKind.url => 'URL',
        QrPresetKind.text => 'Metin',
        QrPresetKind.wifi => 'WiFi',
        QrPresetKind.vcard => 'vCard',
      };
}
