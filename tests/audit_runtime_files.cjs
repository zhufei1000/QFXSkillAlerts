const fs = require('fs');
const path = require('path');
const root = path.resolve(process.argv[2] || '.');
let errors = 0;
for (const addon of ['QFXSkillAlerts', 'QFXSkillAlerts_Config']) {
  const base = path.join(root, addon);
  const loaded = new Set();
  const missing = [];
  function visit(filename) {
    filename = path.resolve(filename);
    if (loaded.has(filename)) return;
    loaded.add(filename);
    if (!fs.existsSync(filename)) { missing.push(filename); return; }
    const ext = path.extname(filename).toLowerCase();
    if (ext === '.toc') {
      for (const raw of fs.readFileSync(filename, 'utf8').split(/\r?\n/)) {
        const line = raw.replace(/^\uFEFF/, '').trim();
        if (line && !/^[#;]/.test(line)) {
          visit(path.join(path.dirname(filename), line.replace(/\s+\[.*$/, '').replaceAll('\\', '/')));
        }
      }
    } else if (ext === '.xml') {
      const xml = fs.readFileSync(filename, 'utf8').replace(/<!--[\s\S]*?-->/g, '');
      for (const match of xml.matchAll(/<(?:Script|Include)\b[^>]*\bfile\s*=\s*["']([^"']+)["']/gi)) {
        visit(path.join(path.dirname(filename), match[1].replaceAll('\\', '/')));
      }
    }
  }
  function files(dir) {
    return fs.readdirSync(dir, {withFileTypes: true}).flatMap(item => {
      const filename = path.join(dir, item.name);
      return item.isDirectory() ? files(filename) : [filename];
    });
  }
  visit(path.join(base, addon + '.toc'));
  const unreferenced = files(base).filter(file => /\.(?:lua|xml)$/i.test(file) && !loaded.has(file));
  errors += missing.length + unreferenced.length;
  console.log(JSON.stringify({addon, loadedScripts: [...loaded].filter(f => /\.lua$/i.test(f)).length,
    missing, unreferenced: unreferenced.map(f => path.relative(base, f))}));
}
process.exitCode = errors ? 1 : 0;
