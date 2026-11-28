const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../ui/app.js'),'utf8');
function setup(){
  const elements={}, clock={value:1000}, state={version:'1.2.2',calls:0,fail:false,checks:0,checkGate:null,installGate:null,available:true};
  function el(id){return elements[id] ||= {textContent:'',style:{},setAttribute(){},classList:{remove(){}},addEventListener(){}}}
  class Clock extends Date {static now(){return clock.value}}
  const ctx=vm.createContext({Date:Clock,document:{getElementById:el},window:{__TAURI__:{app:{getVersion:async()=> '1.2.1'},updater:{check:async()=>{state.checks++;if(state.checkGate)await state.checkGate;if(!state.available)return null;return {version:state.version,currentVersion:'1.2.1',downloadAndInstall:async()=>{state.calls++;if(state.installGate)await state.installGate;if(state.fail)throw Error('failed')}}}},process:{relaunch:async()=>{}}}}});
  vm.runInContext(source,ctx);
  return {ctx,state,clock,el,run:s=>vm.runInContext(s,ctx)};
}
test('successful update cannot be installed twice from the same object',async()=>{const t=setup();await t.run('checkNow()');await t.run('downloadAndInstall()');await t.run('downloadAndInstall()');assert.equal(t.state.calls,1)});
test('a changed version after stale recheck requires a second approval',async()=>{const t=setup();await t.run('checkNow()');t.clock.value+=600001;t.state.version='1.2.3';await t.run('downloadAndInstall()');assert.equal(t.state.calls,0);await t.run('downloadAndInstall()');assert.equal(t.state.calls,1)});
test('failed update invalidates old pending object',async()=>{const t=setup();await t.run('checkNow()');t.state.fail=true;await t.run('downloadAndInstall()');await t.run('downloadAndInstall()');assert.equal(t.state.calls,1);assert.equal(t.el('btn-download').disabled,true)});
test('stale recheck with unchanged version still requires fresh approval',async()=>{const t=setup();await t.run('checkNow()');t.clock.value+=600001;await t.run('downloadAndInstall()');assert.equal(t.state.calls,0);await t.run('downloadAndInstall()');assert.equal(t.state.calls,1)});
test('parallel stale install clicks cannot initiate installation',async()=>{const t=setup();await t.run('checkNow()');t.clock.value+=600001;await Promise.all([t.run('downloadAndInstall()'),t.run('downloadAndInstall()')]);assert.equal(t.state.calls,0);await t.run('downloadAndInstall()');assert.equal(t.state.calls,1)});
test('successful install blocks check and reinstall until restart',async()=>{const t=setup();await t.run('checkNow()');await t.run('downloadAndInstall()');await t.run('checkNow()');await t.run('downloadAndInstall()');assert.equal(t.state.calls,1);assert.equal(t.el('btn-check').disabled,true)});
test('concurrent installation calls only invoke downloader once',async()=>{const t=setup();await t.run('checkNow()');await Promise.all([t.run('downloadAndInstall()'),t.run('downloadAndInstall()')]);assert.equal(t.state.calls,1)});

// Controlled promise resolution, rather than timing sleeps, tests the in-flight guard.
test('in-flight refresh rejects duplicate checks and installation of the previous update',async()=>{
  const t=setup();
  await t.run('checkNow()');
  let release;
  t.state.checkGate=new Promise(resolve=>{release=resolve});
  t.state.version='1.2.3';
  const refresh=t.run('checkNow()');
  try {
    await Promise.all([t.run('checkNow()'),t.run('downloadAndInstall()')]);
    assert.equal(t.state.checks,2);
    assert.equal(t.state.calls,0);
    assert.equal(t.el('btn-download').disabled,true);
  } finally {
    release();
    await refresh;
  }
  assert.equal(t.el('upd-state').textContent,'update available: 1.2.3');
  await t.run('downloadAndInstall()');
  assert.equal(t.state.calls,1);
});
test('failed concurrent refresh invalidates old approval and permits recovery',async()=>{
  const t=setup();
  await t.run('checkNow()');
  let reject;
  t.state.checkGate=new Promise((_,fail)=>{reject=fail});
  const refresh=t.run('checkNow()');
  try {
    await Promise.all([t.run('checkNow()'),t.run('downloadAndInstall()')]);
    assert.equal(t.state.checks,2);
    assert.equal(t.state.calls,0);
  } finally {
    reject(Error('controlled check failure'));
    await refresh;
  }
  assert.equal(t.el('upd-state').textContent,'check failed');
  assert.equal(t.el('btn-download').disabled,true);
  await t.run('downloadAndInstall()');
  assert.equal(t.state.calls,0);
  t.state.checkGate=null;
  await t.run('checkNow()');
  assert.equal(t.state.checks,3);
  await t.run('downloadAndInstall()');
  assert.equal(t.state.calls,1);
});

test('no-update result consumes previous approval',async()=>{
  const t=setup();
  await t.run('checkNow()');
  t.state.available=false;
  await t.run('checkNow()');
  await t.run('downloadAndInstall()');
  assert.equal(t.state.calls,0);
  assert.equal(t.el('btn-download').disabled,true);
  assert.equal(t.el('upd-state').textContent,'up to date');
  t.state.available=true;
  await t.run('checkNow()');
  await t.run('downloadAndInstall()');
  assert.equal(t.state.calls,1);
});
test('installation owns approval exclusively until completion',async()=>{
  const t=setup();
  await t.run('checkNow()');
  let release;
  t.state.installGate=new Promise(resolve=>{release=resolve});
  const install=t.run('downloadAndInstall()');
  try {
    await Promise.all([t.run('checkNow()'),t.run('downloadAndInstall()')]);
    assert.equal(t.state.checks,1);
    assert.equal(t.state.calls,1);
    assert.equal(t.el('btn-check').disabled,true);
    assert.equal(t.el('btn-download').disabled,true);
  } finally {
    release();
    await install;
  }
  await t.run('checkNow()');
  await t.run('downloadAndInstall()');
  assert.equal(t.state.checks,1);
  assert.equal(t.state.calls,1);
  assert.equal(t.el('btn-check').disabled,true);
});
