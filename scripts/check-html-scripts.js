// Extracts every non-Babel, non-external <script> block from each HTML file
// in the repo root and validates its syntax with `node --check`.
// JSX (<script type="text/babel">) blocks are skipped - this project has no
// build step, so we only check plain scripts, the same way they actually run.
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const os = require('os');

const root = path.join(__dirname, '..');
const htmlFiles = fs.readdirSync(root).filter(f => f.endsWith('.html'));

const scriptTagRe = /<script(\s[^>]*)?>([\s\S]*?)<\/script>/gi;

let failures = 0;
let checked = 0;

for (const file of htmlFiles) {
  const content = fs.readFileSync(path.join(root, file), 'utf8');
  let match;
  let index = 0;
  while ((match = scriptTagRe.exec(content))) {
    index++;
    const attrs = match[1] || '';
    const body = match[2];
    if (/\bsrc=/.test(attrs)) continue; // external script, nothing to check
    if (/type\s*=\s*["']text\/babel["']/i.test(attrs)) continue; // JSX, needs Babel
    if (!body.trim()) continue;

    const tmpFile = path.join(os.tmpdir(), `forma-check-${file}-${index}.js`);
    fs.writeFileSync(tmpFile, body, 'utf8');
    checked++;
    try {
      execFileSync(process.execPath, ['--check', tmpFile], { stdio: 'pipe' });
    } catch (e) {
      failures++;
      console.error(`\nSyntax error in ${file}, <script> block #${index}:`);
      console.error(e.stderr ? e.stderr.toString() : e.message);
    } finally {
      fs.unlinkSync(tmpFile);
    }
  }
}

console.log(`Checked ${checked} inline <script> block(s) across ${htmlFiles.length} HTML file(s).`);
if (failures > 0) {
  console.error(`${failures} block(s) failed syntax check.`);
  process.exit(1);
}
console.log('All good.');
