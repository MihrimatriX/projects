using EkranZamani.Models;
using EkranZamani.Services;
using EkranZamani_WinUI.Models;
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace EkranZamani_WinUI.ViewModels;

public partial class GoalsPageViewModel : ObservableObject
{
    [ObservableProperty] private string _newTitle = "Yeni hedef";
    [ObservableProperty] private string _newPattern = "code";
    [ObservableProperty] private string _newTargetMinutes = "120";
    [ObservableProperty] private int _newCategoryIndex;
    [ObservableProperty] private string _statusMessage = string.Empty;
    [ObservableProperty] private int? _editingGoalId;
    [ObservableProperty] private string _formButtonLabel = "Hedef ekle";

    private bool _editingEnabled = true;

    public ObservableCollection<GoalRingView> GoalRings { get; } = new();
    public string[] CategoryOptions { get; } = { "Herhangi", "Verimli", "Dikkat dağıtıcı", "Nötr" };

    public GoalsPageViewModel() => Reload();

    public void Reload()
    {
        GoalRings.Clear();
        foreach (var p in AppServices.FocusGoals.GetTodayProgress())
            GoalRings.Add(new GoalRingView(p));
    }

    [RelayCommand]
    private void AddGoal()
    {
        if (string.IsNullOrWhiteSpace(NewTitle) || string.IsNullOrWhiteSpace(NewPattern))
        {
            StatusMessage = "Başlık ve desen gerekli.";
            return;
        }

        if (EditingGoalId.HasValue)
        {
            AppServices.Database.UpdateFocusGoal(new FocusGoal
            {
                Id = EditingGoalId.Value,
                Title = NewTitle.Trim(),
                MatchPattern = NewPattern.Trim(),
                TargetMinutes = ParseTargetMinutes(),
                RequiredCategory = CategoryIndexToNullable(NewCategoryIndex),
                NotifyOnComplete = true,
                IsEnabled = _editingEnabled
            });
            ClearForm();
            Reload();
            StatusMessage = "Hedef güncellendi.";
            return;
        }

        AppServices.Database.AddFocusGoal(new FocusGoal
        {
            Title = NewTitle.Trim(),
            MatchPattern = NewPattern.Trim(),
            TargetMinutes = ParseTargetMinutes(),
            RequiredCategory = CategoryIndexToNullable(NewCategoryIndex),
            NotifyOnComplete = true,
            IsEnabled = true
        });

        ClearForm();
        Reload();
        StatusMessage = "Hedef eklendi.";
    }

    [RelayCommand]
    private void EditGoal(FocusGoalProgress? item)
    {
        if (item == null) return;
        var g = item.Goal;
        EditingGoalId = g.Id;
        _editingEnabled = g.IsEnabled;
        NewTitle = g.Title;
        NewPattern = g.MatchPattern;
        NewTargetMinutes = g.TargetMinutes.ToString();
        NewCategoryIndex = CategoryToIndex(g.RequiredCategory);
        FormButtonLabel = "Güncelle";
        StatusMessage = "Düzenleme modu.";
    }

    [RelayCommand]
    private void CancelEdit()
    {
        ClearForm();
        StatusMessage = string.Empty;
    }

    [RelayCommand]
    private void DeleteGoal(FocusGoalProgress? item)
    {
        if (item == null) return;
        AppServices.Database.DeleteFocusGoal(item.Goal.Id);
        Reload();
        StatusMessage = "Hedef silindi.";
    }

    private void ClearForm()
    {
        EditingGoalId = null;
        FormButtonLabel = "Hedef ekle";
        NewTitle = "Yeni hedef";
        NewPattern = "code";
        NewTargetMinutes = "120";
        NewCategoryIndex = 0;
    }

    private static int CategoryToIndex(UsageCategory? category) => category switch
    {
        UsageCategory.Productive => 1,
        UsageCategory.Distracting => 2,
        UsageCategory.Neutral => 3,
        _ => 0
    };

    private int ParseTargetMinutes() =>
        int.TryParse(NewTargetMinutes, out var m) ? Math.Clamp(m, 1, 1440) : 120;

    private static UsageCategory? CategoryIndexToNullable(int index) => index switch
    {
        1 => UsageCategory.Productive,
        2 => UsageCategory.Distracting,
        3 => UsageCategory.Neutral,
        _ => null
    };
}
