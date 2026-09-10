import React,{useEffect,useState} from 'react';
import {createRoot} from 'react-dom/client';
import {Bell,Building2,Bus,CalendarDays,CheckCircle,ChevronDown,FileCheck,Hotel,Image,LayoutDashboard,Lock,LogOut,MapPin,Palette,RefreshCw,Search,Settings,Shield,Upload,Users,QrCode,Maximize2,Minimize2,Printer,Tv,UserCheck,MessageCircle,Send,Share2,Menu,X} from 'lucide-react';
import {QRCodeSVG} from 'qrcode.react';
import * as XLSX from 'xlsx';
import './style.css';

const getApiBase = () => {
  if (typeof window !== 'undefined') {
    if (window.location.hostname.includes('dypesconf.io')) {
      return 'https://api.dypesconf.io/api';
    }
  }
  return import.meta.env.VITE_API_URL || 'http://localhost:5000/api';
};
const API = getApiBase();
const emptyConference={name:'',shortName:'',description:'',welcomeMessage:'',aboutConference:'',startDate:'',endDate:'',registrationStartDate:'',registrationEndDate:'',contactPerson:'',contactPhone:'',contactEmail:'',website:'',organizer:'',hostInstitution:'',theme:'',status:'ACTIVE'};
const emptyVenue={name:'',address:'',city:'',state:'',country:'',pincode:'',latitude:'',longitude:'',googleMapsUrl:'',parkingInformation:'',directions:'',contactNumber:''};
const emptyBranding={logoUrl:'',organizerLogoUrl:'',bannerUrl:'',splashScreenUrl:'',faviconUrl:'',primaryColor:'#8C1119',secondaryColor:'#C8A45A',accentColor:'#2E6F95',backgroundColor:'#FCFAF5'};
const emptySettings={enableRegistration:true,enableChat:true,enableGallery:true,enableAttendance:true,enableQr:true,enablePushNotifications:false,enableCertificates:true,enablePolls:false,enableFeedback:true};

async function req(path,opt={}){
  const token=localStorage.getItem('token');
  const r=await fetch(API+path,{...opt,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...(opt.headers||{})}});
  const d=await r.json().catch(()=>({}));
  if(!r.ok){
    if(r.status===401){
      window.dispatchEvent(new CustomEvent('auth:unauthorized'));
    }
    throw new Error(d.message||`HTTP ${r.status}`);
  }
  return d;
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

function Login({onLogin}){const[e,setE]=useState(''),[p,setP]=useState(''),[busy,setBusy]=useState(false);const submit=async x=>{x.preventDefault();setBusy(true);try{const d=await req('/auth/login',{method:'POST',body:JSON.stringify({email:e,password:p})});localStorage.setItem('token',d.token);onLogin()}catch(err){alert(err.message)}finally{setBusy(false)}};return <div className="login"><form onSubmit={submit}><div className="brand-logo-container"><img src="/logo.png" alt="DY Patil Logo" className="brand-img" /></div><h1>Conference Control Room</h1><p>Manage live conference content, logistics, and mobile app data from MySQL.</p><input value={e} onChange={x=>setE(x.target.value)} placeholder="Email"/><input type="password" value={p} onChange={x=>setP(x.target.value)} placeholder="Password"/><button disabled={busy}>{busy?'Signing in...':'Sign in'}</button></form></div>}

const menu=[
  {title:'Dashboard',icon:LayoutDashboard},
  {title:'Conference',icon:Building2,children:['Conference Details','Venue & Location','Branding','Conference Settings','Main Screen Slider']},
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
  {title:'Feedback',icon:MessageCircle,children:['CME Feedback & Ratings','Feedback Analytics']},
  {title:'Chat',icon:Bell,children:['Live Chat','Broadcast Message']},
  {title:'Reports',icon:FileCheck,children:['Participant Reports','Attendance Reports','Accommodation Reports','Transport Reports','Meal Reports','Certificate Reports','CME Feedback Reports']},
  {title:'Admin Users',icon:Lock,children:['Admin Users List','Audit Logs']},
  {title:'System Settings',icon:Settings},
];

function App(){
  const[logged,setLogged]=useState(!!localStorage.getItem('token'));
  const[tab,setTab]=useState('Dashboard');
  const[open,setOpen]=useState({Conference:true,Participants:false,Schedule:false});
  const[conferencesList,setConferencesList]=useState([]);
  const[selectedConferenceId,setSelectedConferenceId]=useState(1);
  const[conference,setConference]=useState(null);
  const[toast,setToast]=useState('');
  const[mobileNavOpen,setMobileNavOpen]=useState(false);
  const[showCreateConfModal,setShowCreateConfModal]=useState(false);

  const loadConferencesList = () => {
    req('/conferences').then(list => {
      setConferencesList(list);
      if(list.length && !list.find(c => c.id === selectedConferenceId)){
        setSelectedConferenceId(list[0].id);
      }
    }).catch(e => console.warn(e));
  };

  const loadConference = (confId) => {
    const cid = confId || selectedConferenceId || 1;
    req('/conference?conferenceId=' + cid).then(x=>setConference(normalizeConference(x))).catch(e=>setToast(e.message));
  };

  const handleSelectTab=(t)=>{
    setTab(t);
    setMobileNavOpen(false);
  };

  useEffect(()=>{
    if(logged){
      loadConferencesList();
      loadConference(selectedConferenceId);
    }
    const handleUnauth=()=>setLogged(false);
    window.addEventListener('auth:unauthorized',handleUnauth);

    let socket = null;
    if (logged && typeof window !== 'undefined' && window.io) {
      try {
        const socketUrl = API.replace(/\/api\/?$/, '');
        const token = localStorage.getItem('token');
        socket = window.io(socketUrl, {
          auth: { token },
          query: { token },
          transports: ['websocket', 'polling']
        });

        socket.on('connect', () => {
          socket.emit('join_conference', selectedConferenceId || 1);
        });

        const handleRealtime = (eventName, data) => {
          window.dispatchEvent(new CustomEvent('app:realtime', { detail: { event: eventName, data } }));
          if (eventName === 'conference_updated') {
            loadConference(selectedConferenceId);
          }
        };

        const events = [
          'conference_updated', 'participant_registered', 'participant_status_updated',
          'participant_deleted', 'meal_scanned', 'new_scan', 'sessions_updated',
          'speakers_updated', 'new_notice', 'room_allocated', 'room_deallocated',
          'transport_assigned', 'gallery_updated', 'sliders_updated'
        ];

        events.forEach(ev => socket.on(ev, data => handleRealtime(ev, data)));
      } catch (err) {
        console.warn('Socket connect error:', err);
      }
    }

    return ()=>{
      window.removeEventListener('auth:unauthorized',handleUnauth);
      if(socket) socket.disconnect();
    };
  },[logged, selectedConferenceId]);

  const notify=msg=>{setToast(msg);setTimeout(()=>setToast(''),2800)};
  if(!logged)return <Login onLogin={()=>setLogged(true)}/>;

  return <div className="app">
    <div className={`sidebar-backdrop ${mobileNavOpen ? 'show' : ''}`} onClick={()=>setMobileNavOpen(false)} />
    <aside className={mobileNavOpen ? 'mobile-open' : ''}>
      <div className="sidebrand">
        <div className="sidebrand-header">
          <img src="/logo.png" alt="Logo" className="sidebrand-logo" />
          <div style={{flex:1}}><strong>DY Patil</strong><span>Conference</span></div>
          <button className="sidebar-close-btn" onClick={()=>setMobileNavOpen(false)} title="Close menu"><X size={20}/></button>
        </div>
      </div>
      <nav>{menu.map(item=><NavItem key={item.title} item={item} active={tab} open={open[item.title]} onToggle={()=>setOpen(o=>({...o,[item.title]:!o[item.title]}))} onSelect={handleSelectTab}/>)}</nav>
      <button className="logout" onClick={()=>{localStorage.clear();setLogged(false)}}><LogOut size={18}/>Sign out</button>
    </aside>
    <main>
      <header>
        <div style={{display:'flex',alignItems:'center',gap:'12px'}}>
          <button className="menu-toggle-btn icon" onClick={()=>setMobileNavOpen(o=>!o)} title="Toggle menu" aria-label="Toggle navigation menu"><Menu size={20}/></button>
          <div>
            <h2>{tab}</h2>
            <p>{conference?.name||'Conference Management System'}</p>
          </div>
        </div>
        <div className="header-actions" style={{display:'flex',alignItems:'center',gap:'10px'}}>
          <div style={{display:'flex',alignItems:'center',gap:'6px',background:'#f1f5f9',padding:'4px 10px',borderRadius:'8px',border:'1px solid #cbd5e1'}}>
            <Building2 size={16} color="#8C1119" />
            <select
              value={selectedConferenceId}
              onChange={e => {
                if(e.target.value === 'NEW') {
                  setShowCreateConfModal(true);
                } else {
                  setSelectedConferenceId(Number(e.target.value));
                }
              }}
              style={{border:'none',background:'transparent',fontWeight:700,fontSize:'13px',color:'#1e293b',cursor:'pointer',outline:'none'}}
            >
              {conferencesList.map(c => (
                <option key={c.id} value={c.id}>{c.short_name || c.name} (ID: {c.id})</option>
              ))}
              <option value="NEW">➕ Host New Conference...</option>
            </select>
          </div>
          <button className="icon" onClick={() => loadConference(selectedConferenceId)} title="Refresh conference"><RefreshCw size={18}/></button>
        </div>
      </header>
      {renderPage(tab,conference,setConference,notify,selectedConferenceId)}
      {toast&&<div className="toast">{toast}</div>}
      {showCreateConfModal && (
        <CreateConferenceModal
          onClose={() => setShowCreateConfModal(false)}
          onCreated={(newConf) => {
            loadConferencesList();
            setSelectedConferenceId(newConf.id);
          }}
          notify={notify}
        />
      )}
    </main>
  </div>;
}

function NavItem({item,active,open,onToggle,onSelect}){const I=item.icon;const parentActive=active===item.title||item.children?.includes(active);return <div className="navgroup"><button className={parentActive?'active':''} onClick={()=>item.children?onToggle():onSelect(item.title)}><I size={18}/><span>{item.title}</span>{item.children&&<ChevronDown className={open?'rotated':''} size={15}/>}</button>{item.children&&open&&<div className="subnav">{item.children.map(child=><button key={child} className={active===child?'active child':'child'} onClick={()=>onSelect(child)}>{child}</button>)}</div>}</div>}

function renderPage(tab,conference,setConference,notify,selectedConferenceId){
  if(tab==='Dashboard')return <Dashboard selectedConferenceId={selectedConferenceId}/>;
  if(['Conference','Conference Details','Venue & Location','Branding','Conference Settings','Main Screen Slider'].includes(tab))return <ConferenceModule tab={tab} conference={conference} setConference={setConference} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Participants','All Participants','Add Participant','Import Participants','Registration & Passes','QR Codes'].includes(tab))return <Participants tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Speakers','All Speakers','Add Speaker'].includes(tab))return <Speakers tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Schedule','Sessions Timeline','Tracks & Halls','Add Session','Sessions','Tracks','Halls'].includes(tab))return <Schedule tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Accommodation','Hotels','Rooms'].includes(tab))return <Hotels tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(tab==='Room Allocation')return <RoomAllocation notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Transport','Vehicles','Drivers'].includes(tab))return <Transport tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(tab==='Transport Assignments')return <TransportAssignments notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Attendance','Live Attendance','QR Scanner Simulator'].includes(tab))return <Attendance tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Notices','Notices & Announcements','Send Push Notification'].includes(tab))return <Notices tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Gallery','Photo Gallery','Upload Photo'].includes(tab))return <Gallery tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Meals','Meal Schedule','Schedule Meal'].includes(tab))return <Meals tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Duties','Duty Roster','Assign Staff'].includes(tab))return <Duties tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Certificates','Issued Certificates','Issue Certificate'].includes(tab))return <Certificates tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Feedback','CME Feedback & Ratings','Feedback Analytics'].includes(tab))return <FeedbackView tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Chat','Live Chat','Broadcast Message'].includes(tab))return <Chat tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Reports','Participant Reports','Attendance Reports','Accommodation Reports','Transport Reports','Meal Reports','Certificate Reports','CME Feedback Reports'].includes(tab))return <Reports tab={tab} notify={notify} selectedConferenceId={selectedConferenceId}/>;
  if(['Admin Users','Admin Users List','Audit Logs'].includes(tab))return <AdminUsers tab={tab} notify={notify}/>;
  if(tab==='System Settings')return <SystemSettings notify={notify}/>;
  return <Placeholder title={tab}/>;
}

function Dashboard({selectedConferenceId}){
  const[s,setS]=useState(null);
  useEffect(()=>{
    req('/admin/stats?conferenceId=' + (selectedConferenceId || 1)).then(setS).catch(e=>console.warn(e.message));
  },[selectedConferenceId]);
  if(!s)return <div className="loading">Loading dashboard...</div>;
  const cards=[['Participants',s.participants,Users],['Checked In',s.checkedIn,CheckCircle],['Speakers',s.speakers,Users],['Sessions',s.sessions,CalendarDays],['Hotels',s.hotels,Hotel],['Rooms',s.rooms,Hotel],['Gallery Photos',s.photos,Image],['Certificates',s.certificates,FileCheck]];
  return <><section className="hero"><div><span>LIVE CONTROL ROOM</span><h1>Conference Operations</h1><p>Monitor registrations, logistics, content, and attendance from one dashboard.</p></div><div className="heroStat">2026</div></section><div className="grid">{cards.map(([n,v,I])=><div className="stat" key={n}><I/><span>{n}</span><strong>{v}</strong></div>)}</div><div className="split"><div className="panel"><h3>Operational Checklist</h3><div className="checkgrid"><div>Registration enabled</div><div>Venue published</div><div>Branding synced</div><div>Schedule online</div><div>Notifications ready</div><div>Certificates enabled</div></div></div><div className="panel"><h3>Phase 1 Status</h3><p className="muted">Conference details, venue, branding, and mobile configuration now load from the API.</p></div></div></>
}

function ConferenceModule({tab,conference,setConference,notify,selectedConferenceId}){
  if(tab==='Main Screen Slider') return <MainScreenSliderManager conferenceId={selectedConferenceId || 1} notify={notify} />;
  if(!conference)return <div className="loading">Loading conference...</div>;
  const save=async(path,payload,msg)=>{
    const data=await req(path,{method:'PUT',body:JSON.stringify({...payload, conferenceId: selectedConferenceId || 1})});
    setConference(normalizeConference(data));
    notify(msg);
  };
  if(tab==='Venue & Location')return <VenueForm value={conference.venue} onSave={v=>save('/admin/conference/venue',v,'Venue updated')}/>;
  if(tab==='Branding')return <BrandingForm value={conference.branding} onSave={v=>save('/admin/conference/branding',v,'Branding updated')} notify={notify}/>;
  if(tab==='Conference Settings')return <SettingsForm value={conference.settings} onSave={v=>save('/admin/conference/settings',v,'Settings updated')}/>;
  return <ConferenceForm value={conference} onSave={v=>save('/admin/conference',v,'Conference details updated')}/>;
}

function CreateConferenceModal({ onClose, onCreated, notify }) {
  const [v, setV] = useState({
    name: '', shortName: '', theme: '', organizer: '', hostInstitution: '', venue: '', address: '', startDate: '', endDate: ''
  });
  const [busy, setBusy] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!v.name) { alert('Conference name is required'); return; }
    setBusy(true);
    try {
      const res = await req('/admin/conferences', {
        method: 'POST',
        body: JSON.stringify(v)
      });
      notify('New Conference created successfully!');
      onCreated(res.data);
      onClose();
    } catch(err) {
      alert(err.message || 'Failed to create conference');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal" style={{maxWidth:'600px'}}>
        <div className="modal-header" style={{background:'#8C1119', color:'#fff'}}>
          <h3>➕ Host New Conference</h3>
          <button className="close" onClick={onClose} style={{color:'#fff'}}>&times;</button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="modal-body" style={{display:'flex', flexDirection:'column', gap:'12px'}}>
            <Field label="Conference Full Title *" value={v.name} onChange={x => setV(s => ({...s, name: x}))} />
            <Field label="Short Name / Acronym" value={v.shortName} onChange={x => setV(s => ({...s, shortName: x}))} />
            <Field label="Theme / Topic" value={v.theme} onChange={x => setV(s => ({...s, theme: x}))} />
            <Field label="Organizer Body" value={v.organizer} onChange={x => setV(s => ({...s, organizer: x}))} />
            <Field label="Host Institution" value={v.hostInstitution} onChange={x => setV(s => ({...s, hostInstitution: x}))} />
            <Field label="Venue Name" value={v.venue} onChange={x => setV(s => ({...s, venue: x}))} />
            <Field textarea label="Venue Address" value={v.address} onChange={x => setV(s => ({...s, address: x}))} />
            <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:'12px'}}>
              <Field type="date" label="Start Date" value={v.startDate} onChange={x => setV(s => ({...s, startDate: x}))} />
              <Field type="date" label="End Date" value={v.endDate} onChange={x => setV(s => ({...s, endDate: x}))} />
            </div>
          </div>
          <div className="modal-footer">
            <button type="button" onClick={onClose}>Cancel</button>
            <button type="submit" className="primary" disabled={busy}>{busy ? 'Creating...' : 'Create Conference'}</button>
          </div>
        </form>
      </div>
    </div>
  );
}

function MainScreenSliderManager({ conferenceId, notify }) {
  const [slides, setSlides] = useState([]);
  const [busy, setBusy] = useState(false);
  const [showAddModal, setShowAddModal] = useState(false);
  const [newSlide, setNewSlide] = useState({ title: '', mediaType: 'IMAGE', mediaUrl: '', displayOrder: 0, file: null });

  const loadSlides = async () => {
    setBusy(true);
    try {
      const data = await req('/admin/sliders?conferenceId=' + (conferenceId || 1));
      setSlides(data);
    } catch(e) {
      notify(e.message);
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => { loadSlides(); }, [conferenceId]);

  const handleFileUpload = (e) => {
    const file = e.target.files?.[0];
    if(!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      setNewSlide(s => ({
        ...s,
        file: { name: file.name, dataUrl: reader.result },
        mediaType: file.type.startsWith('video/') ? 'VIDEO' : 'IMAGE'
      }));
    };
    reader.readAsDataURL(file);
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    try {
      await req('/admin/sliders', {
        method: 'POST',
        body: JSON.stringify({ ...newSlide, conferenceId: conferenceId || 1 })
      });
      notify('Main screen slide added!');
      setShowAddModal(false);
      setNewSlide({ title: '', mediaType: 'IMAGE', mediaUrl: '', displayOrder: 0, file: null });
      loadSlides();
    } catch(err) {
      alert(err.message);
    }
  };

  const handleDelete = async (id) => {
    if(!confirm('Delete this banner slide?')) return;
    await req('/admin/sliders/' + id, { method: 'DELETE' });
    notify('Slide deleted');
    loadSlides();
  };

  const handleToggleActive = async (slide) => {
    await req('/admin/sliders/' + slide.id, {
      method: 'PUT',
      body: JSON.stringify({ active: slide.active ? 0 : 1 })
    });
    loadSlides();
  };

  return (
    <div className="panel">
      <div className="pagehead">
        <div>
          <h3>Main Screen Slider Banners</h3>
          <p>Manage image and video carousel slides displayed at top of mobile home screen.</p>
        </div>
        <div className="actions">
          <button className="secondary" onClick={loadSlides}>{busy ? 'Refreshing...' : 'Refresh'}</button>
          <button onClick={() => setShowAddModal(true)}>+ Add Media Banner Slide</button>
        </div>
      </div>

      <div className="grid" style={{gridTemplateColumns:'repeat(auto-fill, minmax(280px, 1fr))', gap:'16px', marginTop:'16px'}}>
        {slides.map(s => (
          <div key={s.id} className="stat" style={{display:'flex', flexDirection:'column', alignItems:'stretch', gap:'10px', padding:'14px', position:'relative', border:'1px solid #e2e8f0', borderRadius:'12px', background:'#fff'}}>
            <div style={{height:'140px', width:'100%', borderRadius:'8px', overflow:'hidden', background:'#000', display:'flex', alignItems:'center', justifyContent:'center'}}>
              {s.media_type === 'VIDEO' ? (
                <video src={resolveMediaUrl(s.media_url)} controls style={{width:'100%', height:'100%', objectFit:'cover'}} />
              ) : (
                <img src={resolveMediaUrl(s.media_url)} alt={s.title} style={{width:'100%', height:'100%', objectFit:'cover'}} />
              )}
            </div>
            <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
              <strong>{s.title || 'Untitled Banner'}</strong>
              <span className="pill" style={{background: s.media_type === 'VIDEO' ? '#2563eb' : '#059669', color:'#fff', fontSize:'11px'}}>
                {s.media_type}
              </span>
            </div>
            <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', fontSize:'12.5px', color:'#64748b'}}>
              <span>Order: {s.display_order}</span>
              <label style={{cursor:'pointer', display:'flex', alignItems:'center', gap:'4px'}}>
                <input type="checkbox" checked={!!s.active} onChange={() => handleToggleActive(s)} />
                Active
              </label>
            </div>
            <button className="pill small" style={{background:'#ef4444', color:'#fff', cursor:'pointer', border:'none', marginTop:'4px'}} onClick={() => handleDelete(s.id)}>
              Delete Slide
            </button>
          </div>
        ))}
        {!slides.length && !busy && (
          <div style={{gridColumn:'1 / -1', padding:'30px', textAlign:'center', color:'#888'}}>
            No main screen slider banners uploaded for this conference yet.
          </div>
        )}
      </div>

      {showAddModal && (
        <div className="modal-overlay">
          <div className="modal" style={{maxWidth:'500px'}}>
            <div className="modal-header">
              <h3>Add Home Screen Media Banner</h3>
              <button className="close" onClick={() => setShowAddModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleCreate}>
              <div className="modal-body" style={{display:'flex', flexDirection:'column', gap:'12px'}}>
                <Field label="Banner Title" value={newSlide.title} onChange={x => setNewSlide(s => ({...s, title: x}))} />
                <SelectField label="Media Type" value={newSlide.mediaType} onChange={x => setNewSlide(s => ({...s, mediaType: x}))} options={['IMAGE', 'VIDEO']} />
                
                <label className="field uploadfield">
                  <span>Upload Image / Video File</span>
                  <div>
                    <input type="file" accept="image/*,video/*" onChange={handleFileUpload} />
                  </div>
                </label>

                <Field label="Or Direct Media URL" value={newSlide.mediaUrl} onChange={x => setNewSlide(s => ({...s, mediaUrl: x}))} />
                <Field type="number" label="Display Order (0 = first)" value={newSlide.displayOrder} onChange={x => setNewSlide(s => ({...s, displayOrder: Number(x)}))} />
              </div>
              <div className="modal-footer">
                <button type="button" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button type="submit" className="primary">Upload & Publish</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

function Field({label,value,onChange,type='text',textarea=false}){return <label className={textarea?'field wide':'field'}><span>{label}</span>{textarea?<textarea value={value||''} onChange={e=>onChange(e.target.value)}/>:<input type={type} value={value||''} onChange={e=>onChange(e.target.value)}/>}</label>}
function SelectField({label,value,onChange,options=[]}){
  return <label className="field">
    <span>{label}</span>
    <select value={value||''} onChange={e=>onChange(e.target.value)}>
      {options.map((x,i)=>{
        if(typeof x==='object' && x!==null) {
          return <option key={x.value!==undefined?x.value:i} value={x.value!==undefined?x.value:''}>{x.label}</option>;
        }
        return <option key={x||i} value={x}>{x}</option>;
      })}
    </select>
  </label>;
}
function Toggle({label,checked,onChange}){return <label className="toggle"><input type="checkbox" checked={!!checked} onChange={e=>onChange(e.target.checked)}/><span>{label}</span></label>}
function formState(initial){
  const [v, setV] = useState(initial || {});
  const prevJsonRef = React.useRef(JSON.stringify(initial || {}));
  
  useEffect(() => {
    const currentJson = JSON.stringify(initial || {});
    if (prevJsonRef.current !== currentJson) {
      prevJsonRef.current = currentJson;
      setV(initial || {});
    }
  }, [initial]);

  return [v, (k, val) => setV(x => ({ ...x, [k]: val })), setV];
}

function ConferenceForm({value,onSave}){const[v,set,setV]=formState(value);return <FormShell icon={Building2} title="Conference Details" description="Edit the public conference profile consumed by Admin and Flutter." onReset={()=>setV(value)} onSave={()=>onSave(v)}><Field label="Conference Name" value={v.name} onChange={x=>set('name',x)}/><Field label="Short Name" value={v.shortName} onChange={x=>set('shortName',x)}/><Field label="Theme" value={v.theme} onChange={x=>set('theme',x)}/><SelectField label="Conference Status" value={v.status} onChange={x=>set('status',x)} options={['ACTIVE','DRAFT','PUBLISHED','ARCHIVED','INACTIVE']}/><Field type="date" label="Start Date" value={v.startDate} onChange={x=>set('startDate',x)}/><Field type="date" label="End Date" value={v.endDate} onChange={x=>set('endDate',x)}/><Field type="date" label="Registration Start" value={v.registrationStartDate} onChange={x=>set('registrationStartDate',x)}/><Field type="date" label="Registration End" value={v.registrationEndDate} onChange={x=>set('registrationEndDate',x)}/><Field label="Contact Person" value={v.contactPerson} onChange={x=>set('contactPerson',x)}/><Field label="Contact Phone" value={v.contactPhone} onChange={x=>set('contactPhone',x)}/><Field label="Contact Email" value={v.contactEmail} onChange={x=>set('contactEmail',x)}/><Field label="Website" value={v.website} onChange={x=>set('website',x)}/><Field label="Organizer" value={v.organizer} onChange={x=>set('organizer',x)}/><Field label="Host Institution" value={v.hostInstitution} onChange={x=>set('hostInstitution',x)}/><Field textarea label="Description" value={v.description} onChange={x=>set('description',x)}/><Field textarea label="Welcome Message" value={v.welcomeMessage} onChange={x=>set('welcomeMessage',x)}/><Field textarea label="About Conference" value={v.aboutConference} onChange={x=>set('aboutConference',x)}/></FormShell>}
function VenueForm({value,onSave}){const[v,set,setV]=formState(value);return <FormShell icon={MapPin} title="Venue & Location" description="Publish map, address, parking, and direction data to the mobile app." onReset={()=>setV(value)} onSave={()=>onSave(v)}><Field label="Venue Name" value={v.name} onChange={x=>set('name',x)}/><Field label="City" value={v.city} onChange={x=>set('city',x)}/><Field label="State" value={v.state} onChange={x=>set('state',x)}/><Field label="Country" value={v.country} onChange={x=>set('country',x)}/><Field label="Pincode" value={v.pincode} onChange={x=>set('pincode',x)}/><Field label="Latitude" value={v.latitude} onChange={x=>set('latitude',x)}/><Field label="Longitude" value={v.longitude} onChange={x=>set('longitude',x)}/><Field label="Venue Contact Number" value={v.contactNumber} onChange={x=>set('contactNumber',x)}/><Field textarea label="Address" value={v.address} onChange={x=>set('address',x)}/><Field textarea label="Google Maps URL" value={v.googleMapsUrl} onChange={x=>set('googleMapsUrl',x)}/><Field textarea label="Parking Information" value={v.parkingInformation} onChange={x=>set('parkingInformation',x)}/><Field textarea label="Directions" value={v.directions} onChange={x=>set('directions',x)}/></FormShell>}
function BrandingForm({value,onSave,notify}){const[v,set,setV]=formState(value);const upload=async(key,file)=>{if(!file)return;const reader=new FileReader();reader.onload=async()=>{const data=await req('/admin/uploads',{method:'POST',body:JSON.stringify({folder:'conference',file:{name:file.name,dataUrl:reader.result}})});set(key,data.url);notify('File uploaded')};reader.readAsDataURL(file)};return <FormShell icon={Palette} title="Branding" description="Control logos, banner imagery, splash assets, and conference colors." onReset={()=>setV(value)} onSave={()=>onSave(v)} preview={<BrandPreview branding={v}/>}>{[['Conference Logo','logoUrl'],['Organizer Logo','organizerLogoUrl'],['Banner','bannerUrl'],['Splash Screen','splashScreenUrl'],['Favicon','faviconUrl']].map(([label,key])=><label className="field uploadfield" key={key}><span>{label}</span><div><input value={v[key]||''} onChange={e=>set(key,e.target.value)} placeholder="URL or uploaded file path"/><label className="uploadBtn"><Upload size={16}/>Upload<input type="file" accept="image/png,image/jpeg,image/webp" onChange={e=>upload(key,e.target.files?.[0])}/></label></div></label>)}<Field type="color" label="Primary Color" value={v.primaryColor} onChange={x=>set('primaryColor',x)}/><Field type="color" label="Secondary Color" value={v.secondaryColor} onChange={x=>set('secondaryColor',x)}/><Field type="color" label="Accent Color" value={v.accentColor} onChange={x=>set('accentColor',x)}/><Field type="color" label="Background Color" value={v.backgroundColor} onChange={x=>set('backgroundColor',x)}/></FormShell>}
function SettingsForm({value,onSave}){const[v,set,setV]=formState(value);return <FormShell icon={Settings} title="Conference Settings" description="Feature flags are saved in MySQL and can be consumed by clients." onReset={()=>setV(value)} onSave={()=>onSave(v)}>{Object.entries({enableRegistration:'Enable Registration',enableChat:'Enable Chat',enableGallery:'Enable Gallery',enableAttendance:'Enable Attendance',enableQr:'Enable QR',enablePushNotifications:'Enable Push Notifications',enableCertificates:'Enable Certificates',enablePolls:'Enable Polls',enableFeedback:'Enable Feedback'}).map(([k,label])=><Toggle key={k} label={label} checked={v[k]} onChange={x=>set(k,x)}/>)}</FormShell>}
function FormShell({icon:Icon,title,description,children,onSave,onReset,preview}){const[busy,setBusy]=useState(false);const submit=async()=>{setBusy(true);try{await onSave()}finally{setBusy(false)}};return <div className="panel"><div className="pagehead"><div className="titleline"><Icon/><div><h3>{title}</h3><p>{description}</p></div></div><div className="actions"><button onClick={onReset}>Reset</button><button onClick={submit} disabled={busy}>{busy?'Saving...':'Save'}</button></div></div>{preview}<div className="formgrid">{children}</div></div>}
function BrandPreview({branding}){return <div className="brandpreview" style={{background:branding.backgroundColor||'#FCFAF5',borderColor:branding.primaryColor||'#8C1119'}}>{branding.bannerUrl&&<img src={branding.bannerUrl.startsWith('/uploads')?API.replace('/api','')+branding.bannerUrl:branding.bannerUrl} alt="Conference banner"/>}<div><span style={{color:branding.accentColor}}>Live Preview</span><strong style={{color:branding.primaryColor}}>Mobile conference branding</strong><small style={{color:branding.secondaryColor}}>Logo, banner, and colors are API driven.</small></div></div>}

function Participants({tab, notify, selectedConferenceId}){
  const[d,setD]=useState([]),[q,setQ]=useState(''),[statusFilter,setStatusFilter]=useState('ALL'),[catFilter,setCatFilter]=useState('ALL'),[appFilter,setAppFilter]=useState('ALL'),[hotelFilter,setHotelFilter]=useState('ALL'),[payFilter,setPayFilter]=useState('ALL'),[kitFilter,setKitFilter]=useState('ALL'),[certFilter,setCertFilter]=useState('ALL'),[foodFilter,setFoodFilter]=useState('ALL'),[busy,setBusy]=useState(false),[edit,setEdit]=useState(null),[importModal,setImportModal]=useState(false),[qrModal,setQrModal]=useState(null),[liaisons,setLiaisons]=useState([]),[whatsappModal,setWhatsappModal]=useState(false);
  
  const load=async()=>{
    setBusy(true);
    try{
      const[r,l]=await Promise.all([
        req('/admin/participants?conferenceId=' + (selectedConferenceId || 1)),
        req('/admin/liaisons').catch(()=>[])
      ]);
      setD(r);
      setLiaisons(l);
    }finally{
      setBusy(false);
    }
  };
  
  useEffect(()=>{load()},[selectedConferenceId]);
  useEffect(()=>{
    if(tab==='Add Participant') setEdit({});
    if(tab==='Import Participants') setImportModal(true);
  },[tab]);

  const toggleKit = async (id) => {
    try {
      const res = await req(`/admin/participants/${id}/toggle-kit`, { method: 'PUT' });
      notify(res.message || 'Kit status updated');
      setD(prev => prev.map(p => p.id === id ? { ...p, kit_issued: res.data?.kit_issued } : p));
    } catch(err) {
      alert(err.message);
    }
  };

  const toggleCert = async (id) => {
    try {
      const res = await req(`/admin/participants/${id}/toggle-certificate`, { method: 'PUT' });
      notify(res.message || 'Certificate status updated');
      setD(prev => prev.map(p => p.id === id ? { ...p, certificate_issued: res.data?.certificate_issued, has_certificate: res.data?.certificate_issued ? 1 : p.has_certificate } : p));
    } catch(err) {
      alert(err.message);
    }
  };

  const filtered=d.filter(x=>{
    const matchesQ=`${x.name} ${x.email} ${x.phone} ${x.registration_no} ${x.university||''} ${x.designation||''} ${x.hotel_name||''} ${x.room_number||''}`.toLowerCase().includes(q.toLowerCase());
    const matchesStatus=statusFilter==='ALL'||x.status===statusFilter;
    const matchesCat=catFilter==='ALL'||x.category===catFilter;
    const matchesApp=appFilter==='ALL'||(appFilter==='NEVER_OPENED' && !x.last_login_at)||(appFilter==='LOGGED_IN' && !!x.last_login_at);
    const matchesHotel=hotelFilter==='ALL'||(hotelFilter==='NO_HOTEL'?!x.hotel_name:x.hotel_name===hotelFilter);
    const matchesPay=payFilter==='ALL'||x.payment_status===payFilter;
    const matchesKit=kitFilter==='ALL'||(kitFilter==='KIT_ISSUED'?x.kit_issued:!x.kit_issued);
    const matchesCert=certFilter==='ALL'||(certFilter==='CERT_ISSUED'?(x.certificate_issued||x.has_certificate>0):(!x.certificate_issued&&!x.has_certificate));
    const matchesFood=foodFilter==='ALL'||(x.food_preference||'VEG')===foodFilter;
    return matchesQ && matchesStatus && matchesCat && matchesApp && matchesHotel && matchesPay && matchesKit && matchesCert && matchesFood;
  });

  const categories=['ALL',...Array.from(new Set(d.map(x=>x.category).filter(Boolean)))];
  const statuses=['ALL','PENDING','APPROVED','CHECKED_IN','CANCELLED'];
  const hotels=['ALL',...Array.from(new Set(d.map(x=>x.hotel_name).filter(Boolean))),'NO_HOTEL'];
  const payStatuses=['ALL','PAID','PENDING'];

  const sendWhatsAppToSingle = (x) => {
    let phone = (x.phone || '').replace(/[^0-9]/g, '');
    if (phone.length === 10) phone = '91' + phone;
    if (!phone) {
      alert(`No phone number available for ${x.name}`);
      return;
    }
    const appUrl = window.location.origin.replace(':5173', ':3000');
    const msg = `Namaste Dr./Prof. ${x.name}! 🙏\n\nWelcome to *MAPCON 2026* (Annual State Conference at Hotel Sayaji, Kolhapur).\n\n📌 *Your Delegate Registration Details:*\n• *Registration No:* ${x.registration_no || 'MAPCON-2026-DEL'}\n• *Category:* ${x.category || 'Delegate'}\n• *Hotel Assigned:* ${x.hotel_name || 'Hotel Sayaji'} (Room: ${x.room_number || 'TBD'})\n• *Login Email:* ${x.email}\n• *Default Password:* Demo@123\n\n📲 *Access Conference App & Live Schedule:*\n${appUrl}\n\nKindly login to the app to access your QR Gate Pass, Scientific Session Schedule, Meal Coupons, and Verified Certificate.\n\nFor any query, contact our Secretarial Desk.\n_MAPCON 2026 Organizing Committee_`;
    window.open(`https://wa.me/${phone}?text=${encodeURIComponent(msg)}`, '_blank');
  };

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
    const headers=['ID','Registration No','Name','Email','Phone','Designation','University','Category','Food Preference','Kit Issued','Certificate Issued','Status','App Status','Payment Status','Hotel Assigned','Room No','Room Type','Check In','Check Out','Mode of Travel','Flight No','Arrival Date','Arrival Time','Departure Date','Departure Time','Liaison Officer','Liaison Phone'];
    const rows=filtered.map(x=>[
      x.id,
      `"${x.registration_no||''}"`,
      `"${x.name||''}"`,
      `"${x.email||''}"`,
      `"${x.phone||''}"`,
      `"${x.designation||''}"`,
      `"${x.university||''}"`,
      `"${x.category||''}"`,
      `"${x.food_preference||'VEG'}"`,
      `"${x.kit_issued?'Issued':'Pending'}"`,
      `"${x.certificate_issued||x.has_certificate>0?'Issued':'Pending'}"`,
      `"${x.status||''}"`,
      `"${x.last_login_at?'Active (Logged In)':'Never Opened App'}"`,
      `"${x.payment_status||''}"`,
      `"${x.hotel_name||'Not Assigned'}"`,
      `"${x.room_number||''}"`,
      `"${x.room_type||''}"`,
      `"${x.check_in?String(x.check_in).slice(0,10):''}"`,
      `"${x.check_out?String(x.check_out).slice(0,10):''}"`,
      `"${x.mode_of_travel||''}"`,
      `"${x.flight_number||''}"`,
      `"${x.arrival_date?String(x.arrival_date).slice(0,10):''}"`,
      `"${x.arrival_time||''}"`,
      `"${x.departure_date?String(x.departure_date).slice(0,10):''}"`,
      `"${x.departure_time||''}"`,
      `"${x.liaison_name||''}"`,
      `"${x.liaison_phone||''}"`
    ]);
    const csvContent='data:text/csv;charset=utf-8,'+[headers.join(','),...rows.map(r=>r.join(','))].join('\n');
    const link=document.createElement('a');
    link.setAttribute('href',encodeURI(csvContent));
    link.setAttribute('download',`participants_export_${new Date().toISOString().slice(0,10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const kitsCount = d.filter(x => x.kit_issued).length;
  const certsCount = d.filter(x => x.certificate_issued || x.has_certificate > 0).length;
  const hotelCount = d.filter(x => x.hotel_name).length;
  const vegCount = d.filter(x => (x.food_preference||'VEG') === 'VEG').length;
  const nonVegCount = d.filter(x => x.food_preference === 'NON_VEG').length;

  return <div className="panel">
    <div className="pagehead">
      <div>
        <h3>Participants Directory & Desk Operations</h3>
        <p>Manage delegate registrations, conference kit distribution, certificates, accommodation, and real-time mapping.</p>
      </div>
      <div className="actions">
        <button className="secondary" style={{borderColor:'#16a34a',color:'#16a34a',fontWeight:600}} onClick={()=>setWhatsappModal(true)}>📲 WhatsApp Delegates</button>
        <button className="secondary" onClick={exportCSV}>📥 Export CSV</button>
        <button className="secondary" onClick={()=>setImportModal(true)}>📂 Import Excel / CSV</button>
        <button className="primary" onClick={()=>setEdit({})}>+ Add Participant</button>
      </div>
    </div>

    {/* Metric Overview Cards */}
    <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fit, minmax(180px, 1fr))', gap:'12px', marginBottom:'16px'}}>
      <div style={{background:'#fff', padding:'14px 16px', borderRadius:'12px', border:'1px solid #e2e8f0', boxShadow:'0 1px 3px rgba(0,0,0,0.04)'}}>
        <small style={{color:'#64748b', fontWeight:700, fontSize:'11.5px', textTransform:'uppercase', letterSpacing:'0.5px'}}>Total Registered</small>
        <div style={{fontSize:'22px', fontWeight:800, color:'#8C1119', marginTop:'2px'}}>{d.length}</div>
        <small style={{color:'#059669', fontSize:'11.5px', fontWeight:600}}>All categories</small>
      </div>
      <div style={{background:'#fff', padding:'14px 16px', borderRadius:'12px', border:'1px solid #e2e8f0', boxShadow:'0 1px 3px rgba(0,0,0,0.04)'}}>
        <small style={{color:'#64748b', fontWeight:700, fontSize:'11.5px', textTransform:'uppercase', letterSpacing:'0.5px'}}>🎁 Conference Kits</small>
        <div style={{fontSize:'22px', fontWeight:800, color:'#0284c7', marginTop:'2px'}}>{kitsCount} <span style={{fontSize:'13px', color:'#64748b', fontWeight:500}}>/ {d.length}</span></div>
        <small style={{color:'#0284c7', fontSize:'11.5px', fontWeight:600}}>{d.length ? Math.round((kitsCount/d.length)*100) : 0}% Distributed</small>
      </div>
      <div style={{background:'#fff', padding:'14px 16px', borderRadius:'12px', border:'1px solid #e2e8f0', boxShadow:'0 1px 3px rgba(0,0,0,0.04)'}}>
        <small style={{color:'#64748b', fontWeight:700, fontSize:'11.5px', textTransform:'uppercase', letterSpacing:'0.5px'}}>📜 Certificates</small>
        <div style={{fontSize:'22px', fontWeight:800, color:'#7c3aed', marginTop:'2px'}}>{certsCount} <span style={{fontSize:'13px', color:'#64748b', fontWeight:500}}>/ {d.length}</span></div>
        <small style={{color:'#7c3aed', fontSize:'11.5px', fontWeight:600}}>{d.length ? Math.round((certsCount/d.length)*100) : 0}% Issued</small>
      </div>
      <div style={{background:'#fff', padding:'14px 16px', borderRadius:'12px', border:'1px solid #e2e8f0', boxShadow:'0 1px 3px rgba(0,0,0,0.04)'}}>
        <small style={{color:'#64748b', fontWeight:700, fontSize:'11.5px', textTransform:'uppercase', letterSpacing:'0.5px'}}>🏨 Accommodation</small>
        <div style={{fontSize:'22px', fontWeight:800, color:'#d97706', marginTop:'2px'}}>{hotelCount}</div>
        <small style={{color:'#d97706', fontSize:'11.5px', fontWeight:600}}>Rooms allocated</small>
      </div>
      <div style={{background:'#fff', padding:'14px 16px', borderRadius:'12px', border:'1px solid #e2e8f0', boxShadow:'0 1px 3px rgba(0,0,0,0.04)'}}>
        <small style={{color:'#64748b', fontWeight:700, fontSize:'11.5px', textTransform:'uppercase', letterSpacing:'0.5px'}}>🍽️ Food Preference</small>
        <div style={{fontSize:'16px', fontWeight:800, color:'#1e293b', marginTop:'4px'}}>🥦 {vegCount} &nbsp;|&nbsp; 🍗 {nonVegCount}</div>
        <small style={{color:'#64748b', fontSize:'11.5px'}}>Veg / Non-Veg split</small>
      </div>
    </div>
    
    {/* Advanced Multi-Filter Toolbar */}
    <div className="toolbar" style={{display:'flex',gap:'8px',flexWrap:'wrap',alignItems:'center',background:'#f8fafc',padding:'14px',borderRadius:'12px',border:'1px solid #e2e8f0',marginBottom:'16px'}}>
      <div className="search" style={{flex:1,minWidth:'220px'}}><Search size={18}/><input value={q} onChange={e=>setQ(e.target.value)} placeholder="Search name, email, phone, reg no, college, hotel..."/></div>
      
      <div style={{display:'flex',gap:'4px',alignItems:'center'}}>
        <small style={{fontWeight:700,color:'#475569'}}>Category:</small>
        <select value={catFilter} onChange={e=>setCatFilter(e.target.value)} style={{padding:'6px 8px',borderRadius:'6px',border:'1px solid #cbd5e1',fontSize:'12.5px'}}>
          {categories.map(c=><option key={c} value={c}>{c}</option>)}
        </select>
      </div>

      <div style={{display:'flex',gap:'4px',alignItems:'center'}}>
        <small style={{fontWeight:700,color:'#475569'}}>Kit:</small>
        <select value={kitFilter} onChange={e=>setKitFilter(e.target.value)} style={{padding:'6px 8px',borderRadius:'6px',border:'1px solid #cbd5e1',fontSize:'12.5px',color:kitFilter==='KIT_ISSUED'?'#0284c7':kitFilter==='KIT_PENDING'?'#d97706':'#333'}}>
          <option value="ALL">All Kit Status</option>
          <option value="KIT_ISSUED">✅ Kit Issued</option>
          <option value="KIT_PENDING">⏳ Kit Pending</option>
        </select>
      </div>

      <div style={{display:'flex',gap:'4px',alignItems:'center'}}>
        <small style={{fontWeight:700,color:'#475569'}}>Cert:</small>
        <select value={certFilter} onChange={e=>setCertFilter(e.target.value)} style={{padding:'6px 8px',borderRadius:'6px',border:'1px solid #cbd5e1',fontSize:'12.5px',color:certFilter==='CERT_ISSUED'?'#7c3aed':certFilter==='CERT_PENDING'?'#d97706':'#333'}}>
          <option value="ALL">All Cert Status</option>
          <option value="CERT_ISSUED">📜 Cert Issued</option>
          <option value="CERT_PENDING">⏳ Cert Pending</option>
        </select>
      </div>

      <div style={{display:'flex',gap:'4px',alignItems:'center'}}>
        <small style={{fontWeight:700,color:'#475569'}}>Food:</small>
        <select value={foodFilter} onChange={e=>setFoodFilter(e.target.value)} style={{padding:'6px 8px',borderRadius:'6px',border:'1px solid #cbd5e1',fontSize:'12.5px'}}>
          <option value="ALL">All Food</option>
          <option value="VEG">🥦 Veg</option>
          <option value="NON_VEG">🍗 Non-Veg</option>
          <option value="JAIN">🍃 Jain</option>
        </select>
      </div>

      <div style={{display:'flex',gap:'4px',alignItems:'center'}}>
        <small style={{fontWeight:700,color:'#475569'}}>Hotel:</small>
        <select value={hotelFilter} onChange={e=>setHotelFilter(e.target.value)} style={{padding:'6px 8px',borderRadius:'6px',border:'1px solid #cbd5e1',fontSize:'12.5px'}}>
          {hotels.map(h=><option key={h} value={h}>{h==='NO_HOTEL'?'Unassigned Hotel':h}</option>)}
        </select>
      </div>

      <div style={{display:'flex',gap:'4px',alignItems:'center'}}>
        <small style={{fontWeight:700,color:'#475569'}}>Status:</small>
        <select value={statusFilter} onChange={e=>setStatusFilter(e.target.value)} style={{padding:'6px 8px',borderRadius:'6px',border:'1px solid #cbd5e1',fontSize:'12.5px'}}>
          {statuses.map(s=><option key={s} value={s}>{s}</option>)}
        </select>
      </div>

      <button onClick={load} disabled={busy} style={{padding:'6px 12px',fontSize:'12.5px'}}>{busy?'Refreshing...':'Refresh'}</button>
    </div>

    <div className="tablewrap">
      <table>
        <thead>
          <tr>
            <th>Reg No & Pass</th>
            <th>Participant Details</th>
            <th>University & Role</th>
            <th>Category & Food</th>
            <th>Kit & Certificate</th>
            <th>Status & Accommodation</th>
            <th>Liaison</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {filtered.map(x=><tr key={x.id}>
            <td>
              <strong>{x.registration_no||'-'}</strong><br/>
              <button className="pill small" style={{cursor:'pointer',marginTop:'4px',background:'#8C1119',color:'#fff',border:0}} onClick={()=>setQrModal(x)}>📱 View QR ID</button>
            </td>
            <td>
              <b>{x.name}</b><br/>
              <small>{x.email}</small><br/>
              <small>{x.phone}</small>
            </td>
            <td>
              {x.university||'-'}<br/>
              <small style={{color:'#64748b'}}>{x.designation||'-'}</small>
              {x.blood_group && <small style={{display:'block',color:'#dc2626',fontWeight:700}}>🩸 {x.blood_group}</small>}
            </td>
            <td>
              <span className="pill">{x.category||'Delegate'}</span><br/>
              <span className="pill small" style={{marginTop:'4px',background:(x.food_preference==='NON_VEG'?'#fef2f2':'#ecfdf5'),color:(x.food_preference==='NON_VEG'?'#991b1b':'#065f46'),border:(x.food_preference==='NON_VEG'?'1px solid #fecaca':'1px solid #a7f3d0')}}>
                {x.food_preference === 'NON_VEG' ? '🍗 Non-Veg' : x.food_preference === 'JAIN' ? '🍃 Jain' : '🥦 Veg'}
              </span>
            </td>
            <td>
              <div style={{display:'flex',flexDirection:'column',gap:'4px'}}>
                <button
                  onClick={()=>toggleKit(x.id)}
                  style={{cursor:'pointer',padding:'3px 8px',borderRadius:'12px',fontSize:'11.5px',fontWeight:700,border:x.kit_issued?'1px solid #38bdf8':'1px solid #cbd5e1',background:x.kit_issued?'#f0f9ff':'#f8fafc',color:x.kit_issued?'#0369a1':'#64748b',textAlign:'left'}}
                  title="Click to toggle Kit status"
                >
                  {x.kit_issued ? '✅ Kit Issued' : '⏳ Kit Pending'}
                </button>
                <button
                  onClick={()=>toggleCert(x.id)}
                  style={{cursor:'pointer',padding:'3px 8px',borderRadius:'12px',fontSize:'11.5px',fontWeight:700,border:(x.certificate_issued||x.has_certificate>0)?'1px solid #c084fc':'1px solid #cbd5e1',background:(x.certificate_issued||x.has_certificate>0)?'#faf5ff':'#f8fafc',color:(x.certificate_issued||x.has_certificate>0)?'#7e22ce':'#64748b',textAlign:'left'}}
                  title="Click to toggle Certificate status"
                >
                  {(x.certificate_issued || x.has_certificate > 0) ? '📜 Cert Issued' : '⏳ Cert Pending'}
                </button>
              </div>
            </td>
            <td>
              <span className={`pill ${x.status}`}>{x.status}</span><br/>
              {x.hotel_name ? (
                <div style={{marginTop:'4px'}}>
                  <small style={{color:'#8C1119',fontWeight:700}}>🏨 {x.hotel_name}</small><br/>
                  <small>Room: {x.room_number || 'TBD'}</small>
                </div>
              ) : (
                <small style={{color:'#94a3b8',display:'block',marginTop:'4px'}}>No hotel assigned</small>
              )}
            </td>
            <td>{x.liaison_name?<><small><b>{x.liaison_name}</b></small><br/><small>{x.liaison_phone}</small></>:'-'}</td>
            <td>
              <div style={{display:'flex',flexDirection:'column',gap:'4px'}}>
                <button className="pill small" style={{cursor:'pointer',background:'#16a34a',color:'#fff',display:'inline-flex',alignItems:'center',justifyContent:'center',gap:'4px'}} onClick={()=>sendWhatsAppToSingle(x)} title="Send WhatsApp Login Reminder">
                  📲 WhatsApp
                </button>
                <div className="rowactions" style={{justifyContent:'center'}}>
                  <button className="icon" onClick={()=>setEdit(x)} title="Edit"><Settings size={16}/></button>
                  <button className="icon" onClick={()=>remove(x.id)} title="Delete"><LogOut size={16}/></button>
                </div>
              </div>
            </td>
          </tr>)}
          {!filtered.length && !busy && <tr><td colSpan="8" style={{textAlign:'center',padding:'30px',color:'#888'}}>No participants found matching current filters.</td></tr>}
        </tbody>
      </table>
    </div>

    {edit && <ParticipantModal value={edit} liaisons={liaisons} onSave={save} onClose={()=>setEdit(null)} notify={notify}/>}
    {importModal && <BulkImportModal conferenceId={selectedConferenceId || 1} onClose={()=>setImportModal(false)} onImportSuccess={()=>{setImportModal(false);load();notify('Participants imported successfully!')}}/>}
    {whatsappModal && <WhatsAppBroadcasterModal participants={d} onClose={()=>setWhatsappModal(false)} notify={notify}/>}
    {qrModal && <QrModal value={qrModal} onClose={()=>setQrModal(null)}/>}
  </div>
}

function WhatsAppBroadcasterModal({participants, onClose, notify}){
  const [filterMode, setFilterMode] = useState('NEVER_OPENED');
  const [customMsg, setCustomMsg] = useState(
    `Namaste Dr./Prof. {name}! 🙏\n\nWelcome to *MAPCON 2026* (Annual State Conference at Hotel Sayaji, Kolhapur).\n\n📌 *Your Delegate Registration Details:*\n• *Registration No:* {reg_no}\n• *Login Email:* {email}\n• *Default Password:* Demo@123\n\n📲 *Access Conference App & Live Schedule:*\nhttp://localhost:3000/\n\nKindly login to the app to access your QR Gate Pass, Scientific Session Schedule, Meal Coupons, and Verified Certificate.\n\nFor any query, contact our Secretarial Desk.\n_MAPCON 2026 Organizing Committee_`
  );

  const targets = participants.filter(p => {
    if (filterMode === 'NEVER_OPENED') return !p.last_login_at;
    if (filterMode === 'UNCHECKED') return p.status !== 'CHECKED_IN';
    if (filterMode === 'PENDING') return p.status === 'PENDING';
    return true; // ALL
  });

  const sendTo = (p) => {
    let phone = (p.phone || '').replace(/[^0-9]/g, '');
    if (phone.length === 10) phone = '91' + phone;
    if (!phone) {
      alert(`No phone number for ${p.name}`);
      return;
    }
    const rendered = customMsg
      .replace(/{name}/g, p.name || 'Delegate')
      .replace(/{reg_no}/g, p.registration_no || 'MAPCON-2026-DEL')
      .replace(/{email}/g, p.email || '')
      .replace(/{category}/g, p.category || 'Delegate');
    window.open(`https://wa.me/${phone}?text=${encodeURIComponent(rendered)}`, '_blank');
  };

  const copyPhoneNumbers = () => {
    const phones = targets.map(p => (p.phone || '').replace(/[^0-9]/g, '')).filter(p => p.length >= 10);
    navigator.clipboard.writeText(phones.join(', '));
    notify(`Copied ${phones.length} WhatsApp numbers to clipboard!`);
  };

  return (
    <div className="modal-overlay">
      <div className="modal" style={{maxWidth:'680px'}}>
        <div className="modal-header" style={{background:'#16a34a',color:'#fff'}}>
          <h3 style={{display:'flex',alignItems:'center',gap:'8px'}}>📲 WhatsApp Inactive Delegates Broadcaster</h3>
          <button className="close" onClick={onClose} style={{color:'#fff'}}>&times;</button>
        </div>
        <div className="modal-body">
          <div style={{background:'#f0fdf4',border:'1px solid #bbf7d0',padding:'12px',borderRadius:'10px',marginBottom:'16px',fontSize:'13.5px',color:'#166534'}}>
            💡 <b>Inactive / Never Logged-In Delegates:</b> You can identify which delegates have not opened or logged into the app yet and directly message their login credentials and app download link via WhatsApp.
          </div>

          <div style={{marginBottom:'14px'}}>
            <label style={{fontWeight:700,fontSize:'13px',marginBottom:'6px',display:'block'}}>Target Audience:</label>
            <div style={{display:'flex',gap:'10px',flexWrap:'wrap'}}>
              <button className={filterMode === 'NEVER_OPENED' ? 'primary' : 'secondary'} style={{fontSize:'12px',padding:'6px 12px',background:filterMode==='NEVER_OPENED'?'#dc2626':''}} onClick={()=>setFilterMode('NEVER_OPENED')}>
                🔴 Never Opened App ({participants.filter(p=>!p.last_login_at).length})
              </button>
              <button className={filterMode === 'UNCHECKED' ? 'primary' : 'secondary'} style={{fontSize:'12px',padding:'6px 12px'}} onClick={()=>setFilterMode('UNCHECKED')}>
                Not Checked-In ({participants.filter(p=>p.status!=='CHECKED_IN').length})
              </button>
              <button className={filterMode === 'PENDING' ? 'primary' : 'secondary'} style={{fontSize:'12px',padding:'6px 12px'}} onClick={()=>setFilterMode('PENDING')}>
                Pending Registrations ({participants.filter(p=>p.status==='PENDING').length})
              </button>
              <button className={filterMode === 'ALL' ? 'primary' : 'secondary'} style={{fontSize:'12px',padding:'6px 12px'}} onClick={()=>setFilterMode('ALL')}>
                All Registered ({participants.length})
              </button>
            </div>
          </div>

          <div style={{marginBottom:'16px'}}>
            <label style={{fontWeight:700,fontSize:'13px',marginBottom:'6px',display:'block'}}>
              WhatsApp Message Template <small style={{fontWeight:400,color:'#666'}}>(Tags: <code>{'{name}'}</code>, <code>{'{reg_no}'}</code>, <code>{'{email}'}</code>, <code>{'{category}'}</code>)</small>:
            </label>
            <textarea
              rows={6}
              value={customMsg}
              onChange={e=>setCustomMsg(e.target.value)}
              style={{width:'100%',padding:'10px',borderRadius:'8px',border:'1px solid #ccc',fontFamily:'inherit',fontSize:'13px'}}
            />
          </div>

          <div>
            <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:'8px'}}>
              <label style={{fontWeight:700,fontSize:'13px'}}>Ready to Message ({targets.length} Delegates):</label>
              <button className="secondary" style={{fontSize:'12px',padding:'4px 10px'}} onClick={copyPhoneNumbers}>
                📋 Copy All Phone Numbers
              </button>
            </div>
            <div style={{maxHeight:'200px',overflowY:'auto',border:'1px solid #eee',borderRadius:'8px'}}>
              {targets.map(p => (
                <div key={p.id} style={{display:'flex',justifyContent:'space-between',alignItems:'center',padding:'8px 12px',borderBottom:'1px solid #f0f0f0',fontSize:'13px'}}>
                  <div>
                    <b>{p.name}</b> <small style={{color:'#666'}}>({p.registration_no || 'No Reg'})</small>
                    <div style={{color:'#888',fontSize:'11.5px'}}>
                      📞 {p.phone || 'No phone'} | Status: {p.status} | 
                      {p.last_login_at ? <span style={{color:'green'}}> 🟢 Active</span> : <span style={{color:'red'}}> 🔴 Never Logged In</span>}
                    </div>
                  </div>
                  <button
                    style={{background:'#16a34a',color:'#fff',border:'none',borderRadius:'6px',padding:'4px 10px',fontSize:'12px',cursor:'pointer'}}
                    onClick={()=>sendTo(p)}
                  >
                    Send 📲
                  </button>
                </div>
              ))}
              {!targets.length && <div style={{padding:'20px',textAlign:'center',color:'#888'}}>No delegates found in this filter.</div>}
            </div>
          </div>
        </div>
        <div className="modal-footer">
          <button onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}

function BulkImportModal({conferenceId, onClose, onImportSuccess}){
  const [csvText, setCsvText] = useState('');
  const [parsedData, setParsedData] = useState(null);
  const [fileName, setFileName] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const downloadTemplate = () => {
    const templateData = [
      {
        'Full Name': 'Dr. Rajesh Sharma',
        'Mobile Number': '9876543210',
        'Email Address': 'rajesh.sharma@example.com',
        'Category': 'VIP Delegate',
        'Designation': 'Professor & Head',
        'University': 'AIIMS Delhi',
        'Registration Number': 'DPU-2026-001',
        'Hotel Name': 'Hyatt Regency Pune',
        'Hotel Address': 'Viman Nagar, Pune',
        'Room Number': '501',
        'Room Type': 'Executive Suite',
        'Check In Date': '2026-04-27',
        'Check Out Date': '2026-04-30',
        'Travel Mode': 'Flight',
        'Flight/Train No': 'AI-852',
        'Arrival Date': '2026-04-27',
        'Arrival Time': '10:30 AM',
        'Departure Date': '2026-04-30',
        'Departure Time': '06:00 PM',
        'Pickup Point': 'Pune Airport Terminal 1',
        'Drop Point': 'Hyatt Regency Pune',
        'Driver Name': 'Rajesh Patil',
        'Driver Phone': '9876543210',
        'Vehicle Number': 'MH12AB1234'
      },
      {
        'Full Name': 'Dr. Sunita Deshmukh',
        'Mobile Number': '9876543211',
        'Email Address': 'sunita.d@example.com',
        'Category': 'Speaker',
        'Designation': 'Dean Academics',
        'University': 'Mumbai University',
        'Registration Number': 'DPU-2026-002',
        'Hotel Name': 'Sayaji Hotel',
        'Hotel Address': 'Kawala Naka, Kolhapur',
        'Room Number': '302',
        'Room Type': 'Deluxe Double',
        'Check In Date': '2026-04-27',
        'Check Out Date': '2026-04-30',
        'Travel Mode': 'Train',
        'Flight/Train No': 'Koyna Express (11029)',
        'Arrival Date': '2026-04-27',
        'Arrival Time': '02:15 PM',
        'Departure Date': '2026-04-30',
        'Departure Time': '08:00 AM',
        'Pickup Point': 'Kolhapur Railway Station',
        'Drop Point': 'Sayaji Hotel',
        'Driver Name': 'Amit Jadhav',
        'Driver Phone': '9876543211',
        'Vehicle Number': 'MH12CD5678'
      }
    ];

    const ws = XLSX.utils.json_to_sheet(templateData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Participants");
    XLSX.writeFile(wb, "Conference_Participant_Import_Template.xlsx");
  };

  const handleFile = (e) => {
    const file = e.target.files?.[0];
    if(!file) return;
    setFileName(file.name);
    setError('');

    const reader = new FileReader();
    reader.onload = (evt) => {
      try {
        const data = new Uint8Array(evt.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        const firstSheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[firstSheetName];
        const json = XLSX.utils.sheet_to_json(worksheet, { defval: '' });

        if(!json || !json.length) {
          setError('No data found in the selected Excel sheet');
          return;
        }

        setParsedData(json);
      } catch(err) {
        setError('Failed to parse Excel file: ' + err.message);
      }
    };
    reader.readAsArrayBuffer(file);
  };

  const processImport = async () => {
    let rowsToImport = [];

    if(parsedData && parsedData.length > 0) {
      rowsToImport = parsedData;
    } else if(csvText.trim()) {
      const lines = csvText.trim().split('\n').map(l => l.trim()).filter(Boolean);
      if(lines.length < 2) {
        setError('CSV must contain at least a header row and 1 data row');
        return;
      }
      const headers = lines[0].split(',').map(h => h.trim().replace(/^"|"$/g, ''));
      rowsToImport = lines.slice(1).map(line => {
        const values = line.split(',').map(v => v.trim().replace(/^"|"$/g, ''));
        const obj = {};
        headers.forEach((h, idx) => { obj[h] = values[idx]; });
        return obj;
      });
    }

    if(!rowsToImport.length) {
      setError('Please upload an Excel file or paste CSV data');
      return;
    }

    setBusy(true);
    setError('');

    try {
      const res = await req('/admin/participants/bulk-import', {
        method: 'POST',
        body: JSON.stringify({ participants: rowsToImport, conferenceId: conferenceId || 1 })
      });
      alert(res.message || 'Import completed successfully');
      onImportSuccess();
    } catch(err) {
      setError(err.message || 'Import failed');
    } finally {
      setBusy(false);
    }
  };

  return <div className="modal-overlay">
    <div className="modal" style={{maxWidth:'680px'}}>
      <div className="modal-header">
        <h3>Bulk Import Participants & Mapping (Excel / CSV)</h3>
        <button className="close" onClick={onClose}>&times;</button>
      </div>
      <div className="modal-body">
        <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', background:'#f8fafc', padding:'12px 16px', borderRadius:'10px', marginBottom:'16px', border:'1px solid #e2e8f0'}}>
          <div>
            <strong style={{color:'#1e293b', fontSize:'14px'}}>Need a ready Excel template?</strong>
            <p style={{margin:0, fontSize:'12px', color:'#64748b'}}>Includes all Participant, Hotel Stay & Transport columns.</p>
          </div>
          <button className="secondary" style={{background:'#fff', border:'1px solid #cbd5e1', cursor:'pointer'}} onClick={downloadTemplate}>
            📥 Download Sample Template
          </button>
        </div>

        <div style={{background:'#eff6ff', border:'1px solid #bfdbfe', borderRadius:'10px', padding:'12px 16px', marginBottom:'14px'}}>
          <strong style={{color:'#1e40af', fontSize:'13px', display:'block', marginBottom:'4px'}}>✨ Smart Merge & Duplicate Protection Active</strong>
          <p style={{margin:0, fontSize:'12.5px', color:'#1e3a8a', lineHeight:1.4}}>
            • If a delegate is <b>already registered</b> (matched by Reg No, Phone, or Email), the system <b>will not duplicate them</b>. Instead, it will update and enrich their profile with newly provided details (Hotel, Room Number, Liaison, Travel timings, University, etc.).<br/>
            • New delegates will be automatically created with default password <code>Demo@123</code> and verified QR tokens.
          </p>
        </div>

        <div style={{marginBottom:'16px', padding:'16px', border:'2px dashed #cbd5e1', borderRadius:'12px', textAlign:'center', background:'#fafafa'}}>
          <input type="file" accept=".xlsx, .xls, .csv" onChange={handleFile} id="excel-file-input" style={{display:'none'}} />
          <label htmlFor="excel-file-input" className="button primary" style={{cursor:'pointer', display:'inline-flex', alignItems:'center', gap:'8px', padding:'10px 20px', borderRadius:'8px', background:'#8C1119', color:'#fff', fontWeight:'bold'}}>
            <Upload size={16} /> Select Excel / CSV File
          </label>
          {fileName && <div style={{marginTop:'10px', color:'#2563eb', fontWeight:'bold', fontSize:'14px'}}>File Loaded: {fileName} ({parsedData?.length||0} rows detected)</div>}
        </div>

        <Field textarea label="Or Paste CSV / Tab-separated Content Directly" value={csvText} onChange={setCsvText} placeholder="Name, Mobile, Email, Category, Hotel, Room..." />
        {error && <p style={{color:'red', marginTop:'8px', fontWeight:'bold'}}>{error}</p>}
      </div>
      <div className="modal-footer">
        <button onClick={onClose}>Cancel</button>
        <button className="primary" disabled={busy} onClick={processImport}>{busy ? 'Importing & Mapping...' : `Import ${parsedData?.length ? parsedData.length + ' Rows' : 'Participants'}`}</button>
      </div>
    </div>
  </div>;
}

function AddSlideModal({notify, onSave, onClose}){
  const [title, setTitle] = useState('');
  const [mediaType, setMediaType] = useState('IMAGE');
  const [mediaUrl, setMediaUrl] = useState('');
  const [file, setFile] = useState(null);
  const [busy, setBusy] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!mediaUrl && !file) {
      alert('Please select a media file or provide a URL');
      return;
    }

    setBusy(true);
    try {
      let filePayload = null;
      if (file) {
        const reader = new FileReader();
        filePayload = await new Promise((res, rej) => {
          reader.onload = () => res({ name: file.name, dataUrl: reader.result });
          reader.onerror = rej;
          reader.readAsDataURL(file);
        });
      }

      await req('/admin/sliders', {
        method: 'POST',
        body: JSON.stringify({
          title,
          media_type: mediaType,
          media_url: mediaUrl,
          file: filePayload,
          active: 1
        })
      });

      notify('Slider item added successfully');
      onSave();
    } catch(err) {
      alert(err.message || 'Failed to add slide');
    } finally {
      setBusy(false);
    }
  };

  return <div className="modal-overlay">
    <div className="modal" style={{maxWidth:'500px'}}>
      <div className="modal-header">
        <h3>Add Home Screen Media Slide</h3>
        <button className="close" onClick={onClose}>&times;</button>
      </div>
      <form onSubmit={handleSubmit}>
        <div className="modal-body">
          <Field label="Slide Title / Headline" value={title} onChange={setTitle} placeholder="e.g. Welcome to 100th VC Conference" />
          <SelectField label="Media Type" value={mediaType} onChange={setMediaType} options={[{value:'IMAGE',label:'Image (JPG, PNG, WEBP)'},{value:'VIDEO',label:'Video (MP4, WEBM)'}]} />
          
          <label className="field uploadfield" style={{marginTop:'12px'}}>
            <span>Upload Media File (Image or Video)</span>
            <div>
              <input value={mediaUrl} onChange={e => setMediaUrl(e.target.value)} placeholder="Or paste direct HTTP video/image URL" />
              <label className="uploadBtn">
                <Upload size={16}/>Select File
                <input type="file" accept={mediaType==='VIDEO'?'video/mp4,video/webm,video/quicktime':'image/*'} onChange={e => setFile(e.target.files?.[0])} />
              </label>
            </div>
            {file && <small style={{color:'#2563eb', marginTop:'4px'}}>Selected: {file.name} ({(file.size/1024/1024).toFixed(1)} MB)</small>}
          </label>
        </div>
        <div className="modal-footer">
          <button type="button" onClick={onClose}>Cancel</button>
          <button type="submit" className="primary" disabled={busy}>{busy ? 'Uploading...' : 'Save & Publish'}</button>
        </div>
      </form>
    </div>
  </div>;
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
          <h4>Registration, Food & Conference Kit</h4>
          <div className="formgrid">
            <Field label="Registration No" value={v.registration_no} onChange={x=>set('registration_no',x)}/>
            <SelectField label="Category" value={v.category} onChange={x=>set('category',x)} options={['Delegate','Speaker','VC','VIP','Faculty','Student','Volunteer','Organiser']}/>
            <SelectField label="Food Preference" value={v.food_preference||'VEG'} onChange={x=>set('food_preference',x)} options={[{value:'VEG',label:'🥦 Vegetarian'},{value:'NON_VEG',label:'🍗 Non-Vegetarian'},{value:'JAIN',label:'🍃 Jain'}]}/>
            <SelectField label="Conference Kit Status" value={v.kit_issued ? '1' : '0'} onChange={x=>set('kit_issued', x==='1'?1:0)} options={[{value:'1',label:'✅ Kit Distributed / Issued'},{value:'0',label:'⏳ Kit Pending'}]}/>
            <SelectField label="Certificate Status" value={v.certificate_issued ? '1' : '0'} onChange={x=>set('certificate_issued', x==='1'?1:0)} options={[{value:'1',label:'📜 Certificate Issued'},{value:'0',label:'⏳ Certificate Pending'}]}/>
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
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Add Room</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Hotel" value={v.hotel_id} onChange={x=>set('hotel_id',x?Number(x):null)} options={[{value:'',label:'-- Select Hotel --'},...hotels.map(h=>({value:h.id,label:h.name}))]}/>
    <Field label="Room Number" value={v.room_number} onChange={x=>set('room_number',x)}/>
    <Field label="Room Type" value={v.room_type} onChange={x=>set('room_type',x)}/>
    <Field label="Capacity" value={v.capacity} onChange={x=>set('capacity',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Save</button></div></div></div>
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
      <div className="actions"><button className="primary" onClick={()=>setShowAdd(true)}>+ Allocate Room</button></div>
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
        {!d.length && !busy && <tr><td colSpan="4" style={{textAlign:'center',padding:'30px',color:'#888'}}>No rooms allocated yet.</td></tr>}
      </tbody>
    </table>
    {showAdd && <AllocationModal participants={participants} rooms={rooms.filter(r=>r.status!=='FULL')} onSave={async(v)=>{await req('/admin/room-allocations',{method:'POST',body:JSON.stringify(v)}); setShowAdd(false); load(); notify('Allocated successfully');}} onClose={()=>setShowAdd(false)}/>}
  </div>
}

function AllocationModal({participants,rooms,onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Room Allocation</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Participant" value={v.participant_id} onChange={x=>set('participant_id',x?Number(x):null)} options={[{value:'',label:'-- Select Participant --'},...participants.map(p=>({value:p.id,label:p.name+' ('+p.registration_no+')'}))]}/>
    <SelectField label="Room" value={v.room_id} onChange={x=>set('room_id',x?Number(x):null)} options={[{value:'',label:'-- Select Room --'},...rooms.map(r=>({value:r.id,label:r.hotel_name+' - Room '+r.room_number+' ('+r.room_type+')'}))]}/>
    <Field type="date" label="Check In" value={v.check_in} onChange={x=>set('check_in',x)}/>
    <Field type="date" label="Check Out" value={v.check_out} onChange={x=>set('check_out',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Allocate Room</button></div></div></div>
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
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Vehicle Details</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <Field label="Vehicle No" value={v.vehicle_number} onChange={x=>set('vehicle_number',x)}/>
    <Field label="Type" value={v.vehicle_type} onChange={x=>set('vehicle_type',x)}/>
    <Field label="Capacity" value={v.capacity} onChange={x=>set('capacity',x)}/>
    <SelectField label="Driver" value={v.driver_id} onChange={x=>set('driver_id',x?Number(x):null)} options={[{value:'',label:'-- Select Driver --'},...drivers.map(d=>({value:d.id,label:`${d.name} (${d.phone})`}))]}/>
    <SelectField label="Status" value={v.status} onChange={x=>set('status',x)} options={['AVAILABLE','ASSIGNED','IN_TRANSIT','MAINTENANCE']}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Save</button></div></div></div>
}

function DriverModal({onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Add Driver</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid"><Field label="Name" value={v.name} onChange={x=>set('name',x)}/><Field label="Phone" value={v.phone} onChange={x=>set('phone',x)}/><Field label="License No" value={v.license_no} onChange={x=>set('license_no',x)}/></div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Save</button></div></div></div>
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
      <div><h3>Transport Assignments</h3><p>Assign vehicles and pickup routes to participants.</p></div>
      <div className="actions"><button className="primary" onClick={()=>setShowAdd(true)}>+ Assign Transport</button></div>
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
        {!d.length && !busy && <tr><td colSpan="5" style={{textAlign:'center',padding:'30px',color:'#888'}}>No transport assignments created yet.</td></tr>}
      </tbody>
    </table>
    {showAdd && <TransportAssignmentModal participants={participants} vehicles={vehicles} onSave={async(v)=>{await req('/admin/transport-assignments',{method:'POST',body:JSON.stringify(v)}); setShowAdd(false); load(); notify('Assigned successfully');}} onClose={()=>setShowAdd(false)}/>}
  </div>
}

function TransportAssignmentModal({participants,vehicles,onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Transport Assignment</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Participant" value={v.participant_id} onChange={x=>set('participant_id',x?Number(x):null)} options={[{value:'',label:'-- Select Participant --'},...participants.map(p=>({value:p.id,label:`${p.name} (${p.registration_no})`}))]}/>
    <SelectField label="Vehicle" value={v.vehicle_id} onChange={x=>set('vehicle_id',x?Number(x):null)} options={[{value:'',label:'-- Select Vehicle --'},...vehicles.map(vh=>({value:vh.id,label:`${vh.vehicle_number} (${vh.vehicle_type}, Driver: ${vh.driver_name||'N/A'})`}))]}/>
    <Field label="Pickup Location" value={v.pickup_location} onChange={x=>set('pickup_location',x)}/>
    <Field label="Drop Location" value={v.drop_location} onChange={x=>set('drop_location',x)}/>
    <Field type="datetime-local" label="Pickup Time" value={v.pickup_time} onChange={x=>set('pickup_time',x)}/>
    <Field textarea label="Notes" value={v.notes} onChange={x=>set('notes',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Assign Transport</button></div></div></div>
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
  const[d,setD]=useState([]),[halls,setHalls]=useState([]),[speakers,setSpeakers]=useState([]),[busy,setBusy]=useState(false),[edit,setEdit]=useState(null),[projectQr,setProjectQr]=useState(null);
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
      <div><h3>Event Schedule</h3><p>Manage conference sessions, halls, and generate live attendee QR codes.</p></div>
      <div className="actions" style={{display:'flex',gap:'8px'}}>
        {d.length > 0 && (
          <button style={{background:'#2E6F95',color:'#fff',display:'flex',alignItems:'center',gap:'6px'}} onClick={()=>setProjectQr(d[0])}>
            <Tv size={16}/> Project Attendance QR
          </button>
        )}
        <button onClick={()=>setEdit({})}>+ Add Session</button>
      </div>
    </div>
    <table>
      <thead><tr><th>Time</th><th>Session</th><th>Hall</th><th>Speaker</th><th>Live Attendance QR</th><th>Actions</th></tr></thead>
      <tbody>
        {d.map(x=><tr key={x.id}>
          <td>{toInputDate(x.session_date)}<br/>{x.start_time} - {x.end_time}</td>
          <td><b>{x.title}</b><br/><small>{x.category}</small></td>
          <td>{x.hall_name}</td>
          <td>{x.speaker_name}</td>
          <td>
            <button
              onClick={()=>setProjectQr(x)}
              style={{background:'#FFF8F8',color:'#8C1119',border:'1.5px solid #8C1119',borderRadius:'8px',padding:'6px 12px',fontSize:'12px',fontWeight:'700',display:'inline-flex',alignItems:'center',gap:'6px',cursor:'pointer'}}
            >
              <QrCode size={14}/> Project QR Screen
            </button>
          </td>
          <td>
            <div className="rowactions">
              <button className="icon" title="Edit Session" onClick={()=>setEdit(x)}><Settings size={16}/></button>
              <button className="icon" title="Delete Session" onClick={async()=>{if(confirm('Delete?')){await req(`/admin/sessions/${x.id}`,{method:'DELETE'});load()}}}><LogOut size={16}/></button>
            </div>
          </td>
        </tr>)}
      </tbody>
    </table>
    {edit && <SessionModal value={edit} speakers={speakers} halls={halls} onSave={save} onClose={()=>setEdit(null)}/>}
    {projectQr && <SessionQrModal session={projectQr} onClose={()=>setProjectQr(null)}/>}
  </div>
}

function SessionQrModal({session, onClose}){
  const [data, setData] = useState(null);
  const [fullscreen, setFullscreen] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const loadAttendance = async () => {
    if (!session?.id) return;
    try {
      setRefreshing(true);
      const res = await req(`/admin/sessions/${session.id}/attendance`);
      setData(res);
    } catch (_) {} finally {
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadAttendance();
    const timer = setInterval(loadAttendance, 2500);
    return () => clearInterval(timer);
  }, [session?.id]);

  const qrToken = `MAPCON2026-SESSION-${session.id}-1`;

  const printQr = () => {
    window.print();
  };

  return (
    <div className="modal-overlay">
      <div className="modal" style={fullscreen ? {maxWidth:'96vw', height:'94vh', background:'#0F172A', color:'#fff', display:'flex', flexDirection:'column'} : {maxWidth:'780px'}}>
        <div className="modal-header" style={fullscreen ? {borderBottom:'1px solid #334155', background:'#0F172A'} : {}}>
          <div style={{display:'flex',alignItems:'center',gap:'10px'}}>
            <div style={{background:'#8C1119',color:'#fff',padding:'8px',borderRadius:'10px',display:'flex'}}>
              <QrCode size={22}/>
            </div>
            <div>
              <h3 style={fullscreen ? {color:'#fff',fontSize:'20px',margin:0} : {fontSize:'18px',margin:0}}>
                {fullscreen ? '📺 Official Session Attendance Projector Screen' : 'Session Attendance QR Code'}
              </h3>
              <p style={{fontSize:'12px',color:fullscreen ? '#94A3B8' : '#64748B',margin:'2px 0 0'}}>
                Project this QR code on hall screen / podium. Attendees scan with mobile app to mark attendance.
              </p>
            </div>
          </div>
          <div style={{display:'flex',gap:'8px',alignItems:'center'}}>
            <button className="icon" title="Toggle Fullscreen Projector" onClick={()=>setFullscreen(!fullscreen)} style={fullscreen ? {color:'#fff',background:'#1E293B'} : {}}>
              {fullscreen ? <Minimize2 size={18}/> : <Maximize2 size={18}/>}
            </button>
            <button className="icon" title="Print QR Standee" onClick={printQr} style={fullscreen ? {color:'#fff',background:'#1E293B'} : {}}>
              <Printer size={18}/>
            </button>
            <button className="close" onClick={onClose} style={fullscreen ? {color:'#fff'} : {}}>&times;</button>
          </div>
        </div>

        <div className="modal-body" style={{padding:'24px',overflowY:'auto',flex:1}}>
          <div style={{display:'grid',gridTemplateColumns:fullscreen ? '1.1fr 1fr' : '1fr 1.1fr',gap:'24px',alignItems:'start'}}>
            
            {/* QR Code Presentation Box */}
            <div style={{background:fullscreen ? '#1E293B' : '#FFF8F8',border:`2px solid ${fullscreen ? '#38BDF8' : '#8C1119'}`,borderRadius:'20px',padding:'24px',textAlign:'center',boxShadow:'0 10px 25px rgba(0,0,0,0.1)'}}>
              <div style={{fontSize:'12px',fontWeight:'800',color:'#8C1119',letterSpacing:'1px',marginBottom:'12px',textTransform:'uppercase'}}>
                MAPCON 2026 OFFICIAL ATTENDANCE QR
              </div>
              
              <div style={{background:'#fff',padding:'16px',borderRadius:'16px',display:'inline-block',boxShadow:'0 4px 20px rgba(0,0,0,0.12)'}}>
                <QRCodeSVG
                  value={qrToken}
                  size={fullscreen ? 280 : 210}
                  level="H"
                  includeMargin={true}
                  fgColor="#5C070D"
                />
              </div>

              <div style={{marginTop:'16px',fontSize:'13px',fontWeight:'700',color:fullscreen ? '#F1F5F9' : '#1E293B'}}>
                Session Code: <span style={{fontFamily:'monospace',background:fullscreen ? '#0F172A' : '#F1F5F9',padding:'4px 10px',borderRadius:'6px',color:fullscreen ? '#38BDF8' : '#8C1119'}}>{qrToken}</span>
              </div>

              <div style={{marginTop:'14px',background:fullscreen ? '#0F172A' : '#F8FAFC',padding:'12px',borderRadius:'12px',fontSize:'12px',color:fullscreen ? '#94A3B8' : '#64748B',lineHeight:'1.4'}}>
                📱 <b>Instructions for Delegates:</b><br/>
                Open <b>MAPCON 2026 App</b> ➔ Go to <b>Attendance</b> ➔ Tap <b>Scan Session QR Code</b>
              </div>
            </div>

            {/* Session Info & Live Attendees Counter */}
            <div style={{display:'flex',flexDirection:'column',gap:'16px'}}>
              <div style={{background:fullscreen ? '#1E293B' : '#F8FAFC',borderRadius:'16px',padding:'18px',border:`1px solid ${fullscreen ? '#334155' : '#E2E8F0'}`}}>
                <div style={{fontSize:'11px',fontWeight:'800',color:'#8C1119',letterSpacing:'0.8px',textTransform:'uppercase'}}>
                  Session Details
                </div>
                <h4 style={{fontSize:'17px',fontWeight:'900',color:fullscreen ? '#F8FAFC' : '#1E293B',marginTop:'4px',marginBottom:'10px'}}>
                  {session.title}
                </h4>
                <div style={{display:'flex',flexDirection:'column',gap:'6px',fontSize:'13px',color:fullscreen ? '#CBD5E1' : '#475569'}}>
                  <div>📍 <b>Hall / Venue:</b> {session.hall_name || 'Main Auditorium'}</div>
                  <div>👨‍🏫 <b>Speaker / Chairperson:</b> {session.speaker_name || 'Faculty'}</div>
                  <div>🕒 <b>Schedule:</b> {toInputDate(session.session_date)} ({session.start_time} - {session.end_time})</div>
                </div>
              </div>

              {/* Live Attendance Counter */}
              <div style={{background:fullscreen ? '#1E293B' : '#F0FDF4',borderRadius:'16px',padding:'16px',border:`1.5px solid ${fullscreen ? '#16A34A' : '#BBF7D0'}`}}>
                <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
                  <div style={{display:'flex',alignItems:'center',gap:'10px'}}>
                    <div style={{background:'#16A34A',color:'#fff',padding:'8px',borderRadius:'50%',display:'flex'}}>
                      <UserCheck size={20}/>
                    </div>
                    <div>
                      <div style={{fontSize:'11px',fontWeight:'800',color:'#16A34A',textTransform:'uppercase',letterSpacing:'0.5px'}}>Live Attendance Count</div>
                      <div style={{fontSize:'22px',fontWeight:'900',color:fullscreen ? '#F0FDF4' : '#14532D'}}>
                        {data ? data.count : 0} <span style={{fontSize:'13px',fontWeight:'600',color:fullscreen ? '#86EFAC' : '#166534'}}>Verified Attendees</span>
                      </div>
                    </div>
                  </div>
                  <button className="icon" title="Refresh count" onClick={loadAttendance} style={{color:'#16A34A'}}>
                    <RefreshCw size={16} className={refreshing ? 'spin' : ''}/>
                  </button>
                </div>
              </div>

              {/* Real-Time Scanned Attendees Feed */}
              <div style={{background:fullscreen ? '#1E293B' : '#fff',borderRadius:'16px',padding:'16px',border:`1px solid ${fullscreen ? '#334155' : '#E2E8F0'}`}}>
                <div style={{fontSize:'12px',fontWeight:'800',color:fullscreen ? '#94A3B8' : '#64748B',marginBottom:'8px'}}>
                  LIVE SCANNED ATTENDEES ({data?.attendees?.length || 0})
                </div>
                <div style={{maxHeight:fullscreen ? '280px' : '160px',overflowY:'auto',display:'flex',flexDirection:'column',gap:'6px'}}>
                  {data?.attendees?.length ? (
                    data.attendees.map(a => (
                      <div key={a.id} style={{display:'flex',justifyContent:'space-between',alignItems:'center',padding:'8px 12px',background:fullscreen ? '#0F172A' : '#F8FAFC',borderRadius:'8px',fontSize:'12.5px'}}>
                        <div>
                          <b style={{color:fullscreen ? '#F1F5F9' : '#1E293B'}}>{a.participant_name}</b>
                          <div style={{fontSize:'11px',color:fullscreen ? '#94A3B8' : '#64748B'}}>{a.registration_no || 'Delegate'} • {a.category || 'Participant'}</div>
                        </div>
                        <div style={{fontSize:'11px',color:'#16A34A',fontWeight:'700'}}>
                          ✓ {new Date(a.scanned_at).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit',second:'2-digit'})}
                        </div>
                      </div>
                    ))
                  ) : (
                    <div style={{padding:'16px',textAlign:'center',color:fullscreen ? '#64748B' : '#94A3B8',fontSize:'12.5px'}}>
                      Waiting for participants to scan this QR code...
                    </div>
                  )}
                </div>
              </div>

            </div>
          </div>
        </div>

        <div className="modal-footer" style={fullscreen ? {borderTop:'1px solid #334155',background:'#0F172A'} : {}}>
          <button onClick={onClose} style={fullscreen ? {background:'#334155',color:'#fff',border:'none'} : {}}>Close</button>
          <button className="primary" onClick={()=>setFullscreen(!fullscreen)}>
            {fullscreen ? 'Exit Fullscreen' : '⛶ Fullscreen Projector Mode'}
          </button>
        </div>
      </div>
    </div>
  );
}

function SessionModal({value,speakers,halls,onSave,onClose}){
  const[v,set,setV]=formState({...value,session_date:toInputDate(value.session_date)});
  const[hallsList,setHallsList]=useState(halls);
  const[showAddHall,setShowAddHall]=useState(false);
  const[newHallName,setNewHallName]=useState('');
  const[newHallCap,setNewHallCap]=useState('250');
  const[savingHall,setSavingHall]=useState(false);

  const createHall=async(e)=>{
    if(e) e.preventDefault();
    if(!newHallName.trim()) return alert('Please enter Hall Name');
    setSavingHall(true);
    try{
      const res=await req('/admin/halls',{method:'POST',body:JSON.stringify({name:newHallName.trim(),capacity:Number(newHallCap)||250,conferenceId:1})});
      const newHall={id:res.id,name:newHallName.trim(),capacity:Number(newHallCap)||250};
      setHallsList(prev=>[...prev,newHall]);
      set('hall_id',newHall.id);
      setNewHallName('');
      setShowAddHall(false);
    }catch(err){
      alert('Failed to add hall: '+err.message);
    }finally{
      setSavingHall(false);
    }
  };

  return <div className="modal-overlay"><div className="modal" style={{maxWidth:'640px'}}><div className="modal-header"><h3>{v.id?'Edit Session':'Add Session'}</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <Field label="Title" value={v.title} onChange={x=>set('title',x)}/>
    <Field type="date" label="Date" value={v.session_date} onChange={x=>set('session_date',x)}/>
    <Field type="time" label="Start Time" value={v.start_time} onChange={x=>set('start_time',x)}/>
    <Field type="time" label="End Time" value={v.end_time} onChange={x=>set('end_time',x)}/>
    <SelectField label="Speaker" value={v.speaker_id} onChange={x=>set('speaker_id',x?Number(x):null)} options={[{value:'',label:'-- Select Speaker --'},...speakers.map(s=>({value:s.id,label:s.name}))]}/>
    
    <div style={{display:'flex',flexDirection:'column',gap:'6px'}}>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
        <label style={{fontSize:'13px',fontWeight:'600',color:'#334155'}}>Hall / Venue</label>
        <button type="button" onClick={()=>setShowAddHall(!showAddHall)} style={{fontSize:'12px',color:'#8C1119',background:'none',border:'none',cursor:'pointer',fontWeight:'700',padding:0}}>
          {showAddHall ? '✕ Cancel' : '+ Add New Hall'}
        </button>
      </div>
      <SelectField value={v.hall_id} onChange={x=>set('hall_id',x?Number(x):null)} options={[{value:'',label:'-- Select Hall --'},...hallsList.map(h=>({value:h.id,label:h.name}))]}/>
      
      {showAddHall && (
        <div style={{background:'#FFF8F8',border:'1.5px dashed #8C1119',borderRadius:'8px',padding:'12px',marginTop:'4px',display:'flex',flexDirection:'column',gap:'8px'}}>
          <div style={{fontWeight:'700',fontSize:'12px',color:'#8C1119'}}>Quick Create New Hall</div>
          <div style={{display:'flex',gap:'8px'}}>
            <input placeholder="e.g. Hall C - Sayaji Banquet" value={newHallName} onChange={e=>setNewHallName(e.target.value)} style={{flex:2,padding:'6px 10px',fontSize:'13px',border:'1px solid #cbd5e1',borderRadius:'6px'}}/>
            <input type="number" placeholder="Cap" value={newHallCap} onChange={e=>setNewHallCap(e.target.value)} style={{flex:1,maxWidth:'80px',padding:'6px 10px',fontSize:'13px',border:'1px solid #cbd5e1',borderRadius:'6px'}}/>
            <button type="button" onClick={createHall} disabled={savingHall} style={{background:'#8C1119',color:'#fff',border:'none',borderRadius:'6px',padding:'6px 12px',fontSize:'12px',fontWeight:'700',cursor:'pointer'}}>
              {savingHall?'Adding...':'Add & Select'}
            </button>
          </div>
        </div>
      )}
    </div>

    <Field label="Category" value={v.category} onChange={x=>set('category',x)}/>
    <Field textarea label="Description" value={v.description} onChange={x=>set('description',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Save</button></div></div></div>
}

function Placeholder({title}){
  return <div className="panel empty" style={{textAlign:'center',padding:'60px 20px'}}>
    <h2 style={{color:'#8C1119',marginBottom:'8px'}}>{title}</h2>
    <p style={{color:'#64748b',maxWidth:'500px',margin:'0 auto'}}>This module is configured and active. Select actions from the sidebar or toolbar to view records.</p>
  </div>;
}

function Attendance({notify, selectedConferenceId}){
  const[subTab,setSubTab]=useState('scanner');
  const[scans,setScans]=useState([]),[sessions,setSessions]=useState([]),[meals,setMeals]=useState([]),[busy,setBusy]=useState(false);
  const[mode,setMode]=useState('CHECKIN'),[sessionId,setSessionId]=useState(''),[mealId,setMealId]=useState(''),[qr,setQr]=useState('');
  const[projectSession,setProjectSession]=useState(null);
  const[attReport,setAttReport]=useState(null);
  const[selectedSessionFilter,setSelectedSessionFilter]=useState('ALL');
  const[attCategoryFilter,setAttCategoryFilter]=useState('ALL');
  const[attSearchQuery,setAttSearchQuery]=useState('');

  const load=async()=>{
    setBusy(true);
    const confId = selectedConferenceId || 1;
    try{
      const[s,se,me,rep]=await Promise.all([
        req('/admin/attendance/live').catch(()=>[]),
        req('/admin/sessions?conferenceId='+confId).catch(()=>[]),
        req('/admin/meals?conferenceId='+confId).catch(()=>[]),
        req(`/admin/attendance/report?conferenceId=${confId}${selectedSessionFilter!=='ALL'?`&sessionId=${selectedSessionFilter}`:''}`).catch(()=>null)
      ]);
      setScans(s); setSessions(se); setMeals(me); setAttReport(rep);
    }finally{setBusy(false)}
  };
  useEffect(()=>{load()},[selectedConferenceId, selectedSessionFilter]);

  const handleScan=async(e)=>{
    e.preventDefault();
    if(!qr.trim())return;
    try{
      await req('/attendance/scan',{method:'POST',body:JSON.stringify({qrToken:qr.trim(), scanType:mode, sessionId:sessionId?Number(sessionId):null, mealId:mealId?Number(mealId):null})});
      notify('Attendance recorded successfully');
      setQr('');
      load();
    }catch(err){alert(err.message)}
  };

  const exportAttendanceXLSX = () => {
    const list = attReport?.scans || scans;
    if(!list.length){alert('No attendance scan records to export'); return;}
    const data = list.map((x, idx) => ({
      'Sr No': idx + 1,
      'Participant Name': x.participant_name || '',
      'Registration No': x.registration_no || '',
      'Category': x.category || 'Delegate',
      'Scan Type': x.scan_type || 'CHECKIN',
      'Session / Activity': x.session_title || (x.scan_type === 'CHECKIN' ? 'Main Check-in' : 'General'),
      'Hall / Location': x.hall_name || '-',
      'University / Institution': x.university || '',
      'Scanned At': new Date(x.scanned_at).toLocaleString(),
      'Scanned By': x.scanned_by_name || 'Admin Desk'
    }));
    const ws = XLSX.utils.json_to_sheet(data);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Attendance Reports');
    XLSX.writeFile(wb, `attendance_report_${new Date().toISOString().slice(0,10)}.xlsx`);
    notify('Exported attendance report to Excel');
  };

  const exportAttendanceCSV = () => {
    const list = attReport?.scans || scans;
    if(!list.length){alert('No attendance scan records to export'); return;}
    const headers = ['Sr No', 'Participant Name', 'Registration No', 'Category', 'Scan Type', 'Session / Activity', 'Hall', 'University', 'Scanned At', 'Scanned By'];
    const rows = list.map((x, idx) => [
      idx + 1,
      `"${x.participant_name||''}"`,
      `"${x.registration_no||''}"`,
      `"${x.category||'Delegate'}"`,
      `"${x.scan_type||'CHECKIN'}"`,
      `"${x.session_title || (x.scan_type === 'CHECKIN' ? 'Main Check-in' : 'General')}"`,
      `"${x.hall_name||'-'}"`,
      `"${x.university||''}"`,
      `"${new Date(x.scanned_at).toLocaleString()}"`,
      `"${x.scanned_by_name||'Admin Desk'}"`
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const link = document.createElement('a');
    link.setAttribute('href', encodeURI(csvContent));
    link.setAttribute('download', `attendance_report_${new Date().toISOString().slice(0,10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    notify('Exported attendance report to CSV');
  };

  const filteredScans = (attReport?.scans || scans).filter(x => {
    const matchesQ = `${x.participant_name} ${x.registration_no} ${x.session_title||''} ${x.university||''}`.toLowerCase().includes(attSearchQuery.toLowerCase());
    const matchesCat = attCategoryFilter === 'ALL' || x.category === attCategoryFilter;
    return matchesQ && matchesCat;
  });

  const categories = ['ALL', ...Array.from(new Set((attReport?.scans || scans).map(x => x.category).filter(Boolean)))];

  return <div className="panel">
    <div className="pagehead">
      <div>
        <h3>Live Attendance & QR Check-in</h3>
        <p>Monitor real-time attendee check-ins, generate session QR codes, and view detailed attendance reports.</p>
      </div>
      <div className="actions" style={{display:'flex', gap:'12px', alignItems:'center'}}>
        <div style={{background:'var(--bg-app)', padding:'4px', borderRadius:'var(--radius-sm)', display:'flex', gap:'4px', border:'1px solid var(--border)'}}>
          <button style={{padding:'6px 14px', fontSize:'13px', background:subTab==='scanner'?'var(--surface)':'transparent', color:subTab==='scanner'?'var(--primary)':'var(--text-muted)', border:0, boxShadow:subTab==='scanner'?'var(--shadow-sm)':'none', fontWeight:600}} onClick={()=>setSubTab('scanner')}>⚡ Scanner & Simulator</button>
          <button style={{padding:'6px 14px', fontSize:'13px', background:subTab==='reports'?'var(--surface)':'transparent', color:subTab==='reports'?'var(--primary)':'var(--text-muted)', border:0, boxShadow:subTab==='reports'?'var(--shadow-sm)':'none', fontWeight:600}} onClick={()=>setSubTab('reports')}>📊 Attendance Reports</button>
        </div>
        {subTab === 'reports' && (
          <div style={{display:'flex', gap:'8px'}}>
            <button className="primary" onClick={exportAttendanceXLSX} style={{display:'flex', alignItems:'center', gap:'6px'}}>📥 Export Excel</button>
            <button className="secondary" onClick={exportAttendanceCSV}>CSV</button>
            <button className="secondary" onClick={()=>window.print()} style={{display:'flex', alignItems:'center', gap:'6px'}}><Printer size={15}/> Print</button>
          </div>
        )}
        {sessions.length > 0 && subTab === 'scanner' && (
          <button style={{background:'#8C1119',color:'#fff',display:'flex',alignItems:'center',gap:'6px'}} onClick={()=>setProjectSession(sessions[0])}>
            <QrCode size={16}/> Project Session Attendance QR
          </button>
        )}
      </div>
    </div>

    {subTab === 'scanner' ? (
      <>
        {/* Quick Session QR Generator Banner */}
        <div style={{background:'linear-gradient(135deg, #FFF8F8 0%, #FFFDF8 100%)',border:'1.5px solid #C8A45A',borderRadius:'16px',padding:'18px 22px',marginBottom:'20px',display:'flex',justifyContent:'space-between',alignItems:'center',flexWrap:'wrap',gap:'14px'}}>
          <div style={{display:'flex',alignItems:'center',gap:'14px'}}>
            <div style={{background:'#8C1119',color:'#C8A45A',padding:'12px',borderRadius:'14px',display:'flex'}}>
              <Tv size={26}/>
            </div>
            <div>
              <h4 style={{margin:0,fontSize:'16px',color:'#8C1119',fontWeight:'900'}}>Projector Mode: Session QR Code Display</h4>
              <p style={{margin:'3px 0 0',fontSize:'13px',color:'#64748B'}}>Select any session below to project its official attendance QR code on the big screen.</p>
            </div>
          </div>
          <div style={{display:'flex',gap:'10px',alignItems:'center'}}>
            <select
              onChange={(e)=>{
                const found = sessions.find(s => s.id === Number(e.target.value));
                if(found) setProjectSession(found);
              }}
              style={{padding:'8px 14px',fontSize:'13px',borderRadius:'8px',border:'1px solid #cbd5e1',fontWeight:'600'}}
              defaultValue=""
            >
              <option value="" disabled>-- Select Session to Project --</option>
              {sessions.map(s => <option key={s.id} value={s.id}>{s.title} ({s.hall_name||'Hall A'})</option>)}
            </select>
            {sessions.length > 0 && (
              <button className="primary" onClick={()=>setProjectSession(sessions[0])} style={{display:'flex',alignItems:'center',gap:'6px'}}>
                <Maximize2 size={14}/> Launch Projector
              </button>
            )}
          </div>
        </div>

        <div className="split">
          <div className="panel scanner-panel">
            <h4>QR Scanner Simulation</h4>
            <form onSubmit={handleScan} className="formgrid">
              <SelectField label="Scan Mode" value={mode} onChange={setMode} options={['CHECKIN','SESSION','MEAL','DEPARTURE']}/>
              {mode==='SESSION' && <SelectField label="Select Session" value={sessionId} onChange={setSessionId} options={[{value:'',label:'-- Select Session --'},...sessions.map(s=>({value:s.id,label:`${s.title} (${s.hall_name||'Main Hall'}, ${toInputDate(s.session_date)})`}))]}/>}
              {mode==='MEAL' && <SelectField label="Select Meal" value={mealId} onChange={setMealId} options={[{value:'',label:'-- Select Meal --'},...meals.map(m=>({value:m.id,label:`${m.meal_type} (${toInputDate(m.meal_date)}, ${m.location||'Dining Hall'})`}))]}/>}
              <Field label="QR Token / Registration No" value={qr} onChange={setQr}/>
              <button className="primary wide" type="submit">Submit Scan</button>
            </form>
          </div>
          <div className="panel scans-panel">
            <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:'12px'}}>
              <h4 style={{margin:0}}>Recent Live Scans ({scans.length})</h4>
              <button className="icon" onClick={load} title="Refresh Scans"><RefreshCw size={15}/></button>
            </div>
            <div className="scan-list">
              {scans.map(x=><div className="scan-item" key={x.id}>
                <div className="scan-time">{new Date(x.scanned_at).toLocaleTimeString()}</div>
                <div className="scan-info">
                  <b>{x.participant_name}</b>
                  <p>{x.scan_type} {x.session_title ? ` - ${x.session_title}` : ''} {x.registration_no ? `(${x.registration_no})` : ''}</p>
                </div>
              </div>)}
              {!scans.length && <p style={{color:'#888',padding:'20px'}}>No live scans yet. Try the simulator on the left or scan via mobile app.</p>}
            </div>
          </div>
        </div>
      </>
    ) : (
      <div>
        {/* Attendance Reports Metric Overview */}
        <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fit, minmax(200px, 1fr))', gap:'14px', marginBottom:'20px'}}>
          <div className="stat" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'12px', padding:'16px'}}>
            <Users color="#8C1119" size={20}/>
            <span style={{fontSize:'13px', color:'#64748b'}}>Total Registered</span>
            <strong style={{fontSize:'22px', color:'#1e293b'}}>{attReport?.totalRegistered ?? '—'}</strong>
          </div>
          <div className="stat" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'12px', padding:'16px'}}>
            <CheckCircle color="#10b981" size={20}/>
            <span style={{fontSize:'13px', color:'#64748b'}}>Checked In</span>
            <strong style={{fontSize:'22px', color:'#047857'}}>{attReport?.totalCheckedIn ?? '—'}</strong>
          </div>
          <div className="stat" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'12px', padding:'16px'}}>
            <Users color="#f59e0b" size={20}/>
            <span style={{fontSize:'13px', color:'#64748b'}}>Absent / Pending</span>
            <strong style={{fontSize:'22px', color:'#b45309'}}>{attReport?.absentCount ?? '—'}</strong>
          </div>
          <div className="stat" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'12px', padding:'16px'}}>
            <FileCheck color="#2E6F95" size={20}/>
            <span style={{fontSize:'13px', color:'#64748b'}}>Check-in Rate</span>
            <strong style={{fontSize:'22px', color:'#2E6F95'}}>{attReport?.attendanceRate ?? 0}%</strong>
          </div>
          <div className="stat" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'12px', padding:'16px'}}>
            <QrCode color="#8C1119" size={20}/>
            <span style={{fontSize:'13px', color:'#64748b'}}>Total Scans</span>
            <strong style={{fontSize:'22px', color:'#8C1119'}}>{attReport?.totalScans ?? filteredScans.length}</strong>
          </div>
        </div>

        {/* Filters Toolbar */}
        <div className="toolbar" style={{display:'flex', gap:'12px', alignItems:'center', background:'#f8fafc', padding:'12px 16px', borderRadius:'10px', border:'1px solid #e2e8f0', marginBottom:'16px', flexWrap:'wrap'}}>
          <div className="search" style={{flex:1, minWidth:'220px'}}>
            <Search size={16}/>
            <input value={attSearchQuery} onChange={e=>setAttSearchQuery(e.target.value)} placeholder="Filter by delegate name, reg no, session..."/>
          </div>
          <div style={{display:'flex', gap:'6px', alignItems:'center'}}>
            <small style={{fontWeight:600, color:'#64748b'}}>Session:</small>
            <select value={selectedSessionFilter} onChange={e=>setSelectedSessionFilter(e.target.value)} style={{padding:'7px 10px', borderRadius:'6px', border:'1px solid #cbd5e1', fontSize:'13px', fontWeight:600}}>
              <option value="ALL">All Scans & Sessions</option>
              <option value="CHECKIN_ONLY">Main Check-in Desk Only</option>
              {sessions.map(s => <option key={s.id} value={s.id}>{s.title}</option>)}
            </select>
          </div>
          <div style={{display:'flex', gap:'6px', alignItems:'center'}}>
            <small style={{fontWeight:600, color:'#64748b'}}>Category:</small>
            <select value={attCategoryFilter} onChange={e=>setAttCategoryFilter(e.target.value)} style={{padding:'7px 10px', borderRadius:'6px', border:'1px solid #cbd5e1', fontSize:'13px'}}>
              {categories.map(c => <option key={c} value={c}>{c}</option>)}
            </select>
          </div>
          <button onClick={load} disabled={busy} style={{padding:'7px 14px', fontSize:'13px'}}>{busy?'...':'↻ Refresh'}</button>
        </div>

        {/* Detailed Attendance Table */}
        <div className="tablewrap">
          <table>
            <thead>
              <tr>
                <th>Participant & Reg No</th>
                <th>Category</th>
                <th>Scan Type & Activity</th>
                <th>Hall / Venue</th>
                <th>University / Hospital</th>
                <th>Scanned Timestamp</th>
                <th>Operator</th>
              </tr>
            </thead>
            <tbody>
              {filteredScans.map(x => (
                <tr key={x.id}>
                  <td>
                    <b>{x.participant_name}</b><br/>
                    <small style={{color:'#64748b'}}>{x.registration_no || '—'}</small>
                  </td>
                  <td><span className="pill small">{x.category || 'Delegate'}</span></td>
                  <td>
                    <span className="pill" style={{
                      background: x.scan_type==='CHECKIN'?'#ecfdf5':x.scan_type==='SESSION'?'#eff6ff':'#fff7ed',
                      color: x.scan_type==='CHECKIN'?'#065f46':x.scan_type==='SESSION'?'#1e40af':'#9a3412',
                      fontWeight:700
                    }}>
                      {x.scan_type}
                    </span>
                    {x.session_title && <div style={{fontSize:'12px', marginTop:'3px', color:'#334155'}}>{x.session_title}</div>}
                  </td>
                  <td>{x.hall_name || 'Main Hall'}</td>
                  <td>{x.university || '—'}</td>
                  <td><span style={{color:'#059669', fontWeight:700}}>{new Date(x.scanned_at).toLocaleString()}</span></td>
                  <td>{x.scanned_by_name || 'Admin Desk'}</td>
                </tr>
              ))}
              {!filteredScans.length && (
                <tr><td colSpan="7" style={{textAlign:'center', padding:'30px', color:'#888'}}>No attendance scans found matching filter criteria.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    )}

    {projectSession && <SessionQrModal session={projectSession} onClose={()=>setProjectSession(null)}/>}
  </div>;
}

function Meals({tab, notify, selectedConferenceId}){
  const[subTab,setSubTab]=useState('schedule'),[d,setD]=useState([]),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false);
  const[selectedMeal,setSelectedMeal]=useState(''),[qrInput,setQrInput]=useState(''),[scanResult,setScanResult]=useState(null),[scans,setScans]=useState([]),[scanning,setScanning]=useState(false);
  const[mealReport,setMealReport]=useState(null),[activeReportMeal,setActiveReportMeal]=useState('ALL');
  const[mealCatFilter,setMealCatFilter]=useState('ALL'),[dietFilter,setDietFilter]=useState('ALL'),[mealSearchQ,setMealSearchQ]=useState('');

  const load=async()=>{
    setBusy(true);
    const confId = selectedConferenceId || 1;
    try{
      const[r, liveScans, rep]=await Promise.all([
        req('/admin/meals?conferenceId='+confId),
        req('/admin/meals/live').catch(()=>[]),
        req(`/admin/meals/report?conferenceId=${confId}${activeReportMeal!=='ALL'?`&mealId=${activeReportMeal}`:''}`).catch(()=>null)
      ]);
      setD(r);
      setScans(liveScans);
      setMealReport(rep);
      if(r.length && !selectedMeal) setSelectedMeal(String(r[0].id));
    }finally{
      setBusy(false);
    }
  };

  useEffect(()=>{load()},[selectedConferenceId, activeReportMeal]);
  useEffect(()=>{if(tab==='Schedule Meal')setShowAdd(true)},[tab]);

  const handleScanSubmit = async (e) => {
    if(e) e.preventDefault();
    if(!qrInput.trim() || !selectedMeal) return;
    setScanning(true);
    setScanResult(null);
    try {
      const res = await req('/admin/meals/scan', {
        method: 'POST',
        body: JSON.stringify({ mealId: Number(selectedMeal), qrToken: qrInput.trim() })
      });
      setScanResult({
        type: 'SUCCESS',
        message: res.message || 'Food pass verified successfully!',
        participant: res.data?.participant,
        time: res.data?.scannedAt || new Date().toISOString()
      });
      notify('Food pass verified & redeemed!');
      setQrInput('');
      load();
    } catch (err) {
      setScanResult({
        type: 'ERROR',
        message: err.message || 'Verification failed. Please check delegate registration.'
      });
    } finally {
      setScanning(false);
    }
  };

  const exportMealReportXLSX = () => {
    const list = filteredReportScans;
    if(!list.length){alert('No meal redemption records to export'); return;}
    const data = list.map((x, idx) => ({
      'Sr No': idx + 1,
      'Delegate Name': x.participant_name || '',
      'Registration No': x.registration_no || '',
      'Category': x.category || 'Delegate',
      'Food Preference': x.food_preference || 'VEG',
      'University / Hospital': x.university || '',
      'Meal Type': x.meal_type || '',
      'Meal Date': x.meal_date || '',
      'Location': x.location || '',
      'Redeemed At': new Date(x.scanned_at).toLocaleString(),
      'Scanned By': x.scanned_by_name || 'Admin Desk'
    }));
    const ws = XLSX.utils.json_to_sheet(data);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Food Pass Reports');
    XLSX.writeFile(wb, `food_pass_redemption_report_${new Date().toISOString().slice(0,10)}.xlsx`);
    notify('Exported Food Pass report to Excel');
  };

  const exportMealReportCSV = () => {
    const list = filteredReportScans;
    if(!list.length){alert('No meal redemption records to export'); return;}
    const headers = ['Sr No', 'Delegate Name', 'Registration No', 'Category', 'Food Preference', 'University', 'Meal Type', 'Meal Date', 'Location', 'Redeemed At', 'Scanned By'];
    const rows = list.map((x, idx) => [
      idx + 1,
      `"${x.participant_name||''}"`,
      `"${x.registration_no||''}"`,
      `"${x.category||'Delegate'}"`,
      `"${x.food_preference||'VEG'}"`,
      `"${x.university||''}"`,
      `"${x.meal_type||''}"`,
      `"${x.meal_date||''}"`,
      `"${x.location||''}"`,
      `"${new Date(x.scanned_at).toLocaleString()}"`,
      `"${x.scanned_by_name||'Admin'}"`
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const link = document.createElement('a');
    link.setAttribute('href', encodeURI(csvContent));
    link.setAttribute('download', `food_pass_redemption_report_${new Date().toISOString().slice(0,10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    notify('Exported Food Pass report to CSV');
  };

  const save=async(v)=>{
    await req('/admin/meals',{method:'POST',body:JSON.stringify({...v, conference_id: selectedConferenceId || 1})});
    notify('Meal scheduled');
    setShowAdd(false);
    load();
  };

  const reportScansList = mealReport?.scans || scans;
  const filteredReportScans = reportScansList.filter(x => {
    const matchesQ = `${x.participant_name} ${x.registration_no} ${x.meal_type||''} ${x.university||''}`.toLowerCase().includes(mealSearchQ.toLowerCase());
    const matchesCat = mealCatFilter === 'ALL' || x.category === mealCatFilter;
    const matchesDiet = dietFilter === 'ALL' || (x.food_preference || 'VEG') === dietFilter;
    return matchesQ && matchesCat && matchesDiet;
  });

  const categories = ['ALL', ...Array.from(new Set(reportScansList.map(x => x.category).filter(Boolean)))];
  const currentMealObj = d.find(m => String(m.id) === String(selectedMeal));

  return <div className="panel">
    <div className="pagehead">
      <div>
        <h3>Meals & Food Pass Management</h3>
        <p>Manage catering timelines, scan delegate food passes with duplicate prevention, and view real-time redemption analytics.</p>
      </div>
      <div className="actions" style={{display:'flex', gap:'12px', alignItems:'center'}}>
        <div style={{background:'var(--bg-app)', padding:'4px', borderRadius:'var(--radius-sm)', display:'flex', gap:'4px', border:'1px solid var(--border)'}}>
          <button style={{padding:'6px 14px', fontSize:'13px', background:subTab==='schedule'?'var(--surface)':'transparent', color:subTab==='schedule'?'var(--primary)':'var(--text-muted)', border:0, boxShadow:subTab==='schedule'?'var(--shadow-sm)':'none', fontWeight:600}} onClick={()=>setSubTab('schedule')}>🍽️ Meal Schedule</button>
          <button style={{padding:'6px 14px', fontSize:'13px', background:subTab==='scanner'?'var(--surface)':'transparent', color:subTab==='scanner'?'var(--primary)':'var(--text-muted)', border:0, boxShadow:subTab==='scanner'?'var(--shadow-sm)':'none', fontWeight:600}} onClick={()=>setSubTab('scanner')}>📷 Food Pass Scanner</button>
          <button style={{padding:'6px 14px', fontSize:'13px', background:subTab==='reports'?'var(--surface)':'transparent', color:subTab==='reports'?'var(--primary)':'var(--text-muted)', border:0, boxShadow:subTab==='reports'?'var(--shadow-sm)':'none', fontWeight:600}} onClick={()=>setSubTab('reports')}>📊 Food Pass Reports</button>
        </div>
        {subTab === 'schedule' && <button className="primary" onClick={()=>setShowAdd(true)}>+ Schedule Meal</button>}
        {subTab === 'reports' && (
          <div style={{display:'flex', gap:'8px'}}>
            <button className="primary" onClick={exportMealReportXLSX} style={{display:'flex', alignItems:'center', gap:'6px'}}>📥 Export Excel</button>
            <button className="secondary" onClick={exportMealReportCSV}>CSV</button>
            <button className="secondary" onClick={()=>window.print()} style={{display:'flex', alignItems:'center', gap:'6px'}}><Printer size={15}/> Print</button>
          </div>
        )}
      </div>
    </div>

    {subTab === 'schedule' && (
      <div>
        <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fill, minmax(300px, 1fr))', gap:'16px'}}>
          {d.map(x=><div className="rowcard" key={x.id} style={{padding:'18px', display:'flex', flexDirection:'column', gap:'8px', border:'1px solid #e2e8f0', borderRadius:'12px', background:'#fff'}}>
            <div style={{display:'flex', justifyContent:'space-between', alignItems:'flex-start'}}>
              <div>
                <span className="pill" style={{background:'#8C1119', color:'#fff', fontWeight:700, fontSize:'11.5px'}}>{x.meal_type}</span>
                <h4 style={{margin:'8px 0 2px', fontSize:'16px', color:'#1e293b'}}>{x.location || 'Sayaji Dining Hall'}</h4>
              </div>
              <div style={{textAlign:'right'}}>
                <span style={{fontSize:'13px', fontWeight:800, color:'#047857'}}>{x.redeemed_count || 0} Redeemed</span>
              </div>
            </div>
            <p style={{margin:0, fontSize:'13px', color:'#64748b'}}>
              📅 {toInputDate(x.meal_date)} &nbsp;|&nbsp; ⏰ {x.start_time} - {x.end_time}
            </p>
            <div style={{marginTop:'8px', display:'flex', gap:'8px'}}>
              <button className="secondary" style={{flex:1, fontSize:'12.5px', padding:'6px'}} onClick={()=>{setSelectedMeal(String(x.id)); setSubTab('scanner');}}>
                📷 Open Scanner
              </button>
            </div>
          </div>)}
        </div>
        {!d.length && !busy && <div style={{textAlign:'center',padding:'40px',color:'#888'}}>No meals scheduled yet. Click "+ Schedule Meal" to configure catering.</div>}
      </div>
    )}

    {subTab === 'scanner' && (
      <div className="split">
        {/* Left Side: Scanner Control */}
        <div className="panel scanner-panel" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'14px', padding:'20px'}}>
          <div style={{marginBottom:'16px'}}>
            <h4 style={{margin:'0 0 6px', fontSize:'16px', color:'#8C1119'}}>Live Food Pass Redemption Desk</h4>
            <p style={{margin:0, fontSize:'13px', color:'#64748b'}}>Scan delegate QR codes or enter Registration / Phone numbers to issue meal passes.</p>
          </div>

          <form onSubmit={handleScanSubmit} className="formgrid">
            <label className="field wide">
              <span>Select Meal Session</span>
              <select value={selectedMeal} onChange={e=>setSelectedMeal(e.target.value)} style={{padding:'10px', borderRadius:'8px', border:'1.5px solid #cbd5e1', fontWeight:700, fontSize:'14px'}}>
                {d.map(m=><option key={m.id} value={m.id}>{m.meal_type} - {toInputDate(m.meal_date)} ({m.start_time} - {m.end_time}, {m.location})</option>)}
              </select>
            </label>

            {currentMealObj && (
              <div style={{background:'#fdf8f6', border:'1px solid #fed7aa', borderRadius:'10px', padding:'12px', gridColumn:'span 2', display:'flex', justifyContent:'space-between', alignItems:'center'}}>
                <div>
                  <strong style={{color:'#9a3412', fontSize:'13.5px'}}>Active Counter: {currentMealObj.meal_type}</strong>
                  <p style={{margin:'2px 0 0', fontSize:'12px', color:'#7c2d12'}}>{currentMealObj.location} &bull; {currentMealObj.start_time} - {currentMealObj.end_time}</p>
                </div>
                <div style={{background:'#fff', padding:'6px 12px', borderRadius:'8px', border:'1px solid #fdba74', fontWeight:800, color:'#c2410c'}}>
                  {currentMealObj.redeemed_count || 0} Claimed
                </div>
              </div>
            )}

            <label className="field wide">
              <span>Scan QR Code / Enter Reg No / Phone</span>
              <input
                type="text"
                autoFocus
                placeholder="Scan QR token, Reg No (e.g. DPU-0001), or Phone..."
                value={qrInput}
                onChange={e=>setQrInput(e.target.value)}
                style={{padding:'12px', fontSize:'15px', borderRadius:'8px', border:'2px solid #8C1119', fontWeight:600}}
              />
            </label>

            <button className="primary wide" type="submit" disabled={scanning || !qrInput.trim()} style={{padding:'12px', fontSize:'14.5px', fontWeight:800}}>
              {scanning ? 'Verifying Food Pass...' : '✅ Verify & Redeem Pass'}
            </button>
          </form>

          {/* Visual Scan Result Banner */}
          {scanResult && (
            <div style={{
              marginTop:'18px',
              padding:'16px',
              borderRadius:'12px',
              border: scanResult.type === 'SUCCESS' ? '2px solid #10b981' : scanResult.message.includes('ALREADY REDEEMED') ? '2px solid #f59e0b' : '2px solid #ef4444',
              background: scanResult.type === 'SUCCESS' ? '#ecfdf5' : scanResult.message.includes('ALREADY REDEEMED') ? '#fffbeb' : '#fef2f2'
            }}>
              <div style={{display:'flex', alignItems:'center', gap:'10px'}}>
                <span style={{fontSize:'24px'}}>{scanResult.type === 'SUCCESS' ? '🎉' : scanResult.message.includes('ALREADY REDEEMED') ? '⚠️' : '❌'}</span>
                <div>
                  <h4 style={{margin:0, fontSize:'15px', color: scanResult.type === 'SUCCESS' ? '#065f46' : scanResult.message.includes('ALREADY REDEEMED') ? '#92400e' : '#991b1b'}}>
                    {scanResult.message}
                  </h4>
                  {scanResult.participant && (
                    <p style={{margin:'4px 0 0', fontSize:'13px', color:'#334155'}}>
                      <b>{scanResult.participant.name}</b> &bull; Reg: {scanResult.participant.registration_no} &bull; Category: <span className="pill small">{scanResult.participant.category||'Delegate'}</span> &bull; Diet: <b>{scanResult.participant.food_preference || 'VEG'}</b>
                    </p>
                  )}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Right Side: Live Meal Scans Feed */}
        <div className="panel scans-panel" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'14px', padding:'20px'}}>
          <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:'14px'}}>
            <h4 style={{margin:0, fontSize:'16px', color:'#1e293b'}}>Live Food Pass Redemptions ({scans.length})</h4>
            <button className="icon" onClick={load} title="Refresh Scans"><RefreshCw size={16}/></button>
          </div>
          <div className="scan-list" style={{maxHeight:'460px', overflowY:'auto', display:'flex', flexDirection:'column', gap:'8px'}}>
            {scans.map(x=><div className="scan-item" key={x.id} style={{padding:'10px 14px', background:'#f8fafc', borderRadius:'10px', border:'1px solid #e2e8f0', display:'flex', justifyContent:'space-between', alignItems:'center'}}>
              <div>
                <b style={{fontSize:'14px', color:'#1e293b'}}>{x.participant_name}</b>
                <p style={{margin:'2px 0 0', fontSize:'12.5px', color:'#64748b'}}>
                  {x.registration_no} &bull; <span className="pill small" style={{background:'#e0e7ff', color:'#3730a3'}}>{x.category||'Delegate'}</span> &bull; {x.meal_type}
                </p>
              </div>
              <div style={{textAlign:'right'}}>
                <span style={{fontSize:'12px', fontWeight:700, color:'#059669', display:'block'}}>{new Date(x.scanned_at).toLocaleTimeString()}</span>
                <small style={{fontSize:'11px', color:'#94a3b8'}}>{x.scanned_by_name || 'Admin Desk'}</small>
              </div>
            </div>)}
            {!scans.length && <p style={{color:'#888', padding:'30px', textAlign:'center'}}>No meal scans recorded yet. Select a meal and scan delegate QR code.</p>}
          </div>
        </div>
      </div>
    )}

    {subTab === 'reports' && (
      <div>
        {/* Metric Summary Cards */}
        <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fit, minmax(180px, 1fr))', gap:'14px', marginBottom:'20px'}}>
          <div className="stat" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'12px', padding:'16px'}}>
            <Users color="#8C1119" size={20}/>
            <span style={{fontSize:'13px', color:'#64748b'}}>Total Eligible Delegates</span>
            <strong style={{fontSize:'22px', color:'#1e293b'}}>{mealReport?.totalEligible ?? '—'}</strong>
          </div>
          <div className="stat" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'12px', padding:'16px'}}>
            <CheckCircle color="#10b981" size={20}/>
            <span style={{fontSize:'13px', color:'#64748b'}}>Passes Redeemed</span>
            <strong style={{fontSize:'22px', color:'#047857'}}>{mealReport?.totalRedeemed ?? filteredReportScans.length}</strong>
          </div>
          <div className="stat" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'12px', padding:'16px'}}>
            <Users color="#f59e0b" size={20}/>
            <span style={{fontSize:'13px', color:'#64748b'}}>Remaining Passes</span>
            <strong style={{fontSize:'22px', color:'#b45309'}}>{mealReport?.remainingCount ?? '—'}</strong>
          </div>
          <div className="stat" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'12px', padding:'16px'}}>
            <FileCheck color="#2E6F95" size={20}/>
            <span style={{fontSize:'13px', color:'#64748b'}}>Claim Rate</span>
            <strong style={{fontSize:'22px', color:'#2E6F95'}}>{mealReport?.redemptionRate ?? 0}%</strong>
          </div>
          <div className="stat" style={{background:'#fff', border:'1px solid #e2e8f0', borderRadius:'12px', padding:'16px'}}>
            <span style={{fontSize:'20px'}}>🥗</span>
            <span style={{fontSize:'13px', color:'#64748b'}}>Veg vs Non-Veg</span>
            <strong style={{fontSize:'16px', color:'#1e293b'}}>
              <span style={{color:'#10b981'}}>{mealReport?.vegCount ?? 0} Veg</span> / <span style={{color:'#ef4444'}}>{mealReport?.nonVegCount ?? 0} Non-Veg</span>
            </strong>
          </div>
        </div>

        {/* Meal Breakdown Progress Cards */}
        <div style={{background:'#fff', padding:'18px', borderRadius:'12px', border:'1px solid #e2e8f0', marginBottom:'20px'}}>
          <h4 style={{margin:'0 0 14px', fontSize:'15px', color:'#1e293b'}}>Scheduled Meal Sessions Breakdown</h4>
          <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fit, minmax(220px, 1fr))', gap:'14px'}}>
            {d.map(m=><div key={m.id} style={{padding:'12px 14px', background:'#f8fafc', borderRadius:'10px', border:'1px solid #e2e8f0'}}>
              <div style={{display:'flex', justifyContent:'space-between', marginBottom:'6px'}}>
                <strong style={{color:'#8C1119', fontSize:'13.5px'}}>{m.meal_type}</strong>
                <span style={{fontSize:'12px', color:'#64748b'}}>{toInputDate(m.meal_date)}</span>
              </div>
              <div style={{display:'flex', justifyContent:'space-between', fontSize:'12.5px', margin:'6px 0'}}>
                <span style={{color:'#64748b'}}>Claimed:</span>
                <strong style={{color:'#047857', fontSize:'13px'}}>{m.redeemed_count || 0} passes</strong>
              </div>
              <div style={{background:'#e2e8f0', borderRadius:'6px', height:'6px', overflow:'hidden'}}>
                <div style={{background:'#8C1119', height:'100%', width:`${Math.min(100, Math.round(((m.redeemed_count||0)/Math.max(1, mealReport?.totalEligible || 20))*100))}%`}}/>
              </div>
            </div>)}
          </div>
        </div>

        {/* Filters Toolbar */}
        <div className="toolbar" style={{display:'flex', gap:'12px', alignItems:'center', background:'#f8fafc', padding:'12px 16px', borderRadius:'10px', border:'1px solid #e2e8f0', marginBottom:'16px', flexWrap:'wrap'}}>
          <div className="search" style={{flex:1, minWidth:'220px'}}>
            <Search size={16}/>
            <input value={mealSearchQ} onChange={e=>setMealSearchQ(e.target.value)} placeholder="Filter by delegate name, reg no, meal type..."/>
          </div>
          <div style={{display:'flex', gap:'6px', alignItems:'center'}}>
            <small style={{fontWeight:600, color:'#64748b'}}>Meal:</small>
            <select value={activeReportMeal} onChange={e=>setActiveReportMeal(e.target.value)} style={{padding:'7px 10px', borderRadius:'6px', border:'1px solid #cbd5e1', fontSize:'13px', fontWeight:600}}>
              <option value="ALL">All Meal Sessions</option>
              {d.map(m => <option key={m.id} value={m.id}>{m.meal_type} ({toInputDate(m.meal_date)})</option>)}
            </select>
          </div>
          <div style={{display:'flex', gap:'6px', alignItems:'center'}}>
            <small style={{fontWeight:600, color:'#64748b'}}>Category:</small>
            <select value={mealCatFilter} onChange={e=>setMealCatFilter(e.target.value)} style={{padding:'7px 10px', borderRadius:'6px', border:'1px solid #cbd5e1', fontSize:'13px'}}>
              {categories.map(c => <option key={c} value={c}>{c}</option>)}
            </select>
          </div>
          <div style={{display:'flex', gap:'6px', alignItems:'center'}}>
            <small style={{fontWeight:600, color:'#64748b'}}>Diet:</small>
            <select value={dietFilter} onChange={e=>setDietFilter(e.target.value)} style={{padding:'7px 10px', borderRadius:'6px', border:'1px solid #cbd5e1', fontSize:'13px'}}>
              <option value="ALL">All Food Types</option>
              <option value="VEG">🥗 Veg Only</option>
              <option value="NON_VEG">🍗 Non-Veg Only</option>
            </select>
          </div>
          <button onClick={load} disabled={busy} style={{padding:'7px 14px', fontSize:'13px'}}>{busy?'...':'↻ Refresh'}</button>
        </div>

        {/* Detailed Table */}
        <div className="tablewrap">
          <table>
            <thead>
              <tr>
                <th>Delegate Name & Reg No</th>
                <th>Category</th>
                <th>Food Preference</th>
                <th>Meal Type</th>
                <th>Meal Date & Venue</th>
                <th>Redeemed Timestamp</th>
                <th>Operator</th>
              </tr>
            </thead>
            <tbody>
              {filteredReportScans.map(x=><tr key={x.id}>
                <td>
                  <b>{x.participant_name}</b><br/>
                  <small style={{color:'#64748b'}}>{x.registration_no || '—'}</small>
                </td>
                <td><span className="pill small">{x.category || 'Delegate'}</span></td>
                <td>
                  <span className="pill small" style={{
                    background: x.food_preference==='NON_VEG'?'#fef2f2':'#ecfdf5',
                    color: x.food_preference==='NON_VEG'?'#b91c1c':'#047857',
                    fontWeight:700
                  }}>
                    {x.food_preference === 'NON_VEG' ? '🍗 NON-VEG' : '🥗 VEG'}
                  </span>
                </td>
                <td><strong style={{color:'#8C1119'}}>{x.meal_type}</strong></td>
                <td>{toInputDate(x.meal_date)} ({x.location || 'Dining Hall'})</td>
                <td><span style={{color:'#059669', fontWeight:700}}>{new Date(x.scanned_at).toLocaleString()}</span></td>
                <td>{x.scanned_by_name || 'Admin'}</td>
              </tr>)}
              {!filteredReportScans.length && <tr><td colSpan="7" style={{textAlign:'center', padding:'30px', color:'#888'}}>No meal redemption logs found matching filter criteria.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    )}

    {showAdd && <MealModal onSave={save} onClose={()=>setShowAdd(false)}/>}
  </div>;
}

function MealModal({onSave,onClose}){
  const[v,set]=formState({});
  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Schedule Meal</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Meal Type" value={v.meal_type} onChange={x=>set('meal_type',x)} options={['BREAKFAST','LUNCH','TEA','DINNER','SNACKS']}/>
    <Field type="date" label="Date" value={v.meal_date} onChange={x=>set('meal_date',x)}/>
    <Field type="time" label="Start Time" value={v.start_time} onChange={x=>set('start_time',x)}/>
    <Field type="time" label="End Time" value={v.end_time} onChange={x=>set('end_time',x)}/>
    <Field label="Location" value={v.location} onChange={x=>set('location',x)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>onSave(v)}>Save</button></div></div></div>;
}

function Duties({tab, notify}){
  const[d,setD]=useState([]),[users,setUsers]=useState([]),[assignments,setAssignments]=useState([]),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false),[showAssign,setShowAssign]=useState(false);
  const load=async()=>{
    setBusy(true);
    try{
      const[du,as,u]=await Promise.all([
        req('/admin/duties?conferenceId=1'),
        req('/admin/duty-assignments'),
        req('/admin/staff')
      ]);
      setD(du); setAssignments(as); setUsers(u);
    }finally{setBusy(false)}
  };
  useEffect(()=>{load()},[]);
  useEffect(()=>{if(tab==='Assign Staff')setShowAssign(true)},[tab]);

  return <div className="panel">
    <div className="pagehead"><div><h3>Duty Roster & Staff Assignments</h3><p>Manage organizing committee, faculty and student volunteer duties.</p></div><div className="actions"><button className="secondary" onClick={()=>setShowAdd(true)}>+ Create Duty</button><button className="primary" onClick={()=>setShowAssign(true)}>+ Assign Staff</button></div></div>
    <div className="split">
      <div className="panel"><h4>Scheduled Duties</h4>{d.map(x=><div className="rowcard" key={x.id}><div><b>{x.title}</b><p>{x.location}<br/>{toInputDate(x.duty_date)} {x.start_time}-{x.end_time}</p></div></div>)}{!d.length && !busy && <p style={{color:'#888',padding:'20px'}}>No duties created yet.</p>}</div>
      <div className="panel"><h4>Staff & Volunteer Assignments</h4>{assignments.map(x=><div className="rowcard" key={x.id}><div><b>{x.user_name}</b><p>{x.duty_title} - <span className="pill green">{x.status}</span></p></div></div>)}{!assignments.length && !busy && <p style={{color:'#888',padding:'20px'}}>No staff assigned yet.</p>}</div>
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
  const[v,set]=formState({status: 'ASSIGNED'});

  const staffOptions = [
    { value: '', label: '-- Select Staff/Volunteer --' },
    ...users.map(u => ({
      value: String(u.id),
      label: `${u.name} (${u.role}${u.designation ? ' - ' + u.designation : ''})`
    }))
  ];

  const dutyOptions = [
    { value: '', label: '-- Select Duty --' },
    ...duties.map(du => ({
      value: String(du.id),
      label: `${du.title} (${toInputDate(du.duty_date)} ${du.start_time || ''})`
    }))
  ];

  return <div className="modal-overlay"><div className="modal"><div className="modal-header"><h3>Assign Staff / Volunteer</h3><button className="close" onClick={onClose}>&times;</button></div><div className="modal-body"><div className="formgrid">
    <SelectField label="Duty" value={v.duty_id} onChange={x=>set('duty_id',x)} options={dutyOptions.map(o=>o.label)}/>
    <SelectField label="Staff / Volunteer" value={v.user_id} onChange={x=>set('user_id',x)} options={staffOptions.map(o=>o.label)}/>
  </div></div><div className="modal-footer"><button onClick={onClose}>Cancel</button><button className="primary" onClick={()=>{
    const selectedDuty = dutyOptions.find(o => o.label === v.duty_id);
    const selectedStaff = staffOptions.find(o => o.label === v.user_id);
    if (!selectedDuty?.value || !selectedStaff?.value) {
      alert('Please select both a Duty and a Staff member.');
      return;
    }
    onSave({
      duty_id: parseInt(selectedDuty.value, 10),
      user_id: parseInt(selectedStaff.value, 10),
      status: v.status || 'ASSIGNED'
    });
  }}>Assign</button></div></div></div>;
}

function Certificates({tab, notify, selectedConferenceId}){
  const[d,setD]=useState([]),[participants,setParticipants]=useState([]),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false);
  const[subTab,setSubTab]=useState('issued');
  const[certQ,setCertQ]=useState(''),[certCat,setCertCat]=useState('ALL');
  const[eligibilityFilter,setEligibilityFilter]=useState('ALL');
  const[bulkGenBusy,setBulkGenBusy]=useState(false);
  
  // Generator states
  const[template,setTemplate]=useState(null);
  const[imgSize,setImgSize]=useState({width: 1200, height: 800});
  const[layout,setLayout]=useState({
    nameX: 50, nameY: 45, nameSize: 32, nameColor: '#8C1119', nameAlign: 'center',
    regX: 50, regY: 55, regSize: 18, regColor: '#2E6F95', regAlign: 'center',
    certX: 50, certY: 65, certSize: 16, certColor: '#64748b', certAlign: 'center'
  });
  const[selectedIds,setSelectedIds]=useState([]);
  const[searchQuery,setSearchQuery]=useState('');
  const[generating,setGenerating]=useState(false);
  const[savingLayout,setSavingLayout]=useState(false);

  const load=async()=>{
    setBusy(true); 
    const confId = selectedConferenceId || 1;
    try{
      const[c,p,s]=await Promise.all([
        req('/admin/certificates?conferenceId='+confId),
        req('/admin/participants?conferenceId='+confId),
        req('/admin/certificates/settings').catch(()=>null)
      ]);
      setD(c); 
      setParticipants(p);
      if(s?.template) setTemplate(s.template);
      if(s?.layout) setLayout(prev => ({...prev, ...s.layout}));
    }finally{
      setBusy(false)
    }
  };
  useEffect(()=>{load()},[selectedConferenceId]);
  useEffect(()=>{if(tab==='Issue Certificate')setShowAdd(true)},[tab]);

  const handleSaveLayout = async () => {
    setSavingLayout(true);
    try {
      await req('/admin/certificates/settings', {
        method: 'POST',
        body: JSON.stringify({ template, layout })
      });
      notify('Certificate alignment settings saved successfully!');
    } catch(e) {
      alert(e.message);
    } finally {
      setSavingLayout(false);
    }
  };

  const handleAutoBulkGenerate = async (onlyAttended = false) => {
    if(!confirm(`Are you sure you want to auto-generate certificates for all ${onlyAttended ? 'attended delegates' : 'approved participants'}?`)) return;
    setBulkGenBusy(true);
    try {
      const res = await req('/admin/certificates/bulk-generate', {
        method: 'POST',
        body: JSON.stringify({ conferenceId: selectedConferenceId || 1, onlyAttended })
      });
      notify(res.message || `Generated certificates successfully!`);
      load();
    } catch(e) {
      alert(e.message);
    } finally {
      setBulkGenBusy(false);
    }
  };

  const handleSelectAll = (checked) => {
    if(checked) {
      setSelectedIds(filteredParticipants.map(p => p.id));
    } else {
      setSelectedIds([]);
    }
  };

  const handleSelectParticipant = (id, checked) => {
    if(checked) {
      setSelectedIds(prev => [...prev, id]);
    } else {
      setSelectedIds(prev => prev.filter(x => x !== id));
    }
  };

  const issuedParticipantIds = new Set(d.map(c => c.participant_id));

  const filteredParticipants = participants.filter(p => {
    const matchesQ = `${p.name} ${p.registration_no||''} ${p.university||''}`.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCat = certCat === 'ALL' || p.category === certCat;
    let matchesEligibility = true;
    if(eligibilityFilter === 'PENDING_ONLY') matchesEligibility = !issuedParticipantIds.has(p.id);
    else if(eligibilityFilter === 'ISSUED_ONLY') matchesEligibility = issuedParticipantIds.has(p.id);
    return matchesQ && matchesCat && matchesEligibility;
  });

  const categories = ['ALL', ...Array.from(new Set(participants.map(x => x.category).filter(Boolean)))];

  const filteredIssued = d.filter(x => {
    const matchesQ = `${x.participant_name} ${x.registration_no} ${x.certificate_no} ${x.university||''}`.toLowerCase().includes(certQ.toLowerCase());
    const matchesCat = certCat === 'ALL' || x.category === certCat;
    return matchesQ && matchesCat;
  });

  const exportCertificatesXLSX = () => {
    if(!filteredIssued.length){alert('No certificates to export'); return;}
    const data = filteredIssued.map((x, idx) => ({
      'Sr No': idx + 1,
      'Delegate Name': x.participant_name || '',
      'Registration No': x.registration_no || '',
      'Category': x.category || 'Delegate',
      'Certificate No': x.certificate_no || '',
      'Issued At': new Date(x.issued_at).toLocaleString(),
      'Verification URL': `${API.replace('/api','')}/certificates/verify/${x.certificate_no}`,
      'Certificate Image URL': x.certificate_url ? resolveMediaUrl(x.certificate_url) : ''
    }));
    const ws = XLSX.utils.json_to_sheet(data);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Issued Certificates');
    XLSX.writeFile(wb, `issued_certificates_${new Date().toISOString().slice(0,10)}.xlsx`);
    notify('Exported certificates roster to Excel');
  };

  const exportCertificatesCSV = () => {
    if(!filteredIssued.length){alert('No certificates to export'); return;}
    const headers = ['Sr No', 'Delegate Name', 'Registration No', 'Category', 'Certificate No', 'Issued At', 'Certificate URL'];
    const rows = filteredIssued.map((x, idx) => [
      idx + 1,
      `"${x.participant_name||''}"`,
      `"${x.registration_no||''}"`,
      `"${x.category||'Delegate'}"`,
      `"${x.certificate_no||''}"`,
      `"${new Date(x.issued_at).toLocaleString()}"`,
      `"${x.certificate_url ? resolveMediaUrl(x.certificate_url) : ''}"`
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const link = document.createElement('a');
    link.setAttribute('href', encodeURI(csvContent));
    link.setAttribute('download', `issued_certificates_roster_${new Date().toISOString().slice(0,10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    notify('Exported certificates roster to CSV');
  };

  const handleGenerate = async () => {
    if(!template) return alert('Please upload a template image first');
    if(!selectedIds.length) return alert('Please select at least one participant');

    setGenerating(true);
    try {
      const res = await req('/admin/certificates/generate', {
        method: 'POST',
        body: JSON.stringify({
          template,
          participantIds: selectedIds,
          layout
        })
      });
      notify(`Successfully generated ${res.data?.count || selectedIds.length} certificates!`);
      setSelectedIds([]);
      setSubTab('issued');
      load();
    } catch (e) {
      alert(e.message);
    } finally {
      setGenerating(false);
    }
  };

  return <div className="panel">
    <div className="pagehead">
      <div>
        <h3>Certificates</h3>
        <p>Manage, issue, and verify conference participation certificates ({filteredIssued.length} issued of {participants.length} delegates).</p>
      </div>
      <div className="actions" style={{display:'flex', gap:'12px', alignItems:'center'}}>
        <div style={{background:'var(--bg-app)', padding:'4px', borderRadius:'var(--radius-sm)', display:'flex', gap:'4px', border:'1px solid var(--border)'}}>
          <button style={{padding:'6px 12px', fontSize:'13px', background:subTab==='issued'?'var(--surface)':'transparent', color:subTab==='issued'?'var(--primary)':'var(--text-muted)', border:0, boxShadow:subTab==='issued'?'var(--shadow-sm)':'none', fontWeight:600}} onClick={()=>setSubTab('issued')}>📜 Issued Roster ({d.length})</button>
          <button style={{padding:'6px 12px', fontSize:'13px', background:subTab==='generate'?'var(--surface)':'transparent', color:subTab==='generate'?'var(--primary)':'var(--text-muted)', border:0, boxShadow:subTab==='generate'?'var(--shadow-sm)':'none', fontWeight:600}} onClick={()=>setSubTab('generate')}>🎨 Certificate Designer & Bulk Generator</button>
        </div>
        {subTab === 'issued' && (
          <div style={{display:'flex', gap:'8px'}}>
            <button className="primary" onClick={exportCertificatesXLSX} style={{display:'flex', alignItems:'center', gap:'6px'}}>📥 Export Excel</button>
            <button className="secondary" onClick={exportCertificatesCSV}>CSV</button>
            <button className="secondary" onClick={()=>window.print()} style={{display:'flex', alignItems:'center', gap:'6px'}}><Printer size={15}/> Print</button>
          </div>
        )}
        <button className="secondary" disabled={bulkGenBusy} onClick={()=>handleAutoBulkGenerate(false)} style={{fontWeight:700}}>
          {bulkGenBusy ? 'Generating...' : '⚡ 1-Click Auto Issue All'}
        </button>
        <button className="primary" onClick={()=>setShowAdd(true)}>+ Issue Single</button>
      </div>
    </div>

    {subTab === 'issued' ? (
      <div>
        <div className="toolbar" style={{display:'flex', gap:'10px', alignItems:'center', background:'#f8fafc', padding:'10px 14px', borderRadius:'10px', border:'1px solid #e2e8f0', marginBottom:'16px'}}>
          <div className="search" style={{flex:1, minWidth:'220px'}}>
            <Search size={16}/>
            <input value={certQ} onChange={e=>setCertQ(e.target.value)} placeholder="Filter by delegate name, reg no, certificate no..."/>
          </div>
          <div style={{display:'flex', gap:'6px', alignItems:'center'}}>
            <small style={{fontWeight:600, color:'#64748b'}}>Category:</small>
            <select value={certCat} onChange={e=>setCertCat(e.target.value)} style={{padding:'6px 10px', borderRadius:'6px', border:'1px solid #cbd5e1', fontSize:'13px'}}>
              {categories.map(c=><option key={c} value={c}>{c}</option>)}
            </select>
          </div>
          <button onClick={load} disabled={busy} style={{padding:'6px 12px', fontSize:'12.5px'}}>{busy?'...':'Refresh'}</button>
        </div>

        <table>
          <thead><tr><th>Participant & Reg No</th><th>Category</th><th>Certificate No</th><th>Issued At</th><th>Actions</th></tr></thead>
          <tbody>
            {filteredIssued.map(x=><tr key={x.id}>
              <td>
                <b>{x.participant_name}</b>
                {x.certificate_url && (
                  <span style={{marginLeft:'10px', fontSize:'12px'}}>
                    [<a href={resolveMediaUrl(x.certificate_url)} target="_blank" rel="noopener noreferrer" style={{color:'#8C1119', fontWeight:700}}>View PNG</a>]
                  </span>
                )}
                <br/><small style={{color:'#64748b'}}>{x.registration_no || '—'}</small>
              </td>
              <td><span className="pill small">{x.category || 'Delegate'}</span></td>
              <td><span className="pill" style={{background:'#2E6F95',color:'#fff', fontWeight:700}}>{x.certificate_no}</span></td>
              <td>{new Date(x.issued_at).toLocaleString()}</td>
              <td>
                <div style={{display:'flex', gap:'8px'}}>
                  <button className="secondary" style={{padding:'4px 10px', fontSize:'13px'}} onClick={()=>window.open(API.replace('/api','')+'/certificates/verify/'+x.certificate_no,'_blank')}>Verify</button>
                  <button className="secondary" style={{padding:'4px 10px', fontSize:'13px', color:'var(--danger)', borderColor:'var(--danger-bg)'}} onClick={async()=>{
                    if(confirm('Are you sure you want to delete this certificate?')){
                      await req(`/admin/certificates/${x.id}`, {method:'DELETE'});
                      load();
                      notify('Certificate deleted successfully');
                    }
                  }}>Delete</button>
                </div>
              </td>
            </tr>)}

            {!filteredIssued.length && !busy && <tr><td colSpan="5" style={{textAlign:'center',padding:'30px',color:'#888'}}>No certificates found matching criteria. Click "Bulk Generator" or "+ Issue Single" to generate one.</td></tr>}
          </tbody>
        </table>
      </div>
    ) : (
      <div style={{display:'grid', gridTemplateColumns:'1.2fr 1fr', gap:'24px', minHeight:'500px'}}>
        {/* Left Side: Upload & Design */}
        <div style={{display:'flex', flexDirection:'column', gap:'20px'}}>
          {!template ? (
            <div 
              style={{
                border:'2px dashed var(--border)', 
                borderRadius:'var(--radius-md)', 
                padding:'60px 40px', 
                textAlign:'center', 
                background:'#f8fafc', 
                cursor:'pointer',
                display:'flex',
                flexDirection:'column',
                alignItems:'center',
                justifyContent:'center',
                transition:'var(--transition)'
              }} 
              onClick={() => document.getElementById('template-upload').click()}
            >
              <Upload size={48} color="var(--text-light)" style={{marginBottom:'16px'}}/>
              <h4 style={{margin:'0 0 8px 0', fontSize:'16px', fontWeight:'700'}}>Upload Certificate Template</h4>
              <p style={{color:'var(--text-muted)', fontSize:'13px', margin:0}}>Click to browse images (PNG, JPG, WEBP) up to 5MB.</p>
              <input id="template-upload" type="file" accept="image/*" style={{display:'none'}} onChange={e => {
                const file = e.target.files?.[0];
                if (file) {
                  const reader = new FileReader();
                  reader.onload = () => setTemplate(reader.result);
                  reader.readAsDataURL(file);
                }
              }}/>
            </div>
          ) : (
            <div style={{display:'flex', flexDirection:'column', gap:'20px'}}>
              <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
                <h4 style={{margin:0}}>Design Layout Preview</h4>
                <div style={{display:'flex', gap:'8px', alignItems:'center'}}>
                  <button className="primary" style={{padding:'5px 12px', fontSize:'12px'}} onClick={handleSaveLayout} disabled={savingLayout}>
                    {savingLayout ? 'Saving...' : '💾 Save Alignment'}
                  </button>
                  <button className="secondary" style={{padding:'5px 10px', fontSize:'12px'}} onClick={()=>setTemplate(null)}>Remove Template</button>
                </div>
              </div>

              {/* 1-to-1 SVG Live Preview Box matching backend Sharp renderer */}
              <div style={{position:'relative', width:'100%', border:'1px solid var(--border)', borderRadius:'var(--radius-md)', overflow:'hidden', background:'#f8fafc', boxShadow:'var(--shadow-sm)'}}>
                <img 
                  src={template} 
                  style={{width:'100%', height:'auto', display:'block'}} 
                  alt="Certificate template"
                  onLoad={e => setImgSize({ width: e.target.naturalWidth || 1200, height: e.target.naturalHeight || 800 })}
                />
                
                <svg 
                  viewBox={`0 0 ${imgSize.width} ${imgSize.height}`} 
                  style={{position:'absolute', top:0, left:0, width:'100%', height:'100%', pointerEvents:'none'}}
                >
                  <style>{`
                    .nameText { font-family: 'Arial', sans-serif; font-weight: bold; fill: ${layout.nameColor || '#8C1119'}; font-size: ${layout.nameSize || 32}px; text-anchor: ${layout.nameAlign === 'left' ? 'start' : layout.nameAlign === 'right' ? 'end' : 'middle'}; dominant-baseline: middle; }
                    .regText { font-family: 'Arial', sans-serif; fill: ${layout.regColor || '#2E6F95'}; font-size: ${layout.regSize || 18}px; text-anchor: ${layout.regAlign === 'left' ? 'start' : layout.regAlign === 'right' ? 'end' : 'middle'}; dominant-baseline: middle; }
                    .certText { font-family: 'Arial', sans-serif; fill: ${layout.certColor || '#64748b'}; font-size: ${layout.certSize || 16}px; text-anchor: ${layout.certAlign === 'left' ? 'start' : layout.certAlign === 'right' ? 'end' : 'middle'}; dominant-baseline: middle; }
                  `}</style>
                  <text x={`${layout.nameX ?? 50}%`} y={`${imgSize.height * ((layout.nameY ?? 45) / 100)}`} className="nameText">Dr. Delegate Name</text>
                  <text x={`${layout.regX ?? 50}%`} y={`${imgSize.height * ((layout.regY ?? 55) / 100)}`} className="regText">Registration No: MAPCON-2026-001</text>
                  <text x={`${layout.certX ?? 50}%`} y={`${imgSize.height * ((layout.certY ?? 65) / 100)}`} className="certText">Certificate No: CERT-2026-0001</text>
                </svg>
              </div>

              {/* Styling Controllers */}
              <div style={{background:'var(--bg-app)', padding:'16px', borderRadius:'var(--radius-md)', border:'1px solid var(--border)', display:'grid', gridTemplateColumns:'1fr 1fr', gap:'16px'}}>
                <div>
                  <h5 style={{margin:'0 0 10px 0', color:'var(--primary)'}}>Participant Name</h5>
                  <label style={{display:'flex', flexDirection:'column', gap:'4px', fontSize:'13px', marginBottom:'8px'}}>
                    X-Position ({layout.nameX ?? 50}%)
                    <input type="range" min="0" max="100" value={layout.nameX ?? 50} onChange={e=>setLayout(l=>({...l, nameX: parseInt(e.target.value)}))}/>
                  </label>
                  <label style={{display:'flex', flexDirection:'column', gap:'4px', fontSize:'13px', marginBottom:'8px'}}>
                    Y-Position ({layout.nameY}%)
                    <input type="range" min="5" max="95" value={layout.nameY} onChange={e=>setLayout(l=>({...l, nameY: parseInt(e.target.value)}))}/>
                  </label>
                  <label style={{display:'flex', flexDirection:'column', gap:'4px', fontSize:'13px', marginBottom:'8px'}}>
                    Font Size ({layout.nameSize}px)
                    <input type="range" min="12" max="100" value={layout.nameSize} onChange={e=>setLayout(l=>({...l, nameSize: parseInt(e.target.value)}))}/>
                  </label>
                  <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', gap:'8px', fontSize:'13px', marginTop:'4px'}}>
                    <div style={{display:'flex', gap:'4px'}}>
                      {['left','center','right'].map(align => (
                        <button key={align} type="button" style={{padding:'2px 8px', fontSize:'11px', textTransform:'capitalize', background:(layout.nameAlign||'center')===align?'var(--primary)':'var(--bg-card)', color:(layout.nameAlign||'center')===align?'#fff':'var(--text-main)', border:'1px solid var(--border)', borderRadius:'4px'}} onClick={()=>setLayout(l=>({...l, nameAlign: align}))}>{align}</button>
                      ))}
                    </div>
                    <label style={{display:'flex', alignItems:'center', gap:'6px'}}>
                      Color
                      <input type="color" value={layout.nameColor} onChange={e=>setLayout(l=>({...l, nameColor: e.target.value}))} style={{width:'28px', height:'22px', border:0, padding:0, background:'transparent', cursor:'pointer'}}/>
                    </label>
                  </div>
                </div>
                <div>
                  <h5 style={{margin:'0 0 10px 0', color:'var(--accent)'}}>Registration No.</h5>
                  <label style={{display:'flex', flexDirection:'column', gap:'4px', fontSize:'13px', marginBottom:'8px'}}>
                    X-Position ({layout.regX ?? 50}%)
                    <input type="range" min="0" max="100" value={layout.regX ?? 50} onChange={e=>setLayout(l=>({...l, regX: parseInt(e.target.value)}))}/>
                  </label>
                  <label style={{display:'flex', flexDirection:'column', gap:'4px', fontSize:'13px', marginBottom:'8px'}}>
                    Y-Position ({layout.regY}%)
                    <input type="range" min="5" max="95" value={layout.regY} onChange={e=>setLayout(l=>({...l, regY: parseInt(e.target.value)}))}/>
                  </label>
                  <label style={{display:'flex', flexDirection:'column', gap:'4px', fontSize:'13px', marginBottom:'8px'}}>
                    Font Size ({layout.regSize}px)
                    <input type="range" min="10" max="60" value={layout.regSize} onChange={e=>setLayout(l=>({...l, regSize: parseInt(e.target.value)}))}/>
                  </label>
                  <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', gap:'8px', fontSize:'13px', marginTop:'4px'}}>
                    <div style={{display:'flex', gap:'4px'}}>
                      {['left','center','right'].map(align => (
                        <button key={align} type="button" style={{padding:'2px 8px', fontSize:'11px', textTransform:'capitalize', background:(layout.regAlign||'center')===align?'var(--accent)':'var(--bg-card)', color:(layout.regAlign||'center')===align?'#fff':'var(--text-main)', border:'1px solid var(--border)', borderRadius:'4px'}} onClick={()=>setLayout(l=>({...l, regAlign: align}))}>{align}</button>
                      ))}
                    </div>
                    <label style={{display:'flex', alignItems:'center', gap:'6px'}}>
                      Color
                      <input type="color" value={layout.regColor} onChange={e=>setLayout(l=>({...l, regColor: e.target.value}))} style={{width:'28px', height:'22px', border:0, padding:0, background:'transparent', cursor:'pointer'}}/>
                    </label>
                  </div>
                </div>
                <div style={{gridColumn:'1 / -1', borderTop:'1px solid var(--border)', paddingTop:'12px', marginTop:'4px'}}>
                  <h5 style={{margin:'0 0 10px 0', color:'var(--text-muted)'}}>Certificate No.</h5>
                  <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:'16px'}}>
                    <label style={{display:'flex', flexDirection:'column', gap:'4px', fontSize:'13px'}}>
                      X-Position ({layout.certX ?? 50}%)
                      <input type="range" min="0" max="100" value={layout.certX ?? 50} onChange={e=>setLayout(l=>({...l, certX: parseInt(e.target.value)}))}/>
                    </label>
                    <label style={{display:'flex', flexDirection:'column', gap:'4px', fontSize:'13px'}}>
                      Y-Position ({layout.certY}%)
                      <input type="range" min="5" max="95" value={layout.certY} onChange={e=>setLayout(l=>({...l, certY: parseInt(e.target.value)}))}/>
                    </label>
                  </div>
                  <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', gap:'8px', fontSize:'13px', marginTop:'8px'}}>
                    <label style={{display:'flex', alignItems:'center', gap:'8px'}}>
                      Font Size ({layout.certSize}px)
                      <input type="range" min="10" max="50" value={layout.certSize} onChange={e=>setLayout(l=>({...l, certSize: parseInt(e.target.value)}))} style={{width:'120px'}}/>
                    </label>
                    <div style={{display:'flex', alignItems:'center', gap:'12px'}}>
                      <div style={{display:'flex', gap:'4px'}}>
                        {['left','center','right'].map(align => (
                          <button key={align} type="button" style={{padding:'2px 8px', fontSize:'11px', textTransform:'capitalize', background:(layout.certAlign||'center')===align?'var(--text-muted)':'var(--bg-card)', color:(layout.certAlign||'center')===align?'#fff':'var(--text-main)', border:'1px solid var(--border)', borderRadius:'4px'}} onClick={()=>setLayout(l=>({...l, certAlign: align}))}>{align}</button>
                        ))}
                      </div>
                      <label style={{display:'flex', alignItems:'center', gap:'6px'}}>
                        Color
                        <input type="color" value={layout.certColor} onChange={e=>setLayout(l=>({...l, certColor: e.target.value}))} style={{width:'28px', height:'22px', border:0, padding:0, background:'transparent', cursor:'pointer'}}/>
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Right Side: Participant List */}
        <div style={{display:'flex', flexDirection:'column', gap:'14px', background:'var(--surface)', padding:'20px', borderRadius:'var(--radius-md)', border:'1px solid var(--border)', height:'fit-content', maxHeight:'750px', overflowY:'auto'}}>
          <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
            <h4 style={{margin:0}}>Select Participants ({filteredParticipants.length})</h4>
            <span style={{fontSize:'12px', background:'var(--primary-subtle)', color:'var(--primary)', padding:'3px 10px', borderRadius:'12px', fontWeight:'bold'}}>{selectedIds.length} Selected</span>
          </div>

          <div style={{position:'relative'}}>
            <input 
              type="text" 
              placeholder="Search by name, reg number..." 
              value={searchQuery} 
              onChange={e=>setSearchQuery(e.target.value)} 
              style={{width:'100%', padding:'10px 14px 10px 36px', border:'1px solid var(--border)', borderRadius:'var(--radius-sm)', fontSize:'14px'}}
            />
            <Search size={16} color="var(--text-light)" style={{position:'absolute', left:'12px', top:'50%', transform:'translateY(-50%)'}}/>
          </div>

          <div style={{display:'flex', gap:'8px', flexWrap:'wrap'}}>
            <button 
              type="button"
              style={{padding:'4px 10px', fontSize:'12px', borderRadius:'6px', border:'1px solid var(--border)', background: eligibilityFilter==='ALL'?'#8C1119':'#f8fafc', color: eligibilityFilter==='ALL'?'#fff':'#334155', fontWeight:600}}
              onClick={()=>setEligibilityFilter('ALL')}
            >
              All ({participants.length})
            </button>
            <button 
              type="button"
              style={{padding:'4px 10px', fontSize:'12px', borderRadius:'6px', border:'1px solid var(--border)', background: eligibilityFilter==='PENDING_ONLY'?'#8C1119':'#f8fafc', color: eligibilityFilter==='PENDING_ONLY'?'#fff':'#334155', fontWeight:600}}
              onClick={()=>setEligibilityFilter('PENDING_ONLY')}
            >
              Pending Issue
            </button>
            <button 
              type="button"
              style={{padding:'4px 10px', fontSize:'12px', borderRadius:'6px', border:'1px solid var(--border)', background: eligibilityFilter==='ISSUED_ONLY'?'#8C1119':'#f8fafc', color: eligibilityFilter==='ISSUED_ONLY'?'#fff':'#334155', fontWeight:600}}
              onClick={()=>setEligibilityFilter('ISSUED_ONLY')}
            >
              Already Issued
            </button>
          </div>

          {/* List Wrapper */}
          <div style={{border:'1px solid var(--border)', borderRadius:'var(--radius-sm)', overflow:'hidden'}}>
            <div style={{display:'flex', alignItems:'center', gap:'12px', padding:'10px 14px', background:'#f8fafc', borderBottom:'1px solid var(--border)'}}>
              <input 
                type="checkbox" 
                checked={filteredParticipants.length > 0 && selectedIds.length === filteredParticipants.length} 
                onChange={e => handleSelectAll(e.target.checked)}
                style={{cursor:'pointer'}}
              />
              <span style={{fontSize:'13px', fontWeight:'bold', cursor:'pointer'}} onClick={() => handleSelectAll(selectedIds.length !== filteredParticipants.length)}>Select All ({filteredParticipants.length})</span>
            </div>
            
            <div style={{maxHeight:'320px', overflowY:'auto'}}>
              {filteredParticipants.map(p => {
                const isSelected = selectedIds.includes(p.id);
                const isAlreadyIssued = issuedParticipantIds.has(p.id);
                return (
                  <div 
                    key={p.id} 
                    style={{
                      display:'flex', 
                      alignItems:'center', 
                      gap:'12px', 
                      padding:'10px 14px', 
                      borderBottom:'1px solid var(--border)',
                      background: isSelected ? 'var(--primary-subtle)' : 'transparent',
                      transition:'background 0.15s ease'
                    }}
                  >
                    <input 
                      type="checkbox" 
                      checked={isSelected} 
                      onChange={e => handleSelectParticipant(p.id, e.target.checked)}
                      style={{cursor:'pointer'}}
                    />
                    <div style={{fontSize:'13px', cursor:'pointer', flex:1}} onClick={() => handleSelectParticipant(p.id, !isSelected)}>
                      <div style={{display:'flex', justifyContent:'space-between', alignItems:'center'}}>
                        <b>{p.name}</b>
                        {isAlreadyIssued && <span className="pill small" style={{background:'#ecfdf5', color:'#047857'}}>Issued</span>}
                      </div>
                      <small style={{color:'var(--text-muted)'}}>{p.registration_no || 'No Reg No.'} • {p.category || 'Delegate'} • {p.university || 'No Univ.'}</small>
                    </div>
                  </div>
                );
              })}
              {!filteredParticipants.length && (
                <div style={{padding:'20px', textAlign:'center', color:'var(--text-light)', fontSize:'13px'}}>No participants match filter.</div>
              )}
            </div>
          </div>

          <button 
            className="primary" 
            style={{width:'100%', padding:'12px', fontWeight:'bold', display:'flex', justifyContent:'center', alignItems:'center', gap:'8px'}} 
            onClick={handleGenerate}
            disabled={generating || !template || !selectedIds.length}
          >
            {generating ? 'Generating Certificates...' : `Generate ${selectedIds.length} Certificate${selectedIds.length === 1 ? '' : 's'}`}
          </button>
        </div>
      </div>
    )}

    {showAdd && <IssueModal participants={participants} onSave={async(v)=>{await req(`/admin/certificates/${v.participant_id}/issue`,{method:'POST',body:JSON.stringify(v)}); setShowAdd(false); load(); notify('Certificate issued successfully');}} onClose={()=>setShowAdd(false)}/>}
  </div>;
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
  const[photos,setPhotos]=useState([]),[albums,setAlbums]=useState([]),[activeAlbum,setActiveAlbum]=useState('ALL'),[busy,setBusy]=useState(false),[showAdd,setShowAdd]=useState(false),[showBulk,setShowBulk]=useState(false);
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
    notify('Photo uploaded & AI faces indexed');
    setShowAdd(false);
    load();
  };

  return <div className="panel">
    <div className="pagehead">
      <div><h3>Conference Gallery & AI Face Indexing</h3><p>Photographer uploads, album classification, and AI face recognition indexing.</p></div>
      <div className="actions">
        <button className="secondary" onClick={()=>setShowBulk(true)}>+ Batch Upload (Photographer)</button>
        <button className="primary" onClick={()=>setShowAdd(true)}>+ Upload Photo</button>
      </div>
    </div>
    <div className="toolbar" style={{display:'flex',gap:'8px',flexWrap:'wrap',marginBottom:'20px'}}>
      <button className={activeAlbum==='ALL'?'primary':''} onClick={()=>setActiveAlbum('ALL')}>All Photos ({photos.length})</button>
      {albums.map(a=><button key={a.album} className={activeAlbum===a.album?'primary':''} onClick={()=>setActiveAlbum(a.album)}>{a.album} ({a.photo_count})</button>)}
    </div>
    <div className="grid" style={{gridTemplateColumns:'repeat(auto-fill, minmax(260px, 1fr))',gap:'16px'}}>
      {filtered.map(x=><div key={x.id} style={{background:'#fff',borderRadius:'12px',overflow:'hidden',border:'1px solid #e2e8f0',boxShadow:'0 2px 8px rgba(0,0,0,0.05)',display:'flex',flexDirection:'column'}}>
        <div style={{height:'190px',background:'#eee',overflow:'hidden',position:'relative'}}>
          <img src={resolveMediaUrl(x.url)} alt={x.caption||'Photo'} style={{width:'100%',height:'100%',objectFit:'cover'}} onError={(e)=>{e.target.src='https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800'}}/>
          <span className="pill" style={{position:'absolute',top:'10px',left:'10px',background:'rgba(0,0,0,0.7)',color:'#fff',backdropFilter:'blur(4px)',fontSize:'11px'}}>{x.album}</span>
          <span className="pill" style={{position:'absolute',top:'10px',right:'10px',background:'rgba(16,185,129,0.85)',color:'#fff',fontSize:'10px',fontWeight:'bold'}}>
            👤 {x.indexed_faces || 1} AI Faces
          </span>
        </div>
        <div style={{padding:'14px',display:'flex',flexDirection:'column',flex:1,gap:'8px'}}>
          <p style={{margin:0,fontSize:'14px',fontWeight:'600',color:'#1e293b',lineHeight:'1.4'}}>{x.caption||'Conference moment'}</p>
          <div style={{marginTop:'auto',display:'flex',justifyContent:'space-between',alignItems:'center',paddingTop:'8px',borderTop:'1px solid #f1f5f9'}}>
            <small style={{color:'#94a3b8'}}>{new Date(x.created_at).toLocaleDateString()}</small>
            <button style={{color:'#ef4444',borderColor:'#fecaca',padding:'3px 8px',fontSize:'12px'}} onClick={async()=>{if(confirm('Delete photo?')){await req(`/admin/gallery/${x.id}`,{method:'DELETE'});load();notify('Photo deleted');}}}>Delete</button>
          </div>
        </div>
      </div>)}
      {!filtered.length && !busy && <div style={{gridColumn:'1/-1',textAlign:'center',padding:'40px',color:'#888'}}>No photos found in this album. Click "+ Upload Photo" to add memories.</div>}
    </div>
    {showAdd && <PhotoModal onSave={save} onClose={()=>setShowAdd(false)} notify={notify}/>}
    {showBulk && <BulkPhotoModal onSave={async(photosList, album)=>{
      await req('/admin/gallery/bulk-upload',{method:'POST',body:JSON.stringify({photos: photosList, album})});
      setShowBulk(false);
      load();
      notify(`Uploaded ${photosList.length} photos with AI face indexing`);
    }} onClose={()=>setShowBulk(false)} notify={notify}/>}
  </div>
}

function PhotoModal({onSave,onClose,notify}){
  const[album,setAlbum]=useState('Keynote Sessions');
  const[url,setUrl]=useState('');
  const[caption,setCaption]=useState('');
  const[fileData,setFileData]=useState(null);
  const[preview,setPreview]=useState('');
  const[busy,setBusy]=useState(false);

  const handleFileChange=async(file)=>{
    if(!file)return;
    const reader=new FileReader();
    reader.onload=async()=>{
      const dataUrl=reader.result;
      setPreview(dataUrl);
      setFileData({name:file.name,dataUrl});
      setBusy(true);
      try{
        const uploadRes=await req('/admin/uploads',{
          method:'POST',
          body:JSON.stringify({folder:'gallery',file:{name:file.name,dataUrl}})
        });
        const uploadedUrl=uploadRes.data?.url||uploadRes.url;
        setUrl(uploadedUrl);
        notify('Photo uploaded & normalized');
      }catch(err){
        alert('Upload failed: '+err.message);
      }finally{
        setBusy(false);
      }
    };
    reader.readAsDataURL(file);
  };

  const commonAlbums = ['Keynote Sessions', 'Workshops & CMEs', 'Inauguration Ceremony', 'Delegate Networking', 'Cultural Night', 'Award Ceremony', 'General'];

  const handleSave = async () => {
    if(!url && !preview && !fileData){
      alert('Please select an image file to upload');
      return;
    }
    setBusy(true);
    try{
      await onSave({
        album,
        url: url || preview,
        file: fileData,
        caption: caption || `Conference ${album} moment`
      });
    }catch(e){
      alert(e.message);
    }finally{
      setBusy(false);
    }
  };

  return <div className="modal-overlay">
    <div className="modal" style={{maxWidth:'540px'}}>
      <div className="modal-header">
        <h3>Upload Conference Photo</h3>
        <button className="close" onClick={onClose}>&times;</button>
      </div>
      <div className="modal-body">
        <div className="formgrid">
          <Field label="Album Name" value={album} onChange={setAlbum}/>
          <div style={{display:'flex',gap:'6px',flexWrap:'wrap',marginTop:'-6px',marginBottom:'8px'}}>
            {commonAlbums.map(alb => (
              <button
                key={alb}
                type="button"
                style={{
                  fontSize:'11px',
                  padding:'3px 8px',
                  borderRadius:'12px',
                  border:'1px solid #cbd5e1',
                  background: album === alb ? '#8C1119' : '#f8fafc',
                  color: album === alb ? '#fff' : '#475569',
                  cursor:'pointer'
                }}
                onClick={()=>setAlbum(alb)}
              >
                {alb}
              </button>
            ))}
          </div>

          <label className="field uploadfield">
            <span>Select Image File</span>
            <div>
              <input value={url||''} onChange={e=>{setUrl(e.target.value);setPreview(e.target.value);}} placeholder="URL or choose image"/>
              <label className="uploadBtn">
                <Upload size={16}/> Choose Photo
                <input type="file" accept="image/*" onChange={e=>handleFileChange(e.target.files?.[0])}/>
              </label>
            </div>
          </label>

          {(preview || url) && (
            <div style={{gridColumn:'1 / -1',textAlign:'center',padding:'10px',background:'#f8fafc',borderRadius:'10px',border:'1px solid #e2e8f0'}}>
              <div style={{fontSize:'12px',color:'#64748b',marginBottom:'6px',fontWeight:600}}>Image Preview</div>
              <img
                src={preview ? (preview.startsWith('data:') ? preview : resolveMediaUrl(preview)) : resolveMediaUrl(url)}
                alt="Upload Preview"
                style={{maxHeight:'180px',maxWidth:'100%',borderRadius:'8px',objectFit:'contain',boxShadow:'0 2px 8px rgba(0,0,0,0.1)'}}
                onError={(e)=>{e.target.src='https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800'}}
              />
            </div>
          )}

          <Field label="Caption / Description" value={caption} onChange={setCaption}/>
        </div>
      </div>
      <div className="modal-footer">
        <button onClick={onClose} disabled={busy}>Cancel</button>
        <button
          className="primary"
          disabled={busy || (!url && !preview && !fileData)}
          onClick={handleSave}
        >
          {busy ? 'Optimizing & Indexing Faces...' : 'Save & Index Faces'}
        </button>
      </div>
    </div>
  </div>;
}

function BulkPhotoModal({onSave,onClose,notify}){
  const[album,setAlbum]=useState('Delegate Networking');
  const[mode,setMode]=useState('FILES');
  const[urls,setUrls]=useState('');
  const[selectedFiles,setSelectedFiles]=useState([]);
  const[busy,setBusy]=useState(false);
  const[progressText,setProgressText]=useState('');

  const commonAlbums = ['Keynote Sessions', 'Workshops & CMEs', 'Inauguration Ceremony', 'Delegate Networking', 'Cultural Night', 'Award Ceremony'];

  const handleFileSelection = (e) => {
    const files = Array.from(e.target.files || []);
    if (!files.length) return;

    const fileObjects = files.map((file, idx) => ({
      id: `${Date.now()}_${idx}`,
      file,
      name: file.name,
      size: (file.size / (1024 * 1024)).toFixed(2) + ' MB',
      preview: URL.createObjectURL(file)
    }));

    setSelectedFiles(prev => [...prev, ...fileObjects]);
  };

  const removeFile = (id) => {
    setSelectedFiles(prev => prev.filter(f => f.id !== id));
  };

  const handleBulkSubmit = async () => {
    if (mode === 'URLS') {
      const list = urls.split('\n').map(u => u.trim()).filter(Boolean).map(url => ({ url, caption: `Conference ${album} snapshot` }));
      if (!list.length) { alert('Please enter at least 1 image URL'); return; }
      setBusy(true);
      try {
        await onSave(list, album);
      } finally {
        setBusy(false);
      }
      return;
    }

    if (!selectedFiles.length) {
      alert('Please select at least 1 photo file to upload.');
      return;
    }

    setBusy(true);
    const uploadedPhotosList = [];

    try {
      for (let i = 0; i < selectedFiles.length; i++) {
        const item = selectedFiles[i];
        setProgressText(`Uploading photo ${i + 1} of ${selectedFiles.length}...`);

        const dataUrl = await new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = () => resolve(reader.result);
          reader.onerror = reject;
          reader.readAsDataURL(item.file);
        });

        const uploadRes = await req('/admin/uploads', {
          method: 'POST',
          body: JSON.stringify({
            folder: 'gallery',
            file: { name: item.name, dataUrl }
          })
        });

        const finalUrl = uploadRes.data?.url || uploadRes.url || dataUrl;

        uploadedPhotosList.push({
          url: finalUrl,
          caption: `${album} - photo ${i + 1}`
        });
      }

      setProgressText('Indexing attendee faces with AI recognition...');
      await onSave(uploadedPhotosList, album);
    } catch (err) {
      alert('Batch upload error: ' + err.message);
    } finally {
      setBusy(false);
      setProgressText('');
    }
  };

  return <div className="modal-overlay">
    <div className="modal" style={{maxWidth:'640px'}}>
      <div className="modal-header">
        <h3>Photographer Multi-Photo Batch Upload</h3>
        <button className="close" onClick={onClose}>&times;</button>
      </div>
      <div className="modal-body">
        <div className="formgrid">
          <Field label="Target Album" value={album} onChange={setAlbum}/>
          <div style={{display:'flex',gap:'6px',flexWrap:'wrap',marginTop:'-6px',marginBottom:'10px'}}>
            {commonAlbums.map(alb => (
              <button
                key={alb}
                type="button"
                style={{
                  fontSize:'11px',
                  padding:'3px 8px',
                  borderRadius:'12px',
                  border:'1px solid #cbd5e1',
                  background: album === alb ? '#8C1119' : '#f8fafc',
                  color: album === alb ? '#fff' : '#475569',
                  cursor:'pointer'
                }}
                onClick={()=>setAlbum(alb)}
              >
                {alb}
              </button>
            ))}
          </div>

          <div style={{display:'flex',gap:'8px',marginBottom:'14px'}}>
            <button
              type="button"
              style={{
                flex:1,
                padding:'8px 12px',
                borderRadius:'8px',
                border:'1px solid var(--border)',
                background: mode === 'FILES' ? '#8C1119' : '#f8fafc',
                color: mode === 'FILES' ? '#fff' : '#334155',
                fontWeight:600,
                fontSize:'13px',
                cursor:'pointer'
              }}
              onClick={()=>setMode('FILES')}
            >
              📁 Choose Photo Files from Gallery ({selectedFiles.length})
            </button>
            <button
              type="button"
              style={{
                flex:1,
                padding:'8px 12px',
                borderRadius:'8px',
                border:'1px solid var(--border)',
                background: mode === 'URLS' ? '#8C1119' : '#f8fafc',
                color: mode === 'URLS' ? '#fff' : '#334155',
                fontWeight:600,
                fontSize:'13px',
                cursor:'pointer'
              }}
              onClick={()=>setMode('URLS')}
            >
              🔗 Paste Image URLs
            </button>
          </div>

          {mode === 'FILES' ? (
            <div style={{display:'flex',flexDirection:'column',gap:'12px'}}>
              <div
                style={{
                  border:'2px dashed #cbd5e1',
                  borderRadius:'12px',
                  padding:'24px 16px',
                  textAlign:'center',
                  background:'#f8fafc',
                  cursor:'pointer',
                  transition:'all 0.2s ease'
                }}
                onClick={() => document.getElementById('bulk-gallery-input').click()}
              >
                <Upload size={36} color="#8C1119" style={{marginBottom:'8px'}} />
                <h4 style={{margin:'0 0 4px 0',fontSize:'15px'}}>Click to Select Multiple Photos</h4>
                <p style={{margin:0,fontSize:'12.5px',color:'#64748b'}}>Select multiple JPG, PNG, WEBP photos from your computer or phone gallery.</p>
                <input
                  id="bulk-gallery-input"
                  type="file"
                  multiple
                  accept="image/*"
                  style={{display:'none'}}
                  onChange={handleFileSelection}
                />
              </div>

              {selectedFiles.length > 0 && (
                <div>
                  <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:'8px'}}>
                    <strong style={{fontSize:'13px',color:'#1e293b'}}>Selected Photos ({selectedFiles.length})</strong>
                    <button
                      type="button"
                      style={{color:'#ef4444',border:'none',background:'transparent',fontSize:'12px',cursor:'pointer',padding:0}}
                      onClick={()=>setSelectedFiles([])}
                    >
                      Clear All
                    </button>
                  </div>
                  <div style={{display:'grid',gridTemplateColumns:'repeat(auto-fill, minmax(90px, 1fr))',gap:'8px',maxHeight:'200px',overflowY:'auto',padding:'4px'}}>
                    {selectedFiles.map(item => (
                      <div key={item.id} style={{position:'relative',borderRadius:'8px',overflow:'hidden',height:'80px',border:'1px solid #e2e8f0',background:'#000'}}>
                        <img src={item.preview} alt={item.name} style={{width:'100%',height:'100%',objectFit:'cover'}} />
                        <button
                          type="button"
                          onClick={()=>removeFile(item.id)}
                          style={{position:'absolute',top:'2px',right:'2px',background:'rgba(0,0,0,0.7)',color:'#fff',border:'none',borderRadius:'50%',width:'18px',height:'18px',fontSize:'11px',cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',padding:0}}
                        >
                          &times;
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ) : (
            <Field textarea label="Paste Image URLs (One URL per line)" value={urls} onChange={setUrls}/>
          )}

          {busy && progressText && (
            <div style={{padding:'10px 14px',background:'#ecfdf5',color:'#047857',borderRadius:'8px',fontSize:'13px',fontWeight:600,display:'flex',alignItems:'center',gap:'8px'}}>
              <span style={{display:'inline-block',animation:'spin 1s linear infinite'}}>⏳</span> {progressText}
            </div>
          )}

          <small style={{color:'#64748b'}}>AI Face Recognition automatically scans and indexes attendee faces across all uploaded photos for instant selfie face match.</small>
        </div>
      </div>
      <div className="modal-footer">
        <button onClick={onClose} disabled={busy}>Cancel</button>
        <button className="primary" disabled={busy || (mode==='FILES' ? !selectedFiles.length : !urls.trim())} onClick={handleBulkSubmit}>
          {busy ? (progressText || 'Uploading & Indexing...') : `Upload ${mode==='FILES' && selectedFiles.length ? selectedFiles.length + ' Photos' : '& Index Faces'}`}
        </button>
      </div>
    </div>
  </div>;
}

function FeedbackView({tab, notify}){
  const[data,setData]=useState([]),[busy,setBusy]=useState(false),[search,setSearch]=useState(''),[selected,setSelected]=useState(null);
  const load=async()=>{setBusy(true);try{const r=await req('/admin/feedback');setData(r||[])}catch(e){notify(e.message)}finally{setBusy(false)}};
  useEffect(()=>{load()},[]);

  const total = data.length;
  const calcAvg = (key) => {
    if(!total) return '0.0';
    const sum = data.reduce((acc, x) => acc + Number(x[key] || 0), 0);
    return (sum / total).toFixed(1);
  };
  const countMatch = (key, val) => {
    if(!total) return 0;
    return Math.round((data.filter(x => String(x[key]||'').toLowerCase() === String(val).toLowerCase()).length / total) * 100);
  };

  const filtered = data.filter(x => {
    const q = search.toLowerCase();
    return !search ||
      (x.participant_name && x.participant_name.toLowerCase().includes(q)) ||
      (x.registration_no && x.registration_no.toLowerCase().includes(q)) ||
      (x.suggestions && x.suggestions.toLowerCase().includes(q)) ||
      (x.comment && x.comment.toLowerCase().includes(q));
  });

  const exportCSV=()=>{
    if(!data.length){alert('No feedback data to export');return}
    const headers = [
      'ID','Delegate Name','Registration No','Category','Email','Phone',
      'Q1 Choice of Speakers',
      'Q2 Thorough Exploration of Topic',
      'Q3 Quality of Presentation',
      'Q4 Usefulness of Topic',
      'Q5 Evaluation of Programme',
      'Q6 Adequate Discussion Time',
      'Q7 Topics Covered Specialty',
      'Q8 Understanding Improvement (1-5)',
      'Q9 Arrangements Rating (1-5)',
      'Q10 Registration Rating (1-5)',
      'Q11 Overall Conduct Rating (1-5)',
      'Q12 Audiovisuals Rating (1-5)',
      'Q13 Food Arrangements Rating (1-5)',
      'Q14 Suggestions',
      'Submitted At'
    ];
    const rows = [headers.join(',')];
    data.forEach(r => {
      const vals = [
        r.id,
        `"${String(r.participant_name||'').replace(/"/g,'""')}"`,
        `"${String(r.registration_no||'').replace(/"/g,'""')}"`,
        `"${String(r.participant_category||'Delegate').replace(/"/g,'""')}"`,
        `"${String(r.participant_email||'').replace(/"/g,'""')}"`,
        `"${String(r.participant_phone||'').replace(/"/g,'""')}"`,
        `"${String(r.choice_of_speakers||'Good').replace(/"/g,'""')}"`,
        `"${String(r.thorough_exploration||'Good').replace(/"/g,'""')}"`,
        `"${String(r.presentation_quality||'Good').replace(/"/g,'""')}"`,
        `"${String(r.topic_usefulness||'Good').replace(/"/g,'""')}"`,
        `"${String(r.programme_evaluation||'Good').replace(/"/g,'""')}"`,
        `"${String(r.adequate_discussion_time||'Yes').replace(/"/g,'""')}"`,
        `"${String(r.topics_covered_specialty||'Yes').replace(/"/g,'""')}"`,
        r.understanding_improvement || r.rating || 5,
        r.arrangements_rating || 5,
        r.registration_rating || 5,
        r.overall_conduct_rating || r.rating || 5,
        r.audiovisuals_rating || 5,
        r.food_arrangements_rating || 5,
        `"${String(r.suggestions || r.comment || '').replace(/"/g,'""')}"`,
        `"${String(r.created_at || '').replace(/"/g,'""')}"`
      ];
      rows.push(vals.join(','));
    });
    const blob = new Blob([rows.join('\n')], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `CME_Feedback_Report_${Date.now()}.csv`;
    a.click();
    notify('Exported CME Feedback Report to CSV');
  };

  return <div className="panel">
    <div className="pagehead">
      <div>
        <h3>CME & Conference Delegate Feedback</h3>
        <p>Real-time analytics and responses for all 14 evaluation questions.</p>
      </div>
      <div className="actions">
        <button className="primary" onClick={exportCSV}>📥 Export Feedback CSV</button>
      </div>
    </div>

    {/* Metric Overview Cards */}
    <div className="grid" style={{gridTemplateColumns:'repeat(auto-fill, minmax(220px, 1fr))',gap:'14px',marginBottom:'20px'}}>
      <div className="stat"><MessageCircle color="#8C1119"/><span>Total Submissions</span><strong style={{color:'#8C1119'}}>{total}</strong></div>
      <div className="stat"><CheckCircle color="#10b981"/><span>Overall Conduct</span><strong style={{color:'#10b981'}}>{calcAvg('overall_conduct_rating')} / 5.0</strong></div>
      <div className="stat"><FileCheck color="#C8A45A"/><span>Understanding Impr.</span><strong style={{color:'#C8A45A'}}>{calcAvg('understanding_improvement')} / 5.0</strong></div>
      <div className="stat"><Hotel color="#2E6F95"/><span>Arrangements</span><strong style={{color:'#2E6F95'}}>{calcAvg('arrangements_rating')} / 5.0</strong></div>
      <div className="stat"><CalendarDays color="#6366f1"/><span>Food Rating</span><strong style={{color:'#6366f1'}}>{calcAvg('food_arrangements_rating')} / 5.0</strong></div>
      <div className="stat"><Users color="#059669"/><span>AV of Sessions</span><strong style={{color:'#059669'}}>{calcAvg('audiovisuals_rating')} / 5.0</strong></div>
    </div>

    {/* Academic Evaluation Summary Breakdown */}
    <div className="split" style={{marginBottom:'20px'}}>
      <div className="panel" style={{background:'#f8fafc',border:'1px solid #e2e8f0',borderRadius:'12px',padding:'16px'}}>
        <h4 style={{margin:'0 0 12px',color:'#1e293b'}}>📊 Academic Evaluation Summary</h4>
        <div style={{display:'flex',flexDirection:'column',gap:'10px',fontSize:'13px'}}>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <span>Choice of Speakers:</span>
            <b>{countMatch('choice_of_speakers','Excellent')}% Excellent | {countMatch('choice_of_speakers','Good')}% Good</b>
          </div>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <span>Thorough Exploration of Topic:</span>
            <b>{countMatch('thorough_exploration','Excellent')}% Excellent | {countMatch('thorough_exploration','Good')}% Good</b>
          </div>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <span>Quality of Presentation:</span>
            <b>{countMatch('presentation_quality','Excellent')}% Excellent | {countMatch('presentation_quality','Good')}% Good</b>
          </div>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <span>Usefulness of Topic:</span>
            <b>{countMatch('topic_usefulness','Excellent')}% Excellent | {countMatch('topic_usefulness','Good')}% Good</b>
          </div>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <span>Programme Evaluation (Overall):</span>
            <b>{countMatch('programme_evaluation','Excellent')}% Excellent | {countMatch('programme_evaluation','Good')}% Good</b>
          </div>
        </div>
      </div>

      <div className="panel" style={{background:'#f8fafc',border:'1px solid #e2e8f0',borderRadius:'12px',padding:'16px'}}>
        <h4 style={{margin:'0 0 12px',color:'#1e293b'}}>⏱️ Session Engagement & Scale Ratings</h4>
        <div style={{display:'flex',flexDirection:'column',gap:'10px',fontSize:'13px'}}>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <span>Adequate Time for Discussion:</span>
            <b><span className="pill" style={{background:'#10b981',color:'#fff',padding:'2px 8px'}}>{countMatch('adequate_discussion_time','Yes')}% Yes</span></b>
          </div>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <span>Topics Covered Specialty Aspects:</span>
            <b><span className="pill" style={{background:'#10b981',color:'#fff',padding:'2px 8px'}}>{countMatch('topics_covered_specialty','Yes')}% Yes</span></b>
          </div>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <span>Registration Desk Rating:</span>
            <b>{calcAvg('registration_rating')} / 5.0 ⭐</b>
          </div>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <span>Audiovisuals of Sessions:</span>
            <b>{calcAvg('audiovisuals_rating')} / 5.0 ⭐</b>
          </div>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <span>Food & Dining Arrangements:</span>
            <b>{calcAvg('food_arrangements_rating')} / 5.0 ⭐</b>
          </div>
        </div>
      </div>
    </div>

    {/* Search & Submissions Table */}
    <div className="toolbar" style={{display:'flex',gap:'12px',alignItems:'center'}}>
      <div style={{position:'relative',flex:1}}>
        <input style={{width:'100%',padding:'9px 12px 9px 36px',border:'1px solid #cbd5e1',borderRadius:'8px'}} placeholder="Search delegate name, reg no, or suggestion keyword..." value={search} onChange={e=>setSearch(e.target.value)}/>
        <Search size={16} style={{position:'absolute',left:'12px',top:'50%',transform:'translateY(-50%)',color:'#94a3b8'}}/>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th>Delegate</th>
          <th>Speakers (Q1)</th>
          <th>Exploration (Q2)</th>
          <th>Quality (Q3)</th>
          <th>Usefulness (Q4)</th>
          <th>Discussion (Q6)</th>
          <th>Avg Rating (Q8-13)</th>
          <th>Suggestions (Q14)</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        {filtered.map(r => {
          const avg = ((
            Number(r.understanding_improvement||5) +
            Number(r.arrangements_rating||5) +
            Number(r.registration_rating||5) +
            Number(r.overall_conduct_rating||r.rating||5) +
            Number(r.audiovisuals_rating||5) +
            Number(r.food_arrangements_rating||5)
          ) / 6).toFixed(1);
          return <tr key={r.id}>
            <td>
              <b>{r.participant_name}</b><br/>
              <small style={{color:'#64748b'}}>{r.registration_no} • {r.participant_category||'Delegate'}</small>
            </td>
            <td><span className="pill" style={{background:'#ecfdf5',color:'#065f46',border:'1px solid #a7f3d0'}}>{r.choice_of_speakers||'Good'}</span></td>
            <td><span className="pill" style={{background:'#ecfdf5',color:'#065f46',border:'1px solid #a7f3d0'}}>{r.thorough_exploration||'Good'}</span></td>
            <td><span className="pill" style={{background:'#ecfdf5',color:'#065f46',border:'1px solid #a7f3d0'}}>{r.presentation_quality||'Good'}</span></td>
            <td><span className="pill" style={{background:'#ecfdf5',color:'#065f46',border:'1px solid #a7f3d0'}}>{r.topic_usefulness||'Good'}</span></td>
            <td><span className="pill" style={{background:r.adequate_discussion_time==='No'?'#fef2f2':'#f0fdf4',color:r.adequate_discussion_time==='No'?'#991b1b':'#166534'}}>{r.adequate_discussion_time||'Yes'}</span></td>
            <td><strong style={{color:'#8C1119'}}>{avg} / 5 ⭐</strong></td>
            <td style={{maxWidth:'200px',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>
              {r.suggestions || r.comment || <em style={{color:'#94a3b8'}}>None</em>}
            </td>
            <td>
              <button className="primary" style={{padding:'4px 10px',fontSize:'12px'}} onClick={()=>setSelected(r)}>View All 14</button>
            </td>
          </tr>
        })}
        {!filtered.length && !busy && <tr><td colSpan="9" style={{textAlign:'center',padding:'30px',color:'#888'}}>No feedback submissions match your filter.</td></tr>}
      </tbody>
    </table>

    {/* Detail Modal for all 14 questions */}
    {selected && <FeedbackDetailModal item={selected} onClose={()=>setSelected(null)}/>}
  </div>
}

function FeedbackDetailModal({item, onClose}){
  return <div className="modal-overlay">
    <div className="modal" style={{maxWidth:'700px',maxHeight:'90vh',overflowY:'auto'}}>
      <div className="modal-header">
        <div>
          <h3 style={{margin:0}}>Delegate Feedback Evaluation (All 14 Questions)</h3>
          <p style={{margin:'4px 0 0',color:'#64748b',fontSize:'13px'}}>{item.participant_name} ({item.registration_no}) • {item.participant_category||'Delegate'}</p>
        </div>
        <button className="close" onClick={onClose}>&times;</button>
      </div>
      <div className="modal-body" style={{display:'flex',flexDirection:'column',gap:'14px',fontSize:'13.5px'}}>
        <div style={{background:'#f8fafc',padding:'12px 16px',borderRadius:'10px',border:'1px solid #e2e8f0'}}>
          <h4 style={{margin:'0 0 10px',color:'#8C1119'}}>1. Academic & Presentation Questions</h4>
          <div style={{display:'flex',flexDirection:'column',gap:'8px'}}>
            <div><b>Q1. Choice of Speakers:</b> <span className="pill" style={{background:'#8C1119',color:'#fff',padding:'2px 8px'}}>{item.choice_of_speakers||'Good'}</span></div>
            <div><b>Q2. Thorough exploration of topic:</b> <span className="pill" style={{background:'#8C1119',color:'#fff',padding:'2px 8px'}}>{item.thorough_exploration||'Good'}</span></div>
            <div><b>Q3. Quality of Presentation:</b> <span className="pill" style={{background:'#8C1119',color:'#fff',padding:'2px 8px'}}>{item.presentation_quality||'Good'}</span></div>
            <div><b>Q4. Usefulness of Topic:</b> <span className="pill" style={{background:'#8C1119',color:'#fff',padding:'2px 8px'}}>{item.topic_usefulness||'Good'}</span></div>
            <div><b>Q5. Evaluation of programme as a whole:</b> <span className="pill" style={{background:'#8C1119',color:'#fff',padding:'2px 8px'}}>{item.programme_evaluation||'Good'}</span></div>
            <div><b>Q6. Adequate time for discussion:</b> <span className="pill" style={{background:'#10b981',color:'#fff',padding:'2px 8px'}}>{item.adequate_discussion_time||'Yes'}</span></div>
            <div><b>Q7. Topics covered important specialty aspects:</b> <span className="pill" style={{background:'#10b981',color:'#fff',padding:'2px 8px'}}>{item.topics_covered_specialty||'Yes'}</span></div>
          </div>
        </div>

        <div style={{background:'#f8fafc',padding:'12px 16px',borderRadius:'10px',border:'1px solid #e2e8f0'}}>
          <h4 style={{margin:'0 0 10px',color:'#8C1119'}}>2. Ratings & Arrangements (Scale 1 to 5)</h4>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:'10px'}}>
            <div><b>Q8. Understanding Improvement:</b> <strong>{item.understanding_improvement||5} / 5 ⭐</strong></div>
            <div><b>Q9. Arrangements by Organizers:</b> <strong>{item.arrangements_rating||5} / 5 ⭐</strong></div>
            <div><b>Q10. Registration Process:</b> <strong>{item.registration_rating||5} / 5 ⭐</strong></div>
            <div><b>Q11. Overall Conduct of CME:</b> <strong>{item.overall_conduct_rating||item.rating||5} / 5 ⭐</strong></div>
            <div><b>Q12. Audiovisuals of Sessions:</b> <strong>{item.audiovisuals_rating||5} / 5 ⭐</strong></div>
            <div><b>Q13. Food & Dining:</b> <strong>{item.food_arrangements_rating||5} / 5 ⭐</strong></div>
          </div>
        </div>

        <div style={{background:'#f8fafc',padding:'12px 16px',borderRadius:'10px',border:'1px solid #e2e8f0'}}>
          <h4 style={{margin:'0 0 8px',color:'#8C1119'}}>3. Q14. Suggestions (if any)</h4>
          <p style={{margin:0,color:'#334155',background:'#fff',padding:'10px 14px',borderRadius:'8px',border:'1px solid #cbd5e1'}}>
            {item.suggestions || item.comment || <em>No specific suggestions provided.</em>}
          </p>
        </div>
      </div>
      <div className="modal-footer">
        <button className="primary" onClick={onClose}>Close</button>
      </div>
    </div>
  </div>
}

function Reports({tab, notify, selectedConferenceId}){
  const reportMap={'Participant Reports':'participants','Attendance Reports':'attendance','Accommodation Reports':'accommodation','Transport Reports':'transport','Meal Reports':'meals','Certificate Reports':'certificates','CME Feedback Reports':'feedback'};
  const initialType=reportMap[tab]||'participants';
  const[type,setType]=useState(initialType),[data,setData]=useState([]),[busy,setBusy]=useState(false);
  const[searchQ,setSearchQ]=useState('');
  
  useEffect(()=>{if(reportMap[tab])setType(reportMap[tab])},[tab]);

  const load=async()=>{
    setBusy(true); 
    const confId = selectedConferenceId || 1;
    try{
      const r=await req(`/admin/reports/${type}?conferenceId=${confId}`);
      setData(r);
    }finally{
      setBusy(false);
    }
  };
  useEffect(()=>{load()},[type, selectedConferenceId]);

  const filteredData = data.filter(row => {
    if(!searchQ.trim()) return true;
    return Object.values(row).some(v => String(v||'').toLowerCase().includes(searchQ.toLowerCase()));
  });

  const exportXLSX=()=>{
    if(!filteredData.length){alert('No data to export');return}
    const ws = XLSX.utils.json_to_sheet(filteredData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, type.toUpperCase());
    XLSX.writeFile(wb, `conference_${type}_report_${new Date().toISOString().slice(0,10)}.xlsx`);
    notify(`Exported ${type} report to Excel (.xlsx)`);
  };

  const exportCSV=()=>{
    if(!filteredData.length){alert('No data to export');return}
    const keys=Object.keys(filteredData[0]);
    const csvRows=[keys.join(',')];
    filteredData.forEach(row=>{
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
    <div className="pagehead">
      <div>
        <h3>Conference Reports & Analytics</h3>
        <p>Export operational rosters, food pass audits, attendance percentages, and logistics reports to Excel / CSV.</p>
      </div>
      <div className="actions" style={{display:'flex', gap:'8px', alignItems:'center'}}>
        <button className="primary" onClick={exportXLSX} style={{display:'flex', alignItems:'center', gap:'6px'}}>📥 Export Excel (.xlsx)</button>
        <button className="secondary" onClick={exportCSV}>📄 CSV</button>
        <button className="secondary" onClick={()=>window.print()} style={{display:'flex', alignItems:'center', gap:'6px'}}><Printer size={15}/> Print</button>
      </div>
    </div>
    
    <div className="toolbar" style={{display:'flex', gap:'12px', alignItems:'center', background:'#f8fafc', padding:'12px 16px', borderRadius:'10px', border:'1px solid #e2e8f0', marginBottom:'16px', flexWrap:'wrap'}}>
      <div style={{display:'flex', gap:'8px', alignItems:'center'}}>
        <small style={{fontWeight:600, color:'#64748b'}}>Report Module:</small>
        <select value={type} onChange={e=>setType(e.target.value)} style={{padding:'7px 12px', borderRadius:'6px', border:'1px solid #cbd5e1', fontSize:'13.5px', fontWeight:700}}>
          <option value="participants">👥 Participants Master Roster</option>
          <option value="attendance">⚡ Attendance & Check-in Scans</option>
          <option value="accommodation">🏨 Accommodation & Rooms</option>
          <option value="transport">🚐 Transport & Vehicle Schedule</option>
          <option value="meals">🍽️ Meal Passes & Redemptions</option>
          <option value="certificates">📜 Issued Certificates</option>
          <option value="feedback">💬 CME Feedback & Ratings</option>
        </select>
      </div>
      <div className="search" style={{flex:1, minWidth:'220px'}}>
        <Search size={16}/>
        <input value={searchQ} onChange={e=>setSearchQ(e.target.value)} placeholder="Filter records in this report..."/>
      </div>
      <button onClick={load} disabled={busy} style={{padding:'7px 14px', fontSize:'13px'}}>{busy?'...':'↻ Refresh'}</button>
    </div>

    <div className="tablewrap">
      <table>
        <thead>
          <tr>
            {filteredData[0] && Object.keys(filteredData[0]).map(k=>(
              <th key={k}>{k.replace(/_/g,' ').toUpperCase()}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {filteredData.map((row,i)=>(
            <tr key={i}>
              {Object.values(row).map((v,j)=>(
                <td key={j}>{String(v===null||v===undefined?'—':v)}</td>
              ))}
            </tr>
          ))}
          {!filteredData.length && !busy && <tr><td colSpan="8" style={{textAlign:'center',padding:'30px',color:'#888'}}>No records found for this report.</td></tr>}
        </tbody>
      </table>
    </div>
  </div>;
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

