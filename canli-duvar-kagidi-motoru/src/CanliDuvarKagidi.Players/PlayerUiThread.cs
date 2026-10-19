namespace CanliDuvarKagidi.Players;

// Tum oynatici pencereleri (WinForms + WebView2) kendi mesaj dongusu olan tek bir STA thread'inde
// yasar; WinUI thread'inden bagimsiz calisir. Oynaticilara erisim Invoke/InvokeAsync ile buraya yapilir.
internal static class PlayerUiThread
{
    private static Thread? _thread;
    private static Form? _syncForm;
    private static readonly ManualResetEventSlim Ready = new(false);

    public static void EnsureStarted()
    {
        if (_thread != null)
            return;

        _thread = new Thread(() =>
        {
            Application.EnableVisualStyles();
            _syncForm = new Form
            {
                ShowInTaskbar = false,
                FormBorderStyle = FormBorderStyle.None,
                Size = new Size(0, 0),
                Opacity = 0
            };
            _syncForm.Shown += (_, _) => Ready.Set();
            Application.Run(_syncForm);
        })
        {
            IsBackground = true
        };
        _thread.SetApartmentState(ApartmentState.STA);
        _thread.Start();
        Ready.Wait();
    }

    public static void Invoke(Action action)
    {
        EnsureStarted();
        if (_syncForm!.InvokeRequired)
            _syncForm.Invoke(action);
        else
            action();
    }

    public static Task InvokeAsync(Action action)
    {
        EnsureStarted();
        var tcs = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        _syncForm!.BeginInvoke(() =>
        {
            try
            {
                action();
                tcs.SetResult();
            }
            catch (Exception ex)
            {
                tcs.SetException(ex);
            }
        });
        return tcs.Task;
    }

    public static Task InvokeAsync(Func<Task> action)
    {
        EnsureStarted();
        var tcs = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        _syncForm!.BeginInvoke(async () =>
        {
            try
            {
                await action();
                tcs.SetResult();
            }
            catch (Exception ex)
            {
                tcs.SetException(ex);
            }
        });
        return tcs.Task;
    }
}
