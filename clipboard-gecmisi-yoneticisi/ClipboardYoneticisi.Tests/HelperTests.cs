using System.IO;
using ClipboardYoneticisi.Helpers;
using Xunit;

namespace ClipboardYoneticisi.Tests;

public class ContentClassifierTests
{
    [Theory]
    [InlineData("https://example.com", TextCategory.Url)]
    [InlineData("user@mail.com", TextCategory.Email)]
    [InlineData("function hello() {}", TextCategory.Code)]
    [InlineData("plain note", TextCategory.Plain)]
    public void Classify_detects_categories(string input, TextCategory expected)
    {
        Assert.Equal(expected, ContentClassifier.Classify(input));
    }
}

public class SnippetTransformTests
{
    [Fact]
    public void Lowercase_transforms_text()
    {
        Assert.Equal("hello", SnippetTransform.Apply("HELLO", TransformType.Lowercase));
    }

    [Fact]
    public void JsonPretty_indents_valid_json()
    {
        var result = SnippetTransform.Apply("{\"a\":1}", TransformType.JsonPretty);
        Assert.Contains("\n", result);
        Assert.Contains("\"a\"", result);
    }

    [Fact]
    public void MarkdownLink_wraps_url()
    {
        var result = SnippetTransform.Apply("https://x.com", TransformType.MarkdownLink);
        Assert.Equal("[https://x.com](https://x.com)", result);
    }
}

public class HotkeyParserTests
{
    [Fact]
    public void TryParse_parses_ctrl_alt_v()
    {
        var ok = HotkeyParser.TryParse("Ctrl+Alt+V", out var key, out var mods);
        Assert.True(ok);
        Assert.Equal(System.Windows.Input.Key.V, key);
        Assert.Equal(
            System.Windows.Input.ModifierKeys.Control | System.Windows.Input.ModifierKeys.Alt,
            mods);
    }
}

public class HtmlClipboardHelperTests
{
    [Fact]
    public void ExtractPlainText_strips_tags()
    {
        var plain = HtmlClipboardHelper.ExtractPlainText("<b>Hello</b> world");
        Assert.Equal("Hello world", plain);
    }

    [Fact]
    public void ExtractPlainText_uses_utf8_byte_offsets_of_cf_html()
    {
        const string header = "Version:0.9\r\nStartHTML:0000000000\r\nEndHTML:0000000000\r\nStartFragment:SSSSSSSSSS\r\nEndFragment:EEEEEEEEEE\r\n";
        var prefix = header + "<html><body>şğü <!--StartFragment-->";
        var fragment = "<b>Çalışma</b> öğesi";
        var html = prefix + fragment + "<!--EndFragment--> ignored</body></html>";
        var start = System.Text.Encoding.UTF8.GetByteCount(prefix);
        var end = start + System.Text.Encoding.UTF8.GetByteCount(fragment);
        html = html.Replace("SSSSSSSSSS", start.ToString("D10")).Replace("EEEEEEEEEE", end.ToString("D10"));

        Assert.Equal("Çalışma öğesi", HtmlClipboardHelper.ExtractPlainText(html));
    }
}

public class FuzzySearchHelperTests
{
    [Fact]
    public void BuildFtsQuery_uses_prefix_for_single_token()
    {
        var query = FuzzySearchHelper.BuildFtsQuery("hello");
        Assert.Equal("\"hello\"*", query);
    }

    [Fact]
    public void BuildFtsQuery_or_joins_multiple_tokens()
    {
        var query = FuzzySearchHelper.BuildFtsQuery("foo bar");
        Assert.Contains(" OR ", query);
        Assert.Contains("\"foo\"*", query);
        Assert.Contains("\"bar\"*", query);
    }

    [Fact]
    public void MatchesFuzzy_requires_all_tokens()
    {
        Assert.True(FuzzySearchHelper.MatchesFuzzy("hello world test", "hel tes"));
        Assert.False(FuzzySearchHelper.MatchesFuzzy("hello world", "hel xyz"));
    }
}

public class SensitiveContentDetectorTests
{
    [Theory]
    [InlineData("password=abc123", true)]
    [InlineData("my parola is secret", true)]
    [InlineData("hello world", false)]
    public void LooksSensitive_detects_keywords(string input, bool expected)
    {
        Assert.Equal(expected, SensitiveContentDetector.LooksSensitive(input));
    }

    [Fact]
    public void Blur_masks_content()
    {
        Assert.Equal("••••••••••••", SensitiveContentDetector.Blur("password1234"));
    }
}

public class ClipboardFilterTests
{
    [Fact]
    public void Skips_password_manager_content_and_isolates_test_content()
    {
        var plain = new System.Windows.DataObject("metin");
        Assert.False(ClipboardYoneticisi.Services.ClipboardMonitorService.ShouldSkip(plain, testMode: false));
        Assert.True(ClipboardYoneticisi.Services.ClipboardMonitorService.ShouldSkip(plain, testMode: true));

        var excluded = new System.Windows.DataObject("parola");
        excluded.SetData(ClipboardYoneticisi.Services.ClipboardMonitorService.ExcludeFormat, "1");
        Assert.True(ClipboardYoneticisi.Services.ClipboardMonitorService.ShouldSkip(excluded, testMode: false));

        var marked = new System.Windows.DataObject("test");
        marked.SetData(ClipboardYoneticisi.Services.ClipboardMonitorService.TestMarkerFormat, "1");
        Assert.True(ClipboardYoneticisi.Services.ClipboardMonitorService.ShouldSkip(marked, testMode: false));
        Assert.False(ClipboardYoneticisi.Services.ClipboardMonitorService.ShouldSkip(marked, testMode: true));
    }
}
