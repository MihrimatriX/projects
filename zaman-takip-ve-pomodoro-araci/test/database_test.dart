import 'package:flutter_test/flutter_test.dart';
import 'package:zaman_takip_ve_pomodoro_araci/data/database.dart';

void main() {
  test('proje silinince kayitlari da silinir, durdurma bitis anini yazar', () async {
    final db = AppDatabase.test();
    final pid = await db.insertProject('Test');
    final eid = await db.startEntry(pid);
    final end = DateTime.now().add(const Duration(minutes: 5));
    await db.stopEntry(eid, endedAt: end);

    final entries = await db.getTodayEntries();
    expect(entries.single.endedAt!.difference(end).inSeconds.abs(), lessThan(1));

    await db.deleteProject(pid);
    expect(await db.getTodayEntries(includeActive: true), isEmpty);
    await db.close();
  });
}
