// ============================================================================
// Script   : gen_wavedrom.js
// Function : 批量生成 Wavedrom 时序图 SVG→PNG + D2 流程图 D2→PNG
// Usage    : node gen_wavedrom.js <target_dir>
//            target_dir: 包含 wd_*.json / wd_*.d2 的目录，默认当前目录
// Output   : <target_dir>/wd_*.svg + <target_dir>/wd_*.png
// Deps     : npm install playwright-core, d2 on PATH
// ============================================================================

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const TARGET_DIR = process.argv[2] || process.cwd();
const SKILL_DIR = path.dirname(__filename);

// Tool paths: try project-local .claude/tools/ first, then fallback
function findTool(localName, fallback) {
    const local = path.join(SKILL_DIR, '..', '..', 'tools', localName);
    if (fs.existsSync(local)) return local;
    if (fs.existsSync(fallback)) return fallback;
    return path.basename(localName); // assume on PATH
}

const CHROME = process.env.CHROME_PATH ||
    'C:/Users/link_/AppData/Local/ms-playwright/chromium-1134/chrome-win/chrome.exe';
const WAVEDROM_CLI = 'npx wavedrom';
const D2 = findTool('d2/d2.exe', 'C:/Users/link_/d2/d2.exe');

// SVG→PNG helper using playwright-core
async function svgToPng(svgFile, pngFile, browser) {
    const page = await browser.newPage();
    const svg = fs.readFileSync(svgFile, 'utf8');
    await page.setContent(`<html><body style="margin:10px;background:white">${svg}</body></html>`);
    const el = await page.locator('svg').first();
    await el.screenshot({ path: pngFile });
    await page.close();
}

(async () => {
    const { chromium } = require('playwright-core');
    const browser = await chromium.launch({ executablePath: CHROME });

    // 1. Process wd_*.json (Wavedrom -> SVG -> PNG)
    const jsonFiles = fs.readdirSync(TARGET_DIR)
        .filter(f => f.startsWith('wd_') && f.endsWith('.json'));

    for (const f of jsonFiles) {
        const base = path.join(TARGET_DIR, f.replace('.json', ''));
        const jsonFile = base + '.json';
        const svgFile = base + '.svg';
        const pngFile = base + '.png';
        const name = f.replace('.json', '');

        console.log(`[Wavedrom] ${name}`);
        try {
            execSync(`${WAVEDROM_CLI} --input "${jsonFile}" > "${svgFile}"`, {
                cwd: TARGET_DIR, stdio: ['pipe', 'pipe', 'pipe']
            });
            await svgToPng(svgFile, pngFile, browser);
            console.log(`  OK -> ${path.basename(pngFile)}`);
        } catch (e) {
            console.error(`  FAIL: ${e.message}`);
        }
    }

    // 2. Process wd_*.d2 (D2 -> PNG)
    const d2Files = fs.readdirSync(TARGET_DIR)
        .filter(f => f.startsWith('wd_') && f.endsWith('.d2'));

    for (const f of d2Files) {
        const base = path.join(TARGET_DIR, f.replace('.d2', ''));
        const d2File = base + '.d2';
        const pngFile = base + '.png';
        const name = f.replace('.d2', '');

        console.log(`[D2] ${name}`);
        try {
            execSync(`${D2} --layout dagre "${d2File}" "${pngFile}"`, {
                cwd: TARGET_DIR, stdio: ['pipe', 'pipe', 'pipe']
            });
            console.log(`  OK -> ${path.basename(pngFile)}`);
        } catch (e) {
            console.error(`  FAIL: ${e.message}`);
        }
    }

    await browser.close();
    console.log('Done.');
})();
