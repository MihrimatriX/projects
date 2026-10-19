import '../../features/recipes/models/recipe.dart';

List<Recipe> sampleRecipes() => [
      const Recipe(
        id: 'sample_mercimek',
        title: 'Mercimek Çorbası',
        description: 'Klasik kırmızı mercimek çorbası',
        prepMinutes: 10,
        cookMinutes: 25,
        servings: 4,
        tags: ['çorba', 'vejetaryen', 'hızlı'],
        ingredients: '''
1 su bardağı kırmızı mercimek
1 adet soğan
1 yemek kaşığı zeytinyağı
1 yemek kaşığı un
1 litre su
Tuz
''',
        steps: '''
Soğanı kavurun, unu ekleyip kokusu çıkana kadar kavurun.
Mercimek ve suyu ekleyin, 20 dk pişirin.
Blend edip servis edin.
''',
      ),
      const Recipe(
        id: 'sample_kofte',
        title: 'Fırın Köfte',
        description: 'Patatesli fırın köfte',
        prepMinutes: 20,
        cookMinutes: 40,
        servings: 4,
        tags: ['ana yemek'],
        ingredients: '''
500 g kıyma
1 adet soğan
2 diş sarımsak
500 g patates
2 yemek kaşığı zeytinyağı
Tuz, karabiber
''',
        steps: '''
Kıymayı baharatlarla yoğurun, köfte şekli verin.
Patatesleri dilimleyin, tepsiye dizin.
200°C fırında 35-40 dk pişirin.
''',
      ),
      const Recipe(
        id: 'sample_salata',
        title: 'Çoban Salata',
        description: 'Yaz salatası',
        prepMinutes: 15,
        cookMinutes: 0,
        servings: 2,
        tags: ['salata', 'vejetaryen', 'hızlı'],
        ingredients: '''
2 adet domates
1 adet salatalık
1 adet yeşil biber
Yarım soğan
Zeytinyağı, limon, tuz
''',
        steps: '''
Tüm sebzeleri küp doğrayın.
Zeytinyağı, limon ve tuzla karıştırın.
''',
      ),
    ];
