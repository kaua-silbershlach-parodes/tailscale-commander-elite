const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../ui/connection.js'),'utf8');
const html=fs.readFileSync(path.join(__dirname,'../ui/index.html'),'utf8');
const flush=()=>new Promise(resolve=>setImmediate(resolve));
async function setup({confirm=true,failSave=false}={}){
  const elements={}, calls=[];
  const el=id=>elements[id]||=( {textContent:'',value:'',disabled:false,addEventListener(_,fn){this.click=fn}} );
  const invoke=async (name,args)=>{
    calls.push({name,args});
    if(name==='connection_settings')return {tunnelId:'tunnel_fixture123',credentialStored:true};
    if(name==='tailscale_status')return {state:'Running',online:true,hostname:'fixture',dns:'fixture.invalid',addresses:[]};
    if(name==='tunnel_status')return 'Stopped';
    if(name==='connection_save'&&failSave)throw Error('Synthetic failure');
  };
  vm.runInNewContext(source,{document:{getElementById:el},window:{__TAURI__:{core:{invoke}},confirm:()=>confirm}});
  await flush();
  return {el,calls};
}
test('Tunnel ID and masked runtime key exist before updates panel',()=>{
  assert.match(html,/<input id="tunnel-id"[^>]*>/);
  assert.match(html,/<input id="tunnel-key" type="password"[^>]*>/);
  assert.ok(html.indexOf('id="tunnel-key"')<html.indexOf('id="btn-check"'));
});
test('saved key is never populated in renderer; input clears after saving',async()=>{
  const t=await setup();
  assert.equal(t.el('tunnel-id').value,'tunnel_fixture123');
  assert.equal(t.el('tunnel-key').value,'');
  t.el('tunnel-key').value='sk-fixture123456789';
  await t.el('tunnel-save').click();
  assert.equal(t.el('tunnel-key').value,'');
  assert.equal(t.calls.filter(c=>c.name==='connection_save').length,1);
});
test('failed vault save clears typed key',async()=>{
  const t=await setup({failSave:true});
  t.el('tunnel-key').value='sk-fixture123456789';
  await t.el('tunnel-save').click();
  assert.equal(t.el('tunnel-key').value,'');
  assert.match(t.el('tunnel-state').textContent,/Save failed/);
});
test('no automatic tunnel start and declined confirmation blocks connect',async()=>{
  const t=await setup({confirm:false});
  await t.el('tunnel-connect').click();
  assert.equal(t.calls.filter(c=>c.name==='tunnel_start').length,0);
});
test('explicit connect sends only fixed command',async()=>{
  const t=await setup();
  await t.el('tunnel-connect').click();
  assert.equal(t.calls.filter(c=>c.name==='tunnel_start').length,1);
  assert.equal(t.calls.find(c=>c.name==='tunnel_start').args,undefined);
});
