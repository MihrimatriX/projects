using System.Text;

namespace ProjeLauncher.Services;

/// <summary>
/// Arama icin buyuk/kucuk harf ve Turkce harf duyarsiz katlama:
/// "İ/I/ı/i" -> "i", "Ö/ö" -> "o", "Ü" -> "u", "Ş" -> "s", "Ç" -> "c", "Ğ" -> "g".
/// Boylece "ogrenme" "Öğrenme"yi, "ISIK" "ışık"ı bulur (klasor adlari ASCII, gorunen adlar Turkce).
/// </summary>
public static class TurkishText
{
    public static string Fold(string s)
    {
        var sb = new StringBuilder(s.Length);
        foreach (var c in s)
        {
            sb.Append(c switch
            {
                'İ' or 'I' or 'ı' or 'i' => 'i',
                'Ö' or 'ö' => 'o',
                'Ü' or 'ü' => 'u',
                'Ş' or 'ş' => 's',
                'Ç' or 'ç' => 'c',
                'Ğ' or 'ğ' => 'g',
                _ => char.ToLowerInvariant(c)
            });
        }
        return sb.ToString();
    }
}
