import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import { body, validationResult } from 'express-validator';
import { Server } from 'socket.io';
import http from 'http';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from './db.js';
import { auth, roles, errorHandler } from './middleware.js';
dotenv.config();
const app=express(); const server=http.createServer(app);
const io=new Server(server,{cors:{origin:true,credentials:true}});
const __dirname=path.dirname(fileURLToPath(import.meta.url));
const uploadRoot=path.resolve(__dirname,'..','uploads');
app.use(helmet({crossOriginResourcePolicy:{policy:'cross-origin'}})); app.use(cors({origin:true,credentials:true})); app.use(express.json({limit:'12mb'})); app.use(morgan('dev'));
app.use('/uploads',express.static(uploadRoot));
app.use(rateLimit({windowMs:15*60*1000,max:500,standardHeaders:true,legacyHeaders:false}));
const validate=(req,res,next)=>{const e=validationResult(req);if(!e.isEmpty())return res.status(400).json({message:'Validation failed',errors:e.array()});next()};
const asyncRoute=fn=>(req,res,next)=>Promise.resolve(fn(req,res,next)).catch(next);
const ok=(res,data,message='Operation successful')=>res.json({success:true,message,data});
const created=(res,data,message='Created successfully')=>res.status(201).json({success:true,message,data});
const pick=(src,fields)=>fields.reduce((out,k)=>{if(src[k]!==undefined)out[k]=src[k];return out},{});
async function audit(req,action,module,recordId,oldValue,newValue){
  await pool.query('INSERT INTO audit_logs(user_id,action,entity,entity_id,details) VALUES(?,?,?,?,?)',[req.user?.id||null,action,module,recordId||null,JSON.stringify({oldValue,newValue,ip:req.ip})]);
}
async function ensureConferenceChildren(conferenceId=1){
  await pool.query(`INSERT INTO conference_branding(conference_id) VALUES(?) ON DUPLICATE KEY UPDATE conference_id=conference_id`,[conferenceId]);
  await pool.query(`INSERT INTO conference_settings(conference_id) VALUES(?) ON DUPLICATE KEY UPDATE conference_id=conference_id`,[conferenceId]);
}
async function getConference(conferenceId=1){
  await ensureConferenceChildren(conferenceId);
  const [[conference]]=await pool.query('SELECT * FROM conferences WHERE id=?',[conferenceId]);
  if(!conference)return null;
  const [[venue]]=await pool.query('SELECT * FROM venues WHERE conference_id=? ORDER BY id LIMIT 1',[conferenceId]);
  const [[branding]]=await pool.query('SELECT * FROM conference_branding WHERE conference_id=?',[conferenceId]);
  const [[settings]]=await pool.query('SELECT * FROM conference_settings WHERE conference_id=?',[conferenceId]);
  return {id:conference.id,name:conference.name,shortName:conference.short_name,description:conference.description,welcomeMessage:conference.welcome_message,aboutConference:conference.about_conference,startDate:conference.start_date,endDate:conference.end_date,registrationStartDate:conference.registration_start_date,registrationEndDate:conference.registration_end_date,contactPerson:conference.contact_person,contactPhone:conference.contact_phone,contactEmail:conference.contact_email,website:conference.website,organizer:conference.organizer,hostInstitution:conference.host_institution,theme:conference.theme,status:conference.status,active:conference.active,venue:{id:venue?.id||null,name:venue?.name||conference.venue,address:venue?.address||conference.address,city:venue?.city,state:venue?.state,country:venue?.country,pincode:venue?.pincode,latitude:venue?.latitude,longitude:venue?.longitude,googleMapsUrl:venue?.google_maps_url,parkingInformation:venue?.parking_information,directions:venue?.directions,contactNumber:venue?.contact_number},branding:{logoUrl:branding?.conference_logo||conference.logo_url,organizerLogoUrl:branding?.organizer_logo,bannerUrl:branding?.banner||conference.banner_url,splashScreenUrl:branding?.splash_screen,faviconUrl:branding?.favicon,primaryColor:branding?.primary_color,secondaryColor:branding?.secondary_color,accentColor:branding?.accent_color,backgroundColor:branding?.background_color},settings:{enableRegistration:!!settings?.enable_registration,enableChat:!!settings?.enable_chat,enableGallery:!!settings?.enable_gallery,enableAttendance:!!settings?.enable_attendance,enableQr:!!settings?.enable_qr,enablePushNotifications:!!settings?.enable_push_notifications,enableCertificates:!!settings?.enable_certificates,enablePolls:!!settings?.enable_polls,enableFeedback:!!settings?.enable_feedback}};
}
function emptyToNull(v){return v===''?null:v}
function normalizeValues(obj){return Object.fromEntries(Object.entries(obj).map(([k,v])=>[k,emptyToNull(v)]))}
async function saveDataUrlUpload(folder,file){
  if(!file?.dataUrl||!file?.name)throw Object.assign(new Error('File data is required'),{status:400});
  const m=String(file.dataUrl).match(/^data:(image\/(?:png|jpe?g|webp)|application\/pdf);base64,(.+)$/);
  if(!m)throw Object.assign(new Error('Only JPG, PNG, WEBP and PDF uploads are supported'),{status:422});
  const ext={ 'image/png':'png','image/jpeg':'jpg','image/jpg':'jpg','image/webp':'webp','application/pdf':'pdf'}[m[1]];
  const buffer=Buffer.from(m[2],'base64');
  if(buffer.length>5*1024*1024)throw Object.assign(new Error('File size must be 5 MB or less'),{status:422});
  const safeFolder=String(folder||'conference').replace(/[^a-z0-9_-]/gi,'').toLowerCase()||'conference';
  const dir=path.join(uploadRoot,safeFolder);
  await fs.mkdir(dir,{recursive:true});
  const base=path.basename(file.name,path.extname(file.name)).replace(/[^a-z0-9_-]/gi,'-').toLowerCase()||'upload';
  const filename=`${Date.now()}-${base}.${ext}`;
  await fs.writeFile(path.join(dir,filename),buffer);
  return `/uploads/${safeFolder}/${filename}`;
}
app.get('/api/health',(req,res)=>res.json({ok:true,service:'conference-management-api',time:new Date().toISOString()}));
app.get('/api/conference',asyncRoute(async(req,res)=>{const data=await getConference(req.query.conferenceId||1);if(!data)return res.status(404).json({success:false,message:'Conference not found'});ok(res,data)}));
app.put('/api/admin/conference',auth,roles('ADMIN','SUPER_ADMIN'),[
 body('name').optional().notEmpty(),
 body('contactEmail').optional({nullable:true,checkFalsy:true}).isEmail(),
 body('website').optional({nullable:true,checkFalsy:true}).isURL({require_protocol:false}),
 body('status').optional().isIn(['DRAFT','PUBLISHED','ARCHIVED','ACTIVE','INACTIVE'])
],validate,asyncRoute(async(req,res)=>{
 const conferenceId=req.body.conferenceId||1;
 const before=await getConference(conferenceId);
 if(!before)return res.status(404).json({success:false,message:'Conference not found'});
 const data=normalizeValues(pick(req.body,['name','description','theme','website','organizer']));
 const mapped={...data};
 const rename={shortName:'short_name',welcomeMessage:'welcome_message',aboutConference:'about_conference',startDate:'start_date',endDate:'end_date',registrationStartDate:'registration_start_date',registrationEndDate:'registration_end_date',contactPerson:'contact_person',contactPhone:'contact_phone',contactEmail:'contact_email',hostInstitution:'host_institution',status:'status'};
 for(const [from,to] of Object.entries(rename))if(req.body[from]!==undefined)mapped[to]=emptyToNull(req.body[from]);
 if(Object.keys(mapped).length){
   const sets=Object.keys(mapped).map(k=>`${k}=?`).join(',');
   await pool.query(`UPDATE conferences SET ${sets}, updated_at=NOW() WHERE id=?`,[...Object.values(mapped),conferenceId]);
 }
 const after=await getConference(conferenceId);
 await audit(req,'conference.update','conference',conferenceId,before,after);
 io.emit('conference_updated',after);
 ok(res,after,'Conference details updated');
}));
app.put('/api/admin/conference/venue',auth,roles('ADMIN','SUPER_ADMIN'),[
 body('name').optional().notEmpty(),
 body('latitude').optional({nullable:true,checkFalsy:true}).isFloat(),
 body('longitude').optional({nullable:true,checkFalsy:true}).isFloat()
],validate,asyncRoute(async(req,res)=>{
 const conferenceId=req.body.conferenceId||1;
 const before=await getConference(conferenceId);
 const mapped=normalizeValues({name:req.body.name,address:req.body.address,city:req.body.city,state:req.body.state,country:req.body.country,pincode:req.body.pincode,latitude:req.body.latitude,longitude:req.body.longitude,google_maps_url:req.body.googleMapsUrl,parking_information:req.body.parkingInformation,directions:req.body.directions,contact_number:req.body.contactNumber});
 const [[existingVenue]]=await pool.query('SELECT id FROM venues WHERE conference_id=? ORDER BY id LIMIT 1',[conferenceId]);
 if(existingVenue){
   await pool.query(`UPDATE venues SET name=?,address=?,city=?,state=?,country=?,pincode=?,latitude=?,longitude=?,google_maps_url=?,parking_information=?,directions=?,contact_number=? WHERE id=?`,[mapped.name,mapped.address,mapped.city,mapped.state,mapped.country,mapped.pincode,mapped.latitude,mapped.longitude,mapped.google_maps_url,mapped.parking_information,mapped.directions,mapped.contact_number,existingVenue.id]);
 }else{
   await pool.query(`INSERT INTO venues(conference_id,name,address,city,state,country,pincode,latitude,longitude,google_maps_url,parking_information,directions,contact_number) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)`,[conferenceId,mapped.name,mapped.address,mapped.city,mapped.state,mapped.country,mapped.pincode,mapped.latitude,mapped.longitude,mapped.google_maps_url,mapped.parking_information,mapped.directions,mapped.contact_number]);
 }
 await pool.query('UPDATE conferences SET venue=?,address=?,updated_at=NOW() WHERE id=?',[mapped.name,mapped.address,conferenceId]);
 const after=await getConference(conferenceId);
 await audit(req,'conference.venue.update','venue',after.venue.id,before,after);
 io.emit('conference_updated',after);
 ok(res,after,'Venue updated');
}));
app.put('/api/admin/conference/branding',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
 const conferenceId=req.body.conferenceId||1;
 const before=await getConference(conferenceId);
 const mapped=normalizeValues({conference_logo:req.body.logoUrl,organizer_logo:req.body.organizerLogoUrl,banner:req.body.bannerUrl,splash_screen:req.body.splashScreenUrl,favicon:req.body.faviconUrl,primary_color:req.body.primaryColor,secondary_color:req.body.secondaryColor,accent_color:req.body.accentColor,background_color:req.body.backgroundColor});
 await pool.query(`INSERT INTO conference_branding(conference_id,conference_logo,organizer_logo,banner,splash_screen,favicon,primary_color,secondary_color,accent_color,background_color) VALUES(?,?,?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE conference_logo=VALUES(conference_logo),organizer_logo=VALUES(organizer_logo),banner=VALUES(banner),splash_screen=VALUES(splash_screen),favicon=VALUES(favicon),primary_color=VALUES(primary_color),secondary_color=VALUES(secondary_color),accent_color=VALUES(accent_color),background_color=VALUES(background_color)`,[conferenceId,mapped.conference_logo,mapped.organizer_logo,mapped.banner,mapped.splash_screen,mapped.favicon,mapped.primary_color,mapped.secondary_color,mapped.accent_color,mapped.background_color]);
 await pool.query('UPDATE conferences SET logo_url=?,banner_url=?,updated_at=NOW() WHERE id=?',[mapped.conference_logo,mapped.banner,conferenceId]);
 const after=await getConference(conferenceId);
 await audit(req,'conference.branding.update','conference_branding',conferenceId,before,after);
 io.emit('conference_updated',after);
 ok(res,after,'Branding updated');
}));
app.put('/api/admin/conference/settings',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
 const conferenceId=req.body.conferenceId||1;
 const before=await getConference(conferenceId);
 const bool=v=>v?1:0;
 await pool.query(`INSERT INTO conference_settings(conference_id,enable_registration,enable_chat,enable_gallery,enable_attendance,enable_qr,enable_push_notifications,enable_certificates,enable_polls,enable_feedback) VALUES(?,?,?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE enable_registration=VALUES(enable_registration),enable_chat=VALUES(enable_chat),enable_gallery=VALUES(enable_gallery),enable_attendance=VALUES(enable_attendance),enable_qr=VALUES(enable_qr),enable_push_notifications=VALUES(enable_push_notifications),enable_certificates=VALUES(enable_certificates),enable_polls=VALUES(enable_polls),enable_feedback=VALUES(enable_feedback)`,[conferenceId,bool(req.body.enableRegistration),bool(req.body.enableChat),bool(req.body.enableGallery),bool(req.body.enableAttendance),bool(req.body.enableQr),bool(req.body.enablePushNotifications),bool(req.body.enableCertificates),bool(req.body.enablePolls),bool(req.body.enableFeedback)]);
 const after=await getConference(conferenceId);
 await audit(req,'conference.settings.update','conference_settings',conferenceId,before,after);
 io.emit('conference_updated',after);
 ok(res,after,'Settings updated');
}));
app.post('/api/admin/uploads',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{const url=await saveDataUrlUpload(req.body.folder,req.body.file);await audit(req,'file.upload','uploads',null,null,{url});created(res,{url},'File uploaded');}));
app.post('/api/auth/login',[body('email').isEmail(),body('password').isLength({min:6})],validate,asyncRoute(async(req,res)=>{const [rows]=await pool.query('SELECT id,name,email,password_hash,role FROM users WHERE email=? LIMIT 1',[req.body.email]);if(!rows.length)return res.status(401).json({message:'Invalid credentials'});const u=rows[0];if(!await bcrypt.compare(req.body.password,u.password_hash))return res.status(401).json({message:'Invalid credentials'});const token=jwt.sign({id:u.id,name:u.name,email:u.email,role:u.role},process.env.JWT_SECRET,{expiresIn:'7d'});res.json({token,user:{id:u.id,name:u.name,email:u.email,role:u.role}})}));
app.get('/api/auth/me',auth,asyncRoute(async(req,res)=>{const [[u]]=await pool.query('SELECT id,name,email,phone,role,designation,university,blood_group,photo FROM users WHERE id=?',[req.user.id]);res.json(u)}));
app.get('/api/conferences',asyncRoute(async(req,res)=>{const [r]=await pool.query('SELECT * FROM conferences ORDER BY start_date DESC');res.json(r)}));
app.get('/api/conferences/:id',asyncRoute(async(req,res)=>{const [[c]]=await pool.query('SELECT * FROM conferences WHERE id=?',[req.params.id]);if(!c)return res.status(404).json({message:'Conference not found'});res.json(c)}));
app.get('/api/admin/liaisons',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT * FROM liaison_faculty ORDER BY name');
  res.json(r);
}));

app.get('/api/admin/participants',auth,roles('ADMIN','SUPER_ADMIN','VOLUNTEER'),asyncRoute(async(req,res)=>{
  const conferenceId=req.query.conferenceId||1;
  const [r]=await pool.query(`
    SELECT p.*, u.name, u.email, u.phone, u.designation, u.university, u.blood_group, u.photo,
           l.name as liaison_name, l.phone as liaison_phone
    FROM participants p
    JOIN users u ON u.id = p.user_id
    LEFT JOIN liaison_faculty l ON l.id = p.liaison_id
    WHERE p.conference_id = ?
    ORDER BY p.id DESC
  `,[conferenceId]);
  res.json(r);
}));

app.post('/api/admin/participants',auth,roles('ADMIN','SUPER_ADMIN'),[
  body('email').isEmail(),
  body('name').notEmpty()
],validate,asyncRoute(async(req,res)=>{
  const conferenceId=req.body.conferenceId||1;
  const password=req.body.password||'Demo@123';
  const passwordHash=await bcrypt.hash(password,10);
  
  const [existing]=await pool.query('SELECT id FROM users WHERE email=? LIMIT 1',[req.body.email]);
  let userId;
  if(existing.length){
    userId=existing[0].id;
    await pool.query('UPDATE users SET name=?, phone=?, designation=?, university=?, blood_group=?, photo=? WHERE id=?',
      [req.body.name, req.body.phone||null, req.body.designation||null, req.body.university||null, req.body.bloodGroup||req.body.blood_group||null, req.body.photo||null, userId]);
  } else {
    const [uRes]=await pool.query(
      'INSERT INTO users(name, email, password_hash, phone, role, designation, university, blood_group, photo) VALUES(?,?,?,?,?,?,?,?,?)',
      [req.body.name, req.body.email, passwordHash, req.body.phone||null, req.body.role||'PARTICIPANT', req.body.designation||null, req.body.university||null, req.body.bloodGroup||req.body.blood_group||null, req.body.photo||null]
    );
    userId=uRes.insertId;
  }

  const regNo=req.body.registration_no||`CONF-${Date.now().toString().slice(-6)}`;
  const qrToken=req.body.qr_token||`QR-${Date.now()}-${Math.random().toString(36).substring(2,7).toUpperCase()}`;

  const [pRes]=await pool.query(`
    INSERT INTO participants(
      user_id, conference_id, registration_no, category, status, payment_status, amount,
      mode_of_travel, flight_number, arrival_date, arrival_time, departure_date, departure_time,
      emergency_contact, liaison_id, qr_token
    ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    ON DUPLICATE KEY UPDATE
      registration_no=VALUES(registration_no), category=VALUES(category), status=VALUES(status),
      payment_status=VALUES(payment_status), amount=VALUES(amount), mode_of_travel=VALUES(mode_of_travel),
      flight_number=VALUES(flight_number), arrival_date=VALUES(arrival_date), arrival_time=VALUES(arrival_time),
      departure_date=VALUES(departure_date), departure_time=VALUES(departure_time),
      emergency_contact=VALUES(emergency_contact), liaison_id=VALUES(liaison_id)
  `, [
    userId, conferenceId, regNo, req.body.category||'Delegate', req.body.status||'PENDING',
    req.body.payment_status||'PENDING', req.body.amount||0, req.body.mode_of_travel||null,
    req.body.flight_number||null, req.body.arrivalDate||req.body.arrival_date||null,
    req.body.arrivalTime||req.body.arrival_time||null, req.body.departureDate||req.body.departure_date||null,
    req.body.departureTime||req.body.departure_time||null, req.body.emergency_contact||null,
    req.body.liaison_id||null, qrToken
  ]);

  created(res,{id:pRes.insertId, userId, registrationNo:regNo, qrToken},'Participant registered');
}));

app.put('/api/admin/participants/:id',auth,roles('ADMIN','SUPER_ADMIN'),validate,asyncRoute(async(req,res)=>{
  const [[p]]=await pool.query('SELECT user_id FROM participants WHERE id=?',[req.params.id]);
  if(!p) return res.status(404).json({message:'Participant not found'});

  if(req.body.name || req.body.phone || req.body.designation || req.body.university || req.body.email){
    await pool.query('UPDATE users SET name=COALESCE(?,name), email=COALESCE(?,email), phone=COALESCE(?,phone), designation=COALESCE(?,designation), university=COALESCE(?,university), blood_group=COALESCE(?,blood_group), photo=COALESCE(?,photo) WHERE id=?',
      [req.body.name, req.body.email, req.body.phone, req.body.designation, req.body.university, req.body.bloodGroup||req.body.blood_group, req.body.photo, p.user_id]);
  }

  await pool.query(`
    UPDATE participants SET
      registration_no=COALESCE(?,registration_no), category=COALESCE(?,category), status=COALESCE(?,status),
      payment_status=COALESCE(?,payment_status), amount=COALESCE(?,amount), mode_of_travel=COALESCE(?,mode_of_travel),
      flight_number=COALESCE(?,flight_number), arrival_date=?, arrival_time=?, departure_date=?, departure_time=?,
      emergency_contact=COALESCE(?,emergency_contact), liaison_id=?
    WHERE id=?
  `, [
    req.body.registration_no, req.body.category, req.body.status, req.body.payment_status, req.body.amount,
    req.body.mode_of_travel, req.body.flight_number, req.body.arrivalDate||req.body.arrival_date||null,
    req.body.arrivalTime||req.body.arrival_time||null, req.body.departureDate||req.body.departure_date||null,
    req.body.departureTime||req.body.departure_time||null, req.body.emergency_contact,
    req.body.liaison_id||null, req.params.id
  ]);

  ok(res,null,'Participant updated');
}));

app.delete('/api/admin/participants/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [[p]]=await pool.query('SELECT user_id FROM participants WHERE id=?',[req.params.id]);
  if(p){
    await pool.query('DELETE FROM participants WHERE id=?',[req.params.id]);
    await pool.query('DELETE FROM users WHERE id=?',[p.user_id]);
  }
  ok(res,null,'Participant deleted');
}));

app.post('/api/admin/participants/bulk-import',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const { participants, conferenceId = 1 } = req.body;
  if(!Array.isArray(participants) || !participants.length){
    return res.status(400).json({message: 'No participant data provided'});
  }

  const defaultHash=await bcrypt.hash('Demo@123',10);
  let imported=0, skipped=0;

  for(const row of participants){
    if(!row.email || !row.name){
      skipped++;
      continue;
    }
    try{
      const [uRows]=await pool.query('SELECT id FROM users WHERE email=? LIMIT 1',[row.email]);
      let uid;
      if(uRows.length){
        uid=uRows[0].id;
      } else {
        const [uRes]=await pool.query(
          'INSERT INTO users(name,email,password_hash,phone,role,designation,university) VALUES(?,?,?,?,?,?,?)',
          [row.name, row.email, defaultHash, row.phone||null, 'PARTICIPANT', row.designation||null, row.university||null]
        );
        uid=uRes.insertId;
      }
      const regNo=row.registration_no || `CONF-${Date.now().toString().slice(-4)}${Math.floor(Math.random()*1000)}`;
      const qrToken=`QR-${uid}-${Date.now().toString(36)}`;
      await pool.query(`
        INSERT INTO participants(user_id, conference_id, registration_no, category, status, payment_status, mode_of_travel, qr_token)
        VALUES(?,?,?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE category=VALUES(category), status=VALUES(status)
      `, [uid, conferenceId, regNo, row.category||'Delegate', row.status||'APPROVED', row.payment_status||'PAID', row.mode_of_travel||null, qrToken]);
      imported++;
    } catch(err){
      skipped++;
    }
  }

  ok(res, { imported, skipped }, `Imported ${imported} participants (${skipped} skipped)`);
}));

app.get('/api/speakers',asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT * FROM speakers WHERE conference_id=? ORDER BY name',[req.query.conferenceId||1]);
  res.json(r);
}));

app.get('/api/halls',asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT h.*, v.name venue_name FROM halls h JOIN venues v ON v.id=h.venue_id WHERE v.conference_id=?',[req.query.conferenceId||1]);
  res.json(r);
}));

app.get('/api/admin/speakers',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT * FROM speakers WHERE conference_id=? ORDER BY name',[req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/speakers',auth,roles('ADMIN','SUPER_ADMIN'),[body('name').notEmpty()],validate,asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO speakers(conference_id,name,designation,organization,bio,email,phone,photo) VALUES(?,?,?,?,?,?,?,?)',
    [req.body.conferenceId||1, req.body.name, req.body.designation, req.body.organization, req.body.bio, req.body.email, req.body.phone, req.body.photo]);
  created(res,{id:r.insertId},'Speaker added');
}));

app.put('/api/admin/speakers/:id',auth,roles('ADMIN','SUPER_ADMIN'),validate,asyncRoute(async(req,res)=>{
  await pool.query('UPDATE speakers SET name=?, designation=?, organization=?, bio=?, email=?, phone=?, photo=? WHERE id=?',
    [req.body.name, req.body.designation, req.body.organization, req.body.bio, req.body.email, req.body.phone, req.body.photo, req.params.id]);
  ok(res,null,'Speaker updated');
}));

app.delete('/api/admin/speakers/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM speakers WHERE id=?',[req.params.id]);
  ok(res,null,'Speaker deleted');
}));

app.get('/api/admin/halls',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT h.*, v.name venue_name FROM halls h JOIN venues v ON v.id=h.venue_id WHERE v.conference_id=?',[req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/halls',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [[v]]=await pool.query('SELECT id FROM venues WHERE conference_id=? LIMIT 1',[req.body.conferenceId||1]);
  if(!v) return res.status(400).json({message:'Venue not found for conference'});
  const [r]=await pool.query('INSERT INTO halls(venue_id,name,capacity) VALUES(?,?,?)',[v.id,req.body.name,req.body.capacity]);
  created(res,{id:r.insertId},'Hall added');
}));

app.get('/api/admin/sessions',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT s.*, sp.name speaker_name, h.name hall_name
    FROM sessions s
    LEFT JOIN speakers sp ON sp.id=s.speaker_id
    LEFT JOIN halls h ON h.id=s.hall_id
    WHERE s.conference_id=?
    ORDER BY s.session_date, s.start_time`, [req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/sessions',auth,roles('ADMIN','SUPER_ADMIN'),[body('title').notEmpty()],validate,asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO sessions(conference_id,hall_id,speaker_id,title,description,session_date,start_time,end_time,category) VALUES(?,?,?,?,?,?,?,?,?)',
    [req.body.conferenceId||1, req.body.hall_id, req.body.speaker_id, req.body.title, req.body.description, req.body.session_date, req.body.start_time, req.body.end_time, req.body.category]);
  created(res,{id:r.insertId},'Session created');
}));

app.put('/api/admin/sessions/:id',auth,roles('ADMIN','SUPER_ADMIN'),validate,asyncRoute(async(req,res)=>{
  await pool.query('UPDATE sessions SET hall_id=?, speaker_id=?, title=?, description=?, session_date=?, start_time=?, end_time=?, category=? WHERE id=?',
    [req.body.hall_id, req.body.speaker_id, req.body.title, req.body.description, req.body.session_date, req.body.start_time, req.body.end_time, req.body.category, req.params.id]);
  ok(res,null,'Session updated');
}));

app.delete('/api/admin/sessions/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM sessions WHERE id=?',[req.params.id]);
  ok(res,null,'Session deleted');
}));
app.get('/api/sessions',asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT s.*,sp.name speaker_name,sp.photo speaker_photo,v.name venue_name,h.name hall_name FROM sessions s LEFT JOIN speakers sp ON sp.id=s.speaker_id LEFT JOIN halls h ON h.id=s.hall_id LEFT JOIN venues v ON v.id=h.venue_id WHERE s.conference_id=? ORDER BY s.session_date,s.start_time`,[req.query.conferenceId||1]);res.json(r)}));
app.get('/api/notices',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query('SELECT * FROM notices WHERE conference_id=? AND (target_role IS NULL OR target_role=? OR target_user_id=?) ORDER BY created_at DESC',[req.query.conferenceId||1,req.user.role,req.user.id]);res.json(r)}));
app.get('/api/gallery',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query('SELECT * FROM photos WHERE conference_id=? ORDER BY created_at DESC',[req.query.conferenceId||1]);res.json(r)}));
app.get('/api/me/profile',auth,asyncRoute(async(req,res)=>{const [[u]]=await pool.query(`SELECT u.id,u.name,u.email,u.phone,u.role,u.designation,u.university,u.blood_group,u.photo,p.registration_no,p.category,p.mode_of_travel,p.arrival_date,p.arrival_time,p.departure_date,p.departure_time,p.emergency_contact,h.name hotel_name,r.room_number,r.room_type,l.name liaison_name,l.phone liaison_phone FROM users u LEFT JOIN participants p ON p.user_id=u.id LEFT JOIN room_allocations ra ON ra.participant_id=p.id LEFT JOIN rooms r ON r.id=ra.room_id LEFT JOIN hotels h ON h.id=r.hotel_id LEFT JOIN liaison_faculty l ON l.id=p.liaison_id WHERE u.id=?`,[req.user.id]);if(!u)return res.status(404).json({message:'Profile not found'});res.json(u)}));
app.get('/api/me/accommodation',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT h.name hotel_name,h.address,h.latitude,h.longitude,r.room_number,r.room_type,ra.check_in,ra.check_out FROM room_allocations ra JOIN participants p ON p.id=ra.participant_id JOIN rooms r ON r.id=ra.room_id JOIN hotels h ON h.id=r.hotel_id WHERE p.user_id=?`,[req.user.id]);res.json(r[0]||null)}));
app.get('/api/me/transport',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT t.*,v.vehicle_number,v.vehicle_type,d.name driver_name,d.phone driver_phone FROM transport_assignments t LEFT JOIN vehicles v ON v.id=t.vehicle_id LEFT JOIN drivers d ON d.id=v.driver_id JOIN participants p ON p.id=t.participant_id WHERE p.user_id=? ORDER BY t.pickup_time`,[req.user.id]);res.json(r)}));
app.get('/api/me/duties',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT d.*,da.status FROM duties d JOIN duty_assignments da ON da.duty_id=d.id JOIN users u ON u.id=da.user_id WHERE u.id=? ORDER BY d.duty_date,d.start_time`,[req.user.id]);res.json(r)}));
app.get('/api/me/registration',auth,asyncRoute(async(req,res)=>{const [[r]]=await pool.query(`SELECT p.registration_no,p.category,p.status,p.payment_status,p.amount,p.qr_token,c.name conference_name,c.start_date,c.end_date FROM participants p JOIN conferences c ON c.id=p.conference_id WHERE p.user_id=? ORDER BY p.id DESC LIMIT 1`,[req.user.id]);res.json(r||null)}));
app.get('/api/me/certificate',auth,asyncRoute(async(req,res)=>{const [[r]]=await pool.query(`SELECT cert.* FROM certificates cert JOIN participants p ON p.id=cert.participant_id WHERE p.user_id=? ORDER BY cert.issued_at DESC LIMIT 1`,[req.user.id]);res.json(r||null)}));
app.get('/api/me/attendance',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT a.*,s.title,s.session_date,s.start_time FROM attendance a JOIN participants p ON p.id=a.participant_id JOIN sessions s ON s.id=a.session_id WHERE p.user_id=? ORDER BY s.session_date,s.start_time`,[req.user.id]);res.json(r)}));
app.post('/api/attendance/scan',auth,roles('ADMIN','SUPER_ADMIN','VOLUNTEER'),[body('qrToken').notEmpty()],validate,asyncRoute(async(req,res)=>{
  const [[p]]=await pool.query('SELECT id, user_id FROM participants WHERE qr_token=?',[req.body.qrToken]);
  if(!p) return res.status(404).json({message:'Invalid QR Code'});

  const scanType=req.body.scanType||'SESSION';
  const sessionId=req.body.sessionId||null;
  const mealId=req.body.mealId||null;

  if(scanType==='MEAL' && mealId){
    await pool.query('INSERT INTO meal_scans(meal_id,participant_id,scanned_by) VALUES(?,?,?) ON DUPLICATE KEY UPDATE scanned_at=NOW()',
      [mealId, p.id, req.user.id]);
  } else {
    await pool.query('INSERT INTO attendance(participant_id,session_id,scan_type,scanned_by) VALUES(?,?,?,?)',
      [p.id, sessionId, scanType, req.user.id]);
    if(scanType==='CHECKIN') await pool.query("UPDATE participants SET status='CHECKED_IN' WHERE id=?",[p.id]);
  }

  const [[u]]=await pool.query('SELECT name FROM users WHERE id=?',[p.user_id]);
  const scanData={participantName:u.name, scanType, time:new Date().toISOString()};
  io.emit('new_scan',scanData);

  ok(res,scanData,'Attendance recorded');
}));

app.get('/api/admin/attendance/live',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [scans]=await pool.query(`
    SELECT a.*, u.name as participant_name, s.title as session_title
    FROM attendance a
    JOIN participants p ON p.id=a.participant_id
    JOIN users u ON u.id=p.user_id
    LEFT JOIN sessions s ON s.id=a.session_id
    ORDER BY a.scanned_at DESC LIMIT 50`);
  res.json(scans);
}));

app.get('/api/admin/meals',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT * FROM meals WHERE conference_id=? ORDER BY meal_date, start_time',[req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/meals',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO meals(conference_id,meal_date,meal_type,start_time,end_time,location) VALUES(?,?,?,?,?,?)',
    [req.body.conferenceId||1, req.body.meal_date, req.body.meal_type, req.body.start_time, req.body.end_time, req.body.location]);
  created(res,{id:r.insertId},'Meal scheduled');
}));

app.get('/api/admin/duties',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT * FROM duties WHERE conference_id=? ORDER BY duty_date, start_time',[req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/duties',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO duties(conference_id,title,location,duty_date,start_time,end_time,supervisor,notes) VALUES(?,?,?,?,?,?,?,?)',
    [req.body.conferenceId||1, req.body.title, req.body.location, req.body.duty_date, req.body.start_time, req.body.end_time, req.body.supervisor, req.body.notes]);
  created(res,{id:r.insertId},'Duty created');
}));

app.get('/api/admin/duty-assignments',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT da.*, u.name as user_name, d.title as duty_title FROM duty_assignments da JOIN users u ON u.id=da.user_id JOIN duties d ON d.id=da.duty_id');
  res.json(r);
}));

app.post('/api/admin/duty-assignments',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO duty_assignments(duty_id,user_id,status) VALUES(?,?,?)',
    [req.body.duty_id, req.body.user_id, req.body.status||'ASSIGNED']);
  created(res,{id:r.insertId},'Duty assigned');
}));
app.get('/api/me/notifications',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query('SELECT * FROM notifications WHERE conference_id=? AND (user_id IS NULL OR user_id=?) ORDER BY created_at DESC LIMIT 100',[req.query.conferenceId||1,req.user.id]);res.json(r)}));
app.post('/api/notifications/:id/read',auth,asyncRoute(async(req,res)=>{await pool.query('UPDATE notifications SET read_at=NOW() WHERE id=? AND (user_id IS NULL OR user_id=?)',[req.params.id,req.user.id]);res.json({message:'Notification marked as read'})}));
app.get('/api/polls',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query('SELECT p.id,p.question,p.active,o.id option_id,o.option_text FROM polls p JOIN poll_options o ON o.poll_id=p.id WHERE p.conference_id=? AND p.active=1 ORDER BY p.created_at DESC',[req.query.conferenceId||1]);const out={};for(const x of r){out[x.id]??={id:x.id,question:x.question,options:[]};out[x.id].options.push({id:x.option_id,text:x.option_text})}res.json(Object.values(out))}));
app.post('/api/polls/:id/vote',auth,[body('optionId').isInt()],validate,asyncRoute(async(req,res)=>{const [[p]]=await pool.query('SELECT id FROM participants WHERE user_id=? LIMIT 1',[req.user.id]);if(!p)return res.status(400).json({message:'Participant profile not found'});await pool.query('INSERT INTO poll_votes(poll_id,option_id,participant_id) VALUES(?,?,?) ON DUPLICATE KEY UPDATE option_id=VALUES(option_id)',[req.params.id,req.body.optionId,p.id]);res.json({message:'Vote recorded'})}));
app.get('/api/conversations',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query('SELECT c.id,c.title,c.created_at FROM conversations c JOIN conversation_members cm ON cm.conversation_id=c.id WHERE cm.user_id=? ORDER BY c.created_at DESC',[req.user.id]);res.json(r)}));
app.get('/api/conversations/:id/messages',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query('SELECT m.*,u.name sender_name FROM messages m JOIN conversation_members cm ON cm.conversation_id=m.conversation_id JOIN users u ON u.id=m.sender_id WHERE m.conversation_id=? AND cm.user_id=? ORDER BY m.created_at',[req.params.id,req.user.id]);res.json(r)}));
app.get('/api/admin/notices',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT * FROM notices WHERE conference_id=? ORDER BY created_at DESC',[req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/notices',auth,roles('ADMIN','SUPER_ADMIN'),[body('title').notEmpty(),body('message').notEmpty()],validate,asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO notices(conference_id,title,message,type,target_role,target_user_id) VALUES(?,?,?,?,?,?)',
    [req.body.conferenceId||1, req.body.title, req.body.message, req.body.type||'GENERAL', req.body.target_role||null, req.body.target_user_id||null]);
  io.emit('new_notice',{id:r.insertId, title:req.body.title, message:req.body.message, type:req.body.type||'GENERAL'});
  created(res,{id:r.insertId},'Notice published');
}));

app.delete('/api/admin/notices/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM notices WHERE id=?',[req.params.id]);
  ok(res,null,'Notice deleted');
}));

app.get('/api/admin/gallery/albums',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT album, COUNT(*) photo_count FROM photos WHERE conference_id=? GROUP BY album',[req.query.conferenceId||1]);
  res.json(r);
}));

app.get('/api/admin/gallery',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT ph.*, u.name as uploader_name
    FROM photos ph
    LEFT JOIN users u ON u.id = ph.uploaded_by
    WHERE ph.conference_id=?
    ORDER BY ph.created_at DESC`, [req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/gallery',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO photos(conference_id,album,url,caption,uploaded_by) VALUES(?,?,?,?,?)',
    [req.body.conferenceId||1, req.body.album||'General', req.body.url, req.body.caption||'', req.user.id]);
  created(res,{id:r.insertId},'Photo added');
}));

app.delete('/api/admin/gallery/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM photos WHERE id=?',[req.params.id]);
  ok(res,null,'Photo deleted');
}));

app.get('/api/certificates/verify/:certificateNumber',asyncRoute(async(req,res)=>{
  const [[c]]=await pool.query(`
    SELECT cert.*, u.name, p.registration_no, conf.name as conference_name
    FROM certificates cert
    JOIN participants p ON p.id=cert.participant_id
    JOIN users u ON u.id=p.user_id
    JOIN conferences conf ON conf.id=p.conference_id
    WHERE cert.certificate_no=?`, [req.params.certificateNumber]);
  if(!c) return res.status(404).json({success:false,message:'Certificate not found'});
  ok(res,c,'Certificate verified');
}));

app.get('/api/admin/certificates',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT cert.*, u.name as participant_name, p.registration_no
    FROM certificates cert
    JOIN participants p ON p.id=cert.participant_id
    JOIN users u ON u.id=p.user_id
    ORDER BY cert.issued_at DESC`);
  res.json(r);
}));

app.post('/api/admin/certificates/:participantId/issue',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const certNo = req.body.certificateNo || `CERT-${Date.now().toString().slice(-6)}-${Math.floor(Math.random()*1000)}`;
  const [r]=await pool.query(`
    INSERT INTO certificates(participant_id, certificate_no, title, issued_at)
    VALUES(?, ?, 'Certificate of Participation', NOW())
    ON DUPLICATE KEY UPDATE certificate_no=VALUES(certificate_no), issued_at=NOW()
  `, [req.params.participantId, certNo]);
  created(res,{id:r.insertId, certificateNo:certNo},'Certificate issued');
}));

app.get('/api/admin/reports/:type',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const type = req.params.type;
  if(type === 'attendance'){
    const [r]=await pool.query(`
      SELECT u.name as Participant, p.registration_no as Registration_No, a.scan_type as Scan_Type, s.title as Session, a.scanned_at as Scanned_At
      FROM attendance a
      JOIN participants p ON p.id=a.participant_id
      JOIN users u ON u.id=p.user_id
      LEFT JOIN sessions s ON s.id=a.session_id
      ORDER BY a.scanned_at DESC
    `);
    return res.json(r);
  }
  if(type === 'accommodation'){
    const [r]=await pool.query(`
      SELECT u.name as Participant, p.registration_no as Registration_No, h.name as Hotel, r.room_number as Room, r.room_type as Room_Type, ra.check_in as Check_In, ra.check_out as Check_Out
      FROM room_allocations ra
      JOIN participants p ON p.id=ra.participant_id
      JOIN users u ON u.id=p.user_id
      JOIN rooms r ON r.id=ra.room_id
      JOIN hotels h ON h.id=r.hotel_id
    `);
    return res.json(r);
  }
  if(type === 'transport'){
    const [r]=await pool.query(`
      SELECT u.name as Participant, p.registration_no as Registration_No, v.vehicle_number as Vehicle, v.vehicle_type as Type, d.name as Driver, t.pickup_location as Pickup, t.drop_location as Drop_Location, t.pickup_time as Time, t.status as Status
      FROM transport_assignments t
      JOIN participants p ON p.id=t.participant_id
      JOIN users u ON u.id=p.user_id
      LEFT JOIN vehicles v ON v.id=t.vehicle_id
      LEFT JOIN drivers d ON d.id=v.driver_id
    `);
    return res.json(r);
  }
  if(type === 'meals'){
    const [r]=await pool.query(`
      SELECT m.meal_date as Date, m.meal_type as Meal, m.location as Location, COUNT(ms.id) as Attendees
      FROM meals m
      LEFT JOIN meal_scans ms ON ms.meal_id=m.id
      GROUP BY m.id
    `);
    return res.json(r);
  }
  if(type === 'certificates'){
    const [r]=await pool.query(`
      SELECT u.name as Participant, p.registration_no as Registration_No, cert.certificate_no as Certificate_No, cert.issued_at as Issued_At
      FROM certificates cert
      JOIN participants p ON p.id=cert.participant_id
      JOIN users u ON u.id=p.user_id
    `);
    return res.json(r);
  }
  // default participants
  const [r]=await pool.query(`
    SELECT u.name as Name, u.email as Email, u.phone as Phone, u.university as University, p.registration_no as Reg_No, p.category as Category, p.status as Status, p.payment_status as Payment
    FROM participants p
    JOIN users u ON u.id=p.user_id
  `);
  res.json(r);
}));

app.get('/api/admin/conversations',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT c.*, (SELECT body FROM messages WHERE conversation_id=c.id ORDER BY created_at DESC LIMIT 1) as last_message FROM conversations c WHERE c.conference_id=?',[req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/messages',auth,roles('ADMIN','SUPER_ADMIN'),[body('conversationId').isInt(),body('body').notEmpty()],validate,asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO messages(conversation_id,sender_id,message_type,body) VALUES(?,?,?,?)',
    [req.body.conversationId, req.user.id, 'TEXT', req.body.body]);
  const [[u]]=await pool.query('SELECT name FROM users WHERE id=?',[req.user.id]);
  io.to(`conversation:${req.body.conversationId}`).emit('new_message',{id:r.insertId, conversationId:req.body.conversationId, senderId:req.user.id, sender_name:u?.name||'Admin', body:req.body.body});
  created(res,{id:r.insertId},'Message sent');
}));

app.get('/api/admin/users',auth,roles('SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT id, name, email, role, phone, designation FROM users WHERE role != "PARTICIPANT"');
  res.json(r);
}));

app.post('/api/admin/users',auth,roles('SUPER_ADMIN'),[body('email').isEmail(), body('password').isLength({min:6})],validate,asyncRoute(async(req,res)=>{
  const hash=await bcrypt.hash(req.body.password, 10);
  const [r]=await pool.query('INSERT INTO users(name,email,password_hash,role,phone,designation) VALUES(?,?,?,?,?,?)',
    [req.body.name, req.body.email, hash, req.body.role, req.body.phone, req.body.designation]);
  created(res,{id:r.insertId},'Admin user created');
}));

app.get('/api/admin/audit-logs',auth,roles('SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT a.*, u.name as admin_name FROM audit_logs a LEFT JOIN users u ON u.id=a.user_id ORDER BY a.created_at DESC LIMIT 100');
  res.json(r);
}));

app.get('/api/admin/hotels',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT h.*, COUNT(r.id) rooms_count, SUM(r.capacity) total_capacity
    FROM hotels h
    LEFT JOIN rooms r ON r.hotel_id=h.id
    GROUP BY h.id`);
  res.json(r);
}));

app.post('/api/admin/hotels',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO hotels(name,address,latitude,longitude) VALUES(?,?,?,?)',
    [req.body.name, req.body.address, req.body.latitude, req.body.longitude]);
  created(res,{id:r.insertId},'Hotel added');
}));

app.put('/api/admin/hotels/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('UPDATE hotels SET name=?, address=?, latitude=?, longitude=? WHERE id=?',
    [req.body.name, req.body.address, req.body.latitude, req.body.longitude, req.params.id]);
  ok(res,null,'Hotel updated');
}));

app.get('/api/admin/rooms',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT r.*, h.name hotel_name FROM rooms r JOIN hotels h ON h.id=r.hotel_id');
  res.json(r);
}));

app.post('/api/admin/rooms',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO rooms(hotel_id,room_number,room_type,capacity,status) VALUES(?,?,?,?,?)',
    [req.body.hotel_id, req.body.room_number, req.body.room_type, req.body.capacity||1, req.body.status||'AVAILABLE']);
  created(res,{id:r.insertId},'Room added');
}));

app.get('/api/admin/room-allocations',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT ra.*, p.registration_no, u.name participant_name, r.room_number, h.name hotel_name
    FROM room_allocations ra
    JOIN participants p ON p.id=ra.participant_id
    JOIN users u ON u.id=p.user_id
    JOIN rooms r ON r.id=ra.room_id
    JOIN hotels h ON h.id=r.hotel_id`);
  res.json(r);
}));

app.post('/api/admin/room-allocations',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [existing]=await pool.query('SELECT id FROM room_allocations WHERE participant_id=?',[req.body.participant_id]);
  if(existing.length) return res.status(400).json({message:'Participant already has a room allocation'});

  const [[room]]=await pool.query('SELECT capacity, (SELECT COUNT(*) FROM room_allocations WHERE room_id=?) as used FROM rooms WHERE id=?',[req.body.room_id, req.body.room_id]);
  if(room.used >= room.capacity) return res.status(400).json({message:'Room is at full capacity'});

  const [r]=await pool.query('INSERT INTO room_allocations(participant_id,room_id,check_in,check_out) VALUES(?,?,?,?)',
    [req.body.participant_id, req.body.room_id, req.body.check_in, req.body.check_out]);

  if(room.used + 1 >= room.capacity) await pool.query("UPDATE rooms SET status='FULL' WHERE id=?",[req.body.room_id]);

  created(res,{id:r.insertId},'Room allocated');
}));

app.delete('/api/admin/room-allocations/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [[ra]]=await pool.query('SELECT room_id FROM room_allocations WHERE id=?',[req.params.id]);
  await pool.query('DELETE FROM room_allocations WHERE id=?',[req.params.id]);
  if(ra) await pool.query("UPDATE rooms SET status='AVAILABLE' WHERE id=?",[ra.room_id]);
  ok(res,null,'Allocation removed');
}));
app.get('/api/admin/drivers',auth,roles('ADMIN','SUPER_ADMIN','TRANSPORT_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT * FROM drivers');
  res.json(r);
}));

app.post('/api/admin/drivers',auth,roles('ADMIN','SUPER_ADMIN','TRANSPORT_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO drivers(name,phone,license_no) VALUES(?,?,?)',[req.body.name, req.body.phone, req.body.license_no]);
  created(res,{id:r.insertId},'Driver added');
}));

app.get('/api/admin/vehicles',auth,roles('ADMIN','SUPER_ADMIN','TRANSPORT_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT v.*, d.name as driver_name, d.phone as driver_phone
    FROM vehicles v
    LEFT JOIN drivers d ON d.id = v.driver_id
    ORDER BY v.id DESC
  `);
  res.json(r);
}));

app.post('/api/admin/vehicles',auth,roles('ADMIN','SUPER_ADMIN','TRANSPORT_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO vehicles(driver_id,vehicle_number,vehicle_type,capacity,status) VALUES(?,?,?,?,?)',
    [req.body.driver_id, req.body.vehicle_number, req.body.vehicle_type, req.body.capacity, req.body.status||'AVAILABLE']);
  created(res,{id:r.insertId},'Vehicle added');
}));

app.put('/api/admin/vehicles/:id',auth,roles('ADMIN','SUPER_ADMIN','TRANSPORT_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('UPDATE vehicles SET driver_id=?, vehicle_number=?, vehicle_type=?, capacity=?, status=? WHERE id=?',
    [req.body.driver_id, req.body.vehicle_number, req.body.vehicle_type, req.body.capacity, req.body.status, req.params.id]);
  ok(res,null,'Vehicle updated');
}));

app.delete('/api/admin/vehicles/:id',auth,roles('ADMIN','SUPER_ADMIN','TRANSPORT_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM vehicles WHERE id=?',[req.params.id]);
  ok(res,null,'Vehicle deleted');
}));

app.get('/api/admin/transport-assignments',auth,roles('ADMIN','SUPER_ADMIN','TRANSPORT_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT t.*, p.registration_no, u.name participant_name, v.vehicle_number, d.name driver_name
    FROM transport_assignments t
    JOIN participants p ON p.id=t.participant_id
    JOIN users u ON u.id=p.user_id
    LEFT JOIN vehicles v ON v.id=t.vehicle_id
    LEFT JOIN drivers d ON d.id=v.driver_id`);
  res.json(r);
}));

app.post('/api/admin/transport-assignments',auth,roles('ADMIN','SUPER_ADMIN','TRANSPORT_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO transport_assignments(participant_id,vehicle_id,pickup_location,drop_location,pickup_time,status,notes) VALUES(?,?,?,?,?,?,?)',
    [req.body.participant_id, req.body.vehicle_id, req.body.pickup_location, req.body.drop_location, req.body.pickup_time, req.body.status||'ASSIGNED', req.body.notes]);
  created(res,{id:r.insertId},'Transport assigned');
}));
app.get('/api/admin/feedback',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT f.*,s.title,u.name participant_name FROM feedback f JOIN sessions s ON s.id=f.session_id JOIN participants p ON p.id=f.participant_id JOIN users u ON u.id=p.user_id ORDER BY f.created_at DESC LIMIT 500`);res.json(r)}));
app.post('/api/feedback',auth,[body('sessionId').isInt(),body('rating').isInt({min:1,max:5})],validate,asyncRoute(async(req,res)=>{const [[p]]=await pool.query('SELECT id FROM participants WHERE user_id=? ORDER BY id DESC LIMIT 1',[req.user.id]);if(!p)return res.status(400).json({message:'Participant profile not found'});await pool.query('INSERT INTO feedback(participant_id,session_id,rating,content_rating,speaker_rating,comment) VALUES(?,?,?,?,?,?)',[p.id,req.body.sessionId,req.body.rating,req.body.contentRating||req.body.rating,req.body.speakerRating||req.body.rating,req.body.comment||null]);res.status(201).json({message:'Feedback submitted'})}));

app.get('/api/admin/stats',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const q=async(sql)=>{const [[x]]=await pool.query(sql);return Object.values(x)[0]||0};
  res.json({
    participants: await q('SELECT COUNT(*) FROM participants'),
    checkedIn: await q("SELECT COUNT(*) FROM participants WHERE status='CHECKED_IN'"),
    approved: await q("SELECT COUNT(*) FROM participants WHERE status='APPROVED'"),
    speakers: await q('SELECT COUNT(*) FROM speakers'),
    sessions: await q('SELECT COUNT(*) FROM sessions'),
    hotels: await q('SELECT COUNT(*) FROM hotels'),
    rooms: await q('SELECT COUNT(*) FROM rooms'),
    occupiedRooms: await q('SELECT COUNT(*) FROM room_allocations'),
    availableRooms: (await q('SELECT SUM(capacity) FROM rooms')) - (await q('SELECT COUNT(*) FROM room_allocations')),
    photos: await q('SELECT COUNT(*) FROM photos'),
    certificates: await q('SELECT COUNT(*) FROM certificates'),
    notices: await q('SELECT COUNT(*) FROM notices'),
    vehicles: await q('SELECT COUNT(*) FROM vehicles'),
    assignments: await q('SELECT COUNT(*) FROM transport_assignments')
  });
}));
io.on('connection',socket=>{socket.on('join_conversation',id=>socket.join(`conversation:${id}`));socket.on('send_message',async m=>{try{await pool.query('INSERT INTO messages(conversation_id,sender_id,message_type,body) VALUES(?,?,?,?)',[m.conversationId,m.senderId,m.messageType||'TEXT',m.body]);io.to(`conversation:${m.conversationId}`).emit('new_message',m)}catch(e){socket.emit('error_message',{message:e.message})}})});
app.use(errorHandler);
const port=Number(process.env.PORT||5000);server.listen(port,()=>console.log(`API + Socket.IO running on http://localhost:${port}`));
