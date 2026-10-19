using System;

namespace EkranZamani.Models
{
    public class WebDomainRow
    {
        public string Domain { get; init; } = string.Empty;
        public int TotalSeconds { get; init; }

        public string FormattedTime
        {
            get
            {
                var t = TimeSpan.FromSeconds(TotalSeconds);
                if (t.TotalHours >= 1)
                    return $"{(int)t.TotalHours} sa {t.Minutes} dk";
                return $"{t.Minutes} dk";
            }
        }
    }
}
