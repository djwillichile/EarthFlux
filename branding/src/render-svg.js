const { chromium } = require('playwright');
(async () => {
  const [svg, out, w, h, bg] = process.argv.slice(2);
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 });
  const fs = require('fs');
  await p.setContent(`<html><body style="margin:0;background:${bg}">${fs.readFileSync(svg,'utf8').replace('width="520" height="600"', `width="${w}" height="${h}"`)}</body></html>`);
  await p.screenshot({ path: out, omitBackground: bg === 'transparent' }); await b.close();
})();
