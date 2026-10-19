// GitHub Pages: manifest + README + ekran görüntülerinden _site/ üretir.
// Yerelde: node site/build.mjs && npx serve _site · Yayın: .\site\publish.ps1
import { execSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';

const root = join(import.meta.dirname, '..');
const out = join(root, '_site');
const files = execSync('git ls-files', { cwd: root, encoding: 'utf8' }).split('\n').filter(Boolean);
const tracked = new Set(files);
const has = f => tracked.has(f);
const read = f => readFileSync(join(root, f), 'utf8');

// proje-launcher DetectStack ile aynı sıra: .csproj > pubspec > main.py > package.json
function stack(id) {
  const pkg = `${id}/package.json`;
  if (!has(pkg) && files.some(f => f.startsWith(id + '/') && f.endsWith('.csproj') && f.split('/').length <= 4)) return '.NET';
  if (has(`${id}/pubspec.yaml`)) return 'Flutter';
  if (has(`${id}/main.py`) || has(`${id}/pyproject.toml`)) return 'Python';
  if (!has(pkg)) return 'Diğer';
  const { dependencies = {}, devDependencies = {} } = JSON.parse(read(pkg));
  const deps = { ...dependencies, ...devDependencies };
  if (deps.next) return 'Next.js';
  if (deps.electron) return 'Electron';
  return 'Node';
}

// README "## Özellikler" altındaki üst düzey maddeler
function features(id) {
  const lines = read(`${id}/README.md`).split(/\r?\n/);
  const start = lines.findIndex(l => /^##\s+Özellikler/i.test(l));
  if (start < 0) return [];
  const list = [];
  for (const l of lines.slice(start + 1)) {
    if (l.startsWith('#')) break;
    if (/^[-*] /.test(l)) list.push(l.slice(2).replace(/\[([^\]]+)\]\([^)]*\)/g, '$1').replace(/\*\*|`/g, '').trim());
  }
  return list;
}

const projects = files
  .filter(f => /^[^/]+\/assets\/manifest\.json$/.test(f))
  .map(f => {
    const id = f.split('/')[0];
    const m = JSON.parse(read(f));
    const shots = files
      .filter(x => x.startsWith(`${id}/docs/ekran`) && x.endsWith('.png'))
      .sort((a, b) => (a.endsWith('/ekran.png') ? -1 : b.endsWith('/ekran.png') ? 1 : a.localeCompare(b)));
    return {
      id, name: m.name, version: m.version, description: m.description,
      category: m.category, tags: m.tags ?? [], hotkey: m.hotkey ?? null,
      stack: stack(id), features: features(id), shots,
    };
  })
  .sort((a, b) => a.name.localeCompare(b.name, 'tr'));

rmSync(out, { recursive: true, force: true });
mkdirSync(out);
for (const p of projects) for (const s of p.shots) {
  mkdirSync(join(out, dirname(s)), { recursive: true });
  copyFileSync(join(root, s), join(out, s));
}
copyFileSync(join(import.meta.dirname, 'index.html'), join(out, 'index.html'));
writeFileSync(join(out, '.nojekyll'), '');
writeFileSync(join(out, 'projects.json'), JSON.stringify({
  repo: process.env.GITHUB_REPOSITORY ?? 'MihrimatriX/projects',
  projects,
}));
console.log(`${projects.length} proje -> _site/`);
