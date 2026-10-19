using System;
using System.Collections.Generic;
using ClipboardYoneticisi.Models;

namespace ClipboardYoneticisi.Services
{
    public class StackPasteService
    {
        private readonly Queue<(string Type, string Content)> _queue = new();

        public int Count => _queue.Count;

        public event Action? StackChanged;

        public void Enqueue(ClipboardItem item) => Enqueue(item.Type, item.Content);

        public void Enqueue(string type, string content)
        {
            _queue.Enqueue((type, content));
            StackChanged?.Invoke();
        }

        public void EnqueueMany(IEnumerable<ClipboardItem> items)
        {
            foreach (var item in items)
                _queue.Enqueue((item.Type, item.Content));
            StackChanged?.Invoke();
        }

        public bool TryDequeue(out string type, out string content)
        {
            if (_queue.Count == 0)
            {
                type = string.Empty;
                content = string.Empty;
                return false;
            }

            (type, content) = _queue.Dequeue();
            StackChanged?.Invoke();
            return true;
        }

        public void Clear()
        {
            _queue.Clear();
            StackChanged?.Invoke();
        }
    }
}
