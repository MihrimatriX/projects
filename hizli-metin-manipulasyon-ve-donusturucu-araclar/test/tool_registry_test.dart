import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_metin_manipulasyon_ve_donusturucu_araclar/features/tools/data/tool_registry.dart';

void main() {
  group('Türkçe büyük/küçük harf', () {
    test('BÜYÜK HARF (Türkçe): i → İ, ı → I', () {
      expect(toUpperTr('istanbul ılık iğde'), 'İSTANBUL ILIK İĞDE');
      expect(toUpperTr('çğıöşü i ı'), 'ÇĞIÖŞÜ İ I');
    });

    test('küçük harf (Türkçe): I → ı, İ → i', () {
      expect(toLowerTr('İSTANBUL ILIK'), 'istanbul ılık');
      expect(toLowerTr('ÇĞIİÖŞÜ'), 'çğıiöşü');
      // Ayrışık biçim: I + U+0307 birleşen nokta da i olur.
      expect(toLowerTr('İSTANBUL'), 'istanbul');
    });

    test('Türkçe gidiş-dönüş bilgi kaybetmez', () {
      const s = 'ıIiİ';
      expect(toLowerTr(toUpperTr(s)), 'ııii');
      expect(toUpperTr(toLowerTr(s)), 'IIİİ');
    });

    test('dilden bağımsız sürüm İngilizce kuralını uygular, artık nokta bırakmaz', () {
      expect(toUpperCase('istanbul'), 'ISTANBUL');
      expect(toLowerCase('İSTANBUL'), 'istanbul');
      expect(toLowerCase('İ').length, 1);
    });

    test('Başlık Düzeni (Türkçe)', () {
      expect(toTitleTr("istanbul'da ılık bir İZMİR akşamı"), "İstanbul'da Ilık Bir İzmir Akşamı");
      expect(toTitleTr('  çok   boşluk\nsatır'), '  Çok   Boşluk\nSatır');
      expect(toTitleTr('123abc'), '123abc');
    });
  });

  group('Unicode', () {
    test('reverse grafem kümelerini bozmaz', () {
      expect(reverseText('abc'), 'cba');
      expect(reverseText('👨‍👩‍👧 x'), 'x 👨‍👩‍👧');
      expect(reverseText('🇹🇷🇩🇪'), '🇩🇪🇹🇷');
      expect(reverseText('éa'), 'aé');
      expect(reverseText('şığ'), 'ğış');
    });

    test('kelime sayımı görünen karakteri sayar', () {
      expect(wordCount('👍🏽 ok'), startsWith('4 karakter, 2 kelime, 1 satır'));
      expect(wordCount('ç\r\nş\r\n'), contains('2 satır'));
      expect(wordCount('ş'), contains('2 bayt (UTF-8)'));
      expect(wordCount(''), startsWith('0 karakter, 0 kelime, 0 satır'));
    });

    test('base64 ve URL Türkçe/emoji ile gidiş-dönüş', () {
      const input = 'Merhaba dünya! ışğüöç İ 👋🏽';
      expect(decodeBase64(encodeBase64(input)), input);
      expect(urlDecode(urlEncode(input)), input);
      expect(urlEncode('ş'), '%C5%9F');
    });

    test('hash UTF-8 baytları üzerinden', () {
      expect(hashSha256('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(hashMd5('ı'), isNot(hashMd5('i')));
      expect(hashMd5('abc'), '900150983cd24fb0d6963f7d28e17f72');
    });
  });

  group('Base64 decode toleransı', () {
    test('URL-safe, dolgusuz ve satır sonlu girdi', () {
      final std = encodeBase64('şğü?>');
      final urlSafe = std.replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
      expect(decodeBase64(urlSafe), 'şğü?>');
      expect(decodeBase64('TWVy\r\naGFi\nYQ=='), 'Merhaba');
    });

    test('hatalar Türkçe ve araç hatası olarak işaretlenir', () {
      expect(decodeBase64('a'), startsWith('Geçersiz Base64'));
      expect(decodeBase64('@@@@'), startsWith('Geçersiz Base64'));
      expect(decodeBase64(base64Encode([0xff, 0xfe, 0x00])), contains('UTF-8 metin değil'));
      final tool = findToolById('base64-decode')!;
      expect(isTransformError(decodeBase64('@@@@'), tool), isTrue);
    });
  });

  group('HTML entity', () {
    test('sayısal ve adlı varlıklar', () {
      expect(htmlDecode('&#351;&#x15F;&#X15e; &nbsp;&copy;'), 'şşŞ  ©');
      expect(htmlDecode('&amp;lt;'), '&lt;');
      expect(htmlDecode('&bilinmeyen; &#xD800; &#99999999;'), '&bilinmeyen; &#xD800; &#99999999;');
    });

    test('encode → decode gidiş-dönüş', () {
      const s = '<a href="x">Çağ & \'İz\'</a>';
      expect(htmlDecode(htmlEncode(s)), s);
    });
  });

  group('Satır araçları', () {
    test('Türk alfabesine göre sıralar (ç c\'den, ı i\'den önce)', () {
      expect(sortLines('şeker\nçay\nzeytin\ncam\nsu\nılık\nirmik\nİnci\nIrmak'),
          'cam\nçay\nılık\nIrmak\nİnci\nirmik\nsu\nşeker\nzeytin');
    });

    test('büyük/küçük harf duyarsız, rakamlar önce, sondaki satır sonu korunur', () {
      expect(sortLines('b\nA\n10\na\n'), '10\nA\na\nb\n');
    });

    test('CRLF satır sonları korunur', () {
      expect(sortLines('b\r\na\r\n'), 'a\r\nb\r\n');
    });

    test('tekrarlanan satırlar silinir, sıra korunur', () {
      expect(dedupeLines('x\ny\nx\n\ny\n'), 'x\ny\n\n');
      expect(dedupeLines('a\r\na\r\n'), 'a\r\n');
    });
  });

  group('Kod biçimleri', () {
    test('Türkçe harfler korunur (eskiden siliniyordu)', () {
      expect(toSnakeCase('Çalışma Saati'), 'çalışma_saati');
      expect(toKebabCase('Öğrenci Şube No'), 'öğrenci-şube-no');
      expect(toCamelCase('günlük rapor özeti'), 'günlükRaporÖzeti');
    });

    test('camelCase/PascalCase girdisi bölünür', () {
      expect(toSnakeCase('parseHTTPResponse'), 'parse_http_response');
      expect(toKebabCase('userId2Name'), 'user-id2-name');
      expect(toCamelCase('USER_ID'), 'userId');
      expect(toCamelCase('İSTANBUL ŞUBE'), 'istanbulŞube');
    });

    test('slug Türkçe karakterleri sadeleştirir', () {
      expect(toSlug('Çalışma Şekli: İyi & Güzel!'), 'calisma-sekli-iyi-guzel');
      expect(toSlug('  IŞIK  '), 'isik');
      expect(toSlug('Crème brûlée'), 'creme-brulee');
      expect(toSlug('---'), '');
    });
  });

  group('Diğer araçlar', () {
    test('JSON pretty/minify ve Türkçe hata', () {
      expect(jsonMinify('{ "ad": "Şule" }'), '{"ad":"Şule"}');
      expect(jsonPretty('{"a":1}'), '{\n  "a": 1\n}');
      expect(jsonPretty('{bozuk'), startsWith('Geçersiz JSON'));
    });

    test('Unix → ISO saniye, milisaniye, negatif ve aralık dışı', () {
      expect(timestampToIso('0'), '1970-01-01T00:00:00.000Z');
      expect(timestampToIso('1700000000'), '2023-11-14T22:13:20.000Z');
      expect(timestampToIso('1700000000000'), '2023-11-14T22:13:20.000Z');
      expect(timestampToIso('-86400'), '1969-12-31T00:00:00.000Z');
      expect(timestampToIso('abc'), startsWith('Geçersiz timestamp'));
      expect(timestampToIso('99999999999999999'), startsWith('Geçersiz timestamp'));
    });

    test('JWT header/payload', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n69I6ShQ';
      expect(decodeJwtHeader(jwt), contains('"alg": "HS256"'));
      expect(decodeJwtPayload(jwt), contains('"sub": "1234567890"'));
      expect(decodeJwtPayload('abc'), startsWith('Geçersiz JWT'));
    });

    test('UUID v4 biçimi', () {
      expect(generateUuidV4(),
          matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });
  });

  group('Büyük girdi', () {
    test('1 MB+ metinde her araç biter ve tutarlı çıktı verir', () {
      final line = 'Şirket İstanbul ığdır çalışma 👋🏽 <b>&amp;</b>\n';
      final big = List.generate(25000, (i) => '$i $line').join();
      expect(big.length, greaterThan(1000000));
      // Debug (JIT) testte ve paylaşılan CPU altında duvar saati oynak; bu sınır
      // yalnızca karesel (O(n^2)) patlamayı yakalar. Release derlemede çok daha hızlı.
      for (final tool in allTextTools) {
        final sw = Stopwatch()..start();
        tool.transform(big);
        expect(sw.elapsed.inSeconds, lessThan(30), reason: tool.id);
      }
      expect(toUpperTr(big).length, big.length);
      expect(sortLines(big).split('\n').length, big.split('\n').length);
      expect(reverseText(reverseText(big)), big);
    }, timeout: const Timeout(Duration(minutes: 10)));
  });

  test('filterTools Türkçe ve aksansız arama', () {
    expect(filterTools('md5'), isNotEmpty);
    expect(filterTools('md5').every((t) => t.name.toLowerCase().contains('md5') || t.id.contains('md5')), isTrue);
    expect(filterTools('xyzbulunmaz'), isEmpty);
    expect(filterTools('buyuk').map((t) => t.id), contains('upper-tr'));
    expect(filterTools('TÜRKÇE').map((t) => t.id), containsAll(['upper-tr', 'lower-tr', 'title-tr']));
    expect(filterTools('ISO').map((t) => t.id), contains('timestamp-iso'));
  });

  test('looksSensitive JWT ve private key', () {
    expect(
      looksSensitive('eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n69I6ShQ'),
      isTrue,
    );
    expect(looksSensitive('-----BEGIN PRIVATE KEY-----'), isTrue);
    expect(looksSensitive('-----BEGIN OPENSSH PRIVATE KEY-----'), isTrue);
    expect(looksSensitive('hello'), isFalse);
    expect(looksSensitive('www.example.com'), isFalse);
    expect(looksSensitive('hello.world.again'), isFalse);
  });

  test('isTransformError yalnızca hata üretebilen araçlarda', () {
    expect(isTransformError('Geçersiz Base64: foo'), isTrue);
    expect(isTransformError('abc123'), isFalse);
    expect(isTransformError('Geçersiz giriş metni', findToolById('trim')), isFalse);
  });

  test('allTextTools benzersiz id', () {
    final ids = allTextTools.map((t) => t.id).toList();
    expect(ids.length, ids.toSet().length);
    expect(allTextTools.length, greaterThanOrEqualTo(29));
  });
}

