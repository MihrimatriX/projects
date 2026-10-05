using System;
using System.Linq;
using System.Text;

namespace ClipboardYoneticisi.Helpers
{
    public static class FuzzySearchHelper
    {
        /// <summary>
        /// FTS5 prefix query: each token matches word start (token*).
        /// Multiple tokens are OR'd for broader fuzzy matching.
        /// </summary>
        public static string BuildFtsQuery(string input)
        {
            var tokens = Tokenize(input);
            if (tokens.Length == 0)
                return input;

            if (tokens.Length == 1)
                return $"\"{EscapeToken(tokens[0])}\"*";

            return string.Join(" OR ", tokens.Select(t => $"\"{EscapeToken(t)}\"*"));
        }

        public static bool MatchesFuzzy(string haystack, string needle)
        {
            if (string.IsNullOrWhiteSpace(needle))
                return true;

            var content = haystack ?? string.Empty;
            var tokens = Tokenize(needle);

            return tokens.All(token =>
                content.Contains(token, StringComparison.OrdinalIgnoreCase));
        }

        private static string[] Tokenize(string input) =>
            input.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        private static string EscapeToken(string token) =>
            token.Replace("\"", "\"\"");
    }
}
