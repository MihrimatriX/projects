namespace EkranZamani.Models
{
    public class CategoryRule
    {
        public int Id { get; set; }
        public string Pattern { get; set; } = string.Empty;
        public UsageCategory Category { get; set; }
        public int Priority { get; set; }
    }
}
