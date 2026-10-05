using EkranZamani.Models;
using EkranZamani.Services;
using EkranZamani_WinUI.Models;
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace EkranZamani_WinUI.ViewModels;

public partial class CategoriesPageViewModel : ObservableObject
{
    [ObservableProperty] private string _newPattern = string.Empty;
    [ObservableProperty] private int _newCategoryIndex;
    [ObservableProperty] private string _statusMessage = string.Empty;
    [ObservableProperty] private bool _hasSuggestions;

    public Microsoft.UI.Xaml.Visibility SuggestionsVisibility =>
        HasSuggestions ? Microsoft.UI.Xaml.Visibility.Visible : Microsoft.UI.Xaml.Visibility.Collapsed;

    public ObservableCollection<CategoryRuleItem> Rules { get; } = new();
    public ObservableCollection<CategorySuggestionView> Suggestions { get; } = new();
    public string[] CategoryOptions { get; } = { "Verimli", "Dikkat dağıtıcı", "İletişim", "Nötr" };

    public CategoriesPageViewModel() => Reload();

    private void Reload()
    {
        Rules.Clear();
        foreach (var rule in AppServices.Database.GetCategoryRules())
            Rules.Add(new CategoryRuleItem(rule));

        Suggestions.Clear();
        foreach (var s in AppServices.CategorySuggestions.GetSuggestions())
            Suggestions.Add(new CategorySuggestionView(s));
        HasSuggestions = Suggestions.Count > 0;
        OnPropertyChanged(nameof(SuggestionsVisibility));
    }

    [RelayCommand]
    private void AddRule()
    {
        if (string.IsNullOrWhiteSpace(NewPattern))
        {
            StatusMessage = "Desen boş olamaz.";
            return;
        }
        AppServices.Database.AddCategoryRule(NewPattern.Trim(), IndexToCategory(NewCategoryIndex), 60);
        NewPattern = string.Empty;
        Reload();
        StatusMessage = "Kural eklendi.";
    }

    [RelayCommand]
    private void DeleteRule(CategoryRuleItem? row)
    {
        if (row == null) return;
        AppServices.Database.DeleteCategoryRule(row.Id);
        Reload();
        StatusMessage = "Kural silindi.";
    }

    [RelayCommand]
    private void ResetDefaults()
    {
        AppServices.Database.ResetCategoryRulesToDefaults();
        AppServices.Categories.Refresh();
        Reload();
        StatusMessage = "Varsayılan kurallar yüklendi.";
    }

    [RelayCommand]
    private void ApplySuggestion(CategorySuggestionView? item)
    {
        if (item == null) return;
        AppServices.CategorySuggestions.ApplySuggestion(item.Source);
        AppServices.Categories.Refresh();
        Reload();
        StatusMessage = $"Kural eklendi: {item.Pattern}";
    }

    [RelayCommand]
    private void UpdateCategory(CategoryRuleItem? row)
    {
        if (row == null) return;
        var rules = AppServices.Database.GetCategoryRules();
        var rule = rules.FirstOrDefault(r => r.Id == row.Id);
        if (rule == null) return;
        rule.Category = IndexToCategory(row.CategoryIndex);
        AppServices.Database.UpdateCategoryRule(rule);
        AppServices.Categories.Refresh();
        Reload();
        StatusMessage = "Kategori güncellendi.";
    }

    private static UsageCategory IndexToCategory(int index) => index switch
    {
        0 => UsageCategory.Productive,
        1 => UsageCategory.Distracting,
        2 => UsageCategory.Communication,
        _ => UsageCategory.Neutral
    };
}

public sealed partial class CategoryRuleItem : ObservableObject
{
    public CategoryRuleItem(CategoryRule rule)
    {
        Id = rule.Id;
        Pattern = rule.Pattern;
        CategoryIndex = rule.Category switch
        {
            UsageCategory.Productive => 0,
            UsageCategory.Distracting => 1,
            UsageCategory.Communication => 2,
            _ => 3
        };
    }

    public int Id { get; }
    public string Pattern { get; }
    [ObservableProperty] private int _categoryIndex;

    public string CategoryLabel => CategoryOptionsStatic[CategoryIndex];

    private static readonly string[] CategoryOptionsStatic = { "Verimli", "Dikkat dağıtıcı", "İletişim", "Nötr" };

    partial void OnCategoryIndexChanged(int value) => OnPropertyChanged(nameof(CategoryLabel));
}
