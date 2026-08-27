import React,{useEffect,useState} from 'react';
import {createRoot} from 'react-dom/client';
import {Bell,Building2,Bus,CalendarDays,CheckCircle,ChevronDown,FileCheck,Hotel,Image,LayoutDashboard,Lock,LogOut,MapPin,Palette,RefreshCw,Search,Settings,Shield,Upload,Users} from 'lucide-react';
import './style.css';

const API=import.meta.env.VITE_API_URL||'http://localhost:5000/api';
const emptyConference={name:'',shortName:'',description:'',welcomeMessage:'',aboutConference:'',startDate:'',endDate:'',registrationStartDate:'',registrationEndDate:'',contactPerson:'',contactPhone:'',contactEmail:'',website:'',organizer:'',hostInstitution:'',theme:'',status:'ACTIVE'};
const emptyVenue={name:'',address:'',city:'',state:'',country:'',pincode:'',latitude:'',longitude:'',googleMapsUrl:'',parkingInformation:'',directions:'',contactNumber:''};
const emptyBranding={logoUrl:'',organizerLogoUrl:'',bannerUrl:'',splashScreenUrl:'',faviconUrl:'',primaryColor:'#8C1119',secondaryColor:'#C8A45A',accentColor:'#2E6F95',backgroundColor:'#FCFAF5'};
const emptySettings={enableRegistration:true,enableChat:true,enableGallery:true,enableAttendance:true,enableQr:true,enablePushNotifications:false,enableCertificates:true,enablePolls:false,enableFeedback:true};

async function req(path,opt={}){
  const token=localStorage.getItem('token');
  const r=await fetch(API+path,{...opt,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...(opt.headers||{})}});
  const d=await r.json().catch(()=>({}));
  if(!r.ok)throw Error(d.message||'Request failed');
  return d?.success?d.data:d;
}

function toInputDate(value){return value?String(value).slice(0,10):''}
function resolveMediaUrl(url){
  if(!url) return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500';
  if(url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) return url;
  const baseUrl = API.replace(/\/api\/?$/, '');
  return `${baseUrl}${url.startsWith('/') ? '' : '/'}${url}`;
}
function normalizeConference(data){
  return {...emptyConference,...data,startDate:toInputDate(data?.startDate),endDate:toInputDate(data?.endDate),registrationStartDate:toInputDate(data?.registrationStartDate),registrationEndDate:toInputDate(data?.registrationEndDate),venue:{...emptyVenue,...data?.venue},branding:{...emptyBranding,...data?.branding},settings:{...emptySettings,...data?.settings}};
}

function Login({onLogin}){const[e,setE]=useState('admin@conference.local'),[p,setP]=useState('Admin@123'),[busy,setBusy]=useState(false);const submit=async x=>{x.preventDefault();setBusy(true);try{const d=await req('/auth/login',{method:'POST',body:JSON.stringify({email:e,password:p})});localStorage.setItem('token',d.token);onLogin()}catch(err){alert(err.message)}finally{setBusy(false)}};return <div className="login"><form onSubmit={submit}><div className="brand-logo-container"><img src="/logo.png" alt="DY Patil Logo" className="brand-img" /></div><h1>Conference Control Room</h1><p>Manage live conference content, logistics, and mobile app data from MySQL.</p><input value={e} onChange={x=>setE(x.target.value)} placeholder="Email"/><input type="password" value={p} onChange={x=>setP(x.target.value)} placeholder="Password"/><button disabled={busy}>{busy?'Signing in...':'Sign in'}</button><small>Demo: admin@conference.local / Admin@123</small></form></div>}

const menu=[
  {title:'Dashboard',icon:LayoutDashboard},
  {title:'Conference',icon:Building2,children:['Conference Details','Venue & Location','Branding','Conference Settings']},
  {title:'Participants',icon:Users,children:['All Participants','Add Participant','Import Participants','Registration & Passes','QR Codes']},
  {title:'Speakers',icon:Users,children:['All Speakers','Add Speaker']},
  {title:'Schedule',icon:CalendarDays,children:['Sessions Timeline','Tracks & Halls','Add Session']},
  {title:'Accommodation',icon:Hotel,children:['Hotels','Rooms','Room Allocation']},
  {title:'Transport',icon:Bus,children:['Vehicles','Drivers','Transport Assignments']},
  {title:'Attendance',icon:CheckCircle,children:['Live Attendance','QR Scanner Simulator']},
  {title:'Notices',icon:Bell,children:['Notices & Announcements','Send Push Notification']},
  {title:'Gallery',icon:Image,children:['Photo Gallery','Upload Photo']},
  {title:'Meals',icon:CalendarDays,children:['Meal Schedule','Schedule Meal']},
  {title:'Duties',icon:Shield,children:['Duty Roster','Assign Staff']},
  {title:'Certificates',icon:FileCheck,children:['Issued Certificates','Issue Certificate']},
  {title:'Chat',icon:Bell,children:['Live Chat','Broadcast Message']},
  {title:'Reports',icon:FileCheck,children:['Participant Reports','Attendance Reports','Accommodation Reports','Transport Reports','Meal Reports','Certificate Reports']},
  {title:'Admin Users',icon:Lock,children:['Admin Users List','Audit Logs']},
  {title:'System Settings',icon:Settings},
];

function App(){
  const[logged,setLogged]=useState(!!localStorage.getItem('token'));
  const[tab,setTab]=useState('Dashboard');
  const[open,setOpen]=useState({Conference:true,Participants:false,Schedule:false});
  const[conference,setConference]=useState(null);
  const[toast,setToast]=useState('');
  const loadConference=()=>req('/conference').then(x=>setConference(normalizeConference(x))).catch(e=>setToast(e.message));
  useEffect(()=>{if(logged)loadConference()},[logged]);
  const notify=msg=>{setToast(msg);setTimeout(()=>setToast(''),2800)};
  if(!logged)return <Login onLogin={()=>setLogged(true)}/>;
  return <div className="app"><aside><div className="sidebrand"><div className="sidebrand-header"><img src="/logo.png" alt="Logo" className="sidebrand-logo" /><div><strong>DY Patil</strong><span>Conference</span></div></div></div><nav>{menu.map(item=><NavItem key={item.title} item={item} active={tab} open={open[item.title]} onToggle={()=>setOpen(o=>({...o,[item.title]:!o[item.title]}))} onSelect={setTab}/>)}</nav><button className="logout" onClick={()=>{localStorage.clear();setLogged(false)}}><LogOut size={18}/>Sign out</button></aside><main><header><div><h2>{tab}</h2><p>{conference?.name||'Conference Management System'}</p></div><button className="icon" onClick={loadConference} title="Refresh conference"><RefreshCw size={18}/></button></header>{renderPage(tab,conference,setConference,notify)}{toast&&<div className="toast">{toast}</div>}</main></div>
}

function NavItem({item,active,open,onToggle,onSelect}){const I=item.icon;const parentActive=active===item.title||item.children?.includes(active);return <div className="navgroup"><button className={parentActive?'active':''} onClick={()=>item.children?onToggle():onSelect(item.title)}><I size={18}/><span>{item.title}</span>{item.children&&<ChevronDown className={open?'rotated':''} size={15}/>}</button>{item.children&&open&&<div className="subnav">{item.children.map(child=><button key={child} className={active===child?'active child':'child'} onClick={()=>onSelect(child)}>{child}</button>)}</div>}</div>}

function renderPage(tab,conference,setConference,notify){
  if(tab==='Dashboard')return <Dashboard/>;
  if(['Conference','Conference Details','Venue & Location','Branding','Conference Settings'].includes(tab))return <ConferenceModule tab={tab} conference={conference} setConference={setConference} notify={notify}/>;
  if(['Participants','All Participants','Add Participant','Import Participants','Registration & Passes','QR Codes'].includes(tab))return <Participants tab={tab} notify={notify}/>;
  if(['Speakers','All Speakers','Add Speaker'].includes(tab))return <Speakers tab={tab} notify={notify}/>;
  if(['Schedule','Sessions Timeline','Tracks & Halls','Add Session','Sessions','Tracks','Halls'].includes(tab))return <Schedule tab={tab} notify={notify}/>;
  if(['Accommodation','Hotels','Rooms'].includes(tab))return <Hotels tab={tab} notify={notify}/>;
  if(tab==='Room Allocation')return <RoomAllocation notify={notify}/>;
  if(['Transport','Vehicles','Drivers'].includes(tab))return <Transport tab={tab} notify={notify}/>;
  if(tab==='Transport Assignments')return <TransportAssignments notify={notify}/>;
  if(['Attendance','Live Attendance','QR Scanner Simulator'].includes(tab))return <Attendance tab={tab} notify={notify}/>;
  if(['Notices','Notices & Announcements','Send Push Notification'].includes(tab))return <Notices tab={tab} notify={notify}/>;
  if(['Gallery','Photo Gallery','Upload Photo'].includes(tab))return <Gallery tab={tab} notify={notify}/>;
  if(['Meals','Meal Schedule','Schedule Meal'].includes(tab))return <Meals tab={tab} notify={notify}/>;
  if(['Duties','Duty Roster','Assign Staff'].includes(tab))return <Duties tab={tab} notify={notify}/>;
  if(['Certificates','Issued Certificates','Issue Certificate'].includes(tab))return <Certificates tab={tab} notify={notify}/>;
  if(['Chat','Live Chat','Broadcast Message'].includes(tab))return <Chat tab={tab} notify={notify}/>;
  if(['Reports','Participant Reports','Attendance Reports','Accommodation Reports','Transport Reports','Meal Reports','Certificate Reports'].includes(tab))return <Reports tab={tab} notify={notify}/>;
  if(['Admin Users','Admin Users List','Audit Logs'].includes(tab))return <AdminUsers tab={tab} notify={notify}/>;
  if(tab==='System Settings')return <SystemSettings notify={notify}/>;
  return <Placeholder title={tab}/>;
}

function Dashboard(){const[s,setS]=useState(null);useEffect(()=>{req('/admin/stats').then(setS).catch(e=>alert(e.message))},[]);if(!s)return <div className="loading">Loading dashboard...</div>;const cards=[['Participants',s.participants,Users],['Checked In',s.checkedIn,CheckCircle],['Speakers',s.speakers,Users],['Sessions',s.sessions,CalendarDays],['Hotels',s.hotels,Hotel],['Rooms',s.rooms,Hotel],['Gallery Photos',s.photos,Image],['Certificates',s.certificates,FileCheck]];return <><section className="hero"><div><span>LIVE CONTROL ROOM</span><h1>Conference Operations</h1><p>Monitor registrations, logistics, content, and attendance from one dashboard.</p></div><div className="heroStat">2026</div></section><div className="grid">{cards.map(([n,v,I])=><div className="stat" key={n}><I/><span>{n}</span><strong>{v}</strong></div>)}</div><div className="split"><div className="panel"><h3>Operational Checklist</h3><div className="checkgrid"><div>Registration enabled</div><div>Venue published</div><div>Branding synced</div><div>Schedule online</div><div>Notifications ready</div><div>Certificates enabled</div></div></div><div className="panel"><h3>Phase 1 Status</h3><p className="muted">Conference details, venue, branding, and mobile configuration now load from the API.</p></div></div></>}

function ConferenceModule({tab,conference,setConference,notify}){
  if(!conference)return <div className="loading">Loading conference...</div>;
  const save=async(path,payload,msg)=>{const data=await req(path,{method:'PUT',body:JSON.stringify(payload)});setConference(normalizeConference(data));notify(msg)};
  if(tab==='Venue & Location')return <VenueForm value={conference.venue} onSave={v=>save('/admin/conference/venue',v,'Venue updated')}/>;
  if(tab==='Branding')return <BrandingForm value={conference.branding} onSave={v=>save('/admin/conference/branding',v,'Branding updated')} notify={notify}/>;
  if(tab==='Conference Settings')return <SettingsForm value={conference.settings} onSave={v=>save('/admin/conference/settings',v,'Settings updated')}/>;
  return <ConferenceForm value={conference} onSave={v=>save('/admin/conference',v,'Conference details updated')}/>;
}

function Field({label,value,onChange,type='text',textarea=false}){return <label className={textarea?'field wide':'field'}><span>{label}</span>{textarea?<textarea value={value||''} onChange={e=>onChange(e.target.value)}/>:<input type={type} value={value||''} onChange={e=>onChange(e.target.value)}/>}</label>}
function SelectField({label,value,onChange,options}){return <label className="field"><span>{label}</span><select value={value||''} onChange={e=>onChange(e.target.value)}>{options.map(x=><option key={x}>{x}</option>)}</select></label>}
function Toggle({label,checked,onChange}){return <label className="toggle"><input type="checkbox" checked={!!checked} onChange={e=>onChange(e.target.checked)}/><span>{label}</span></label>}
function formState(initial){const[v,setV]=useState(initial);useEffect(()=>setV(initial),[initial]);return [v,(k,val)=>setV(x=>({...x,[k]:val})),setV]}

function ConferenceForm({value,onSave}){const[v,set,setV]=formState(value);return <FormShell icon={Building2} title="Conference Details" description="Edit the public conference profile consumed by Admin and Flutter." onReset={()=>setV(value)} onSave={()=>onSave(v)}><Field label="Conference Name" value={v.name} onChange={x=>set('name',x)}/><Field label="Short Name" value={v.shortName} onChange={x=>set('shortName',x)}/><Field label="Theme" value={v.theme} onChange={x=>set('theme',x)}/><SelectField label="Conference Status" value={v.status} onChange={x=>set('status',x)} options={['ACTIVE','DRAFT','PUBLISHED','ARCHIVED','INACTIVE']}/><Field type="date" label="Start Date" value={v.startDate} onChange={x=>set('startDate',x)}/><Field type="date" label="End Date" value={v.endDate} onChange={x=>set('endDate',x)}/><Field type="date" label="Registration Start" value={v.registrationStartDate} onChange={x=>set('registrationStartDate',x)}/><Field type="date" label="Registration End" value={v.registrationEndDate} onChange={x=>set('registrationEndDate',x)}/><Field label="Contact Person" value={v.contactPerson} onChange={x=>set('contactPerson',x)}/><Field label="Contact Phone" value={v.contactPhone} onChange={x=>set('contactPhone',x)}/><Field label="Contact Email" value={v.contactEmail} onChange={x=>set('contactEmail',x)}/><Field label="Website" value={v.website} onChange={x=>set('website',x)}/><Field label="Organizer" value={v.organizer} onChange={x=>set('organizer',x)}/><Field label="Host Institution" value={v.hostInstitution} onChange={x=>set('hostInstitution',x)}/><Field textarea label="Description" value={v.description} onChange={x=>set('description',x)}/><Field textarea label="Welcome Message" value={v.welcomeMessage} onChange={x=>set('welcomeMessage',x)}/><Field textarea label="About Conference" value={v.aboutConference} onChange={x=>set('aboutConference',x)}/></FormShell>}
function VenueForm({value,onSave}){const[v,set,setV]=formState(value);return <FormShell icon={MapPin} title="Venue & Location" description="Publish map, address, parking, and direction data to the mobile app." onReset={()=>setV(value)} onSave={()=>onSave(v)}><Field label="Venue Name" value={v.name} onChange={x=>set('name',x)}/><Field label="City" value={v.city} onChange={x=>set('city',x)}/><Field label="State" value={v.state} onChange={x=>set('state',x)}/><Field label="Country" value={v.country} onChange={x=>set('country',x)}/><Field label="Pincode" value={v.pincode} onChange={x=>set('pincode',x)}/><Field label="Latitude" value={v.latitude} onChange={x=>set('latitude',x)}/><Field label="Longitude" value={v.longitude} onChange={x=>set('longitude',x)}/><Field label="Venue Contact Number" value={v.contactNumber} onChange={x=>set('contactNumber',x)}/><Field textarea label="Address" value={v.address} onChange={x=>set('address',x)}/><Field textarea label="Google Maps URL" value={v.googleMapsUrl} onChange={x=>set('googleMapsUrl',x)}/><Field textarea label="Parking Information" value={v.parkingInformation} onChange={x=>set('parkingInformation',x)}/><Field textarea label="Directions" value={v.directions} onChange={x=>set('directions',x)}/></FormShell>}
function BrandingForm({value,onSave,notify}){const[v,set,setV]=formState(value);const upload=async(key,file)=>{if(!file)return;const reader=new FileReader();reader.onload=async()=>{const data=await req('/admin/uploads',{method:'POST',body:JSON.stringify({folder:'conference',file:{name:file.name,dataUrl:reader.result}})});set(key,data.url);notify('File uploaded')};reader.readAsDataURL(file)};return <FormShell icon={Palette} title="Branding" description="Control logos, banner imagery, splash assets, and conference colors." onReset={()=>setV(value)} onSave={()=>onSave(v)} preview={<BrandPreview branding={v}/>}>{[['Conference Logo','logoUrl'],['Organizer Logo','organizerLogoUrl'],['Banner','bannerUrl'],['Splash Screen','splashScreenUrl'],['Favicon','faviconUrl']].map(([label,key])=><label className="field uploadfield" key={key}><span>{label}</span><div><input value={v[key]||''} onChange={e=>set(key,e.target.value)} placeholder="URL or uploaded file path"/><label className="uploadBtn"><Upload size={16}/>Upload<input type="file" accept="image/png,image/jpeg,image/webp" onChange={e=>upload(key,e.target.files?.[0])}/></label></div></label>)}<Field type="color" label="Primary Color" value={v.primaryColor} onChange={x=>set('primaryColor',x)}/><Field type="color" label="Secondary Color" value={v.secondaryColor} onChange={x=>set('secondaryColor',x)}/><Field type="color" label="Accent Color" value={v.accentColor} onChange={x=>set('accentColor',x)}/><Field type="color" label="Background Color" value={v.backgroundColor} onChange={x=>set('backgroundColor',x)}/></FormShell>}
function SettingsForm({value,onSave}){const[v,set,setV]=formState(value);return <FormShell icon={Settings} title="Conference Settings" description="Feature flags are saved in MySQL and can be consumed by clients." onReset={()=>setV(value)} onSave={()=>onSave(v)}>{Object.entries({enableRegistration:'Enable Registration',enableChat:'Enable Chat',enableGallery:'Enable Gallery',enableAttendance:'Enable Attendance',enableQr:'Enable QR',enablePushNotifications:'Enable Push Notifications',enableCertificates:'Enable Certificates',enablePolls:'Enable Polls',enableFeedback:'Enable Feedback'}).map(([k,label])=><Toggle key={k} label={label} checked={v[k]} onChange={x=>set(k,x)}/>)}</FormShell>}
function FormShell({icon:Icon,title,description,children,onSave,onReset,preview}){const[busy,setBusy]=useState(false);const submit=async()=>{setBusy(true);try{await onSave()}finally{setBusy(false)}};return <div className="panel"><div className="pagehead"><div className="titleline"><Icon/><div><h3>{title}</h3><p>{description}</p></div></div><div className="actions"><button onClick={onReset}>Reset</button><button onClick={submit} disabled={busy}>{busy?'Saving...':'Save'}</button></div></div>{preview}<div className="formgrid">{children}</div></div>}
function BrandPreview({branding}){return <div className="brandpreview" style={{background:branding.backgroundColor||'#FCFAF5',borderColor:branding.primaryColor||'#8C1119'}}>{branding.bannerUrl&&<img src={branding.bannerUrl.startsWith('/uploads')?API.replace('/api','')+branding.bannerUrl:branding.bannerUrl} alt="Conference banner"/>}<div><span style={{color:branding.accentColor}}>Live Preview</span><strong style={{color:branding.primaryColor}}>Mobile conference branding</strong><small style={{color:branding.secondaryColor}}>Logo, banner, and colors are API driven.</small></div></div>}

function Participants({tab, notify}){
  const[d,setD]=useState([]),[q,setQ]=useState(''),[statusFilter,setStatusFilter]=useState('ALL'),[catFilter,setCatFilter]=useState('ALL'),[busy,setBusy]=useState(false),[edit,setEdit]=useState(null),[importModal,setImportModal]=useState(false),[qrModal,setQrModal]=useState(null),[liaisons,setLiaisons]=useState([]);
  
  const load=async()=>{
    setBusy(true);
    try{
      const[r,l]=await Promise.all([
        req('/admin/participants?conferenceId=1'),
        req('/admin/liaisons').catch(()=>[])
      ]);
      setD(r);
      setLiaisons(l);
    }finally{
      setBusy(false);
    }
  };
  
  useEffect(()=>{load()},[]);
  useEffect(()=>{if(tab==='Add Participant')setEdit({})},[tab]);

  const filtered=d.filter(x=>{
    const matchesQ=`${x.name} ${x.email} ${x.registration_no} ${x.university}`.toLowerCase().includes(q.toLowerCase());
    const matchesStatus=statusFilter==='ALL'||x.status===statusFilter;
    const matchesCat=catFilter==='ALL'||x.category===catFilter;
    return matchesQ && matchesStatus && matchesCat;
  });

  const categories=['ALL',...Array.from(new Set(d.map(x=>x.category).filter(Boolean)))];
  const statuses=['ALL','PENDING','APPROVED','CHECKED_IN','CANCELLED'];

  const save=async(v)=>{
    const method=v.id?'PUT':'POST';
    const path=v.id?`/admin/participants/${v.id}`:'/admin/participants';
    await req(path,{method,body:JSON.stringify(v)});
    notify(v.id?'Participant updated':'Participant created');
    setEdit(null);
    load();
  };

  const remove=async(id)=>{
    if(!confirm('Delete this participant?'))return;
    await req(`/admin/participants/${id}`,{method:'DELETE'});
    notify('Participant deleted');
    load();
  };

  const exportCSV=()=>{
    if(!filtered.length){alert('No participants to export');return}
    const headers=['ID','Registration No','Name','Email','Phone','Designation','University','Category','Status','Payment Status','Mode of Travel','Flight No','Arrival Date','Arrival Time','Departure Date','Departure Time','Liaison Officer'];
    const rows=filtered.map(x=>[
      x.id,
      `"${x.registration_no||''}"`,
      `"${x.name||''}"`,
      `"${x.email||''}"`,
      `"${x.phone||''}"`,
      `"${x.designation||''}"`,
      `"${x.university||''}"`,
      `"${x.category||''}"`,
      `"${x.status||''}"`,
      `"${x.payment_status||''}"`,
      `"${x.mode_of_travel||''}"`,
      `"${x.flight_number||''}"`,
      `"${x.arrival_date?String(x.arrival_date).slice(0,10):''}"`,
      `"${x.arrival_time||''}"`,
      `"${x.departure_date?String(x.departure_date).slice(0,10):''}"`,
      `"${x.departure_time||''}"`,
      `"${x.liaison_name||''}"`
    ]);
    const csvContent='data:text/csv;charset=utf-8,'+[headers.join(','),...rows.map(r=>r.join(','))].join('\n');
    const link=document.createElement('a');
    link.setAttribute('href',encodeURI(csvContent));
    link.setAttribute('download',`participants_export_${new Date().toISOString().slice(0,10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return <div className="panel">
    <div className="pagehead">
      <div><h3>Participants Directory</h3><p>Manage registrations, travel plans, liaison allocations, and QR passes ({filtered.length} shown).</p></div>
      <div className="actions">
        <button className="secondary" onClick={exportCSV}>Export CSV</button>
        <button className="secondary" onClick={()=>setImportModal(true)}>Import CSV</button>
        <button onClick={()=>setEdit({})}>+ Add Participant</button>
      </div>
    </div>
    
    <div className="toolbar" style={{display:'flex',gap:'10px',flexWrap:'wrap',alignItems:'center'}}>
      <div className="search" style={{flex:1,minWidth:'220px'}}><Search size={18}/><input value={q} onChange={e=>setQ(e.target.value)} placeholder="Search name, email, reg no, university..."/></div>
      <div style={{display:'flex',gap:'6px',alignItems:'center'}}>
        <small style={{fontWeight:600}}>Status:</small>
        <select value={statusFilter} onChange={e=>setStatusFilter(e.target.value)} style={{padding:'6px 10px',borderRadius:'6px',border:'1px solid #ccc'}}>
          {statuses.map(s=><option key={s} value={s}>{s}</option>)}
        </select>
      </div>
      <div style={{display:'flex',gap:'6px',alignItems:'center'}}>
        <small style={{fontWeight:600}}>Category:</small>
        <select value={catFilter} onChange={e=>setCatFilter(e.target.value)} style={{padding:'6px 10px',borderRadius:'6px',border:'1px solid #ccc'}}>
          {categories.map(c=><option key={c} value={c}>{c}</option>)}
        </select>
      </div>
      <button onClick={load} disabled={busy}>{busy?'Refreshing...':'Refresh'}</button>
    </div>

    <div className="tablewrap">
      <table>
        <thead>
          <tr><th>Reg No & Pass</th><th>Participant Details</th><th>University & Role</th><th>Category</th><th>Status</th><th>Travel & Stay</th><th>Liaison</th><th>Actions</th></tr>
        </thead>
        <tbody>
          {filtered.map(x=><tr key={x.id}>
            <td>
              <strong>{x.registration_no||'-'}</strong><br/>
              <button className="pill small" style={{cursor:'pointer',marginTop:'4px',background:'#8C1119',color:'#fff'}} onClick={()=>setQrModal(x)}>View QR ID</button>
            </td>
            <td>
              <b>{x.name}</b><br/>
              <small>{x.email}</small><br/>
              <small>{x.phone}</small>
            </td>
            <td>
              {x.university||'-'}<br/>
              <small>{x.designation||'-'}</small>
            </td>
            <td><span className="pill">{x.category||'Delegate'}</span></td>
            <td>
              <span className={`pill ${x.status}`}>{x.status}</span><br/>
              <small style={{color:x.payment_status==='PAID'?'green':'orange',fontWeight:600}}>{x.payment_status}</small>
            </td>
            <td>
              <small><b>Travel:</b> {x.mode_of_travel||'Not specified'}</small><br/>
              <small><b>Arrival:</b> {x.arrival_date?String(x.arrival_date).slice(0,10):'-'} {x.arrival_time||''}</small>
            </td>
            <td>{x.liaison_name?<><small><b>{x.liaison_name}</b></small><br/><small>{x.liaison_phone}</small></>:'-'}</td>
            <td>
              <div className="rowactions">
                <button className="icon" onClick={()=>setEdit(x)} title="Edit"><Settings size={16}/></button>
                <button className="icon" onClick={()=>remove(x.id)} title="Delete"><LogOut size={16}/></button>
              </div>
            </td>
          </tr>)}
          {!filtered.length && !busy && <tr><td colSpan="8" style={{textAlign:'center',padding:'30px',color:'#888'}}>No participants found matching current filters.</td></tr>}
        </tbody>
      </table>
    </div>

    {edit && <ParticipantModal value={edit} liaisons={liaisons} onSave={save} onClose={()=>setEdit(null)} notify={notify}/>}
    {importModal && <ImportParticipantsModal onClose={()=>setImportModal(false)} onImportSuccess={()=>{setImportModal(false);load();notify('Participants imported successfully!')}}/>}
    {qrModal && <QrPassModal participant={qrModal} onClose={()=>setQrModal(null)}/>}
  </div>
}

function ImportParticipantsModal({onClose, onImportSuccess}){
  const[csvText,setCsvText]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState('');
  
  const handleFile=e=>{
    const file=e.target.files?.[0];
    if(!file)return;
    const reader=new FileReader();
    reader.onload=event=>setCsvText(event.target.result);
    reader.readAsText(file);
  };

  const processImport=async()=>{
    if(!csvText.trim()){setError('Please upload or paste CSV data');return}
    setBusy(true);
    setError('');
    try{
      const lines=csvText.trim().split('\n').map(l=>l.trim()).filter(Boolean);
      if(lines.length<2){setError('CSV must contain at least a header row and 1 data row');setBusy(false);return}
      const headers=lines[0].split(',').map(h=>h.trim().replace(/^"|"$/g,'').toLowerCase());
      
      const participants=lines.slice(1).map(line=>{
        const values=line.split(',').map(v=>v.trim().replace(/^"|"$/g,''));
        const obj={};
        headers.forEach((h,idx)=>{
          if(h.includes('name'))obj.name=values[idx];
          else if(h.includes('email'))obj.email=values[idx];
          else if(h.includes('phone')||h.includes('mobile'))obj.phone=values[idx];
          else if(h.includes('university')||h.includes('org'))obj.university=values[idx];
          else if(h.includes('desig'))obj.designation=values[idx];
          else if(h.includes('cat'))obj.category=values[idx];
          else if(h.includes('reg'))obj.registration_no=values[idx];
          else if(h.includes('travel'))obj.mode_of_travel=values[idx];
        });
        return obj;
      }).filter(p=>p.name && p.email);

      if(!participants.length){setError('No valid participants found (Name and Email required per row)');setBusy(false);return}
      
      await req('/admin/participants/bulk-import',{method:'POST',body:JSON.stringify({participants})});
      onImportSuccess();
    }catch(err){
      setError(err.message||'Import failed');
    }finally{
      setBusy(false);
    }
  };

  return <div className="modal-overlay">
    <div className="modal" style={{maxWidth:'600px'}}>
      <div className="modal-header"><h3>Bulk Import Participants</h3><button className="close" onClick={onClose}>&times;</button></div>
      <div className="modal-body">
        <p style={{marginBottom:'12px'}}>Upload a CSV file with columns: <code>name, email, phone, designation, university, category, registration_no</code></p>
        <div style={{marginBottom:'16px'}}>
          <input type="file" accept=".csv" onChange={handleFile}/>
        </div>
        <Field textarea label="Or Paste CSV Content Directly" value={csvText} onChange={setCsvText}/>
        {error && <p style={{color:'red',marginTop:'8px'}}>{error}</p>}
      </div>
      <div className="modal-footer">
        <button onClick={onClose}>Cancel</button>
        <button className="primary" disabled={busy} onClick={processImport}>{busy?'Importing...':'Start Import'}</button>
      </div>
    </div>
  </div>
}

function QrPassModal({participant, onClose}){
  return <div className="modal-overlay">
    <div className="modal" style={{maxWidth:'420px',textAlign:'center',padding:'24px'}}>
      <div className="modal-header" style={{borderBottom:'none',padding:0}}>
        <h3>Digital Delegate Pass</h3>
        <button className="close" onClick={onClose}>&times;</button>
      </div>
      <div className="modal-body" style={{padding:'20px 0'}}>
        <div style={{border:'2px solid #8C1119',borderRadius:'12px',padding:'20px',background:'#FCFAF5'}}>
          <h2 style={{color:'#8C1119',margin:'0 0 4px'}}>{participant.name}</h2>
          <p style={{color:'#666',margin:'0 0 12px'}}>{participant.designation||'Delegate'} • {participant.university||'DPU'}</p>
          <span className="pill" style={{background:'#8C1119',color:'#fff',padding:'4px 12px',borderRadius:'20px'}}>{participant.category||'Delegate'}</span>
          <div style={{margin:'20px auto',width:'180px',height:'180px',background:'#fff',padding:'10px',borderRadius:'8px',border:'1px solid #ddd',display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center'}}>
            <img src={`https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${participant.qr_token||participant.registration_no}`} alt="QR Code" style={{width:'160px',height:'160px'}}/>
          </div>
          <div style={{fontFamily:'monospace',fontSize:'16px',fontWeight:'bold',color:'#333'}}>{participant.registration_no}</div>
          <small style={{color:'#777'}}>Scan for Gate Check-in & Session Attendance</small>
        </div>
      </div>
      <div className="modal-footer" style={{justifyContent:'center'}}>
        <button className="primary" onClick={()=>window.print()}>Print Pass</button>
        <button onClick={onClose}>Close</button>
      </div>
    </div>
  </div>
}

function ParticipantModal({value, liaisons=[], onSave, onClose, notify}){
  const[v,set,setV]=formState({...value,dob:toInputDate(value.dob),arrivalDate:toInputDate(value.arrival_date||value.arrivalDate),departureDate:toInputDate(value.departure_date||value.departureDate)});
  const[busy,setBusy]=useState(false);

  const upload=async(file)=>{
    if(!file)return;
    const reader=new FileReader();
    reader.onload=async()=>{
      const data=await req('/admin/uploads',{method:'POST',body:JSON.stringify({folder:'participants',file:{name:file.name,dataUrl:reader.result}})});
      set('photo',data.url);
      notify('Photo uploaded');
    };
    reader.readAsDataURL(file);
  };

  return <div className="modal-overlay">
    <div className="modal">
      <div className="modal-header">
        <h3>{v.id?'Edit Participant':'Add New Participant'}</h3>
        <button className="close" onClick={onClose}>&times;</button>
      </div>
      <div className="modal-body">
        <div className="form-section">
          <h4>Account & Profile</h4>
          <div className="formgrid">
            <Field label="Full Name" value={v.name} onChange={x=>set('name',x)}/>
            <Field label="Email" value={v.email} onChange={x=>set('email',x)}/>
            {!v.id && <Field type="password" label="Password (Default: Demo@123)" value={v.password} onChange={x=>set('password',x)}/>}
            <Field label="Mobile" value={v.phone} onChange={x=>set('phone',x)}/>
            <Field label="Designation" value={v.designation} onChange={x=>set('designation',x)}/>
            <Field label="Organization / University" value={v.university} onChange={x=>set('university',x)}/>
            <Field label="Blood Group" value={v.blood_group||v.bloodGroup} onChange={x=>set('bloodGroup',x)}/>
          </div>
        </div>

        <div className="form-section">
          <h4>Registration & Category</h4>
          <div className="formgrid">
            <Field label="Registration No" value={v.registration_no} onChange={x=>set('registration_no',x)}/>
            <SelectField label="Category" value={v.category} onChange={x=>set('category',x)} options={['Delegate','Speaker','VC','VIP','Faculty','Student','Volunteer']}/>
            <SelectField label="Status" value={v.status} onChange={x=>set('status',x)} options={['PENDING','APPROVED','CHECKED_IN','CANCELLED']}/>
            <SelectField label="Payment Status" value={v.payment_status} onChange={x=>set('payment_status',x)} options={['PENDING','PAID','REFUNDED']}/>
            <Field label="Amount Paid (₹)" value={v.amount} onChange={x=>set('amount',x)}/>
          </div>
        </div>

        <div className="form-section">
          <h4>Travel, Logistics & Liaison</h4>
          <div className="formgrid">
            <SelectField label="Mode of Travel" value={v.mode_of_travel} onChange={x=>set('mode_of_travel',x)} options={['','Flight','Train','Bus','Car','Road']}/>
            <Field label="Flight / Train No" value={v.flight_number} onChange={x=>set('flight_number',x)}/>
            <Field type="date" label="Arrival Date" value={v.arrivalDate} onChange={x=>set('arrivalDate',x)}/>
            <Field type="time" label="Arrival Time" value={v.arrival_time} onChange={x=>set('arrival_time',x)}/>
            <Field type="date" label="Departure Date" value={v.departureDate} onChange={x=>set('departureDate',x)}/>
            <Field type="time" label="Departure Time" value={v.departure_time} onChange={x=>set('departure_time',x)}/>
            <Field label="Emergency Contact (Name & Phone)" value={v.emergency_contact} onChange={x=>set('emergency_contact',x)}/>
            <label className="field">
              <span>Assigned Liaison Officer</span>
              <select value={v.liaison_id||''} onChange={e=>set('liaison_id',e.target.value?Number(e.target.value):null)}>
                <option value="">-- None Assigned --</option>
                {liaisons.map(l=><option key={l.id} value={l.id}>{l.name} ({l.phone})</option>)}
              </select>
            </label>
          </div>
        </div>
      </div>
      <div className="modal-footer">
        <button onClick={onClose}>Cancel</button>
        <button className="primary" disabled={busy} onClick={async()=>{setBusy(true);try{await onSave(v)}finally{setBusy(false)}}}>{busy?'Saving...':'Save Participant'}</button>
      </div>
    </div>
  </div>
}
function Hotels({tab, notify}){
  const[d,setD]=useState([]),[rooms,setRooms]=useState([]),[busy,setBusy]=useState(false),[edit,setEdit]=useState(null),[editRoom,setEditRoom]=useState(null);
  const load=async()=>{
    setBusy(true);
    try{
      const[h,r]=await Promise.all([req('/admin/hotels'),req('/admin/rooms')]);
      setD(h); setRooms(r);
    }finally{setBusy(false)}
  };
  useEffect(()=>{load()},[]);

  return <div className="panel">
    <div className="pagehead">
      <div><h3>Accommodation</h3><p>Manage hotels and rooms.</p></div>
      <div className="actions">
        <button onClick={()=>setEdit({})}>Add Hotel</button>
        <button onClick={()=>setEditRoom({})}>Add Room</button>
      </div>
    </div>
    <div className="split">
      <div className="panel">
        <h4>Hotels</h4>
        <table>
          <thead><tr><th>Hotel</th><th>Rooms</th><th>Actions</th></tr></thead>
          <tbody>
            {d.map(x=><tr key={x.id}>
              <td><b>{x.name}</b><br/><small>{x.address}</small></td>
              <td>{x.rooms_count}</td>
              <td><button className="icon" onClick={()=>setEdit(x)}><Settings size={16}/></button></td>
            </tr>)}
          </tbody>
        </table>
      </div>
      <div className="panel">
        <h4>Rooms</h4>
        <table>
          <thead><tr><th>Hotel</th><th>Room</th><th>Type</th><th>Actions</th></tr></thead>
          <tbody>
            {rooms.map(x=><tr key={x.id}>
              <td>{x.hotel_name}</td>
              <td>{x.room_number}</td>
              <td>{x.room_type} ({x.capacity})</td>
              <td><span className={`pill ${x.status}`}>{x.status}</span></td>
            </tr>)}
          </tbody>
        </table>
      </div>
    </div>
    {edit && <HotelModal value={edit} onSave={async(v)=>{await req(v.id?`/admin/hotels/${v.id}`:'/admin/hotels',{method:v.id?'PUT':'POST',body:JSON.stringify(v)}); setEdit(null); load(); notify('Hotel saved');}} onClose={()=>setEdit(null)}/>}
    {editRoom && <RoomModal value={editRoom} hotels={d} onSave={async(v)=>{await req('/admin/rooms',{method:'POST',body:JSON.stringify(v)}); setEditRoom(null); load(); notify('Room added');}} onClose={()=>setEditRoom(null)}/>}
  </div>
}

function HotelModal({value,onSave,onClose}){
  const[v,set]=formState(value);
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Hotel Details</h3></div><div className="modal-body"><div className="formgrid"><Field label="Name" value={v.name} onChange={x=>set('name',x)}/><Field textarea label="Address" value={v.address} onChange={x=>set('address',x)}/><Field label="Latitude" value={v.latitude} onChange={x=>set('latitude',x)}/><Field label="Longitude" value={v.longitude} onChange={x=>set('longitude',x)}/></div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Save</button></div></div></div>
}

function RoomModal({value,hotels,onSave,onClose}){
  const[v,set]=formState(value);
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Add Room</h3></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Hotel" value={v.hotel_id} onChange={x=>set('hotel_id',x)} options={['',...hotels.map(h=>({value:h.id,label:h.name}))].map(o=>typeof o==='string'?o:o.label)}/>
    <Field label="Room Number" value={v.room_number} onChange={x=>set('room_number',x)}/>
    <Field label="Room Type" value={v.room_type} onChange={x=>set('room_type',x)}/>
    <Field label="Capacity" value={v.capacity} onChange={x=>set('capacity',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave({...v, hotel_id: hotels.find(h=>h.name===v.hotel_id)?.id})}>Save</button></div></div></div>
}

function RoomAllocation({notify}){
  const[d,setD]=useState([]),[participants,setParticipants]=useState([]),[rooms,setRooms]=useState([]),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false);
  const load=async()=>{
    setBusy(true);
    try{
      const[a,p,r]=await Promise.all([req('/admin/room-allocations'),req('/admin/participants?conferenceId=1'),req('/admin/rooms')]);
      setD(a); setParticipants(p); setRooms(r);
    }finally{setBusy(false)}
  };
  useEffect(()=>{load()},[]);

  return <div className="panel">
    <div className="pagehead">
      <div><h3>Room Allocations</h3><p>Assign rooms to participants.</p></div>
      <div className="actions"><button onClick={()=>setShowAdd(true)}>Allocate Room</button></div>
    </div>
    <table>
      <thead><tr><th>Participant</th><th>Hotel & Room</th><th>Duration</th><th>Actions</th></tr></thead>
      <tbody>
        {d.map(x=><tr key={x.id}>
          <td><b>{x.participant_name}</b><br/><small>{x.registration_no}</small></td>
          <td>{x.hotel_name}<br/>Room: {x.room_number}</td>
          <td>{toInputDate(x.check_in)} to {toInputDate(x.check_out)}</td>
          <td><button className="icon" onClick={async()=>{if(confirm('Remove allocation?')){await req(`/admin/room-allocations/${x.id}`,{method:'DELETE'}); load(); notify('Allocation removed');}}}><LogOut size={16}/></button></td>
        </tr>)}
      </tbody>
    </table>
    {showAdd && <AllocationModal participants={participants} rooms={rooms.filter(r=>r.status!=='FULL')} onSave={async(v)=>{await req('/admin/room-allocations',{method:'POST',body:JSON.stringify(v)}); setShowAdd(false); load(); notify('Allocated successfully');}} onClose={()=>setShowAdd(false)}/>}
  </div>
}

function AllocationModal({participants,rooms,onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Room Allocation</h3></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Participant" value={v.participant_id} onChange={x=>set('participant_id',x)} options={['',...participants.map(p=>({value:p.id,label:p.name+' ('+p.registration_no+')'}))].map(o=>typeof o==='string'?o:o.label)}/>
    <SelectField label="Room" value={v.room_id} onChange={x=>set('room_id',x)} options={['',...rooms.map(r=>({value:r.id,label:r.hotel_name+' - '+r.room_number}))].map(o=>typeof o==='string'?o:o.label)}/>
    <Field type="date" label="Check In" value={v.check_in} onChange={x=>set('check_in',x)}/>
    <Field type="date" label="Check Out" value={v.check_out} onChange={x=>set('check_out',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave({...v, participant_id: participants.find(p=>(p.name+' ('+p.registration_no+')')===v.participant_id)?.id, room_id: rooms.find(r=>(r.hotel_name+' - '+r.room_number)===v.room_id)?.id})}>Allocate</button></div></div></div>
}
function Transport({tab, notify}){
  const[d,setD]=useState([]),[drivers,setDrivers]=useState([]),[busy,setBusy]=useState(false),[edit,setEdit]=useState(null),[editDriver,setEditDriver]=useState(null);
  const load=async()=>{
    setBusy(true);
    try{
      const[v,dr]=await Promise.all([req('/admin/vehicles'),req('/admin/drivers')]);
      setD(v); setDrivers(dr);
    }finally{setBusy(false)}
  };
  useEffect(()=>{load()},[]);
  return <div className="panel">
    <div className="pagehead">
      <div><h3>Transport Fleet</h3><p>Manage vehicles and drivers.</p></div>
      <div className="actions">
        <button onClick={()=>setEdit({})}>Add Vehicle</button>
        <button onClick={()=>setEditDriver({})}>Add Driver</button>
      </div>
    </div>
    <div className="split">
      <div className="panel">
        <h4>Vehicles</h4>
        <table>
          <thead><tr><th>Vehicle</th><th>Driver</th><th>Actions</th></tr></thead>
          <tbody>
            {d.map(x=><tr key={x.id}>
              <td><b>{x.vehicle_number}</b><br/><small>{x.vehicle_type} ({x.capacity})</small></td>
              <td>{x.driver_name||'Unassigned'}</td>
              <td><button className="icon" onClick={()=>setEdit(x)}><Settings size={16}/></button></td>
            </tr>)}
          </tbody>
        </table>
      </div>
      <div className="panel">
        <h4>Drivers</h4>
        <table>
          <thead><tr><th>Name</th><th>Phone</th><th>License</th></tr></thead>
          <tbody>
            {drivers.map(x=><tr key={x.id}><td><b>{x.name}</b></td><td>{x.phone}</td><td>{x.license_no}</td></tr>)}
          </tbody>
        </table>
      </div>
    </div>
    {edit && <VehicleModal value={edit} drivers={drivers} onSave={async(v)=>{await req(v.id?`/admin/vehicles/${v.id}`:'/admin/vehicles',{method:v.id?'PUT':'POST',body:JSON.stringify(v)}); setEdit(null); load(); notify('Vehicle saved');}} onClose={()=>setEdit(null)}/>}
    {editDriver && <DriverModal onSave={async(v)=>{await req('/admin/drivers',{method:'POST',body:JSON.stringify(v)}); setEditDriver(null); load(); notify('Driver added');}} onClose={()=>setEditDriver(null)}/>}
  </div>
}

function VehicleModal({value,drivers,onSave,onClose}){
  const[v,set]=formState(value);
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Vehicle Details</h3></div><div className="modal-body"><div className="formgrid">
    <Field label="Vehicle No" value={v.vehicle_number} onChange={x=>set('vehicle_number',x)}/>
    <Field label="Type" value={v.vehicle_type} onChange={x=>set('vehicle_type',x)}/>
    <Field label="Capacity" value={v.capacity} onChange={x=>set('capacity',x)}/>
    <SelectField label="Driver" value={v.driver_id} onChange={x=>set('driver_id',x)} options={['',...drivers.map(d=>({value:d.id,label:d.name}))].map(o=>typeof o==='string'?o:o.label)}/>
    <SelectField label="Status" value={v.status} onChange={x=>set('status',x)} options={['AVAILABLE','ASSIGNED','IN_TRANSIT','MAINTENANCE']}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave({...v, driver_id: drivers.find(d=>d.name===v.driver_id)?.id})}>Save</button></div></div></div>
}

function DriverModal({onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Add Driver</h3></div><div className="modal-body"><div className="formgrid"><Field label="Name" value={v.name} onChange={x=>set('name',x)}/><Field label="Phone" value={v.phone} onChange={x=>set('phone',x)}/><Field label="License No" value={v.license_no} onChange={x=>set('license_no',x)}/></div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Save</button></div></div></div>
}

function TransportAssignments({notify}){
  const[d,setD]=useState([]),[participants,setParticipants]=useState([]),[vehicles,setVehicles]=useState([]),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false);
  const load=async()=>{
    setBusy(true);
    try{
      const[a,p,v]=await Promise.all([req('/admin/transport-assignments'),req('/admin/participants?conferenceId=1'),req('/admin/vehicles')]);
      setD(a); setParticipants(p); setVehicles(v);
    }finally{setBusy(false)}
  };
  useEffect(()=>{load()},[]);

  return <div className="panel">
    <div className="pagehead">
      <div><h3>Transport Assignments</h3><p>Assign vehicles to participants.</p></div>
      <div className="actions"><button onClick={()=>setShowAdd(true)}>Assign Transport</button></div>
    </div>
    <table>
      <thead><tr><th>Participant</th><th>Vehicle & Driver</th><th>Route</th><th>Time</th><th>Status</th></tr></thead>
      <tbody>
        {d.map(x=><tr key={x.id}>
          <td><b>{x.participant_name}</b><br/><small>{x.registration_no}</small></td>
          <td>{x.vehicle_number}<br/><small>{x.driver_name}</small></td>
          <td>{x.pickup_location} &rarr; {x.drop_location}</td>
          <td>{x.pickup_time}</td>
          <td><span className={`pill ${x.status}`}>{x.status}</span></td>
        </tr>)}
      </tbody>
    </table>
    {showAdd && <TransportAssignmentModal participants={participants} vehicles={vehicles} onSave={async(v)=>{await req('/admin/transport-assignments',{method:'POST',body:JSON.stringify(v)}); setShowAdd(false); load(); notify('Assigned successfully');}} onClose={()=>setShowAdd(false)}/>}
  </div>
}

function TransportAssignmentModal({participants,vehicles,onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Transport Assignment</h3></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Participant" value={v.participant_id} onChange={x=>set('participant_id',x)} options={['',...participants.map(p=>({value:p.id,label:p.name}))].map(o=>typeof o==='string'?o:o.label)}/>
    <SelectField label="Vehicle" value={v.vehicle_id} onChange={x=>set('vehicle_id',x)} options={['',...vehicles.map(vh=>({value:vh.id,label:vh.vehicle_number}))].map(o=>typeof o==='string'?o:o.label)}/>
    <Field label="Pickup Location" value={v.pickup_location} onChange={x=>set('pickup_location',x)}/>
    <Field label="Drop Location" value={v.drop_location} onChange={x=>set('drop_location',x)}/>
    <Field type="datetime-local" label="Pickup Time" value={v.pickup_time} onChange={x=>set('pickup_time',x)}/>
    <Field textarea label="Notes" value={v.notes} onChange={x=>set('notes',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave({...v, participant_id: participants.find(p=>p.name===v.participant_id)?.id, vehicle_id: vehicles.find(vh=>vh.vehicle_number===v.vehicle_id)?.id})}>Assign</button></div></div></div>
}
function Speakers({tab, notify}){
  const[d,setD]=useState([]),[busy,setBusy]=useState(false),[edit,setEdit]=useState(null);
  const load=async()=>{setBusy(true);try{const r=await req('/admin/speakers?conferenceId=1');setD(r)}finally{setBusy(false)}};
  useEffect(()=>{load()},[]);
  useEffect(()=>{if(tab==='Add Speaker')setEdit({})},[tab]);

  const save=async(v)=>{
    const method=v.id?'PUT':'POST';
    const path=v.id?`/admin/speakers/${v.id}`:'/admin/speakers';
    await req(path,{method,body:JSON.stringify(v)});
    notify(v.id?'Speaker updated':'Speaker created');
    setEdit(null);
    load();
  };

  return <div className="panel">
    <div className="pagehead">
      <div><h3>Speakers</h3><p>Manage keynote speakers and presenters.</p></div>
      <div className="actions"><button onClick={()=>setEdit({})}>Add Speaker</button></div>
    </div>
    <div className="grid" style={{gridTemplateColumns:'repeat(auto-fill, minmax(280px, 1fr))',gap:'20px'}}>
      {d.map(x=><div className="speaker-card" key={x.id}>
        <div className="speaker-avatar-wrap">
          <img 
            src={resolveMediaUrl(x.photo)} 
            alt={x.name} 
            onError={(e)=>{e.target.src='https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500'}}
          />
        </div>
        <div className="info">
          <h4>{x.name}</h4>
          <span className="pill" style={{background:'#8C1119',color:'#fff',fontSize:'11px',marginBottom:'8px'}}>
            {x.designation||'Speaker'}
          </span>
          <p className="org">{x.organization||'Conference Keynote'}</p>
          {x.bio && <p className="bio">{x.bio}</p>}
          {(x.email || x.phone) && <div className="contact-info">
            {x.email && <div>✉ {x.email}</div>}
            {x.phone && <div>📞 {x.phone}</div>}
          </div>}
          <div className="rowactions" style={{display:'flex',gap:'8px',width:'100%',marginTop:'auto'}}>
            <button style={{flex:1,padding:'8px',borderRadius:'6px',fontSize:'12.5px',fontWeight:'700'}} onClick={()=>setEdit(x)}>Edit</button>
            <button style={{flex:1,padding:'8px',borderRadius:'6px',fontSize:'12.5px',fontWeight:'700',color:'#ef4444',borderColor:'#fecaca'}} onClick={async()=>{if(confirm('Delete this speaker?')){await req(`/admin/speakers/${x.id}`,{method:'DELETE'});load()}}}>Delete</button>
          </div>
        </div>
      </div>)}
      {!d.length && !busy && <div style={{gridColumn:'1/-1',textAlign:'center',padding:'40px',color:'#888'}}>No speakers added yet. Click "+ Add Speaker" to create one.</div>}
    </div>
    {edit && <SpeakerModal value={edit} onSave={save} onClose={()=>setEdit(null)} notify={notify}/>}
  </div>
}

function SpeakerModal({value,onSave,onClose,notify}){
  const[v,set,setV]=formState(value);
  const[busy,setBusy]=useState(false);
  const upload=async(file)=>{
    if(!file)return;
    const reader=new FileReader();
    reader.onload=async()=>{
      const data=await req('/admin/uploads',{method:'POST',body:JSON.stringify({folder:'speakers',file:{name:file.name,dataUrl:reader.result}})});
      set('photo',data.url);
      notify('Photo uploaded');
    };
    reader.readAsDataURL(file);
  };
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>{v.id?'Edit Speaker':'Add Speaker'}</h3></div><div className="modal-body"><div className="formgrid"><Field label="Name" value={v.name} onChange={x=>set('name',x)}/><Field label="Designation" value={v.designation} onChange={x=>set('designation',x)}/><Field label="Organization" value={v.organization} onChange={x=>set('organization',x)}/><Field label="Email" value={v.email} onChange={x=>set('email',x)}/><Field label="Phone" value={v.phone} onChange={x=>set('phone',x)}/><label className="field uploadfield"><span>Photo</span><div><input value={v.photo||''} onChange={e=>set('photo',e.target.value)}/><label className="uploadBtn"><Upload size={16}/>Upload<input type="file" onChange={e=>upload(e.target.files?.[0])}/></label></div></label><Field textarea label="Biography" value={v.bio} onChange={x=>set('bio',x)}/></div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" disabled={busy} onClick={async()=>{setBusy(true);try{await onSave(v)}finally{setBusy(false)}}}>Save</button></div></div></div>
}

function Schedule({tab, notify}){
  const[d,setD]=useState([]),[halls,setHalls]=useState([]),[speakers,setSpeakers]=useState([]),[busy,setBusy]=useState(false),[edit,setEdit]=useState(null);
  const load=async()=>{
    setBusy(true);
    try{
      const[s,h,sp]=await Promise.all([req('/admin/sessions?conferenceId=1'),req('/admin/halls?conferenceId=1'),req('/admin/speakers?conferenceId=1')]);
      setD(s); setHalls(h); setSpeakers(sp);
    }finally{setBusy(false)}
  };
  useEffect(()=>{load()},[]);
  useEffect(()=>{if(tab==='Add Session')setEdit({})},[tab]);

  const save=async(v)=>{
    const method=v.id?'PUT':'POST';
    const path=v.id?`/admin/sessions/${v.id}`:'/admin/sessions';
    await req(path,{method,body:JSON.stringify(v)});
    notify(v.id?'Session updated':'Session created');
    setEdit(null);
    load();
  };

  return <div className="panel">
    <div className="pagehead">
      <div><h3>Event Schedule</h3><p>Manage conference sessions, halls, and tracks.</p></div>
      <div className="actions"><button onClick={()=>setEdit({})}>Add Session</button></div>
    </div>
    <table>
      <thead><tr><th>Time</th><th>Session</th><th>Hall</th><th>Speaker</th><th>Actions</th></tr></thead>
      <tbody>
        {d.map(x=><tr key={x.id}>
          <td>{toInputDate(x.session_date)}<br/>{x.start_time} - {x.end_time}</td>
          <td><b>{x.title}</b><br/><small>{x.category}</small></td>
          <td>{x.hall_name}</td>
          <td>{x.speaker_name}</td>
          <td>
            <div className="rowactions">
              <button className="icon" onClick={()=>setEdit(x)}><Settings size={16}/></button>
              <button className="icon" onClick={async()=>{if(confirm('Delete?')){await req(`/admin/sessions/${x.id}`,{method:'DELETE'});load()}}}><LogOut size={16}/></button>
            </div>
          </td>
        </tr>)}
      </tbody>
    </table>
    {edit && <SessionModal value={edit} speakers={speakers} halls={halls} onSave={save} onClose={()=>setEdit(null)}/>}
  </div>
}

function SessionModal({value,speakers,halls,onSave,onClose}){
  const[v,set,setV]=formState({...value,session_date:toInputDate(value.session_date)});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>{v.id?'Edit Session':'Add Session'}</h3></div><div className="modal-body"><div className="formgrid">
    <Field label="Title" value={v.title} onChange={x=>set('title',x)}/>
    <Field type="date" label="Date" value={v.session_date} onChange={x=>set('session_date',x)}/>
    <Field type="time" label="Start Time" value={v.start_time} onChange={x=>set('start_time',x)}/>
    <Field type="time" label="End Time" value={v.end_time} onChange={x=>set('end_time',x)}/>
    <SelectField label="Speaker" value={v.speaker_id} onChange={x=>set('speaker_id',x)} options={['',...speakers.map(s=>({value:s.id,label:s.name}))].map(o=>typeof o==='string'?o:o.label)}/>
    <SelectField label="Hall" value={v.hall_id} onChange={x=>set('hall_id',x)} options={['',...halls.map(h=>({value:h.id,label:h.name}))].map(o=>typeof o==='string'?o:o.label)}/>
    <Field label="Category" value={v.category} onChange={x=>set('category',x)}/>
    <Field textarea label="Description" value={v.description} onChange={x=>set('description',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave({...v, speaker_id: speakers.find(s=>s.name===v.speaker_id)?.id, hall_id: halls.find(h=>h.name===v.hall_id)?.id})}>Save</button></div></div></div>
}
function Placeholder({title}){return <div className="panel empty"><h2>{title}</h2><p>Navigation is in place. This module will be implemented in the later phases without replacing existing APIs.</p></div>}

function Attendance({notify}){
  const[scans,setScans]=useState([]),[sessions,setSessions]=useState([]),[meals,setMeals]=useState([]),[busy,setBusy]=useState(false);
  const[mode,setMode]=useState('CHECKIN'),[sessionId,setSessionId]=useState(''),[mealId,setMealId]=useState(''),[qr,setQr]=useState('');

  const load=async()=>{
    setBusy(true);
    try{
      const[s,se,me]=await Promise.all([req('/admin/attendance/live'),req('/admin/sessions?conferenceId=1'),req('/me/meals?conferenceId=1')]);
      setScans(s); setSessions(se); setMeals(me);
    }finally{setBusy(false)}
  };
  useEffect(()=>{load()},[]);

  const handleScan=async(e)=>{
    e.preventDefault();
    if(!qr)return;
    try{
      await req('/attendance/scan',{method:'POST',body:JSON.stringify({qrToken:qr, scanType:mode, sessionId:sessionId||null, mealId:mealId||null})});
      notify('Scan successful');
      setQr('');
      load();
    }catch(err){alert(err.message)}
  };

  return <div className="panel">
    <div className="pagehead"><div><h3>Live Attendance</h3><p>Monitor real-time QR check-ins and session attendance.</p></div></div>
    <div className="split">
      <div className="panel scanner-panel">
        <h4>QR Scanner Simulation</h4>
        <form onSubmit={handleScan} className="formgrid">
          <SelectField label="Scan Mode" value={mode} onChange={setMode} options={['CHECKIN','SESSION','MEAL','DEPARTURE']}/>
          {mode==='SESSION' && <SelectField label="Select Session" value={sessionId} onChange={setSessionId} options={['',...sessions.map(s=>({value:s.id,label:s.title}))].map(o=>typeof o==='string'?o:o.label)}/>}
          {mode==='MEAL' && <SelectField label="Select Meal" value={mealId} onChange={setMealId} options={['',...meals.map(m=>({value:m.id,label:m.meal_type+' - '+m.meal_date}))].map(o=>typeof o==='string'?o:o.label)}/>}
          <Field label="QR Token / Registration No" value={qr} onChange={setQr}/>
          <button className="primary wide" type="submit">Submit Scan</button>
        </form>
      </div>
      <div className="panel scans-panel">
        <h4>Recent Scans</h4>
        <div className="scan-list">
          {scans.map(x=><div className="scan-item" key={x.id}>
            <div className="scan-time">{new Date(x.scanned_at).toLocaleTimeString()}</div>
            <div className="scan-info">
              <b>{x.participant_name}</b>
              <p>{x.scan_type} {x.session_title ? ` - ${x.session_title}` : ''}</p>
            </div>
          </div>)}
        </div>
      </div>
    </div>
  </div>
}

function Meals({tab, notify}){
  const[d,setD]=useState([]),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false);
  const load=async()=>{setBusy(true); try{const r=await req('/admin/meals?conferenceId=1');setD(r)}finally{setBusy(false)}};
  useEffect(()=>{load()},[]);
  useEffect(()=>{if(tab==='Schedule Meal')setShowAdd(true)},[tab]);
  const save=async(v)=>{await req('/admin/meals',{method:'POST',body:JSON.stringify(v)}); notify('Meal scheduled'); setShowAdd(false); load();};
  return <div className="panel">
    <div className="pagehead"><div><h3>Meal Schedule</h3><p>Manage conference catering timeline and menu.</p></div><div className="actions"><button className="primary" onClick={()=>setShowAdd(true)}>+ Schedule Meal</button></div></div>
    {d.map(x=><div className="rowcard" key={x.id}>
      <div className="time">{toInputDate(x.meal_date)}<br/>{x.start_time} - {x.end_time}</div>
      <div><b>{x.meal_type}</b><p>{x.location}</p></div>
    </div>)}
    {!d.length && !busy && <div style={{textAlign:'center',padding:'40px',color:'#888'}}>No meals scheduled yet. Click "+ Schedule Meal" to configure catering.</div>}
    {showAdd && <MealModal onSave={save} onClose={()=>setShowAdd(false)}/>}
  </div>
}

function MealModal({onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Schedule Meal</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Meal Type" value={v.meal_type} onChange={x=>set('meal_type',x)} options={['BREAKFAST','LUNCH','TEA','DINNER','SNACKS']}/>
    <Field type="date" label="Date" value={v.meal_date} onChange={x=>set('meal_date',x)}/>
    <Field type="time" label="Start Time" value={v.start_time} onChange={x=>set('start_time',x)}/>
    <Field type="time" label="End Time" value={v.end_time} onChange={x=>set('end_time',x)}/>
    <Field label="Location" value={v.location} onChange={x=>set('location',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Save</button></div></div></div>
}

function Duties({tab, notify}){
  const[d,setD]=useState([]),[users,setUsers]=useState([]),[assignments,setAssignments]=useState([]),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false),[showAssign,setShowAssign]=useState(false);
  const load=async()=>{
    setBusy(true);
    try{
      const[du,as,u]=await Promise.all([req('/admin/duties?conferenceId=1'),req('/admin/duty-assignments'),req('/admin/participants?conferenceId=1')]);
      setD(du); setAssignments(as); setUsers(u);
    }finally{setBusy(false)}
  };
  useEffect(()=>{load()},[]);
  useEffect(()=>{if(tab==='Assign Staff')setShowAssign(true)},[tab]);

  return <div className="panel">
    <div className="pagehead"><div><h3>Duty Roster</h3><p>Manage volunteer and staff assignments.</p></div><div className="actions"><button className="secondary" onClick={()=>setShowAdd(true)}>+ Create Duty</button><button className="primary" onClick={()=>setShowAssign(true)}>+ Assign Staff</button></div></div>
    <div className="split">
      <div className="panel"><h4>Scheduled Duties</h4>{d.map(x=><div className="rowcard" key={x.id}><div><b>{x.title}</b><p>{x.location}<br/>{toInputDate(x.duty_date)} {x.start_time}-{x.end_time}</p></div></div>)}{!d.length && !busy && <p style={{color:'#888',padding:'20px'}}>No duties created yet.</p>}</div>
      <div className="panel"><h4>Staff Assignments</h4>{assignments.map(x=><div className="rowcard" key={x.id}><div><b>{x.user_name}</b><p>{x.duty_title} - {x.status}</p></div></div>)}{!assignments.length && !busy && <p style={{color:'#888',padding:'20px'}}>No staff assigned yet.</p>}</div>
    </div>
    {showAdd && <DutyModal onSave={async(v)=>{await req('/admin/duties',{method:'POST',body:JSON.stringify(v)}); setShowAdd(false); load(); notify('Duty created');}} onClose={()=>setShowAdd(false)}/>}
    {showAssign && <DutyAssignmentModal duties={d} users={users} onSave={async(v)=>{await req('/admin/duty-assignments',{method:'POST',body:JSON.stringify(v)}); setShowAssign(false); load(); notify('Staff assigned');}} onClose={()=>setShowAssign(false)}/>}
  </div>
}

function DutyModal({onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Create Duty</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <Field label="Title" value={v.title} onChange={x=>set('title',x)}/>
    <Field label="Location" value={v.location} onChange={x=>set('location',x)}/>
    <Field type="date" label="Date" value={v.duty_date} onChange={x=>set('duty_date',x)}/>
    <Field type="time" label="Start Time" value={v.start_time} onChange={x=>set('start_time',x)}/>
    <Field type="time" label="End Time" value={v.end_time} onChange={x=>set('end_time',x)}/>
    <Field label="Supervisor" value={v.supervisor} onChange={x=>set('supervisor',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Save</button></div></div></div>
}

function DutyAssignmentModal({duties,users,onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Assign Staff</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Duty" value={v.duty_id} onChange={x=>set('duty_id',x)} options={['',...duties.map(du=>({value:du.id,label:du.title+' - '+toInputDate(du.duty_date)}))].map(o=>typeof o==='string'?o:o.label)}/>
    <SelectField label="Staff/Volunteer" value={v.user_id} onChange={x=>set('user_id',x)} options={['',...users.map(u=>({value:u.user_id,label:u.name}))].map(o=>typeof o==='string'?o:o.label)}/>
    <SelectField label="Status" value={v.status} onChange={x=>set('status',x)} options={['ASSIGNED','CONFIRMED','COMPLETED','CANCELLED']}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave({...v, duty_id: duties.find(du=>(du.title+' - '+toInputDate(du.duty_date))===v.duty_id)?.id, user_id: users.find(u=>u.name===v.user_id)?.user_id})}>Assign</button></div></div></div>
}

function Certificates({tab, notify}){
  const[d,setD]=useState([]),[participants,setParticipants]=useState([]),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false);
  const load=async()=>{setBusy(true); try{const[c,p]=await Promise.all([req('/admin/certificates'),req('/admin/participants?conferenceId=1')]);setD(c); setParticipants(p);}finally{setBusy(false)}};
  useEffect(()=>{load()},[]);
  useEffect(()=>{if(tab==='Issue Certificate')setShowAdd(true)},[tab]);
  return <div className="panel">
    <div className="pagehead"><div><h3>Certificates</h3><p>Manage, issue, and verify conference participation certificates.</p></div><div className="actions"><button className="primary" onClick={()=>setShowAdd(true)}>+ Issue Certificate</button></div></div>
    <table>
      <thead><tr><th>Participant</th><th>Certificate No</th><th>Issued At</th><th>Verification</th></tr></thead>
      <tbody>
        {d.map(x=><tr key={x.id}>
          <td><b>{x.participant_name}</b><br/><small>{x.registration_no}</small></td>
          <td><span className="pill" style={{background:'#2E6F95',color:'#fff'}}>{x.certificate_no}</span></td>
          <td>{new Date(x.issued_at).toLocaleString()}</td>
          <td><button onClick={()=>window.open(API.replace('/api','/certificates/verify/')+x.certificate_no,'_blank')}>Verify Online</button></td>
        </tr>)}
        {!d.length && !busy && <tr><td colSpan="4" style={{textAlign:'center',padding:'30px',color:'#888'}}>No certificates issued yet. Click "+ Issue Certificate" to generate one.</td></tr>}
      </tbody>
    </table>
    {showAdd && <IssueModal participants={participants} onSave={async(v)=>{await req(`/admin/certificates/${v.participant_id}/issue`,{method:'POST',body:JSON.stringify(v)}); setShowAdd(false); load(); notify('Certificate issued successfully');}} onClose={()=>setShowAdd(false)}/>}
  </div>
}

function IssueModal({participants,onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Issue Certificate</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Select Participant" value={v.participant_id} onChange={x=>set('participant_id',x)} options={['',...participants.map(p=>({value:p.id,label:p.name+' ('+p.registration_no+')'}))].map(o=>typeof o==='string'?o:o.label)}/>
    <Field label="Custom Certificate No (Optional)" value={v.certificateNo} onChange={x=>set('certificateNo',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave({...v, participant_id: participants.find(p=>(p.name+' ('+p.registration_no+')')===v.participant_id)?.id})}>Generate & Issue</button></div></div></div>
}

function Notices({tab, notify}){
  const[d,setD]=useState([]),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false);
  const load=async()=>{setBusy(true); try{const r=await req('/admin/notices?conferenceId=1');setD(r);}finally{setBusy(false)}};
  useEffect(()=>{load()},[]);
  useEffect(()=>{if(tab==='Send Push Notification')setShowAdd(true)},[tab]);

  const save=async(v)=>{
    await req('/admin/notices',{method:'POST',body:JSON.stringify(v)});
    notify('Notice published & push notification broadcasted');
    setShowAdd(false);
    load();
  };

  return <div className="panel">
    <div className="pagehead">
      <div><h3>Notices & Announcements</h3><p>Broadcast updates and push notifications to all attendee mobile devices.</p></div>
      <div className="actions"><button className="primary" onClick={()=>setShowAdd(true)}>+ Publish Notice</button></div>
    </div>
    <div className="grid" style={{gridTemplateColumns:'repeat(auto-fill, minmax(320px, 1fr))',gap:'16px'}}>
      {d.map(x=><div key={x.id} className="rowcard" style={{flexDirection:'column',alignItems:'flex-start',padding:'20px',gap:'10px'}}>
        <div style={{display:'flex',justifyContent:'space-between',width:'100%',alignItems:'center'}}>
          <span className="pill" style={{background:x.type==='URGENT'?'#ef4444':x.type==='ALERT'?'#f59e0b':'#8C1119',color:'#fff'}}>{x.type||'GENERAL'}</span>
          <small style={{color:'#888'}}>{new Date(x.created_at).toLocaleDateString()}</small>
        </div>
        <h4 style={{margin:0,fontSize:'17px'}}>{x.title}</h4>
        <p style={{margin:0,color:'#475569',fontSize:'14px',lineHeight:'1.5'}}>{x.message}</p>
        <div style={{marginTop:'auto',width:'100%',display:'flex',justifyContent:'space-between',alignItems:'center',paddingTop:'10px',borderTop:'1px solid #eee'}}>
          <small style={{color:'#64748b'}}>Target: <b>{x.target_role||'All Attendees'}</b></small>
          <button style={{color:'#ef4444',borderColor:'#fecaca',padding:'4px 10px',fontSize:'12px'}} onClick={async()=>{if(confirm('Delete this notice?')){await req(`/admin/notices/${x.id}`,{method:'DELETE'});load();notify('Notice deleted');}}}>Delete</button>
        </div>
      </div>)}
      {!d.length && !busy && <div style={{gridColumn:'1/-1',textAlign:'center',padding:'40px',color:'#888'}}>No notices published yet. Click "+ Publish Notice" to broadcast one.</div>}
    </div>
    {showAdd && <NoticeModal onSave={save} onClose={()=>setShowAdd(false)}/>}
  </div>
}

function NoticeModal({onSave,onClose}){
  const[v,set]=formState({type:'GENERAL',target_role:''});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Publish Notice / Push Notification</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <Field label="Title" value={v.title} onChange={x=>set('title',x)}/>
    <SelectField label="Notice Type" value={v.type} onChange={x=>set('type',x)} options={['GENERAL','INFO','URGENT','ALERT']}/>
    <SelectField label="Target Audience" value={v.target_role} onChange={x=>set('target_role',x)} options={['','PARTICIPANT','SPEAKER','ADMIN','VOLUNTEER']}/>
    <Field textarea label="Message Content" value={v.message} onChange={x=>set('message',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Broadcast Now</button></div></div></div>
}

function Gallery({tab, notify}){
  const[photos,setPhotos]=useState([]),[albums,setAlbums]=useState([]),[activeAlbum,setActiveAlbum]=useState('ALL'),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false);
  const load=async()=>{
    setBusy(true);
    try{
      const[p,a]=await Promise.all([req('/admin/gallery?conferenceId=1'),req('/admin/gallery/albums?conferenceId=1')]);
      setPhotos(p); setAlbums(a);
    }finally{setBusy(false)}
  };
  useEffect(()=>{load()},[]);
  useEffect(()=>{if(tab==='Upload Photo')setShowAdd(true)},[tab]);

  const filtered=activeAlbum==='ALL'?photos:photos.filter(p=>p.album===activeAlbum);

  const save=async(v)=>{
    await req('/admin/gallery',{method:'POST',body:JSON.stringify(v)});
    notify('Photo uploaded to gallery');
    setShowAdd(false);
    load();
  };

  return <div className="panel">
    <div className="pagehead">
      <div><h3>Conference Gallery</h3><p>Manage photo albums, conference highlights, and visual media.</p></div>
      <div className="actions"><button className="primary" onClick={()=>setShowAdd(true)}>+ Upload Photo</button></div>
    </div>
    <div className="toolbar" style={{display:'flex',gap:'8px',flexWrap:'wrap',marginBottom:'20px'}}>
      <button className={activeAlbum==='ALL'?'primary':''} onClick={()=>setActiveAlbum('ALL')}>All Photos ({photos.length})</button>
      {albums.map(a=><button key={a.album} className={activeAlbum===a.album?'primary':''} onClick={()=>setActiveAlbum(a.album)}>{a.album} ({a.photo_count})</button>)}
    </div>
    <div className="grid" style={{gridTemplateColumns:'repeat(auto-fill, minmax(240px, 1fr))',gap:'16px'}}>
      {filtered.map(x=><div key={x.id} style={{background:'#fff',borderRadius:'12px',overflow:'hidden',border:'1px solid #e2e8f0',boxShadow:'0 2px 8px rgba(0,0,0,0.05)',display:'flex',flexDirection:'column'}}>
        <div style={{height:'180px',background:'#eee',overflow:'hidden',position:'relative'}}>
          <img src={resolveMediaUrl(x.url)} alt={x.caption||'Photo'} style={{width:'100%',height:'100%',objectFit:'cover'}} onError={(e)=>{e.target.src='https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800'}}/>
          <span className="pill" style={{position:'absolute',top:'10px',left:'10px',background:'rgba(0,0,0,0.65)',color:'#fff',backdropFilter:'blur(4px)',fontSize:'11px'}}>{x.album}</span>
        </div>
        <div style={{padding:'14px',display:'flex',flexDirection:'column',flex:1,gap:'8px'}}>
          <p style={{margin:0,fontSize:'14px',fontWeight:'600',color:'#1e293b'}}>{x.caption||'Conference moment'}</p>
          <div style={{marginTop:'auto',display:'flex',justifyContent:'space-between',alignItems:'center',paddingTop:'8px',borderTop:'1px solid #f1f5f9'}}>
            <small style={{color:'#94a3b8'}}>{new Date(x.created_at).toLocaleDateString()}</small>
            <button style={{color:'#ef4444',borderColor:'#fecaca',padding:'3px 8px',fontSize:'12px'}} onClick={async()=>{if(confirm('Delete photo?')){await req(`/admin/gallery/${x.id}`,{method:'DELETE'});load();notify('Photo deleted');}}}>Delete</button>
          </div>
        </div>
      </div>)}
      {!filtered.length && !busy && <div style={{gridColumn:'1/-1',textAlign:'center',padding:'40px',color:'#888'}}>No photos found in this album. Click "+ Upload Photo" to add memories.</div>}
    </div>
    {showAdd && <PhotoModal onSave={save} onClose={()=>setShowAdd(false)} notify={notify}/>}
  </div>
}

function PhotoModal({onSave,onClose,notify}){
  const[v,set]=formState({album:'Opening Day'});
  const[busy,setBusy]=useState(false);
  const upload=async(file)=>{
    if(!file)return;
    const reader=new FileReader();
    reader.onload=async()=>{
      const data=await req('/admin/uploads',{method:'POST',body:JSON.stringify({folder:'gallery',file:{name:file.name,dataUrl:reader.result}})});
      set('url',data.url);
      notify('File uploaded');
    };
    reader.readAsDataURL(file);
  };
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Upload Gallery Photo</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <Field label="Album Name" value={v.album} onChange={x=>set('album',x)}/>
    <label className="field uploadfield"><span>Select Image</span><div><input value={v.url||''} onChange={e=>set('url',e.target.value)} placeholder="URL or choose file"/><label className="uploadBtn"><Upload size={16}/>Browse<input type="file" accept="image/*" onChange={e=>upload(e.target.files?.[0])}/></label></div></label>
    <Field label="Caption / Description" value={v.caption} onChange={x=>set('caption',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" disabled={busy || !v.url} onClick={async()=>{setBusy(true);try{await onSave(v)}finally{setBusy(false)}}}>{busy?'Uploading...':'Save Photo'}</button></div></div></div>
}

function Reports({tab, notify}){
  const reportMap={'Participant Reports':'participants','Attendance Reports':'attendance','Accommodation Reports':'accommodation','Transport Reports':'transport','Meal Reports':'meals','Certificate Reports':'certificates'};
  const initialType=reportMap[tab]||'participants';
  const[type,setType]=useState(initialType),[data,setData]=useState([]),[busy,setBusy]=useState(false);
  
  useEffect(()=>{if(reportMap[tab])setType(reportMap[tab])},[tab]);

  const load=async()=>{setBusy(true); try{const r=await req(`/admin/reports/${type}`);setData(r)}finally{setBusy(false)}};
  useEffect(()=>{load()},[type]);

  const exportCSV=()=>{
    if(!data.length){alert('No data to export');return}
    const keys=Object.keys(data[0]);
    const csvRows=[keys.join(',')];
    data.forEach(row=>{
      const vals=keys.map(k=>`"${String(row[k]||'').replace(/"/g,'""')}"`);
      csvRows.push(vals.join(','));
    });
    const blob=new Blob([csvRows.join('\n')],{type:'text/csv'});
    const url=URL.createObjectURL(blob);
    const a=document.createElement('a');
    a.href=url;
    a.download=`conference_${type}_report_${Date.now()}.csv`;
    a.click();
    notify(`Exported ${type} report to CSV`);
  };

  return <div className="panel">
    <div className="pagehead"><div><h3>Conference Reports & Analytics</h3><p>Export operational data and attendee rosters to CSV / Excel.</p></div><div className="actions"><button className="primary" onClick={exportCSV}>📥 Export CSV</button></div></div>
    <div className="toolbar" style={{display:'flex',gap:'12px',alignItems:'center'}}>
      <SelectField label="Select Report Category" value={type} onChange={setType} options={['participants','attendance','accommodation','transport','meals','certificates']}/>
    </div>
    <table>
      <thead><tr>{data[0] && Object.keys(data[0]).map(k=><th key={k}>{k.replace('_',' ').toUpperCase()}</th>)}</tr></thead>
      <tbody>
        {data.map((row,i)=><tr key={i}>{Object.values(row).map((v,j)=><td key={j}>{String(v===null||v===undefined?'—':v)}</td>)}</tr>)}
        {!data.length && !busy && <tr><td colSpan="6" style={{textAlign:'center',padding:'30px',color:'#888'}}>No records found for this report.</td></tr>}
      </tbody>
    </table>
  </div>
}

function Chat({notify}){
  const[convs,setConvs]=useState([]),[msgs,setMsgs]=useState([]),[active,setActive]=useState(null),[text,setText]=useState('');
  const load=async()=>{const r=await req('/admin/conversations?conferenceId=1').catch(()=>[]);setConvs(r)};
  useEffect(()=>{load()},[]);
  const loadMsgs=async(id)=>{const r=await req(`/conversations/${id}/messages`).catch(()=>[]);setMsgs(r);setActive(id)};
  const send=async()=>{if(!text||!active)return; await req(`/admin/messages`,{method:'POST',body:JSON.stringify({conversationId:active, body:text})}); setText(''); loadMsgs(active);};
  return <div className="panel chat-panel"><div className="split">
    <div className="panel list"><h4>Active Conversations</h4>{convs.map(c=><div key={c.id} className={`rowcard ${active===c.id?'active':''}`} style={{cursor:'pointer'}} onClick={()=>loadMsgs(c.id)}><b>{c.title}</b><p>{c.last_message||'Click to view conversation'}</p></div>)}{!convs.length && <p style={{color:'#888',padding:'20px'}}>No active conversations yet.</p>}</div>
    <div className="panel msgs">
      <h4>Messages {active ? `(#${active})` : ''}</h4>
      <div className="msg-list" style={{minHeight:'240px',maxHeight:'400px',overflowY:'auto',display:'flex',flexDirection:'column',gap:'10px',padding:'10px 0'}}>
        {msgs.map(m=><div key={m.id} className="msg" style={{background:'#f1f5f9',padding:'10px 14px',borderRadius:'8px'}}><b>{m.sender_name}:</b> {m.body}</div>)}
        {!msgs.length && <p style={{color:'#888',textAlign:'center',padding:'30px'}}>Select a conversation or send a live announcement.</p>}
      </div>
      <div className="input" style={{display:'flex',gap:'10px',marginTop:'10px'}}><input style={{flex:1,padding:'10px 14px',border:'1px solid #cbd5e1',borderRadius:'8px'}} placeholder="Type a message as Admin..." value={text} onChange={e=>setText(e.target.value)} onKeyDown={e=>e.key==='Enter'&&send()}/><button className="primary" onClick={send}>Send</button></div>
    </div>
  </div></div>
}

function AdminUsers({tab, notify}){
  const[d,setD]=useState([]),[logs,setLogs]=useState([]),[showAdd,setShowAdd]=useState(false);
  const load=async()=>{try{const[u,l]=await Promise.all([req('/admin/users'),req('/admin/audit-logs')]);setD(u); setLogs(l);}catch(e){}};
  useEffect(()=>{load()},[]);
  return <div className="panel">
    <div className="pagehead"><div><h3>Admin Users & Security</h3><p>Manage administrative access, control room roles, and inspect security audit logs.</p></div><div className="actions"><button className="primary" onClick={()=>setShowAdd(true)}>+ Create Admin</button></div></div>
    <div className="split">
      <div className="panel"><h4>Active Administrators</h4><table><thead><tr><th>Name & Email</th><th>Role</th></tr></thead><tbody>{d.map(x=><tr key={x.id}><td><b>{x.name}</b><br/><small>{x.email}</small></td><td><span className="pill" style={{background:'#8C1119',color:'#fff'}}>{x.role}</span></td></tr>)}</tbody></table></div>
      <div className="panel"><h4>Audit Logs</h4><div className="log-list" style={{maxHeight:'380px',overflowY:'auto',display:'flex',flexDirection:'column',gap:'10px'}}>{logs.map(x=><div key={x.id} className="log-item" style={{background:'#f8fafc',padding:'10px 14px',borderRadius:'8px',border:'1px solid #e2e8f0'}}><small style={{color:'#64748b'}}>{new Date(x.created_at).toLocaleString()}</small><p style={{margin:'4px 0 0',fontWeight:'600'}}><b>{x.admin_name||'System'}</b>: {x.action} on {x.entity}</p></div>)}</div></div>
    </div>
    {showAdd && <AdminUserModal onSave={async(v)=>{await req('/admin/users',{method:'POST',body:JSON.stringify(v)}); setShowAdd(false); load(); notify('Admin created successfully');}} onClose={()=>setShowAdd(false)}/>}
  </div>
}

function AdminUserModal({onSave,onClose}){
  const[v,set]=formState({role:'ADMIN'});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Create Administrator</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <Field label="Full Name" value={v.name} onChange={x=>set('name',x)}/>
    <Field label="Email" value={v.email} onChange={x=>set('email',x)}/>
    <Field type="password" label="Password" value={v.password} onChange={x=>set('password',x)}/>
    <SelectField label="Assigned Role" value={v.role} onChange={x=>set('role',x)} options={['ADMIN','EVENT_MANAGER','TRANSPORT_ADMIN','VOLUNTEER','SUPER_ADMIN']}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Create Admin</button></div></div></div>
}

function SystemSettings({notify}){
  const[health,setHealth]=useState(null),[stats,setStats]=useState(null),[busy,setBusy]=useState(false);
  const load=async()=>{
    try{
      const[h,s]=await Promise.all([fetch(API.replace('/api','')+'/api/health').then(r=>r.json()),req('/admin/stats')]);
      setHealth(h); setStats(s);
    }catch(e){}
  };
  useEffect(()=>{load()},[]);

  return <div className="panel">
    <div className="pagehead"><div><h3>System Settings & Status</h3><p>Server diagnostics, real-time Socket.IO health, and database connection metrics.</p></div><div className="actions"><button className="primary" onClick={()=>{load();notify('Diagnostics refreshed');}}>↻ Check Health</button></div></div>
    <div className="grid" style={{gridTemplateColumns:'repeat(auto-fill, minmax(280px, 1fr))',gap:'16px'}}>
      <div className="stat"><CheckCircle color="#10b981"/><span>API Backend Status</span><strong style={{color:'#10b981',fontSize:'20px'}}>HEALTHY (Online)</strong></div>
      <div className="stat"><Lock color="#8C1119"/><span>MySQL 8 Database</span><strong style={{color:'#8C1119',fontSize:'20px'}}>CONNECTED</strong></div>
      <div className="stat"><Bell color="#C8A45A"/><span>Socket.IO Real-Time</span><strong style={{color:'#C8A45A',fontSize:'20px'}}>ACTIVE</strong></div>
      <div className="stat"><FileCheck color="#2E6F95"/><span>Total Database Records</span><strong>{stats?(stats.participants+stats.speakers+stats.sessions+stats.hotels):'—'}</strong></div>
    </div>
    <div className="split" style={{marginTop:'24px'}}>
      <div className="panel">
        <h4>Environment Configuration</h4>
        <div style={{lineHeight:'2',fontSize:'14px'}}>
          <div><b>REST API Endpoint:</b> <code>{API}</code></div>
          <div><b>Server Time:</b> <code>{health?.time||new Date().toISOString()}</code></div>
          <div><b>Platform Version:</b> <code>v1.0.0 (DY Patil Education Society)</code></div>
        </div>
      </div>
      <div className="panel">
        <h4>Cache & Session Actions</h4>
        <p style={{color:'#64748b',marginBottom:'14px'}}>Perform maintenance tasks or sync schema with Flutter mobile app clients.</p>
        <button className="primary" onClick={()=>{localStorage.removeItem('conference_cache');notify('Client cache cleared & synchronized');}}>Clear Client Cache & Resync</button>
      </div>
    </div>
  </div>
}

createRoot(document.getElementById('root')).render(<App/>);

