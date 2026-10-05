import type { RegexPreset } from "./types";

export const REGEX_PRESETS: RegexPreset[] = [
  {
    id: "email",
    name: "✉️ E-posta Doğrulama",
    pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
    flags: "gm",
    testText: "test@example.com\nhello.world_123@domain.co.uk\ninvalid-email@domain\n@missing-local.com",
    description: "RFC 5322 standardına uygun e-posta adreslerini tespit eder."
  },
  {
    id: "url",
    name: "🌐 Web URL Adresi",
    pattern: "https?:\\/\\/(www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b([-a-zA-Z0-9()@:%_\\+.~#?&//=]*)",
    flags: "g",
    testText: "Uygulamayı https://github.com adresinden veya http://localhost:3000 adresinden çalıştırabilirsiniz.",
    description: "HTTP ve HTTPS protokolüyle başlayan web bağlantılarını yakalar."
  },
  {
    id: "phone_tr",
    name: "📞 Türkiye Telefon No",
    pattern: "^(0|\\+90)?\\s*5\\d{2}\\s*\\d{3}\\s*\\d{2}\\s*\\d{2}$",
    flags: "gm",
    testText: "0532 123 45 67\n+90 542 987 65 43\n5551234567\n0212 123 45 67",
    description: "Türkiye GSM operatör kodları (5xx) ile başlayan cep telefon numaralarını doğrular."
  },
  {
    id: "tckn",
    name: "🆔 TC Kimlik Numarası",
    pattern: "^[1-9]\\d{9}[02468]$",
    flags: "gm",
    testText: "12345678902\n10000000000\n01234567890 (Sıfır ile başlayamaz)\n12345678901 (Son hanesi tek olamaz)",
    description: "11 haneli, sıfır ile başlamayan ve son hanesi çift olan Türkiye Cumhuriyeti Kimlik Numaralarını sorgular."
  },
  {
    id: "ipv4",
    name: "🖥️ IPv4 Adresi",
    pattern: "\\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\b",
    flags: "g",
    testText: "Localhost IP adresi: 127.0.0.1. Modemin IP adresi 192.168.1.1. Geçersiz IP: 256.100.0.1.",
    description: "0.0.0.0 ile 255.255.255.255 aralığındaki IPv4 adreslerini yakalar."
  },
  {
    id: "date_tr",
    name: "📅 Tarih (GG/AA/YYYY)",
    pattern: "\\b(0[1-9]|[12]\\d|3[01])[-/\\.](0[1-9]|1[012])[-/\\.](19|20)\\d\\d\\b",
    flags: "g",
    testText: "Bugün 01.06.2026. Toplantı 15/08/2026 tarihinde. Geçersiz tarih: 32/13/2020.",
    description: "GG/AA/YYYY formatındaki geçerli gün, ay ve yılları (1900-2099 arası) tespit eder."
  },
  {
    id: "password",
    name: "🔑 Güçlü Şifre",
    pattern: "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$",
    flags: "gm",
    testText: "Aa1!asdf (Geçerli)\nPass1234 (Eksik özel karakter)\nlowercase1! (Eksik büyük harf)\nUPPERCASE1! (Eksik küçük harf)",
    description: "En az 8 karakter, bir büyük, bir küçük harf, bir rakam ve bir özel karakter içerir."
  },
  {
    id: "plate",
    name: "🚗 Plaka Kodu (Türkiye)",
    pattern: "^(0[1-9]|[1-7][0-9]|8[01])\\s*[A-Z]{1,3}\\s*\\d{2,4}$",
    flags: "gm",
    testText: "34 AAA 123\n06 B 4567\n82 Z 999 (Geçersiz il kodu)\n35AB12",
    description: "Türkiye taşıt plaka formatlarını (İl Kodu + Harf + Rakam) doğrular."
  },
  {
    id: "html",
    name: "🏷️ HTML Etiketi Ayıklama",
    pattern: "<(\\/?[a-zA-Z0-9]+)([^>]*)>",
    flags: "g",
    testText: "<div className=\"bg-slate-900\">\n  <h1 id=\"title\">Başlık</h1>\n  <p>Paragraf</p>\n</div>",
    description: "HTML etiket adlarını ve niteliklerini (attributes) ayıklar."
  },
  {
    id: "hex_color",
    name: "🎨 Hex Renk Kodu",
    pattern: "#([a-fA-F0-9]{6}|[a-fA-F0-9]{3})\\b",
    flags: "g",
    testText: "Renk paleti: #FFF (beyaz), #F43F5E (rose), #0000 (geçersiz), #abc12345 (geçersiz).",
    description: "3 veya 6 basamaklı Hexadecimal CSS renk tanımlarını bulur."
  },
  {
    id: "turkish_chars",
    name: "🇹🇷 Türkçe Karakterler",
    pattern: "[çğıöşüÇĞİÖŞÜ]",
    flags: "g",
    testText: "İstanbul'da öğrenciler şehir içi ulaşımı kullanıyor. Çiğdem ve Gökhan da burada.",
    description: "Türkçe'ye özgü ç, ğ, ı, ö, ş, ü harflerini (büyük/küçük) yakalar."
  },
  {
    id: "iban_tr",
    name: "🏦 Türkiye IBAN",
    pattern: "TR\\d{2}\\s?\\d{4}\\s?\\d{4}\\s?[\\d\\s]{1,16}",
    flags: "gi",
    testText: "Havale için IBAN: TR33 0006 1005 1978 6457 8413 26\nGeçersiz: TR1 1234",
    description: "TR ile başlayan Türkiye IBAN numaralarını tespit eder."
  },
  {
    id: "uuid",
    name: "🔖 UUID v4",
    pattern: "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}",
    flags: "g",
    testText: "Kayıt ID: 550e8400-e29b-41d4-a716-446655440000\nGeçersiz: 123e4567-e89b-12d3-a456-426614174000",
    description: "RFC 4122 UUID v4 formatındaki benzersiz tanımlayıcıları bulur."
  },
  {
    id: "slug",
    name: "🔗 URL Slug",
    pattern: "\\b[a-z0-9]+(?:-[a-z0-9]+)+\\b",
    flags: "g",
    testText: "Blog yazısı: regex-ogrenme-rehberi ve next-js-kurulum rehberi.",
    description: "Küçük harf, rakam ve tire ile oluşturulmuş URL slug'larını yakalar."
  },
  {
    id: "time_24h",
    name: "⏰ Saat (24s)",
    pattern: "\\b([01]?\\d|2[0-3]):[0-5]\\d\\b",
    flags: "g",
    testText: "Toplantı 09:30'da başlıyor. Bitiş 17:45. Geçersiz: 25:99.",
    description: "00:00 ile 23:59 arası geçerli 24 saat formatı saatleri bulur."
  },
  {
    id: "markdown_link",
    name: "📎 Markdown Bağlantı",
    pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
    flags: "g",
    testText: "Detaylar için [Regex rehberi](https://example.com/regex) sayfasına bakın.",
    description: "Markdown [metin](url) bağlantı sözdizimini ve yakalama gruplarını ayıklar."
  },
  {
    id: "hashtag",
    name: "#️⃣ Hashtag",
    pattern: "#[\\wçğıöşüÇĞİÖŞÜ]+",
    flags: "gu",
    testText: "Bugün #RegexÖğreniyorum ve #YazılımGeliştirme trendlerinde.",
    description: "Sosyal medya hashtag'lerini (Türkçe karakter destekli) yakalar."
  },
  {
    id: "credit_card",
    name: "💳 Kredi Kartı (Luhn değil)",
    pattern: "\\b(?:\\d{4}[\\s-]?){3}\\d{4}\\b",
    flags: "g",
    testText: "Test kartı: 4111 1111 1111 1111\nGeçersiz: 1234 5678",
    description: "16 haneli kart numarası formatını tespit eder (doğrulama yapmaz)."
  },
  {
    id: "json_string",
    name: "📄 JSON String Değeri",
    pattern: "\"(?:[^\"\\\\]|\\\\.)*\"",
    flags: "g",
    testText: "{\"name\": \"Ali\", \"city\": \"İstanbul\", \"note\": \"Merhaba \\\"dünya\\\"\"}",
    description: "JSON içindeki çift tırnaklı string değerlerini ayıklar."
  },
  {
    id: "whitespace_trim",
    name: "✂️ Satır Başı/Sonu Boşluk",
    pattern: "^\\s+|\\s+$",
    flags: "gm",
    testText: "   Başında boşluk var\nSonunda boşluk var   \n  Her iki tarafta  ",
    description: "Satır başı veya sonundaki gereksiz boşluk karakterlerini bulur."
  }
];
