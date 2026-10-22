#!/usr/bin/env node
// design-diff.cjs <old-dir> <new-dir> <out-dir> <pages.txt> <shots.txt> <components.tsv> <repo-root>
//
// Visual diff of two versions of one design folder, driven by design-diff.sh. Renders every page in
// both versions with Playwright, captures each component instance by its selector, compares the
// images pixel by pixel in the browser (canvas — no image library needed), and for every change
// writes one PNG triptych "Before | After | Diff" under <out-dir>.
//
// Inputs (one path per line / tab-separated, all paths relative to the design folder):
//   pages.txt       page files (.html) present in either version
//   shots.txt       image files (screenshots, exported jpgs/pngs) present in either version
//   components.tsv  <Component>\t<CSS selector>\t<Used in pages, comma-separated, or empty = all>
//
// stdout: one tab-separated row per finding:
//   <change>\t<kind>\t<item>\t<file>\t<pixels>\t<diff png rel to out-dir | ->
//   change := changed | added | removed | count | uncaptured
// Exit: 0 ok | 3 Playwright or its browser unavailable | 1 other failure.
//
// Pages load through a routed origin (http://design.local/) rather than file://, because design
// runtimes (React, token bundles, fonts) refuse to load over file://. A request the folder cannot
// satisfy at its exact path is retried with leading path segments dropped, so a page in a
// sub-folder still finds a runtime that the export placed one level up — never outside the folder.
'use strict';

const fs = require('fs');
const path = require('path');

const [oldDir, newDir, outDir, pagesFile, shotsFile, compFile, repoRoot] =
  process.argv.slice(2);
const TOL = Number(process.env.SDLC_DESIGN_DIFF_TOLERANCE || 24); // per-channel delta, 0–255
const MIN_PX = Number(process.env.SDLC_DESIGN_DIFF_MIN_PX || 16); // fewer changed pixels = noise
const [VW, VH] = (process.env.SDLC_DESIGN_RENDER_SIZE || '1440,900')
  .split(',')
  .map(Number);

function loadPlaywright() {
  const pinned = process.env.SDLC_PLAYWRIGHT;
  if (pinned) return require(pinned);
  for (const name of ['playwright', 'playwright-core', '@playwright/test']) {
    try {
      return require(
        require.resolve(name, { paths: [repoRoot, process.cwd()] }),
      );
    } catch {
      /* try the next one */
    }
  }
  // pnpm keeps non-hoisted packages under node_modules/.pnpm/<name>@<version>/node_modules/<name>
  const store = path.join(repoRoot, 'node_modules', '.pnpm');
  const found = fs.existsSync(store)
    ? fs
        .readdirSync(store)
        .filter((d) => /^playwright(-core)?@\d/.test(d))
        .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))
    : [];
  for (const d of found) {
    const name = d.startsWith('playwright-core@')
      ? 'playwright-core'
      : 'playwright';
    try {
      return require(path.join(store, d, 'node_modules', name));
    } catch {
      /* try the next one */
    }
  }
  return null;
}

function lines(file) {
  return fs
    .readFileSync(file, 'utf8')
    .split('\n')
    .filter((l) => l.trim() !== '');
}

const safe = (s) => s.replace(/[^A-Za-z0-9._-]+/g, '_');
const emit = (...cols) => process.stdout.write(cols.join('\t') + '\n');

async function launch(pw) {
  const browser = process.env.SDLC_DESIGN_BROWSER;
  const opts = browser && browser !== 'none' ? { executablePath: browser } : {};
  try {
    return await pw.chromium.launch(opts);
  } catch (err) {
    // Playwright's own browser not installed: fall back to a system Chrome.
    for (const p of [
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/usr/bin/google-chrome',
      '/usr/bin/chromium',
      '/usr/bin/chromium-browser',
    ]) {
      if (fs.existsSync(p)) return pw.chromium.launch({ executablePath: p });
    }
    throw err;
  }
}

async function routeFolder(ctx, dir) {
  const root = fs.realpathSync(dir);
  await ctx.route('http://design.local/**', (route) => {
    let segs;
    try {
      segs = decodeURIComponent(new URL(route.request().url()).pathname)
        .split('/')
        .filter(Boolean);
    } catch {
      return route.fulfill({ status: 404, body: '' }); // malformed escape in a design URL
    }
    // exact path, then one directory dropped (deepest first: html/altA/vendor/x -> html/vendor/x),
    // then leading segments dropped
    const tries = [segs];
    for (let k = segs.length - 2; k >= 0; k--)
      tries.push([...segs.slice(0, k), ...segs.slice(k + 1)]);
    for (let k = 1; k < segs.length; k++) tries.push(segs.slice(k));
    for (const t of tries) {
      const f = path.join(root, ...t);
      if (!fs.existsSync(f)) continue;
      const real = fs.realpathSync(f); // a symlink must not serve a file from outside the folder
      if (real.startsWith(root + path.sep) && fs.statSync(real).isFile())
        return route.fulfill({ path: real });
    }
    return route.fulfill({ status: 404, body: '' });
  });
}

// Compare two PNG/JPEG buffers in the browser. Returns { changed, total } and, when anything
// changed, a "Before | After | Diff" triptych PNG buffer.
async function compare(page, before, after, mime = 'image/png') {
  const res = await page.evaluate(
    async ({ a, b, mime, tol }) => {
      const load = (b64) =>
        new Promise((ok, ko) => {
          const img = new Image();
          img.onload = () => ok(img);
          img.onerror = () => ko(new Error('undecodable image'));
          img.src = `data:${mime};base64,${b64}`;
        });
      const [ia, ib] = await Promise.all([load(a), load(b)]);
      const W = Math.max(ia.width, ib.width);
      const H = Math.max(ia.height, ib.height);
      const pixels = (img) => {
        const c = document.createElement('canvas');
        c.width = W;
        c.height = H;
        const x = c.getContext('2d');
        x.fillStyle = '#fff';
        x.fillRect(0, 0, W, H);
        x.drawImage(img, 0, 0);
        return x.getImageData(0, 0, W, H).data;
      };
      const pa = pixels(ia);
      const pb = pixels(ib);
      const d = document.createElement('canvas');
      d.width = W;
      d.height = H;
      const dx = d.getContext('2d');
      const out = dx.createImageData(W, H);
      const near = (p, i, q, j) =>
        Math.max(
          Math.abs(p[i] - q[j]),
          Math.abs(p[i + 1] - q[j + 1]),
          Math.abs(p[i + 2] - q[j + 2]),
        ) <= tol;
      // A sub-pixel shift re-antialiases edges: a pixel that matches a neighbour (1px) in the other
      // image, both ways round, is a shift, not a change.
      const shifted = (x, y, i) => {
        let ab = false;
        let ba = false;
        for (let dy = -1; dy <= 1 && !(ab && ba); dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            const nx = x + dx;
            const ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
            const j = (ny * W + nx) * 4;
            if (!ab && near(pa, i, pb, j)) ab = true;
            if (!ba && near(pb, i, pa, j)) ba = true;
          }
        }
        return ab && ba;
      };
      let changed = 0;
      for (let y = 0; y < H; y++) {
        for (let x = 0; x < W; x++) {
          const i = (y * W + x) * 4;
          const outside =
            x >= ia.width || y >= ia.height || x >= ib.width || y >= ib.height;
          if (outside || (!near(pa, i, pb, i) && !shifted(x, y, i))) {
            changed++;
            out.data.set([230, 20, 20, 255], i);
          } else {
            // faded greyscale of the new image as context
            const g =
              255 -
              (255 - (pb[i] * 0.3 + pb[i + 1] * 0.59 + pb[i + 2] * 0.11)) * 0.3;
            out.data.set([g, g, g, 255], i);
          }
        }
      }
      if (changed === 0) return { changed, total: W * H };
      dx.putImageData(out, 0, 0);
      const GAP = 16;
      const HEAD = 28;
      const t = document.createElement('canvas');
      t.width = W * 3 + GAP * 2;
      t.height = H + HEAD;
      const tx = t.getContext('2d');
      tx.fillStyle = '#fff';
      tx.fillRect(0, 0, t.width, t.height);
      tx.fillStyle = '#222';
      tx.font = '600 15px system-ui, sans-serif';
      ['Before', 'After', 'Diff'].forEach((label, k) =>
        tx.fillText(label, k * (W + GAP) + 4, 19),
      );
      tx.drawImage(ia, 0, HEAD);
      tx.drawImage(ib, W + GAP, HEAD);
      tx.drawImage(d, (W + GAP) * 2, HEAD);
      return {
        changed,
        total: W * H,
        png: t.toDataURL('image/png').split(',')[1],
      };
    },
    {
      a: before.toString('base64'),
      b: after.toString('base64'),
      mime,
      tol: TOL,
    },
  );
  return { ...res, png: res.png ? Buffer.from(res.png, 'base64') : null };
}

function pct(changed, total) {
  const p = (100 * changed) / total;
  return p >= 0.1 ? `${p.toFixed(1)}%` : `${changed}px`;
}

function save(rel, buf) {
  const f = path.join(outDir, rel);
  fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, buf);
  return rel;
}

async function render(page, rel) {
  await page.goto(
    'http://design.local/' + rel.split('/').map(encodeURIComponent).join('/'),
    {
      waitUntil: 'networkidle',
      timeout: 30000,
    },
  );
  await page.evaluate(() => document.fonts && document.fonts.ready);
  return page.screenshot({
    fullPage: true,
    animations: 'disabled',
    caret: 'hide',
  });
}

async function instances(page, selector) {
  const loc = page.locator(selector);
  const n = await loc.count().catch(() => 0);
  const shots = [];
  for (let i = 0; i < n; i++) {
    const el = loc.nth(i);
    const box = await el.boundingBox().catch(() => null);
    if (!box || box.width < 1 || box.height < 1) continue; // hidden or zero-size
    const png = await el.screenshot({ animations: 'disabled', caret: 'hide' });
    shots.push({ png, html: await el.evaluate((e) => e.outerHTML) });
  }
  return shots;
}

(async () => {
  const pw = loadPlaywright();
  if (!pw) {
    console.error(
      'design-diff: Playwright not found (set SDLC_PLAYWRIGHT to its module path)',
    );
    process.exit(3);
  }
  let browser;
  try {
    browser = await launch(pw);
  } catch (err) {
    console.error(
      `design-diff: no browser for Playwright — ${err.message.split('\n')[0]}`,
    );
    process.exit(3);
  }
  const ctxOpts = {
    viewport: { width: VW, height: VH },
    reducedMotion: 'reduce',
  };
  const oldCtx = await browser.newContext(ctxOpts);
  const newCtx = await browser.newContext(ctxOpts);
  await routeFolder(oldCtx, path.resolve(oldDir));
  await routeFolder(newCtx, path.resolve(newDir));
  const oldPage = await oldCtx.newPage();
  const newPage = await newCtx.newPage();
  const cmpPage = await (await browser.newContext()).newPage();

  const comps = lines(compFile).map((l) => {
    const [name, selector, usedIn = ''] = l.split('\t');
    return {
      name,
      selector,
      usedIn: usedIn
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
    };
  });
  const captured = new Set();
  const looked = new Set(); // components whose pages were rendered in both versions

  for (const rel of lines(pagesFile)) {
    const inOld = fs.existsSync(path.join(oldDir, rel));
    const inNew = fs.existsSync(path.join(newDir, rel));
    const title = path.basename(rel).replace(/(\.dc)?\.html?$/i, '');
    if (!inOld || !inNew) {
      emit(inNew ? 'added' : 'removed', 'page', title, rel, '-', '-');
      continue;
    }
    const before = await render(oldPage, rel);
    const after = await render(newPage, rel);
    const page = await compare(cmpPage, before, after);
    const onPage = comps.filter(
      (c) => c.usedIn.length === 0 || c.usedIn.includes(rel),
    );
    if (page.changed >= MIN_PX) {
      const out = save(`pages/${safe(rel)}.png`, page.png);
      emit('changed', 'page', title, rel, pct(page.changed, page.total), out);
    }
    for (const c of onPage) {
      looked.add(c.name);
      const a = await instances(oldPage, c.selector);
      const b = await instances(newPage, c.selector);
      if (a.length || b.length) captured.add(c.name);
      if (a.length !== b.length)
        emit('count', 'component', c.name, rel, `${a.length}→${b.length}`, '-');
      if (page.changed < MIN_PX) continue; // page pixel-identical: its instances are too
      for (let i = 0; i < Math.min(a.length, b.length); i++) {
        const r = await compare(cmpPage, a[i].png, b[i].png);
        if (r.changed < MIN_PX) continue;
        // same markup and under 5% of pixels: re-antialiasing after a sub-pixel move, not a change
        if (a[i].html === b[i].html && r.changed / r.total < 0.05) continue;
        const item = a.length > 1 ? `${c.name} #${i + 1}` : c.name;
        const out = save(
          `components/${safe(c.name)}--${safe(title)}--${i + 1}.png`,
          r.png,
        );
        emit('changed', 'component', item, rel, pct(r.changed, r.total), out);
      }
    }
  }
  for (const c of comps)
    if (looked.has(c.name) && !captured.has(c.name))
      emit('uncaptured', 'component', c.name, '-', '-', '-');

  for (const rel of lines(shotsFile)) {
    const fo = path.join(oldDir, rel);
    const fn = path.join(newDir, rel);
    const title = path.basename(rel).replace(/\.[^.]+$/, '');
    if (!fs.existsSync(fo) || !fs.existsSync(fn)) {
      emit(
        fs.existsSync(fn) ? 'added' : 'removed',
        'screenshot',
        title,
        rel,
        '-',
        '-',
      );
      continue;
    }
    const a = fs.readFileSync(fo);
    const b = fs.readFileSync(fn);
    if (a.equals(b)) continue;
    const ext = path.extname(rel).slice(1).toLowerCase();
    const mime =
      { jpg: 'image/jpeg', jpeg: 'image/jpeg', svg: 'image/svg+xml' }[ext] ||
      `image/${ext}`;
    const r = await compare(cmpPage, a, b, mime);
    if (r.changed < MIN_PX) continue;
    const out = save(`screenshots/${safe(rel)}.png`, r.png);
    emit('changed', 'screenshot', title, rel, pct(r.changed, r.total), out);
  }
  await browser.close();
})().catch((err) => {
  console.error(`design-diff: ${err.message}`);
  process.exit(1);
});
