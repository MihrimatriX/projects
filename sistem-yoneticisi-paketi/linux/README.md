# Sistem Yöneticisi Paketi — Linux CLI

Terminal tabanlı basit sistem monitörü (`psutil`).

- CPU, RAM, disk ve toplam ağ trafiği özeti
- CPU kullanımına göre sıralı süreç listesi
- `--json` ile script dostu çıktı

## Kurulum ve kullanım

```bash
cd linux
pip install -r requirements.txt
python3 monitor.py dashboard            # anlık özet
python3 monitor.py watch --interval 1   # canlı izleme (Ctrl+C ile çık)
python3 monitor.py processes --limit 10 --json
```

Gereksinim: Python 3.9+, psutil 5.9+.
