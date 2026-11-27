//! Local-only connectivity settings. Credentials never returned to WebView.
use serde_json::{json, Value};
use std::net::IpAddr;

const TARGET: &str = "AEliteEstrangeira/TailscaleCommanderElite/connection/v1";
const NETWORK_TARGET: &str = "AEliteEstrangeira/TailscaleCommanderElite/network/v1";
fn valid_id(id: &str) -> bool {
    id.strip_prefix("tunnel_").is_some_and(|s| (8..=128).contains(&s.len())
        && s.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'_' || c == b'-'))
}
fn valid_key(key: &str) -> bool {
    key.strip_prefix("sk-").is_some_and(|s| (12..=512).contains(&s.len())
        && s.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'_' || c == b'-'))
}
fn sanitized_network(v: &Value) -> Value {
    let self_node = &v["Self"];
    let addresses: Vec<String> = v["TailscaleIPs"].as_array().into_iter().flatten()
        .filter_map(|a| a.as_str()?.parse::<IpAddr>().ok().map(|ip| ip.to_string())).take(8).collect();
    json!({"state":v["BackendState"].as_str().unwrap_or("Unknown"),
        "hostname":self_node["HostName"].as_str().unwrap_or(""),
        "dns":self_node["DNSName"].as_str().unwrap_or(""),
        "online":self_node["Online"].as_bool().unwrap_or(false),
        "addresses":addresses})
}

#[cfg(windows)]
mod native {
    use super::*;
    use std::{os::windows::process::CommandExt, path::PathBuf, process::{Command, Stdio}, time::{Duration,Instant}, io::Read};
    use windows_sys::Win32::Security::Credentials::*;
    use windows_sys::Win32::Foundation::{GetLastError, ERROR_NOT_FOUND};
    fn wide(s:&str)->Vec<u16>{s.encode_utf16().chain(Some(0)).collect()}
    pub fn read(target:&str)->Result<Option<Value>,String>{
        let name=wide(target);
        let mut ptr=std::ptr::null_mut();
        unsafe {
            if CredReadW(name.as_ptr(),CRED_TYPE_GENERIC,0,&mut ptr)==0 {
                return if GetLastError()==ERROR_NOT_FOUND {Ok(None)} else {Err("Windows credential vault unavailable".into())};
            }
            if ptr.is_null(){return Err("Invalid credential record".into())}
            let c=&*ptr;
            let result=if c.CredentialBlobSize==0 || c.CredentialBlobSize>2560 || c.CredentialBlob.is_null(){
                Err("Invalid credential record".into())
            }else{
                serde_json::from_slice(std::slice::from_raw_parts(c.CredentialBlob,c.CredentialBlobSize as usize))
                    .map(Some).map_err(|_|"Invalid credential record".into())
            };
            CredFree(ptr.cast());
            result
        }
    }
    pub fn write(target:&str,value:&Value)->Result<(),String>{
        let mut data=serde_json::to_vec(value).map_err(|_|"Invalid settings")?;
        if data.len()>2560{return Err("Settings exceed vault limit".into())}
        let mut name=wide(target);
        let mut user=wide("Tailscale Commander Elite");
        let c=CREDENTIALW{Type:CRED_TYPE_GENERIC,TargetName:name.as_mut_ptr(),UserName:user.as_mut_ptr(),
            CredentialBlobSize:data.len() as u32,CredentialBlob:data.as_mut_ptr(),
            Persist:CRED_PERSIST_LOCAL_MACHINE,..Default::default()};
        let ok=unsafe{CredWriteW(&c,0)};
        data.fill(0);
        if ok==0{Err("Could not save in Windows credential vault".into())}else{Ok(())}
    }
    pub fn clear(target:&str)->Result<(),String>{
        let name=wide(target);
        unsafe{if CredDeleteW(name.as_ptr(),CRED_TYPE_GENERIC,0)==0 && GetLastError()!=ERROR_NOT_FOUND{
            return Err("Could not remove credential record".into())
        }}
        Ok(())
    }
    pub fn source_id()->Option<String>{
        let path=PathBuf::from(std::env::var_os("APPDATA")?).join("gpt-commander").join("tunnel-id.txt");
        if std::fs::metadata(&path).ok()?.len()>256{return None}
        let text=std::fs::read_to_string(path).ok()?;
        let id=text.trim();
        valid_id(id).then(||id.to_owned())
    }
    pub fn network()->Result<Value,String>{
        let base=std::env::var_os("ProgramFiles").ok_or("Program Files unavailable")?;
        let exe=PathBuf::from(base).join("Tailscale").join("tailscale.exe");
        if !exe.is_file(){return Err("Tailscale CLI not installed in Program Files".into())}
        let mut child=Command::new(exe).args(["status","--json"]).creation_flags(0x08000000)
            .stdin(Stdio::null()).stdout(Stdio::piped()).stderr(Stdio::null())
            .spawn().map_err(|_|"Tailscale unavailable")?;
        let pipe=child.stdout.take().ok_or("Tailscale output unavailable")?;
        let reader=std::thread::spawn(move||{
            let mut buf=Vec::new();
            pipe.take(2*1024*1024+1).read_to_end(&mut buf).map(|_|buf)
        });
        let deadline=Instant::now()+Duration::from_secs(6);
        let status=loop{
            match child.try_wait(){
                Ok(Some(status))=>break status,
                Ok(None) if Instant::now()<deadline=>std::thread::sleep(Duration::from_millis(30)),
                _=>{let _=child.kill();let _=child.wait();return Err("Tailscale status timed out".into())}
            }
        };
        let bytes=reader.join().map_err(|_|"Tailscale output unavailable")?.map_err(|_|"Tailscale output unavailable")?;
        if !status.success()||bytes.len()>2*1024*1024{return Err("Tailscale status failed".into())}
        let data:Value=serde_json::from_slice(&bytes).map_err(|_|"Invalid Tailscale status")?;
        Ok(sanitized_network(&data))
    }
}
#[cfg(not(windows))]
mod native {
    use super::*;
    pub fn read(_: &str)->Result<Option<Value>,String>{Err("Windows vault not available on this platform".into())}
    pub fn write(_: &str,_:&Value)->Result<(),String>{Err("Windows vault not available on this platform".into())}
    pub fn clear(_: &str)->Result<(),String>{Err("Windows vault not available on this platform".into())}
    pub fn source_id()->Option<String>{None}
    pub fn network()->Result<Value,String>{Err("Tailscale integration currently Windows-only".into())}
}
pub(crate) fn local(window:&tauri::WebviewWindow)->Result<(),String>{
    if window.label()!="main"{return Err("Only the local main window is authorized".into())}
    Ok(())
}
#[tauri::command]
pub fn connection_settings(window:tauri::WebviewWindow)->Result<Value,String>{
    local(&window)?;
    let record=native::read(TARGET)?;
    let id=record.as_ref().and_then(|r|r["tunnelId"].as_str()).filter(|s|valid_id(s)).map(str::to_owned)
        .or_else(native::source_id).unwrap_or_default();
    let stored=record.as_ref().and_then(|r|r["apiKey"].as_str()).is_some_and(valid_key);
    Ok(json!({"tunnelId":id,"credentialStored":stored,"vault":"Windows Credential Manager"}))
}
#[tauri::command]
pub fn connection_save(window:tauri::WebviewWindow,tunnel_id:String,api_key:String,state:tauri::State<'_,super::tunnel::TunnelState>)->Result<Value,String>{
    local(&window)?;
    if state.active()?{return Err("Disconnect the tunnel before changing credentials".into())}
    if !valid_id(&tunnel_id){return Err("Invalid tunnel ID".into())}
    let key=if api_key.is_empty(){
        let old=native::read(TARGET)?.ok_or("Enter a runtime API key")?;
        if old["tunnelId"].as_str()!=Some(&tunnel_id){return Err("Enter a key when changing the tunnel ID".into())}
        old["apiKey"].as_str().filter(|s|valid_key(s)).ok_or("Enter a runtime API key")?.to_owned()
    }else{api_key};
    if !valid_key(&key){return Err("Invalid runtime API key format".into())}
    native::write(TARGET,&json!({"schema":1,"tunnelId":tunnel_id,"apiKey":key}))?;
    connection_settings(window)
}
#[tauri::command]
pub fn connection_clear(window:tauri::WebviewWindow,state:tauri::State<'_,super::tunnel::TunnelState>)->Result<(),String>{local(&window)?;state.stop()?;native::clear(TARGET)}
pub(crate) fn network_snapshot()->Result<Value,String>{native::network()}
pub(crate) fn saved_credentials()->Result<(String,String),String>{
    let r=native::read(TARGET)?.ok_or("Save protected settings first")?;
    let id=r["tunnelId"].as_str().filter(|s|valid_id(s)).ok_or("Invalid saved tunnel ID")?;
    let key=r["apiKey"].as_str().filter(|s|valid_key(s)).ok_or("Invalid saved credential")?;
    Ok((id.to_owned(),key.to_owned()))
}
#[tauri::command]
pub async fn tailscale_status(window:tauri::WebviewWindow)->Result<Value,String>{
    local(&window)?;
    tauri::async_runtime::spawn_blocking(|| {
        match native::network() {
            Ok(mut snapshot) => {
                snapshot["cached"]=json!(false);
                snapshot["checkedAtUnix"]=json!(std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs());
                let stored=native::write(NETWORK_TARGET,&snapshot).is_ok();
                snapshot["persisted"]=json!(stored);
                Ok(snapshot)
            }
            Err(error) => {
                if let Some(mut snapshot)=native::read(NETWORK_TARGET).ok().flatten() {
                    if snapshot.is_object() {
                        snapshot["cached"]=json!(true);
                        snapshot["online"]=json!(false);
                        snapshot["state"]=json!("Last known — connection unverified");
                        snapshot["persisted"]=json!(true);
                        return Ok(snapshot)
                    }
                }
                Err(error)
            }
        }
    }).await.map_err(|_|"Tailscale worker failed")?
}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn formats(){assert!(valid_id("tunnel_abcdefgh"));assert!(!valid_id("tunnel_abc"));assert!(!valid_id("tunnel_abcdefgh\n"));assert!(valid_key("sk-abcdefgh123456"));assert!(!valid_key("sk-short"));assert!(!valid_key("sk-abcdefgh123456 "));}
    #[test]fn network_minimizes(){let v=json!({"BackendState":"Running","Self":{"HostName":"test","DNSName":"test.ts.net","Online":true,"PublicKey":"secret"},"TailscaleIPs":["100.64.0.1","fd7a:115c:a1e0::1","invalid"],"Peer":{"private":"omit"}});let got=sanitized_network(&v);assert_eq!(got["addresses"].as_array().unwrap().len(),2);assert!(got.get("Peer").is_none());assert!(got.get("PublicKey").is_none());}
    #[cfg(windows)]
    #[test]
    #[ignore = "requires installed and connected Tailscale on the authorized device"]
    fn live_tailscale_status(){let result=native::network().unwrap();assert_eq!(result["state"],"Running");assert_eq!(result["online"],true);assert!(!result["addresses"].as_array().unwrap().is_empty());println!("Native live Tailscale status verified; addresses withheld from test log.");}
    #[cfg(windows)]
    #[test]fn vault_roundtrip(){let target=format!("{TARGET}/test-{}",std::process::id());assert!(native::read(&target).unwrap().is_none());let data=json!({"tunnelId":"tunnel_fixture123","apiKey":"sk-fixture123456789"});native::write(&target,&data).unwrap();assert_eq!(native::read(&target).unwrap(),Some(data));native::clear(&target).unwrap();assert!(native::read(&target).unwrap().is_none());}
}
