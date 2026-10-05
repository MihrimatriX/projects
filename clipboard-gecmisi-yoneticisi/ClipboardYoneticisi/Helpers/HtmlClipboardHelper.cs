using System;
using System.Text;
using System.Text.RegularExpressions;

namespace ClipboardYoneticisi.Helpers
{
    public static class HtmlClipboardHelper
    {
        private static readonly Regex HtmlTagRegex = new("<[^>]+>", RegexOptions.Compiled);

        public static string ExtractPlainText(string htmlFragment)
        {
            if (string.IsNullOrWhiteSpace(htmlFragment))
                return string.Empty;

            var body = htmlFragment;
            // CF_HTML basligi: "StartFragment:000123" / "EndFragment:000456".
            // Ofsetler UTF-8 BAYT cinsindendir (karakter degil); Turkce karakterlerde kaymamasi icin
            // bayt dizisi uzerinden kesilir. Bozuk baslikta tum metin kullanilir (istisna atilmaz).
            var startMatch = Regex.Match(htmlFragment, @"StartFragment:(\d+)", RegexOptions.IgnoreCase);
            var endMatch = Regex.Match(htmlFragment, @"EndFragment:(\d+)", RegexOptions.IgnoreCase);
            if (startMatch.Success && endMatch.Success &&
                int.TryParse(startMatch.Groups[1].Value, out var startIndex) &&
                int.TryParse(endMatch.Groups[1].Value, out var endIndex))
            {
                var bytes = Encoding.UTF8.GetBytes(htmlFragment);
                if (startIndex >= 0 && endIndex <= bytes.Length && endIndex > startIndex)
                    body = Encoding.UTF8.GetString(bytes, startIndex, endIndex - startIndex);
            }

            var text = HtmlTagRegex.Replace(body, " ");
            text = System.Net.WebUtility.HtmlDecode(text);
            return NormalizeWhitespace(text);
        }

        private static string NormalizeWhitespace(string text)
        {
            var sb = new StringBuilder(text.Length);
            var lastWasSpace = false;
            foreach (var ch in text)
            {
                if (char.IsWhiteSpace(ch))
                {
                    if (!lastWasSpace)
                    {
                        sb.Append(' ');
                        lastWasSpace = true;
                    }
                }
                else
                {
                    sb.Append(ch);
                    lastWasSpace = false;
                }
            }
            return sb.ToString().Trim();
        }
    }
}
