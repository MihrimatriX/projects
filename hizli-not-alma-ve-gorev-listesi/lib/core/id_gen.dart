/// Kayıt kimlikleri: milisaniye zaman damgası (görevlerde `createdAt` buradan
/// okunur), ama aynı milisaniyede ikinci çağrı bir sonraki değeri alır.
/// Önceden hızlı art arda eklemede (ör. tekrarlayan görev tamamlanınca açılan
/// kopya, Enter'a iki kez basma) birincil anahtar çakışıyordu.
int _last = 0;

String newId() {
  final now = DateTime.now().millisecondsSinceEpoch;
  _last = now > _last ? now : _last + 1;
  return '$_last';
}
