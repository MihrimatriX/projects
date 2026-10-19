using System;
using System.Threading;
using System.Threading.Tasks;

namespace EkranZamani.Services
{
    public static class SingleInstanceService
    {
        private const string MutexName = "Global\\EkranZamani_App_v1";
        private const string ShowEventName = "Global\\EkranZamani_Show_v1";

        private static Mutex? _mutex;
        private static EventWaitHandle? _showEvent;
        private static CancellationTokenSource? _listenerCts;
        private static Action<Action>? _invokeOnUiThread;

        public static bool TryBecomePrimaryInstance()
        {
            _mutex = new Mutex(true, MutexName, out bool created);
            return created;
        }

        public static void SignalExistingInstance()
        {
            try
            {
                using var evt = EventWaitHandle.OpenExisting(ShowEventName);
                evt.Set();
            }
            catch (WaitHandleCannotBeOpenedException)
            {
                // Primary not ready yet
            }
        }

        public static void StartShowListener(Action onShowRequested, Action<Action> invokeOnUiThread)
        {
            _invokeOnUiThread = invokeOnUiThread;
            _showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, ShowEventName);
            _listenerCts = new CancellationTokenSource();
            var token = _listenerCts.Token;

            Task.Run(() =>
            {
                while (!token.IsCancellationRequested)
                {
                    try
                    {
                        if (_showEvent.WaitOne(500))
                            _invokeOnUiThread?.Invoke(onShowRequested);
                    }
                    catch (ObjectDisposedException)
                    {
                        break;
                    }
                }
            }, token);
        }

        public static void Dispose()
        {
            _listenerCts?.Cancel();
            _listenerCts?.Dispose();
            _showEvent?.Dispose();
            if (_mutex != null)
            {
                try { _mutex.ReleaseMutex(); } catch { /* already released */ }
                _mutex.Dispose();
            }
        }
    }
}
