using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using NHotkey;
using NHotkey.Wpf;
using OtomasyonMakro.Helpers;
using OtomasyonMakro.Models;
using OtomasyonMakro.Services;

namespace OtomasyonMakro.ViewModels
{
    public partial class MainViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService = new();
        private readonly GlobalHookService _hookService = new();
        private readonly PlaybackService _playbackService = new();
        private readonly UIAutomationService _uiAutomationService = new();
        private readonly ScheduleService _scheduleService;
        private readonly DispatcherTimer _recordTimer;

        private CancellationTokenSource? _playbackCts;
        private int _debugStepIndex;
        private int _recordSeconds;
        private int _currentIteration;
        private volatile bool _emergencyStopped;
        private string? _lastNote;

        [ObservableProperty] private MacroProfile? _selectedProfile;
        [ObservableProperty] private MacroStep? _selectedStep;
        [ObservableProperty] private bool _isRecording;
        [ObservableProperty] private bool _isPlaying;
        [ObservableProperty] private bool _isRecordPaused;
        [ObservableProperty] private string _recordTimeText = "00:00";
        [ObservableProperty] private double _playbackProgress;
        [ObservableProperty] private bool _showHotkeysWindow;

        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(StatusText))]
        private int _activeExecutingStepSequence;

        public ObservableCollection<MacroProfile> Profiles { get; } = new();

        public MainViewModel()
        {
            _hookService.OnStepRecorded += HookService_OnStepRecorded;
            _playbackService.OnStepStarted += Playback_OnStepStarted;
            _playbackService.OnFinished += Playback_OnFinished;
            _playbackService.OnError += Playback_OnError;
            _playbackService.OnCancelled += Playback_OnCancelled;
            _playbackService.OnIterationStarted += iteration =>
            {
                _currentIteration = iteration;
                OnPropertyChanged(nameof(StatusText));
            };

            _scheduleService = new ScheduleService(_dbService, profile =>
            {
                Application.Current.Dispatcher.Invoke(async () =>
                {
                    if (!IsPlaying && !IsRecording)
                        await PlayMacro(profile);
                });
            });

            _recordTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _recordTimer.Tick += (_, _) =>
            {
                if (!IsRecording || IsRecordPaused) return;
                _recordSeconds++;
                RecordTimeText = FormatRecordTime(_recordSeconds);
            };

            LoadProfiles();
            RegisterRecordToggleHotkey();
        }

        public bool SafeModeEnabled
        {
            get => SelectedProfile?.IsSafetyLockEnabled ?? true;
            set
            {
                if (SelectedProfile == null) return;
                SelectedProfile.TargetProcessName = value
                    ? MacroProfile.FocusOnlyTarget
                    : string.Empty;
                OnPropertyChanged(nameof(SafeModeEnabled));
                OnPropertyChanged(nameof(StatusText));
                NotifyProfileHints();
            }
        }

        public string StatusText
        {
            get
            {
                if (IsRecording)
                    return IsRecordPaused ? "Kayıt duraklatıldı" : "Kayıt aktif";
                if (IsPlaying)
                {
                    int repeat = SelectedProfile?.RepeatCount ?? 1;
                    var tour = repeat == 1 ? "" : $"tur {_currentIteration}{(repeat > 1 ? "/" + repeat : "")} · ";
                    return $"Oynatılıyor — {tour}adım {ActiveExecutingStepSequence} · ESC: acil durdur";
                }
                if (ActiveExecutingStepSequence > 0)
                    return $"Debug — adım {ActiveExecutingStepSequence} çalıştırıldı";
                if (_lastNote != null)
                    return _lastNote;
                return SafeModeEnabled ? "Hazır · Güvenli mod açık" : "Hazır · Güvenli mod kapalı";
            }
        }

        public int StepCount => SelectedProfile?.Steps.Count ?? 0;

        public IEnumerable<HotkeyAssignment> HotkeyAssignments
        {
            get
            {
                var rows = new List<HotkeyAssignment>
                {
                    new() { Key = "Ctrl+Alt+M", MacroName = "—", Action = "Kayıt toggle" },
                    new() { Key = "F5", MacroName = "Aktif makro", Action = "Çalıştır" }
                };

                var seen = new Dictionary<string, MacroProfile>(StringComparer.OrdinalIgnoreCase);
                foreach (var profile in Profiles)
                {
                    if (string.IsNullOrWhiteSpace(profile.Hotkey)) continue;
                    var key = profile.Hotkey.Trim();
                    var conflict = seen.TryGetValue(key, out var other);
                    rows.Add(new HotkeyAssignment
                    {
                        Key = key,
                        MacroName = profile.Name,
                        Action = "Çalıştır",
                        HasConflict = conflict,
                        ConflictWith = conflict ? other!.Name : null
                    });
                    if (!conflict) seen[key] = profile;
                }

                return rows;
            }
        }

        public int HotkeyConflictCount => HotkeyAssignments.Count(h => h.HasConflict);

        public void Cleanup()
        {
            _recordTimer.Stop();
            if (IsRecording)
            {
                _hookService.StopRecording();
                IsRecording = false;
            }

            UnregisterAllHotkeys();
            try { HotkeyManager.Current.Remove("RecordToggle"); } catch { }
            _playbackCts?.Cancel();
            _scheduleService.Dispose();
            _playbackService.Dispose();
            _uiAutomationService.Dispose();
        }

        [RelayCommand]
        public void LoadProfiles()
        {
            UnregisterAllHotkeys();
            Profiles.Clear();

            foreach (var profile in _dbService.GetProfiles())
            {
                if (string.IsNullOrWhiteSpace(profile.TargetProcessName))
                    profile.TargetProcessName = MacroProfile.FocusOnlyTarget;
                Profiles.Add(profile);
                RegisterProfileHotkey(profile);
            }

            SelectedProfile = Profiles.FirstOrDefault();
            OnPropertyChanged(nameof(HotkeyAssignments));
            OnPropertyChanged(nameof(HotkeyConflictCount));
        }

        [RelayCommand]
        public void AddProfile()
        {
            var profile = new MacroProfile
            {
                Name = "Yeni makro",
                Description = "Klavye ve fare adımları",
                TargetProcessName = MacroProfile.FocusOnlyTarget
            };

            _dbService.SaveProfile(profile);
            Profiles.Add(profile);
            SelectedProfile = profile;
        }

        [RelayCommand]
        public void DeleteProfile(MacroProfile? profile)
        {
            if (profile == null) return;
            if (MessageBox.Show($"«{profile.Name}» makrosu ve tüm adımları silinsin mi?", "Makroyu sil",
                    MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
                return;

            try { HotkeyManager.Current.Remove($"ProfileHotkey_{profile.Id}"); } catch { }
            _dbService.DeleteProfile(profile.Id);
            Profiles.Remove(profile);
            SelectedProfile = Profiles.FirstOrDefault();
            OnPropertyChanged(nameof(HotkeyAssignments));
            OnPropertyChanged(nameof(HotkeyConflictCount));
        }

        [RelayCommand]
        public void SaveProfile()
        {
            if (SelectedProfile == null) return;
            if (!ValidateHotkeyUnique(SelectedProfile)) return;

            try
            {
                _dbService.SaveProfile(SelectedProfile);
                RegisterProfileHotkey(SelectedProfile);
                OnPropertyChanged(nameof(HotkeyAssignments));
                OnPropertyChanged(nameof(HotkeyConflictCount));
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Kaydetme hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        /// <summary>Seçili makronun kopyasını oluşturur (kısayol çakışmasın diye kısayolu boş bırakır).</summary>
        [RelayCommand]
        public void DuplicateProfile()
        {
            if (SelectedProfile == null) return;
            var copy = SelectedProfile.Clone();
            copy.Id = 0;
            copy.Name = SelectedProfile.Name + " (kopya)";
            copy.Hotkey = string.Empty;
            copy.ScheduleEnabled = false;

            _dbService.SaveProfile(copy);
            Profiles.Add(copy);
            SelectedProfile = copy;
            OnPropertyChanged(nameof(HotkeyAssignments));
        }

        /// <summary>Bellekteki makrolar veritabanındakinden farklı mı (kapatırken sorulur).</summary>
        public bool HasUnsavedChanges()
        {
            try { return MacroProfile.Snapshot(Profiles) != MacroProfile.Snapshot(_dbService.GetProfiles()); }
            catch { return false; }
        }

        public void SaveAll()
        {
            foreach (var profile in Profiles)
                _dbService.SaveProfile(profile);
        }

        [RelayCommand]
        public void ToggleSafeMode() => SafeModeEnabled = !SafeModeEnabled;

        [RelayCommand]
        public void ToggleRecordPause() => IsRecordPaused = !IsRecordPaused;

        [RelayCommand]
        public void OpenHotkeys()
        {
            OnPropertyChanged(nameof(HotkeyAssignments));
            OnPropertyChanged(nameof(HotkeyConflictCount));
            ShowHotkeysWindow = true;
        }

        [RelayCommand]
        public void CloseHotkeys() => ShowHotkeysWindow = false;

        partial void OnSelectedProfileChanged(MacroProfile? value)
        {
            _debugStepIndex = 0;
            SelectedStep = value?.Steps.FirstOrDefault();
            OnPropertyChanged(nameof(SafeModeEnabled));
            OnPropertyChanged(nameof(StepCount));
            OnPropertyChanged(nameof(StatusText));
            NotifyProfileHints();
        }

        partial void OnSelectedStepChanged(MacroStep? value)
        {
            OnPropertyChanged(nameof(SelectedStepIsRisky));
        }

        public bool SelectedStepIsRisky => SelectedStep?.IsRisky ?? false;

        partial void OnIsRecordingChanged(bool value)
        {
            if (value)
            {
                _recordSeconds = 0;
                RecordTimeText = "00:00";
                IsRecordPaused = false;
                _recordTimer.Start();
            }
            else
            {
                _recordTimer.Stop();
            }

            OnPropertyChanged(nameof(StatusText));
        }

        partial void OnIsRecordPausedChanged(bool value)
        {
            _hookService.IsPaused = value;
            OnPropertyChanged(nameof(StatusText));
        }

        [RelayCommand]
        public void StartRecord()
        {
            if (SelectedProfile == null || IsRecording || IsPlaying) return;

            var overwrite = SelectedProfile.Steps.Count > 0
                ? $"DİKKAT: «{SelectedProfile.Name}» makrosundaki {SelectedProfile.Steps.Count} adım silinip yerine yeni kayıt yazılacak. " +
                  "Korumak için önce «Çoğalt» ile kopyalayın.\n\n"
                : "";
            var confirm = MessageBox.Show(
                overwrite +
                "Makro kaydı başlatılacak. Klavye ve fare hareketleriniz kaydedilir.\n\n" +
                "Kayıt sırasında hassas bilgi girmeyin.\n" +
                "Durdurmak için Ctrl+Alt+M veya «Durdur ve kaydet».",
                "Kayıt uyarısı",
                MessageBoxButton.OKCancel,
                MessageBoxImage.Warning);

            if (confirm != MessageBoxResult.OK) return;

            SelectedProfile.Steps.Clear();
            _debugStepIndex = 0;
            IsRecording = true;
            _hookService.StartRecording();
        }

        [RelayCommand]
        public void StopRecord()
        {
            if (!IsRecording) return;

            _hookService.StopRecording();
            IsRecording = false;

            if (SelectedProfile != null)
                _dbService.SaveProfile(SelectedProfile);
        }

        [RelayCommand]
        public async Task PlayMacro(MacroProfile? profile)
        {
            var target = profile ?? SelectedProfile;
            if (target == null || IsPlaying || IsRecording) return;

            if (target.Steps.Count == 0)
            {
                MessageBox.Show("Oynatılacak adım yok.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (!ConfirmRiskyPlayback(target)) return;

            IsPlaying = true;
            PlaybackProgress = 0;
            _debugStepIndex = 0;
            _currentIteration = 1;
            _lastNote = null;
            ActiveExecutingStepSequence = 0;
            OnPropertyChanged(nameof(StatusText));

            var cts = _playbackCts = new CancellationTokenSource();
            using var emergency = StartEmergencyStop(cts);
            try { await Task.Delay(500, cts.Token); }
            catch (OperationCanceledException) { Playback_OnCancelled(); return; } // bu 500 ms içinde durdurulduysa çökme
            await _playbackService.PlayAsync(target, cts.Token);
        }

        /// <summary>Oynatma süresince fiziksel ESC (uygulama odakta olmasa da) oynatmayı anında iptal eder.</summary>
        private EmergencyStopMonitor StartEmergencyStop(CancellationTokenSource cts)
        {
            _emergencyStopped = false;
            return EmergencyStopMonitor.Start(() =>
            {
                _emergencyStopped = true;
                cts.Cancel();
            });
        }

        [RelayCommand]
        public async Task StepForward()
        {
            if (SelectedProfile == null || IsRecording || IsPlaying) return;
            if (SelectedProfile.Steps.Count == 0) return;

            int index = SelectedStep != null
                ? SelectedProfile.Steps.IndexOf(SelectedStep)
                : _debugStepIndex;

            if (index < 0) index = 0;
            if (index >= SelectedProfile.Steps.Count) return;

            if (!ConfirmRiskyStep(SelectedProfile.Steps[index])) return;

            ActiveExecutingStepSequence = SelectedProfile.Steps[index].Sequence;
            OnPropertyChanged(nameof(StatusText));

            var cts = _playbackCts = new CancellationTokenSource();
            using (StartEmergencyStop(cts))
                await _playbackService.PlayStepAsync(SelectedProfile, index, cts.Token);

            ActiveExecutingStepSequence = 0;
            OnPropertyChanged(nameof(StatusText));

            _debugStepIndex = index + 1;
            if (_debugStepIndex < SelectedProfile.Steps.Count)
                SelectedStep = SelectedProfile.Steps[_debugStepIndex];
        }

        [RelayCommand]
        public void StopPlayback()
        {
            if (!IsPlaying) return;
            _playbackCts?.Cancel();
            IsPlaying = false;
            PlaybackProgress = 0;
            ActiveExecutingStepSequence = 0;
            OnPropertyChanged(nameof(StatusText));
        }

        [RelayCommand]
        public void DeleteStep(MacroStep? step)
        {
            if (SelectedProfile == null || step == null) return;
            SelectedProfile.Steps.Remove(step);
            ReorderSteps();
        }

        [RelayCommand]
        public void MoveStepUp(MacroStep? step)
        {
            if (SelectedProfile == null || step == null) return;
            int index = SelectedProfile.Steps.IndexOf(step);
            if (index <= 0) return;
            SelectedProfile.Steps.RemoveAt(index);
            SelectedProfile.Steps.Insert(index - 1, step);
            ReorderSteps();
            SelectedStep = step;
        }

        [RelayCommand]
        public void MoveStepDown(MacroStep? step)
        {
            if (SelectedProfile == null || step == null) return;
            int index = SelectedProfile.Steps.IndexOf(step);
            if (index < 0 || index >= SelectedProfile.Steps.Count - 1) return;
            SelectedProfile.Steps.RemoveAt(index);
            SelectedProfile.Steps.Insert(index + 1, step);
            ReorderSteps();
            SelectedStep = step;
        }

        [RelayCommand]
        public void AddNewStep(string type)
        {
            if (SelectedProfile == null) return;

            var step = new MacroStep { Sequence = SelectedProfile.Steps.Count + 1 };
            switch (type.ToUpperInvariant())
            {
                case "MOUSE":
                    step.ActionType = MacroActionType.MouseClick;
                    step.MouseX = 500;
                    step.MouseY = 300;
                    break;
                case "TEXT":
                    step.ActionType = MacroActionType.WriteText;
                    step.Text = "Metin";
                    break;
                case "DELAY":
                    step.ActionType = MacroActionType.TextDelay;
                    step.DelayMs = 500;
                    break;
                case "KEY":
                    step.ActionType = MacroActionType.KeyPress;
                    step.Text = "ENTER";
                    break;
                case "UI":
                    step.ActionType = MacroActionType.UiElementClick;
                    step.UiElementName = "Tamam";
                    break;
                case "IF":
                    step.ActionType = MacroActionType.IfWindowTitle;
                    step.Text = "Not Defteri";
                    step.JumpToSequence = SelectedProfile.Steps.Count + 2;
                    break;
                case "JUMP":
                    step.ActionType = MacroActionType.JumpToStep;
                    step.JumpToSequence = 1;
                    break;
            }

            SelectedProfile.Steps.Add(step);
            SelectedStep = step;
            OnPropertyChanged(nameof(StepCount));
        }

        [RelayCommand]
        public async Task PickUiElement()
        {
            if (SelectedProfile == null || IsRecording || IsPlaying) return;

            MessageBox.Show("3 saniye içinde hedef öğenin üzerine fareyi getirin.",
                "UI öğe seçici", MessageBoxButton.OK, MessageBoxImage.Information);

            await Task.Delay(3000);

            if (!Win32Api.GetCursorPos(out Win32Api.POINT pt)) return;

            var info = _uiAutomationService.PickElementAt(pt.X, pt.Y);
            if (info == null)
            {
                MessageBox.Show("Öğe algılanamadı.", "UI seçici", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var step = new MacroStep
            {
                Sequence = SelectedProfile.Steps.Count + 1,
                ActionType = MacroActionType.UiElementClick,
                UiElementName = info.Name,
                UiAutomationId = info.AutomationId,
                UiClassName = info.ClassName
            };

            SelectedProfile.Steps.Add(step);
            SelectedStep = step;
            OnPropertyChanged(nameof(StepCount));
        }

        [RelayCommand]
        public void ExportMacro()
        {
            if (SelectedProfile == null) return;

            var sfd = new SaveFileDialog
            {
                Filter = "Makro (*.macro.json)|*.macro.json",
                FileName = $"{SelectedProfile.Name}.macro.json"
            };

            if (sfd.ShowDialog() != true) return;

            try
            {
                SelectedProfile.SchemaVersion = 2;
                var json = JsonSerializer.Serialize(SelectedProfile, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(sfd.FileName, json);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Dışa aktarım hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        [RelayCommand]
        public void ImportMacro()
        {
            var ofd = new OpenFileDialog { Filter = "Makro (*.macro.json)|*.macro.json" };
            if (ofd.ShowDialog() != true) return;

            var confirm = MessageBox.Show(
                $"Bilinmeyen kaynaktan makro:\n{ofd.FileName}\n\nDevam edilsin mi?",
                "İçe aktarma",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning);

            if (confirm != MessageBoxResult.Yes) return;

            try
            {
                var imported = JsonSerializer.Deserialize<MacroProfile>(File.ReadAllText(ofd.FileName));
                if (imported == null) return;

                imported.Id = 0;
                imported.Name = "[İthal] " + imported.Name;
                imported.SchemaVersion = Math.Max(imported.SchemaVersion, 2);
                if (string.IsNullOrWhiteSpace(imported.TargetProcessName))
                    imported.TargetProcessName = MacroProfile.FocusOnlyTarget;

                _dbService.SaveProfile(imported);
                Profiles.Add(imported);
                RegisterProfileHotkey(imported);
                SelectedProfile = imported;
            }
            catch (Exception ex)
            {
                MessageBox.Show($"İçe aktarım hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        [RelayCommand]
        public void ResolveHotkeyConflict()
        {
            if (SelectedProfile == null || string.IsNullOrWhiteSpace(SelectedProfile.Hotkey)) return;
            SelectedProfile.Hotkey = "";
            OnPropertyChanged(nameof(HotkeyAssignments));
            OnPropertyChanged(nameof(HotkeyConflictCount));
        }

        private void ReorderSteps()
        {
            if (SelectedProfile == null) return;
            SelectedProfile.RenumberSteps(); // koşul/atlama hedefleri taşınan adımı izler
            OnPropertyChanged(nameof(StepCount));
        }

        private void NotifyProfileHints()
        {
            if (SelectedProfile == null) return;
            OnPropertyChanged(nameof(SafeModeEnabled));
        }

        private static string FormatRecordTime(int seconds)
        {
            int m = seconds / 60;
            int s = seconds % 60;
            return $"{m:D2}:{s:D2}";
        }

        private void HookService_OnStepRecorded(MacroStep step)
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                if (SelectedProfile == null) return;
                step.Sequence = SelectedProfile.Steps.Count + 1;
                SelectedProfile.Steps.Add(step);
                OnPropertyChanged(nameof(StepCount));
            });
        }

        private void Playback_OnStepStarted(int seq)
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                ActiveExecutingStepSequence = seq;
                if (SelectedProfile != null && seq > 0 && seq <= SelectedProfile.Steps.Count)
                {
                    SelectedStep = SelectedProfile.Steps[seq - 1];
                    PlaybackProgress = SelectedProfile.Steps.Count == 0
                        ? 0
                        : (double)seq / SelectedProfile.Steps.Count * 100;
                }

                OnPropertyChanged(nameof(StatusText));
            });
        }

        private void Playback_OnFinished()
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                IsPlaying = false;
                PlaybackProgress = 100;
                ActiveExecutingStepSequence = 0;
                OnPropertyChanged(nameof(StatusText));
            });
        }

        private void Playback_OnCancelled()
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                IsPlaying = false;
                PlaybackProgress = 0;
                ActiveExecutingStepSequence = 0;
                _lastNote = _emergencyStopped ? "Acil durduruldu (ESC)" : "Oynatma durduruldu";
                OnPropertyChanged(nameof(StatusText));
            });
        }

        private void Playback_OnError(string errorMsg)
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                IsPlaying = false;
                PlaybackProgress = 0;
                ActiveExecutingStepSequence = 0;
                OnPropertyChanged(nameof(StatusText));
                MessageBox.Show(errorMsg, "Makro durduruldu", MessageBoxButton.OK, MessageBoxImage.Warning);
            });
        }

        private void RegisterRecordToggleHotkey()
        {
            try
            {
                HotkeyManager.Current.AddOrReplace("RecordToggle", Key.M, ModifierKeys.Control | ModifierKeys.Alt, (_, e) =>
                {
                    e.Handled = true;
                    Application.Current.Dispatcher.Invoke(() =>
                    {
                        if (IsRecording) StopRecord();
                        else if (SelectedProfile != null && !IsPlaying) StartRecord();
                    });
                });
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Record hotkey failed: {ex.Message}");
            }
        }

        private static bool ConfirmRiskyPlayback(MacroProfile profile)
        {
            var risky = profile.Steps.Where(s => s.IsRisky).ToList();
            if (risky.Count == 0) return true;

            var summary = string.Join("\n", risky.Take(5).Select(s => $"  • {s.StepTitle}: {s.StepDetail}"));
            if (risky.Count > 5) summary += $"\n  • ... +{risky.Count - 5}";

            return MessageBox.Show(
                $"{risky.Count} riskli adım var:\n\n{summary}\n\nDevam edilsin mi?",
                "Risk onayı",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning) == MessageBoxResult.Yes;
        }

        private static bool ConfirmRiskyStep(MacroStep step)
        {
            if (!step.IsRisky) return true;
            return MessageBox.Show(
                $"Riskli adım: {step.StepTitle}\n{step.StepDetail}\n\nDevam?",
                "Risk onayı",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning) == MessageBoxResult.Yes;
        }

        private bool ValidateHotkeyUnique(MacroProfile profile)
        {
            if (string.IsNullOrWhiteSpace(profile.Hotkey)) return true;

            var normalized = profile.Hotkey.Trim();
            var duplicate = Profiles.FirstOrDefault(p =>
                p.Id != profile.Id &&
                string.Equals(p.Hotkey?.Trim(), normalized, StringComparison.OrdinalIgnoreCase));

            if (duplicate == null) return true;

            MessageBox.Show(
                $"Hotkey çakışması: «{normalized}» zaten «{duplicate.Name}» makrosunda.",
                "Çakışma",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
            return false;
        }

        private void RegisterProfileHotkey(MacroProfile profile)
        {
            // Hotkey silindi/geçersizse eski kayıt tetiklemeye devam etmesin
            try { HotkeyManager.Current.Remove($"ProfileHotkey_{profile.Id}"); } catch { }
            if (string.IsNullOrWhiteSpace(profile.Hotkey)) return;

            try
            {
                var parts = profile.Hotkey.Split('+');
                ModifierKeys modifiers = ModifierKeys.None;
                Key key = Key.None;

                foreach (var part in parts)
                {
                    var p = part.Trim().ToUpperInvariant();
                    if (p is "CTRL" or "CONTROL") modifiers |= ModifierKeys.Control;
                    else if (p == "ALT") modifiers |= ModifierKeys.Alt;
                    else if (p == "SHIFT") modifiers |= ModifierKeys.Shift;
                    else if (p is "WIN" or "WINDOWS") modifiers |= ModifierKeys.Windows;
                    else if (Enum.TryParse<Key>(p, true, out var parsedKey))
                        key = parsedKey;
                }

                if (key == Key.None) return;

                var id = $"ProfileHotkey_{profile.Id}";
                HotkeyManager.Current.AddOrReplace(id, key, modifiers, (_, e) =>
                {
                    e.Handled = true;
                    if (!IsPlaying && !IsRecording)
                        PlayMacro(profile).ConfigureAwait(false);
                });
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Hotkey register failed: {ex.Message}");
            }
        }

        private void UnregisterAllHotkeys()
        {
            foreach (var profile in Profiles)
            {
                try { HotkeyManager.Current.Remove($"ProfileHotkey_{profile.Id}"); } catch { }
            }
        }
    }
}
