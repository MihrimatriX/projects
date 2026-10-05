/* Canlı Duvar Kağıdı Motoru — paylaşılan WinUI shell */

const APP_NAV = [
  {
    id: 'catalog',
    href: 'catalog.html',
    label: 'Katalog',
    icon: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" aria-hidden="true"><rect x="2" y="2" width="5" height="5" rx="1"/><rect x="9" y="2" width="5" height="5" rx="1"/><rect x="2" y="9" width="5" height="5" rx="1"/><rect x="9" y="9" width="5" height="5" rx="1"/></svg>',
  },
  {
    id: 'player',
    href: 'player.html',
    label: 'Oynatıcı',
    icon: '<svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M4 3l10 5-10 5V3z"/></svg>',
  },
  {
    id: 'monitors',
    href: 'monitors.html',
    label: 'Monitörler',
    icon: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" aria-hidden="true"><rect x="1" y="3" width="14" height="9" rx="1"/><path d="M5 14h6M8 12v2"/></svg>',
  },
  {
    id: 'settings',
    href: 'settings.html',
    label: 'Ayarlar',
    icon: '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" aria-hidden="true"><circle cx="8" cy="8" r="2"/><path d="M8 1v2M8 13v2M1 8h2M13 8h2M3.05 3.05l1.41 1.41M11.54 11.54l1.41 1.41M3.05 12.95l1.41-1.41M11.54 4.46l1.41-1.41"/></svg>',
  },
  {
    id: 'tray',
    href: 'tray.html',
    label: 'Tepsi',
    icon: '<svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><rect x="1" y="12" width="14" height="2" rx="1"/><circle cx="4" cy="13" r="1.5"/></svg>',
  },
];

const TITLEBAR_ICON =
  '<svg class="titlebar-icon" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><rect x="1" y="3" width="14" height="10" rx="1.5" fill="none" stroke="currentColor" stroke-width="1.2"/><path d="M4 7h8M4 10h5" stroke="currentColor" stroke-width="1.2"/></svg>';

function currentPageId() {
  const page = document.body.dataset.page;
  if (page) return page;
  const file = location.pathname.split('/').pop() || 'index.html';
  const match = APP_NAV.find(item => item.href === file);
  return match?.id || '';
}

function renderTitlebar() {
  return `
    <header class="titlebar">
      ${TITLEBAR_ICON}
      <span class="titlebar-title">Canlı Duvar Kağıdı Motoru</span>
      <div class="win-controls">
        <button type="button" class="win-btn" aria-label="Simge durumuna küçült">─</button>
        <button type="button" class="win-btn" aria-label="Ekranı kapla">□</button>
        <button type="button" class="win-btn close" aria-label="Kapat">✕</button>
      </div>
    </header>
  `;
}

function renderSidebar(activeId) {
  const items = APP_NAV.map(item => `
    <a class="nav-item${item.id === activeId ? ' active' : ''}" href="${item.href}">
      ${item.icon}
      ${item.label}
    </a>
  `).join('');

  return `
    <nav class="sidebar" aria-label="Ana menü">
      ${items}
      <a class="nav-item nav-back" href="../index.html">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" aria-hidden="true"><path d="M10 3L5 8l5 5"/></svg>
        Prototip ana sayfa
      </a>
    </nav>
  `;
}

function injectAppShell() {
  const shell = document.querySelector('.win-shell');
  if (!shell) return;

  const titlebarSlot = shell.querySelector('[data-shell="titlebar"]');
  const sidebarSlot = shell.querySelector('[data-shell="sidebar"]');
  const activeId = currentPageId();

  if (titlebarSlot) titlebarSlot.outerHTML = renderTitlebar();
  if (sidebarSlot) sidebarSlot.outerHTML = renderSidebar(activeId);
}

document.addEventListener('DOMContentLoaded', injectAppShell);
