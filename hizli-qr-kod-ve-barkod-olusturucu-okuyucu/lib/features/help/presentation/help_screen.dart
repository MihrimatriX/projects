import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Yardım'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'QR ve Barkod',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          Text(
            'Tüm işlemler cihazınızda yapılır; hesap veya bulut senkronizasyonu yoktur.',
          ),
          SizedBox(height: 20),
          _HelpSection(
            title: 'Oluştur',
            bullets: [
              'QR sekmesi: URL, Wi-Fi, vCard ve şablonlar',
              'Logo eklerken hata düzeltme otomatik H olur',
              'SVG dışa aktarma logo varken kullanılamaz',
              'Barkod: Code128 metin, EAN-13 12/13 rakam',
              'Toplu: CSV/TXT → ZIP (QR PNG/SVG veya barkod SVG)',
            ],
          ),
          _HelpSection(
            title: 'Oku',
            bullets: [
              'Kamera veya galeriden okuma',
              'URL açmadan önce güvenlik uyarısı gösterilir',
              'Wi-Fi şifreleri ayarlardan maskelenebilir',
            ],
          ),
          _HelpSection(
            title: 'Gizlilik',
            bullets: [
              'Geçmiş yalnızca cihazda saklanır',
              'JSON dışa/içe aktarma isteğe bağlıdır',
            ],
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(b)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
