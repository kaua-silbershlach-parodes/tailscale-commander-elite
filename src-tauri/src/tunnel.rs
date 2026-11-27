//! Explicitly started, local-only MCP bridge. No shell or file permissions.
use serde_json::{json,Value};
use std::{io::{Read,Write}, net::{TcpListener,TcpStream,SocketAddrV4,Ipv4Addr}, sync::{Arc,atomic::{AtomicBool,Ordering}}, time::{Duration,Instant}};
const MAX_REQUEST:usize=32*1024;
const MAX_HEADER:usize=8192;
fn error(id:Value,code:i32,message:&str)->Value{json!({"jsonrpc":"2.0","id":id,"error":{"code":code,"message":message}})}
fn tools()->Value{json!([
 {"name":"system_info","description":"Read-only local platform and application version; no environment or filesystem access.","inputSchema":{"type":"object","properties":{},"additionalProperties":false},"annotations":{"readOnlyHint":true,"destructiveHint":false,"openWorldHint":false}},
 {"name":"tailscale_status","description":"Read-only status of this approved device, including its Tailscale addresses and hostname.","inputSchema":{"type":"object","properties":{},"additionalProperties":false},"annotations":{"readOnlyHint":true,"destructiveHint":false,"openWorldHint":false}}
])}
fn rpc(message:Value)->Option<Value>{
    let id=message.get("id").cloned().unwrap_or(Value::Null);
    if message["jsonrpc"]!="2.0" || !message["method"].is_string() || !(id.is_null()||id.is_string()||id.is_number()){
        return Some(error(Value::Null,-32600,"Invalid request"))
    }
    if message.get("id").is_none(){return None}
    let result=match message["method"].as_str().unwrap_or("") {
        "initialize"=>{
            let asked=message["params"]["protocolVersion"].as_str().unwrap_or("");
            let version=if ["2025-11-25","2025-06-18","2025-03-26","2024-11-05"].contains(&asked){asked}else{"2025-11-25"};
            json!({"protocolVersion":version,"capabilities":{"tools":{}},"serverInfo":{"name":"tailscale-commander-elite","version":env!("CARGO_PKG_VERSION")}})
        },
        "ping"=>json!({}),
        "tools/list"=>json!({"tools":tools()}),
        "resources/list"=>json!({"resources":[]}),
        "prompts/list"=>json!({"prompts":[]}),
        "tools/call"=>{
            let args=&message["params"]["arguments"];
            if !args.is_null() && !args.as_object().is_some_and(|x|x.is_empty()){
                return Some(error(id,-32602,"Arguments are not permitted"))
            }
            let info=match message["params"]["name"].as_str(){
                Some("system_info")=>Ok(json!({"platform":std::env::consts::OS,"arch":std::env::consts::ARCH,"version":env!("CARGO_PKG_VERSION")})),
                Some("tailscale_status")=>super::connection::network_snapshot(),
                _=>return Some(error(id,-32602,"Tool not available"))
            };
            match info{Ok(v)=>json!({"content":[{"type":"text","text":v.to_string()}]}),Err(_)=>json!({"isError":true,"content":[{"type":"text","text":"Local service unavailable"}]})}
        },
        _=>return Some(error(id,-32601,"Method not found"))
    };
    Some(json!({"jsonrpc":"2.0","id":id,"result":result}))
}
fn response(stream:&mut TcpStream,status:&str,body:&[u8]){
    let _=write!(stream,"HTTP/1.1 {status}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",body.len());
    let _=stream.write_all(body);
}
fn constant_eq(a:&[u8],b:&[u8])->bool{
    if a.len()!=b.len(){return false}
    a.iter().zip(b).fold(0u8,|v,(x,y)|v|(x^y))==0
}
fn handle(stream:&mut TcpStream,token:&str){
    let _=stream.set_read_timeout(Some(Duration::from_millis(500)));
    let _=stream.set_write_timeout(Some(Duration::from_secs(2)));
    let deadline=Instant::now()+Duration::from_secs(3);
    let mut data=Vec::new();
    let mut temp=[0u8;4096];
    let header_end=loop{
        if Instant::now()>=deadline||data.len()>MAX_HEADER{response(stream,"400 Bad Request",b"");return}
        if let Some(i)=data.windows(4).position(|x|x==b"\r\n\r\n"){break i+4}
        match stream.read(&mut temp){Ok(n) if n>0=>data.extend_from_slice(&temp[..n]),_=>return}
    };
    if header_end>MAX_HEADER{response(stream,"431 Request Header Fields Too Large",b"");return}
    let Ok(header)=std::str::from_utf8(&data[..header_end-4]) else {response(stream,"400 Bad Request",b"");return};
    let mut lines=header.split("\r\n");
    let first=lines.next().unwrap_or("");
    if first!="POST /mcp HTTP/1.1" && first!="POST /mcp HTTP/1.0"{response(stream,"405 Method Not Allowed",b"");return}
    let mut headers=std::collections::HashMap::new();
    for line in lines{
        let Some((name,value))=line.split_once(':')else{response(stream,"400 Bad Request",b"");return};
        if name.is_empty()||!name.bytes().all(|x|x.is_ascii_alphanumeric()||x==b'-')||headers.insert(name.to_ascii_lowercase(),value.trim()).is_some(){
            response(stream,"400 Bad Request",b"");return
        }
    }
    let auth=format!("Bearer {token}");
    if !headers.get("authorization").is_some_and(|v|constant_eq(v.as_bytes(),auth.as_bytes())){
        response(stream,"401 Unauthorized",b"");return
    }
    if headers.contains_key("transfer-encoding")||headers.contains_key("origin") {
        response(stream,"403 Forbidden",b"");return
    }
    let Some(len)=headers.get("content-length").and_then(|x|x.parse::<usize>().ok()).filter(|n|*n<=MAX_REQUEST) else{
        response(stream,"413 Payload Too Large",b"");return
    };
    if !headers.get("content-type").is_some_and(|v|v.split(';').next()==Some("application/json")){
        response(stream,"415 Unsupported Media Type",b"");return
    }
    while data.len()<header_end+len{
        if Instant::now()>=deadline{response(stream,"408 Request Timeout",b"");return}
        match stream.read(&mut temp){Ok(n) if n>0=>data.extend_from_slice(&temp[..n]),_=>return}
    }
    if data.len()!=header_end+len{response(stream,"400 Bad Request",b"");return}
    match serde_json::from_slice::<Value>(&data[header_end..]){
        Ok(v)=>match rpc(v){
            Some(r)=>response(stream,"200 OK",r.to_string().as_bytes()),
            None=>response(stream,"202 Accepted",b""),
        },
        Err(_)=>response(stream,"400 Bad Request",b"")
    }
}
struct Server{addr:std::net::SocketAddr,stop:Arc<AtomicBool>,thread:Option<std::thread::JoinHandle<()>>}
impl Server{
    fn start(token:String)->Result<Self,String>{
        let listener=TcpListener::bind(SocketAddrV4::new(Ipv4Addr::LOCALHOST,0)).map_err(|_|"Local MCP bind failed")?;
        let addr=listener.local_addr().map_err(|_|"Local MCP address unavailable")?;
        listener.set_nonblocking(true).map_err(|_|"MCP listener setup failed")?;
        let stop=Arc::new(AtomicBool::new(false));let flag=stop.clone();
        let thread=std::thread::spawn(move||{
            while !flag.load(Ordering::Acquire){
                match listener.accept(){
                    Ok((mut stream,peer)) if peer.ip().is_loopback()=>handle(&mut stream,&token),
                    Ok(_)=>{},
                    Err(e) if e.kind()==std::io::ErrorKind::WouldBlock=>std::thread::sleep(Duration::from_millis(20)),
                    Err(_)=>break
                }
            }
        });
        Ok(Self{addr,stop,thread:Some(thread)})
    }
}
impl Drop for Server{fn drop(&mut self){self.stop.store(true,Ordering::Release);if let Some(t)=self.thread.take(){let _=t.join();}}}

#[cfg(windows)]
mod runtime{
    use super::*;
    use std::{os::windows::{io::AsRawHandle,fs::OpenOptionsExt,process::CommandExt},path::PathBuf,process::{Child,Command,Stdio}};
    use sha2::{Digest,Sha256};
    use windows_sys::Win32::{Foundation::CloseHandle,System::JobObjects::*};
    use tauri::Manager;
    const PIN:&str="e0b2f25d08f24a4ddb7a04f3d43b62f88d4b18a5b20f2e478295cd8f353f21e5";
    struct Job(usize);
    impl Drop for Job{fn drop(&mut self){unsafe{CloseHandle(self.0 as _);}}}
    impl Job{
        fn new()->Result<Self,String>{unsafe{
            let h=CreateJobObjectW(std::ptr::null(),std::ptr::null());
            if h.is_null(){return Err("Cannot create process job".into())}
            let job=Self(h as usize);
            let mut info:JOBOBJECT_EXTENDED_LIMIT_INFORMATION=std::mem::zeroed();
            info.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            if SetInformationJobObject(h,JobObjectExtendedLimitInformation,(&info as *const JOBOBJECT_EXTENDED_LIMIT_INFORMATION).cast(),std::mem::size_of_val(&info) as u32)==0{
                return Err("Cannot restrict process lifetime".into())
            }
            Ok(job)
        }}
        fn attach(&self,child:&Child)->Result<(),String>{
            if unsafe{AssignProcessToJobObject(self.0 as _,child.as_raw_handle().cast())}==0{Err("Cannot constrain tunnel process".into())}else{Ok(())}
        }
    }
    pub struct Run{child:Child,_job:Job,_server:Server,folder:tempfile::TempDir}
    impl Drop for Run{fn drop(&mut self){let _=self.child.kill();let _=self.child.wait();}}
    impl Run{
        pub fn start(app:&tauri::AppHandle,id:&str,key:&str)->Result<Self,String>{
            let exe:PathBuf=app.path().app_local_data_dir().map_err(|_|"Local app data unavailable")?.join("bin").join("tunnel-client.exe");
            let mut f=std::fs::OpenOptions::new().read(true).share_mode(1).open(&exe).map_err(|_|"Verified tunnel client not provisioned")?;
            let size=f.metadata().map_err(|_|"Tunnel client metadata unavailable")?.len();
            if size!=26860544{return Err("Tunnel executable size mismatch".into())}
            let mut hash=Sha256::new();
            let mut bytes=[0u8;65536];
            loop{let n=f.read(&mut bytes).map_err(|_|"Tunnel binary read failed")?;if n==0{break}hash.update(&bytes[..n]);}
            if format!("{:x}",hash.finalize())!=PIN{return Err("Tunnel client integrity mismatch".into())}
            let mut raw=[0u8;32];getrandom::fill(&mut raw).map_err(|_|"Secure random unavailable")?;
            let token=raw.iter().map(|b|format!("{b:02x}")).collect::<String>();
            let server=Server::start(token.clone())?;
            let folder=tempfile::Builder::new().prefix("tce-mcp-").tempdir().map_err(|_|"Cannot create private runtime directory")?;
            let health=folder.path().join("health-url");
            let job=Job::new()?;
            let mut cmd=Command::new(&exe);
            cmd.args(["run","--control-plane.tunnel-id",id,"--control-plane.api-key","env:CONTROL_PLANE_API_KEY",
                "--mcp.server-url",&format!("http://{}/mcp",server.addr),"--mcp.extra-headers","Authorization: env:TCE_MCP_AUTH",
                "--mcp.oauth-discovery","disabled","--health.listen-addr","127.0.0.1:0","--health.url-file"])
                .arg(&health).args(["--log.level","warn"])
                .current_dir(folder.path()).env_clear().env("CONTROL_PLANE_API_KEY",key).env("TCE_MCP_AUTH",format!("Bearer {token}"))
                .stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null()).creation_flags(0x08000000);
            if let Some(root)=std::env::var_os("SystemRoot"){cmd.env("SystemRoot",root);}
            if let Some(tmp)=std::env::var_os("TEMP"){cmd.env("TEMP",tmp);}
            let mut child=cmd.spawn().map_err(|_|"Tunnel client launch failed")?;
            if let Err(e)=job.attach(&child){let _=child.kill();let _=child.wait();return Err(e)}
            drop(f);
            Ok(Self{child,_job:job,_server:server,folder})
        }
        pub fn status(&mut self)->Result<&'static str,String>{
            if self.child.try_wait().map_err(|_|"Tunnel process check failed")?.is_some(){return Ok("Stopped")}
            let health=self.folder.path().join("health-url");
            if std::fs::metadata(&health).map(|x|x.len()).unwrap_or(0)>256{return Err("Invalid readiness URL".into())}
            let Ok(raw)=std::fs::read_to_string(health)else{return Ok("Connecting")};
            let Some(addr)=raw.trim().strip_prefix("http://127.0.0.1:").and_then(|v|v.trim_end_matches('/').parse::<u16>().ok()).filter(|p|*p!=0)else{return Err("Invalid readiness URL".into())};
            let socket=SocketAddrV4::new(Ipv4Addr::LOCALHOST,addr).into();
            let Ok(mut stream)=TcpStream::connect_timeout(&socket,Duration::from_millis(500))else{return Ok("Connecting")};
            let _=stream.set_read_timeout(Some(Duration::from_millis(700)));let _=stream.set_write_timeout(Some(Duration::from_millis(700)));
            if stream.write_all(b"GET /readyz HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n").is_err(){return Ok("Connecting")}
            let mut buf=[0u8;256];
            match stream.read(&mut buf){Ok(n) if buf[..n].starts_with(b"HTTP/1.1 200 ")||buf[..n].starts_with(b"HTTP/1.0 200 ")=>Ok("Ready"),_=>Ok("Connecting")}
        }
    }
}
#[cfg(not(windows))]
mod runtime{
    pub struct Run;
    impl Run{
        pub fn start(_: &tauri::AppHandle,_:&str,_:&str)->Result<Self,String>{Err("Tunnel runtime currently Windows-only".into())}
        pub fn status(&mut self)->Result<&'static str,String>{Ok("Stopped")}
    }
}
#[derive(Default)]
pub struct TunnelState(std::sync::Mutex<Option<runtime::Run>>);
impl TunnelState{
    pub fn active(&self)->Result<bool,String>{Ok(self.0.lock().map_err(|_|"Tunnel state unavailable")?.is_some())}
    pub fn stop(&self)->Result<(),String>{self.0.lock().map_err(|_|"Tunnel state unavailable")?.take();Ok(())}
}
#[tauri::command]
pub fn tunnel_start(window:tauri::WebviewWindow,app:tauri::AppHandle,state:tauri::State<'_,TunnelState>)->Result<(),String>{
    super::connection::local(&window)?;
    let mut active=state.0.lock().map_err(|_|"Tunnel state unavailable")?;
    if active.is_some(){return Err("Disconnect existing tunnel first".into())}
    let (id,key)=super::connection::saved_credentials()?;
    *active=Some(runtime::Run::start(&app,&id,&key)?);
    Ok(())
}
#[tauri::command]
pub fn tunnel_stop(window:tauri::WebviewWindow,state:tauri::State<'_,TunnelState>)->Result<(),String>{super::connection::local(&window)?;state.stop()}
#[tauri::command]
pub fn tunnel_status(window:tauri::WebviewWindow,state:tauri::State<'_,TunnelState>)->Result<String,String>{
    super::connection::local(&window)?;
    let mut active=state.0.lock().map_err(|_|"Tunnel state unavailable")?;
    let status=match active.as_mut(){Some(run)=>run.status()?,None=>"Stopped"};
    if status=="Stopped"{active.take();}
    Ok(status.into())
}
#[cfg(test)]
mod tests{
    use super::*;
    fn request(server:&Server,auth:&str,value:&Value)->String{
        let mut stream=TcpStream::connect(server.addr).unwrap();
        stream.set_read_timeout(Some(Duration::from_secs(10))).unwrap();
        let body=value.to_string();
        write!(stream,"POST /mcp HTTP/1.1\r\nHost: 127.0.0.1\r\nAuthorization: Bearer {auth}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len()).unwrap();
        let mut result=String::new();stream.read_to_string(&mut result).unwrap();result
    }
    #[test]fn authenticated_local_tools(){let server=Server::start("fixture".into()).unwrap();assert!(server.addr.ip().is_loopback());let req=json!({"jsonrpc":"2.0","id":1,"method":"tools/list"});assert!(request(&server,"wrong",&req).starts_with("HTTP/1.1 401"));let response=request(&server,"fixture",&req);assert!(response.starts_with("HTTP/1.1 200"));assert!(response.contains("system_info"));assert!(response.contains("tailscale_status"));assert!(!response.contains("workspace_run"));assert!(!response.contains("linkedin"));}
    #[test]fn denies_unknown_tool(){let req=json!({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"workspace_run","arguments":{}}});assert_eq!(rpc(req).unwrap()["error"]["code"],-32602);}
    #[test]fn no_notification_side_effect(){assert!(rpc(json!({"jsonrpc":"2.0","method":"tools/call","params":{"name":"system_info"}})).is_none());}
}
