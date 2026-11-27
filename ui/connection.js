'use strict';
(() => {
  const invoke = window.__TAURI__?.core?.invoke;
  const el = id => document.getElementById(id);
  const text = (id, value) => { el(id).textContent = value; };
  const safeError = () => 'Unavailable. Check local installation or credential vault.';
  async function refresh() {
    el('ts-refresh').disabled = true;
    text('ts-state','Checking...');
    try {
      const s = await invoke('tailscale_status');
      text('ts-state', s.state + (s.online ? ' · online' : ' · offline') + (s.cached ? ' · saved snapshot' : ''));
      text('ts-host', s.hostname || '—');
      text('ts-dns', s.dns || '—');
      text('ts-ips', s.addresses.join(' · ') || '—');
    } catch {
      text('ts-state',safeError());
      for (const id of ['ts-host','ts-dns','ts-ips']) text(id,'—');
    } finally { el('ts-refresh').disabled = false; }
  }
  async function load() {
    try {
      const s = await invoke('connection_settings');
      el('tunnel-id').value = s.tunnelId || '';
      text('tunnel-state', s.credentialStored ? 'Credential protected' : 'No saved credential');
    } catch { text('tunnel-state',safeError()); }
  }
  async function save() {
    const key = el('tunnel-key');
    el('tunnel-save').disabled = true; el('tunnel-clear').disabled = true;
    try {
      await invoke('connection_save',{tunnelId:el('tunnel-id').value.trim(),apiKey:key.value});
      key.value = ''; await load();
    } catch { text('tunnel-state','Save failed. Verify the tunnel ID and runtime key.'); }
    finally { key.value=''; el('tunnel-save').disabled=false; el('tunnel-clear').disabled=false; }
  }
  async function clear() {
    if (!window.confirm('Remove the saved tunnel credential from this application?')) return;
    el('tunnel-clear').disabled=true; el('tunnel-save').disabled=true;
    try { await invoke('connection_clear'); el('tunnel-key').value=''; await load(); }
    catch { text('tunnel-state','Credential removal failed.'); }
    finally { el('tunnel-clear').disabled=false; el('tunnel-save').disabled=false; }
  }
  let runtimeBusy = false;
  async function runtimeStatus() {
    try { text('tunnel-runtime', await invoke('tunnel_status')); }
    catch { text('tunnel-runtime','Readiness unavailable'); }
  }
  async function toggle(start) {
    if (runtimeBusy) return;
    if (start && !window.confirm('Connect this saved tunnel? Stop any other client using this tunnel ID first. Two read-only device tools will be available to your MCP client.')) return;
    runtimeBusy = true;
    el('tunnel-connect').disabled = true; el('tunnel-disconnect').disabled = true;
    try { await invoke(start ? 'tunnel_start' : 'tunnel_stop'); await runtimeStatus(); }
    catch { text('tunnel-runtime',start ? 'Connection start failed; verify vault and official client.' : 'Disconnect failed'); }
    finally { runtimeBusy=false;el('tunnel-connect').disabled=false;el('tunnel-disconnect').disabled=false; }
  }
  if (!invoke) { text('tunnel-state','Native interface unavailable'); return; }
  el('ts-refresh').addEventListener('click', refresh);
  el('tunnel-save').addEventListener('click', save);
  el('tunnel-clear').addEventListener('click', clear);
  el('tunnel-connect').addEventListener('click',()=>toggle(true));
  el('tunnel-disconnect').addEventListener('click',()=>toggle(false));
  el('tunnel-test').addEventListener('click',runtimeStatus);
  void load(); void refresh(); void runtimeStatus();
})();
