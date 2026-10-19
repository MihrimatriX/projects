using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using EkranRenkSecici.Models;
using DrawingPixelFormat = System.Drawing.Imaging.PixelFormat;
using Color = System.Windows.Media.Color;

namespace EkranRenkSecici.Helpers;

public static class ColorHelper
{
    public static string ToHex(Color color) =>
        $"#{color.R:X2}{color.G:X2}{color.B:X2}";

    public static string ToRgbString(Color color) =>
        $"rgb({color.R}, {color.G}, {color.B})";

    public static string ToHslString(Color color)
    {
        var (h, s, l) = ToHsl(color);
        return $"hsl({Math.Round(h)}, {Math.Round(s * 100)}%, {Math.Round(l * 100)}%)";
    }

    // CSS/JSON ciktilari kultur bagimsiz olmali (tr-TR'de ondalik ayirici virgul olur).
    public static string ToOklchString(Color color)
    {
        var (l, c, h) = ToOklch(color);
        return string.Create(CultureInfo.InvariantCulture, $"oklch({l:F1}% {c:F3} {h:F1})");
    }

    /// <summary>"#RGB", "#RRGGBB", "RRGGBB" veya "rgb(r, g, b)" metnini renge cevirir.</summary>
    public static bool TryParse(string? input, out Color color)
    {
        color = default;
        var s = input?.Trim() ?? string.Empty;

        var m = Regex.Match(s, @"^rgb\(\s*(\d{1,3})[\s,]+(\d{1,3})[\s,]+(\d{1,3})\s*\)$", RegexOptions.IgnoreCase);
        if (m.Success)
        {
            int r = int.Parse(m.Groups[1].Value), g = int.Parse(m.Groups[2].Value), b = int.Parse(m.Groups[3].Value);
            if (r > 255 || g > 255 || b > 255) return false;
            color = Color.FromRgb((byte)r, (byte)g, (byte)b);
            return true;
        }

        s = s.TrimStart('#');
        if (s.Length == 3) s = string.Concat(s.Select(ch => new string(ch, 2)));
        if (s.Length != 6 || !int.TryParse(s, NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture, out var v))
            return false;

        color = Color.FromRgb((byte)(v >> 16), (byte)(v >> 8), (byte)v);
        return true;
    }

    public static (double L, double C, double H) ToOklch(Color color)
    {
        double r = SrgbToLinear(color.R / 255.0);
        double g = SrgbToLinear(color.G / 255.0);
        double b = SrgbToLinear(color.B / 255.0);

        double lr = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
        double mg = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
        double sb = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

        double lRoot = Math.Cbrt(lr);
        double mRoot = Math.Cbrt(mg);
        double sRoot = Math.Cbrt(sb);

        double okL = 0.2104542553 * lRoot + 0.7936177850 * mRoot - 0.0040720468 * sRoot;
        double okA = 1.9779984951 * lRoot - 2.4285922050 * mRoot + 0.4505937099 * sRoot;
        double okB = 0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.8086757660 * sRoot;

        double chroma = Math.Sqrt(okA * okA + okB * okB);
        double hue = Math.Atan2(okB, okA) * 180.0 / Math.PI;
        if (hue < 0) hue += 360.0;

        return (okL * 100.0, chroma, hue);
    }

    private static double SrgbToLinear(double channel) =>
        channel <= 0.04045 ? channel / 12.92 : Math.Pow((channel + 0.055) / 1.055, 2.4);

    public static (double H, double S, double L) ToHsl(Color color)
    {
        double r = color.R / 255.0, g = color.G / 255.0, b = color.B / 255.0;
        double max = Math.Max(r, Math.Max(g, b));
        double min = Math.Min(r, Math.Min(g, b));
        double h = 0, s = 0, l = (max + min) / 2.0;

        if (max != min)
        {
            double d = max - min;
            s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);
            if (max == r) h = (g - b) / d + (g < b ? 6.0 : 0.0);
            else if (max == g) h = (b - r) / d + 2.0;
            else h = (r - g) / d + 4.0;
            h /= 6.0;
        }

        return (h * 360.0, s, l);
    }

    public static Color FromHsl(double h, double s, double l)
    {
        h /= 360.0;
        double r = l, g = l, b = l;
        if (s != 0)
        {
            double q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
            double p = 2.0 * l - q;
            r = Hue2Rgb(p, q, h + 1.0 / 3.0);
            g = Hue2Rgb(p, q, h);
            b = Hue2Rgb(p, q, h - 1.0 / 3.0);
        }
        return Color.FromRgb((byte)Math.Round(r * 255), (byte)Math.Round(g * 255), (byte)Math.Round(b * 255));
    }

    private static double Hue2Rgb(double p, double q, double t)
    {
        if (t < 0.0) t += 1.0;
        if (t > 1.0) t -= 1.0;
        if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
        if (t < 1.0 / 2.0) return q;
        if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
        return p;
    }

    public static Color GetComplementary(Color color)
    {
        var (h, s, l) = ToHsl(color);
        return FromHsl((h + 180.0) % 360.0, s, l);
    }

    public static List<Color> GetAnalogous(Color color)
    {
        var (h, s, l) = ToHsl(color);
        return
        [
            FromHsl((h + 330.0) % 360.0, s, l),
            color,
            FromHsl((h + 30.0) % 360.0, s, l)
        ];
    }

    public static List<Color> GetExportPalette(Color baseColor)
    {
        var comp = GetComplementary(baseColor);
        var (h, s, l) = ToHsl(baseColor);
        return
        [
            baseColor,
            FromHsl(h, Math.Min(1, s + 0.1), Math.Min(1, l + 0.15)),
            FromHsl(h, Math.Max(0, s - 0.1), Math.Min(1, l + 0.25)),
            comp,
            FromHsl(h, s, Math.Max(0, l - 0.2))
        ];
    }

    public enum ColorBlindnessType { None, Protan, Deutan, Tritan }

    public static Color SimulateColorBlindness(Color color, ColorBlindnessType type)
    {
        if (type == ColorBlindnessType.None) return color;

        double r = color.R, g = color.G, b = color.B;
        double nr, ng, nb;

        switch (type)
        {
            case ColorBlindnessType.Protan:
                nr = r * 0.567 + g * 0.433;
                ng = r * 0.558 + g * 0.442;
                nb = g * 0.242 + b * 0.758;
                break;
            case ColorBlindnessType.Deutan:
                nr = r * 0.625 + g * 0.375;
                ng = r * 0.7 + g * 0.3;
                nb = g * 0.3 + b * 0.7;
                break;
            default:
                nr = r * 0.95 + g * 0.05;
                ng = g * 0.433 + b * 0.567;
                nb = g * 0.475 + b * 0.525;
                break;
        }

        return Color.FromRgb(
            (byte)Math.Clamp(Math.Round(nr), 0, 255),
            (byte)Math.Clamp(Math.Round(ng), 0, 255),
            (byte)Math.Clamp(Math.Round(nb), 0, 255));
    }

    public static Color GetAverageColor(Bitmap bitmap, int centerX, int centerY, int sampleSize)
    {
        if (sampleSize <= 1)
            return ReadPixel(bitmap, centerX, centerY);

        int half = sampleSize / 2;
        long r = 0, g = 0, b = 0, count = 0;

        for (int y = centerY - half; y <= centerY + half; y++)
        for (int x = centerX - half; x <= centerX + half; x++)
        {
            if (x < 0 || y < 0 || x >= bitmap.Width || y >= bitmap.Height) continue;
            var c = ReadPixel(bitmap, x, y);
            r += c.R; g += c.G; b += c.B;
            count++;
        }

        return count == 0
            ? Colors.Black
            : Color.FromRgb((byte)(r / count), (byte)(g / count), (byte)(b / count));
    }

    public static void CopyRegionToWriteableBitmap(Bitmap source, WriteableBitmap target, int centerX, int centerY, int cropSize)
    {
        int half = cropSize / 2;
        int srcX = Math.Clamp(centerX - half, 0, Math.Max(0, source.Width - cropSize));
        int srcY = Math.Clamp(centerY - half, 0, Math.Max(0, source.Height - cropSize));

        var rect = new Rectangle(srcX, srcY, cropSize, cropSize);
        var data = source.LockBits(rect, ImageLockMode.ReadOnly, DrawingPixelFormat.Format32bppArgb);
        try
        {
            var buffer = new byte[cropSize * cropSize * 4];
            int dstStride = cropSize * 4;
            for (int row = 0; row < cropSize; row++)
            {
                Marshal.Copy(
                    IntPtr.Add(data.Scan0, row * data.Stride),
                    buffer,
                    row * dstStride,
                    dstStride);
            }
            target.WritePixels(new System.Windows.Int32Rect(0, 0, cropSize, cropSize), buffer, dstStride, 0);
        }
        finally
        {
            source.UnlockBits(data);
        }
    }

    private static Color ReadPixel(Bitmap bitmap, int x, int y)
    {
        x = Math.Clamp(x, 0, bitmap.Width - 1);
        y = Math.Clamp(y, 0, bitmap.Height - 1);

        var rect = new Rectangle(x, y, 1, 1);
        var data = bitmap.LockBits(rect, ImageLockMode.ReadOnly, DrawingPixelFormat.Format32bppArgb);
        try
        {
            int argb = Marshal.ReadInt32(data.Scan0);
            return Color.FromRgb(
                (byte)((argb >> 16) & 0xFF),
                (byte)((argb >> 8) & 0xFF),
                (byte)(argb & 0xFF));
        }
        finally
        {
            bitmap.UnlockBits(data);
        }
    }

    public static double GetContrastRatio(Color foreground, Color background)
    {
        static double Lum(byte c)
        {
            double v = c / 255.0;
            v = v <= 0.03928 ? v / 12.92 : Math.Pow((v + 0.055) / 1.055, 2.4);
            return v;
        }

        double l1 = 0.2126 * Lum(foreground.R) + 0.7152 * Lum(foreground.G) + 0.0722 * Lum(foreground.B);
        double l2 = 0.2126 * Lum(background.R) + 0.7152 * Lum(background.G) + 0.0722 * Lum(background.B);
        return (Math.Max(l1, l2) + 0.05) / (Math.Min(l1, l2) + 0.05);
    }

    public static string FormatContrastRatio(double ratio) => $"{ratio:F2}:1";

    public static string GetWcagNormalTextStatus(double ratio) =>
        ratio >= 7.0 ? "AAA ✓" : ratio >= 4.5 ? "AA ✓" : "AA ✗";

    public static string GetWcagLargeTextStatus(double ratio) =>
        ratio >= 4.5 ? "AAA ✓" : ratio >= 3.0 ? "AA ✓" : "AA ✗";

    public static string FormatForCopy(Color color, CopyFormat format) => format switch
    {
        CopyFormat.HEX => ToHex(color),
        CopyFormat.RGB => ToRgbString(color),
        CopyFormat.HSL => ToHslString(color),
        CopyFormat.OKLCH => ToOklchString(color),
        CopyFormat.CSS => $"--color-picked: {ToHex(color)};",
        _ => ToHex(color)
    };

    public static string ExportTailwind(Color color)
    {
        var hex = ToHex(color);
        var palette = GetExportPalette(color);
        return $$"""
            // tailwind.config.js
            module.exports = {
              theme: {
                extend: {
                  colors: {
                    picked: '{{hex}}',
                    'picked-light': '{{ToHex(palette[1])}}',
                    'picked-dark': '{{ToHex(palette[4])}}'
                  }
                }
              }
            }
            """;
    }

    public static string ExportFigma(Color color)
    {
        var (l, c, h) = ToOklch(color);
        return string.Create(CultureInfo.InvariantCulture, $$"""
            {
              "picked": {
                "$type": "color",
                "$value": {
                  "colorSpace": "oklch",
                  "components": [{{l:F1}}, {{c:F3}}, {{h:F1}}]
                }
              }
            }
            """);
    }

    public static string ExportCssVariables(Color color)
    {
        var hex = ToHex(color);
        return $$"""
            :root {
              --color-picked: {{hex}};
              --color-picked-rgb: {{color.R}}, {{color.G}}, {{color.B}};
              --color-picked-oklch: {{ToOklchString(color)}};
            }
            """;
    }
}
