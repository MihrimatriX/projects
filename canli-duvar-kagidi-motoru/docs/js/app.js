/* Canlı Duvar Kağıdı Motoru — shared interactions */

const WALLPAPERS = [
  { id: 'aurora-loop', title: 'Aurora Loop', type: 'video', source: 'katalog://yerel/aurora-loop.mp4', monitors: [1, 2] },
  { id: 'neon-city', title: 'Neon City', type: 'video', source: 'katalog://bulut/neon-city.webm', monitors: [1] },
  { id: 'mist-forest', title: 'Mist Forest', type: 'image', source: 'katalog://yerel/mist-forest.jpg', monitors: [2] },
  { id: 'particle-field', title: 'Particle Field', type: 'web', source: 'https://cdn.ornek.dev/wallpapers/particles/', monitors: [1] },
  { id: 'rain-glass', title: 'Rain on Glass', type: 'video', source: 'katalog://yerel/rain-glass.mp4', monitors: [] },
  { id: 'clock-widget', title: 'Minimal Clock', type: 'web', source: 'https://cdn.ornek.dev/wallpapers/clock/', monitors: [] },
  { id: 'mountain-still', title: 'Mountain Still', type: 'image', source: 'katalog://yerel/mountain.jpg', monitors: [] },
  { id: 'shader-waves', title: 'Shader Waves', type: 'web', source: 'https://cdn.ornek.dev/wallpapers/waves/', monitors: [] },
];

const MONITORS = [
  { id: 1, name: 'Birincil', res: '2560×1440', primary: true, wallpaper: 'aurora-loop', status: 'playing' },
  { id: 2, name: 'İkincil', res: '1920×1080', primary: false, wallpaper: 'mist-forest', status: 'playing' },
];

function typePill(type) {
  const labels = { video: 'Video', image: 'Görsel', web: 'Web' };
  return `<span class="pill pill-${type}">${labels[type] || type}</span>`;
}

function showToast(message) {
  const toast = document.getElementById('toast');
  if (!toast) return;
  toast.textContent = message;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 2800);
}

function setFeedback(el, message, tone = 'muted') {
  if (!el) return;
  el.textContent = message;
  el.style.color = tone === 'success' ? 'var(--success)'
    : tone === 'danger' ? 'var(--danger)'
    : 'var(--muted)';
}

function initCatalog() {
  const grid = document.getElementById('wp-grid');
  const search = document.getElementById('search');
  const tabs = document.querySelectorAll('.filter-tab');
  const applyBtn = document.getElementById('apply-btn');
  const detail = document.getElementById('selection-detail');
  const refreshBtn = document.getElementById('refresh-catalog');
  const countEl = document.getElementById('catalog-count');
  let filter = 'all';
  let selected = null;

  function render(items) {
    if (!grid) return;
    if (countEl) countEl.textContent = `katalog.json · ${items.length} öğe`;

    if (!items.length) {
      grid.innerHTML = '<p class="selection-empty">Eşleşen duvar kağıdı bulunamadı.</p>';
      return;
    }

    grid.innerHTML = items.map(wp => `
      <div class="wp-card${selected === wp.id ? ' selected' : ''}" data-id="${wp.id}" tabindex="0" role="button" aria-pressed="${selected === wp.id}">
        <div class="wp-thumb"><div class="wp-thumb-inner" style="background:linear-gradient(${hashHue(wp.id)}deg, var(--surface-2), var(--border))"></div></div>
        <div class="wp-meta">
          <div class="wp-title">${wp.title}</div>
          <div class="wp-sub">${wp.source}</div>
          <div style="margin-top:6px">${typePill(wp.type)}</div>
        </div>
      </div>
    `).join('');

    grid.querySelectorAll('.wp-card').forEach(card => {
      const select = () => {
        selected = card.dataset.id;
        const wp = WALLPAPERS.find(w => w.id === selected);
        if (detail) {
          detail.classList.remove('selection-empty');
          detail.innerHTML = wp ? `
            <strong>${wp.title}</strong><br>
            <span style="color:var(--muted);font-size:12px">${wp.source}</span><br>
            <span style="margin-top:8px;display:inline-block">${typePill(wp.type)}</span>
          ` : '';
        }
        if (applyBtn) applyBtn.disabled = !wp;
        render(filterList());
      };
      card.addEventListener('click', select);
      card.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          select();
        }
      });
    });
  }

  function filterList() {
    const q = (search?.value || '').toLowerCase();
    return WALLPAPERS.filter(wp => {
      if (filter !== 'all' && wp.type !== filter) return false;
      if (q && !wp.title.toLowerCase().includes(q) && !wp.source.toLowerCase().includes(q)) return false;
      return true;
    });
  }

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      tabs.forEach(t => {
        t.classList.remove('active');
        t.setAttribute('aria-selected', 'false');
      });
      tab.classList.add('active');
      tab.setAttribute('aria-selected', 'true');
      filter = tab.dataset.filter;
      render(filterList());
    });
  });

  search?.addEventListener('input', () => render(filterList()));

  applyBtn?.addEventListener('click', () => {
    if (!selected) return;
    const wp = WALLPAPERS.find(w => w.id === selected);
    showToast(`«${wp.title}» birincil monitöre uygulandı`);
  });

  refreshBtn?.addEventListener('click', () => {
    render(filterList());
    showToast('Katalog yenilendi');
  });

  render(filterList());
}

function hashHue(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) h = (h * 31 + str.charCodeAt(i)) % 360;
  return h;
}

function initPlayer() {
  const playBtn = document.getElementById('play-toggle');
  const progress = document.getElementById('progress');
  const fill = progress?.querySelector('.progress-fill');
  const timeEl = document.getElementById('time');
  const pauseAll = document.getElementById('pause-all');
  let playing = true;
  let pct = 35;

  function updateProgress(next) {
    pct = Math.max(0, Math.min(100, next));
    if (fill) fill.style.width = pct + '%';
    if (progress) progress.setAttribute('aria-valuenow', String(pct));
    if (timeEl) timeEl.textContent = formatTime(pct);
  }

  playBtn?.addEventListener('click', () => {
    playing = !playing;
    playBtn.textContent = playing ? '⏸' : '▶';
    playBtn.setAttribute('aria-label', playing ? 'Duraklat' : 'Oynat');
  });

  progress?.addEventListener('click', (e) => {
    const rect = progress.getBoundingClientRect();
    updateProgress(Math.round(((e.clientX - rect.left) / rect.width) * 100));
  });

  progress?.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowRight') updateProgress(pct + 5);
    if (e.key === 'ArrowLeft') updateProgress(pct - 5);
  });

  pauseAll?.addEventListener('click', () => {
    playing = false;
    if (playBtn) {
      playBtn.textContent = '▶';
      playBtn.setAttribute('aria-label', 'Oynat');
    }
    const status = document.getElementById('player-status');
    if (status) status.textContent = 'Aurora Loop · Monitör 1 · tam ekran uygulama — duraklatıldı';
  });
}

function formatTime(pct) {
  const total = 124;
  const cur = Math.round(total * pct / 100);
  const m = Math.floor(cur / 60);
  const s = String(cur % 60).padStart(2, '0');
  return `${m}:${s} / 2:04`;
}

function initMonitors() {
  const list = document.getElementById('monitor-list');
  const feedback = document.getElementById('monitor-feedback');
  if (!list) return;

  function render() {
    list.innerHTML = MONITORS.map(m => {
      const wp = WALLPAPERS.find(w => w.id === m.wallpaper);
      return `
        <div class="monitor-row" data-id="${m.id}">
          <div class="monitor-icon${m.primary ? ' primary' : ''}">${m.id}</div>
          <div>
            <div style="font-weight:600;margin-bottom:2px">${m.name} · ${m.res}</div>
            <div style="font-size:12px;color:var(--muted)">${wp ? wp.title : '—'} ${wp ? typePill(wp.type) : ''}</div>
          </div>
          <select class="select" style="width:180px" data-monitor="${m.id}" aria-label="${m.name} duvar kağıdı">
            <option value="">Duvar kağıdı seç…</option>
            ${WALLPAPERS.map(w => `<option value="${w.id}"${w.id === m.wallpaper ? ' selected' : ''}>${w.title}</option>`).join('')}
          </select>
        </div>
      `;
    }).join('');

    list.querySelectorAll('select').forEach(sel => {
      sel.addEventListener('change', () => {
        const mon = MONITORS.find(m => m.id === +sel.dataset.monitor);
        if (mon) mon.wallpaper = sel.value;
      });
    });
  }

  document.getElementById('apply-monitors')?.addEventListener('click', () => {
    setFeedback(feedback, 'Monitör atamaları uygulandı — WorkerW güncellendi', 'success');
  });

  document.getElementById('sync-monitors')?.addEventListener('click', () => {
    const primary = MONITORS.find(m => m.primary);
    if (!primary?.wallpaper) return;
    MONITORS.forEach(m => { m.wallpaper = primary.wallpaper; });
    render();
    setFeedback(feedback, 'Tüm monitörler birincil duvar kağıdı ile senkronize edildi', 'success');
  });

  render();
}

function initSettings() {
  document.querySelectorAll('.toggle:not([disabled])').forEach(btn => {
    btn.addEventListener('click', () => {
      btn.classList.toggle('on');
      btn.setAttribute('aria-pressed', btn.classList.contains('on') ? 'true' : 'false');
    });
  });

  const urlInput = document.getElementById('catalog-url');
  const testBtn = document.getElementById('test-catalog');
  const result = document.getElementById('catalog-result');

  testBtn?.addEventListener('click', () => {
    const url = urlInput?.value.trim() || '';
    if (!url.startsWith('http')) {
      setFeedback(result, 'Geçersiz URL — http veya https ile başlamalı', 'danger');
      return;
    }
    setFeedback(result, 'Katalog yüklendi — 8 öğe, imza doğrulaması kapalı (MVP)', 'success');
  });
}

function initTray() {
  document.querySelectorAll('.tray-item[data-action]').forEach(item => {
    item.addEventListener('click', () => {
      const action = item.dataset.action;
      const feedback = document.getElementById('tray-feedback');
      const msgs = {
        pause: 'Tüm duvar kağıtları duraklatıldı',
        resume: 'Oynatma devam ediyor',
        reconnect: 'Explorer yeniden bağlanıyor…',
        quit: 'Uygulama kapatılıyor (simülasyon)',
      };
      setFeedback(feedback, msgs[action] || action, action === 'quit' ? 'danger' : 'success');
    });
  });
}

document.addEventListener('DOMContentLoaded', () => {
  initCatalog();
  initPlayer();
  initMonitors();
  initSettings();
  initTray();
});
