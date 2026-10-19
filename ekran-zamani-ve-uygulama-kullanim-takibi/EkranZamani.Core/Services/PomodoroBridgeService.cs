using System;
using System.IO;
using System.Text.Json;
using EkranZamani.Models;

namespace EkranZamani.Services
{
    public class PomodoroBridgeService
    {
        private readonly string _bridgeFolder;
        private readonly string _statePath;
        private readonly string _incomingPath;

        public PomodoroBridgeService(string dataFolder)
        {
            _bridgeFolder = Path.Combine(dataFolder, "bridge");
            Directory.CreateDirectory(_bridgeFolder);
            _statePath = Path.Combine(_bridgeFolder, "ekran-zamani-state.json");
            _incomingPath = Path.Combine(_bridgeFolder, "pomodoro-state.json");
        }

        public string BridgeFolder => _bridgeFolder;

        public void PublishTrackingState(string? activeApp, bool isTracking, bool isIdle)
        {
            var state = new PomodoroBridgeState
            {
                Phase = isIdle ? "idle" : (isTracking ? "tracking" : "paused"),
                ActiveApp = activeApp,
                IsTracking = isTracking,
                LastUpdated = DateTime.Now
            };

            TryReadPomodoroState(state);
            WriteJson(_statePath, state);
        }

        public PomodoroBridgeState? ReadPomodoroIncoming()
        {
            if (!File.Exists(_incomingPath)) return null;
            try
            {
                var json = File.ReadAllText(_incomingPath);
                return JsonSerializer.Deserialize<PomodoroBridgeState>(json);
            }
            catch
            {
                return null;
            }
        }

        private void TryReadPomodoroState(PomodoroBridgeState target)
        {
            var incoming = ReadPomodoroIncoming();
            if (incoming == null) return;
            target.Phase = incoming.Phase;
            target.RemainingSeconds = incoming.RemainingSeconds;
            target.CompletedFocusSessions = incoming.CompletedFocusSessions;
        }

        private static void WriteJson(string path, PomodoroBridgeState state)
        {
            var json = JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(path, json);
        }
    }
}
