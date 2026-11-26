// Update driver for the Tailscale Commander Elite shell.
// Uses the global Tauri API (app.withGlobalTauri = true in tauri.conf.json):
// no bundler and no npm packages are needed for the interface.
const tauri = window.__TAURI__ || {};
const getVersion = tauri.app?.getVersion;
const check = tauri.updater?.check;
const relaunch = tauri.process?.relaunch;

const el = (id) => document.getElementById(id);
let pendingUpdate = null;

function errText(err) {
  return err?.message ?? String(err);
}

function setState(text) {
  el('upd-state').textContent = text;
}

function setProgress(percent) {
  const clamped = Math.max(0, Math.min(100, Math.round(percent)));
  const bar = el('upd-bar');
  bar.style.width = clamped + '%';
  bar.setAttribute('aria-valuenow', String(clamped));
}

function logLine(text) {
  const log = el('upd-log');
  const time = new Date().toLocaleTimeString();
  const lines = (log.textContent + `[${time}] ${text}\n`).split('\n');
  log.textContent = lines.slice(-50).join('\n');
  log.scrollTop = log.scrollHeight;
}

async function init() {
  if (!getVersion || !check || !relaunch) {
    setState('unavailable');
    logLine('Tauri API unavailable in this context.');
    el('btn-check').disabled = true;
    return;
  }
  try {
    el('version').textContent = 'v' + (await getVersion());
  } catch (err) {
    logLine('Could not read the app version: ' + errText(err));
  }
}

async function checkNow() {
  el('btn-check').disabled = true;
  el('btn-download').disabled = true;
  pendingUpdate = null;
  setProgress(0);
  setState('checking...');
  try {
    const update = await check();
    if (!update) {
      setState('up to date');
      logLine('No update available. You are on the newest version.');
      return;
    }
    pendingUpdate = update;
    setState('update available: ' + update.version);
    logLine(`Update found: ${update.version} (current: ${update.currentVersion}).`);
    el('btn-download').disabled = false;
  } catch (err) {
    setState('check failed');
    logLine('Update check failed: ' + errText(err));
  } finally {
    el('btn-check').disabled = false;
  }
}

async function downloadAndInstall() {
  if (!pendingUpdate) return;
  el('btn-download').disabled = true;
  el('btn-check').disabled = true;
  setProgress(0);
  setState('downloading...');
  let downloaded = 0;
  let total = 0;
  try {
    await pendingUpdate.downloadAndInstall((event) => {
      if (event.event === 'Started') {
        total = Number(event.data.contentLength) || 0;
        logLine(`Download started (${total} bytes).`);
      } else if (event.event === 'Progress') {
        downloaded += Number(event.data.chunkLength) || 0;
        if (total > 0) {
          setProgress((downloaded / total) * 100);
        }
      } else if (event.event === 'Finished') {
        setProgress(100);
        logLine('Download finished.');
      }
    });
    setState('update installed - restart to apply');
    logLine('Update installed. Restart the app to apply it.');
    el('btn-restart').classList.remove('hidden');
  } catch (err) {
    setState('install failed');
    logLine('Download/install failed: ' + errText(err));
    el('btn-download').disabled = false;
  } finally {
    el('btn-check').disabled = false;
  }
}

el('btn-check').addEventListener('click', checkNow);
el('btn-download').addEventListener('click', downloadAndInstall);
el('btn-restart').addEventListener('click', async () => {
  try {
    await relaunch();
  } catch (err) {
    logLine('Restart failed: ' + errText(err));
  }
});
init();
