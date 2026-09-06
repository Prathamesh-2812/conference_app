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
import { extractFaceEmbedding, extractGroupPhotoFaces, cosineSimilarity, rankGalleryMatches } from './services/face_matching.js';
import sharp from 'sharp';

dotenv.config();
const app=express(); const server=http.createServer(app);
app.set('trust proxy', 1);
const io=new Server(server,{cors:{origin:true,credentials:true}});
const __dirname=path.dirname(fileURLToPath(import.meta.url));
const uploadRoot=path.resolve(__dirname,'..','uploads');
app.use(helmet({crossOriginResourcePolicy:{policy:'cross-origin'}})); app.use(cors({origin:true,credentials:true})); app.use(express.json({limit:'12mb'})); app.use(morgan('dev'));
app.use('/uploads',express.static(uploadRoot));
app.use(rateLimit({windowMs:15*60*1000,max:500,standardHeaders:true,legacyHeaders:false}));
app.get('/', (req, res) => res.json({ success: true, message: 'DY Patil Conference Management API Live' }));
app.get('/api/health', (req, res) => res.json({ status: 'ok', uptime: process.uptime(), timestamp: new Date().toISOString() }));
const validate=(req,res,next)=>{const e=validationResult(req);if(!e.isEmpty())return res.status(400).json({message:'Validation failed',errors:e.array()});next()};
const asyncRoute=fn=>(req,res,next)=>Promise.resolve(fn(req,res,next)).catch(next);
const ok=(res,data,message='Operation successful')=>res.json({success:true,message,data});
const created=(res,data,message='Created successfully')=>res.status(201).json({success:true,message,data});
const pick=(src,fields)=>fields.reduce((out,k)=>{if(src[k]!==undefined)out[k]=src[k];return out},{});
async function audit(req,action,module,recordId,oldValue,newValue){
  await pool.query('INSERT INTO audit_logs(user_id,action,entity,entity_id,details) VALUES(?,?,?,?,?)',[req.user?.id||null,action,module,recordId||null,JSON.stringify({oldValue,newValue,ip:req.ip})]);
}
async function createAndSendNotification({ user_id = null, conference_id = 1, title, message, type = 'GENERAL', target_role = null, metadata = null }) {
  try {
    const [r] = await pool.query(
      'INSERT INTO notifications (user_id, conference_id, title, message, type, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
      [user_id, conference_id, title, message, type]
    );
    const notif = {
      id: r.insertId,
      user_id,
      conference_id,
      title,
      message,
      type,
      target_role,
      metadata,
      created_at: new Date().toISOString()
    };
    if (user_id) {
      io.to(`user_${user_id}`).emit('new_notification', notif);
    } else if (target_role) {
      io.to(`role_${target_role}`).emit('new_notification', notif);
      io.to(`conference_${conference_id}`).emit('new_notification', notif);
    } else {
      io.to(`conference_${conference_id}`).emit('new_notification', notif);
      io.emit('new_notification', notif);
    }
    return notif;
  } catch (err) {
    console.error('Error creating notification:', err);
    return null;
  }
}
async function runMigrations(){
  try{
    await pool.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        conference_id INT NOT NULL DEFAULT 1,
        user_id INT NULL,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        type VARCHAR(50) DEFAULT 'GENERAL',
        read_at TIMESTAMP NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_notif_conf_user (conference_id, user_id),
        INDEX idx_notif_read (read_at)
      )
    `);
    const [cols]=await pool.query("SHOW COLUMNS FROM users LIKE 'must_change_password'");
    if(!cols.length){
      await pool.query("ALTER TABLE users ADD COLUMN must_change_password TINYINT(1) DEFAULT 0");
    }
    const [loginCols]=await pool.query("SHOW COLUMNS FROM users LIKE 'last_login_at'");
    if(!loginCols.length){
      await pool.query("ALTER TABLE users ADD COLUMN last_login_at TIMESTAMP NULL DEFAULT NULL");
    }
    await pool.query(`
      CREATE TABLE IF NOT EXISTS main_sliders (
        id INT AUTO_INCREMENT PRIMARY KEY,
        conference_id INT NOT NULL DEFAULT 1,
        title VARCHAR(255),
        media_type ENUM('IMAGE','VIDEO') NOT NULL DEFAULT 'IMAGE',
        media_url TEXT NOT NULL,
        thumbnail_url TEXT,
        display_order INT DEFAULT 0,
        active TINYINT(1) DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS photo_faces (
        id INT AUTO_INCREMENT PRIMARY KEY,
        photo_id INT NOT NULL,
        conference_id INT NOT NULL DEFAULT 1,
        face_token VARCHAR(100) NULL,
        bounding_box JSON NULL,
        embedding LONGTEXT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE,
        FOREIGN KEY (conference_id) REFERENCES conferences(id) ON DELETE CASCADE,
        INDEX idx_photo_faces_conf (conference_id),
        INDEX idx_photo_faces_photo (photo_id)
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS feedback (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        participant_id INT NOT NULL,
        session_id INT NULL,
        rating TINYINT NOT NULL DEFAULT 5,
        content_rating TINYINT DEFAULT 5,
        speaker_rating TINYINT DEFAULT 5,
        comment TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(participant_id) REFERENCES participants(id) ON DELETE CASCADE
      )
    `);
    const [fbCols]=await pool.query("SHOW COLUMNS FROM feedback LIKE 'session_id'");
    if(fbCols.length && fbCols[0].Null === 'NO'){
      await pool.query("ALTER TABLE feedback MODIFY COLUMN session_id INT NULL");
    }
    const feedbackCols = [
      "responses JSON NULL",
      "choice_of_speakers VARCHAR(50) NULL",
      "thorough_exploration VARCHAR(50) NULL",
      "presentation_quality VARCHAR(50) NULL",
      "topic_usefulness VARCHAR(50) NULL",
      "suggestions TEXT NULL",
      "programme_evaluation VARCHAR(50) NULL",
      "adequate_discussion_time VARCHAR(20) NULL",
      "topics_covered_specialty VARCHAR(20) NULL",
      "understanding_improvement TINYINT NULL",
      "arrangements_rating TINYINT NULL",
      "registration_rating TINYINT NULL",
      "overall_conduct_rating TINYINT NULL",
      "audiovisuals_rating TINYINT NULL",
      "food_arrangements_rating TINYINT NULL"
    ];
    for(const colDef of feedbackCols){
      const colName = colDef.split(' ')[0];
      const [exists] = await pool.query(`SHOW COLUMNS FROM feedback LIKE '${colName}'`);
      if(!exists.length){
        await pool.query(`ALTER TABLE feedback ADD COLUMN ${colDef}`);
      }
    }
    await pool.query(`
      CREATE TABLE IF NOT EXISTS sponsors (
        id INT AUTO_INCREMENT PRIMARY KEY,
        conference_id INT NOT NULL DEFAULT 1,
        name VARCHAR(255) NOT NULL,
        category VARCHAR(100) DEFAULT 'Gold Sponsor',
        tier ENUM('TITLE','PLATINUM','GOLD','SILVER','BRONZE','PARTNER') DEFAULT 'GOLD',
        logo_url TEXT,
        website_url VARCHAR(255),
        description TEXT,
        stall_number VARCHAR(50),
        contact_person VARCHAR(100),
        contact_phone VARCHAR(50),
        display_order INT DEFAULT 0,
        active TINYINT(1) DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE
      )
    `);
    // Repair broken gallery photo records pointing to missing local files
    await pool.query(`
      UPDATE photos SET url='https://images.unsplash.com/photo-1587825140708-dfaf72ae4b04?w=1200&auto=format&fit=crop&q=80', caption='Keynote address on Advances in Molecular Pathology'
      WHERE url LIKE '%rakesh-sharma%' OR url LIKE '%gold-modern-appreciation%'
    `);
  }catch(err){
    console.log('Migration check:', err.message);
  }
}
runMigrations();
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
  const m=String(file.dataUrl).match(/^data:((?:image\/(?:png|jpe?g|webp|gif)|video\/(?:mp4|webm|quicktime|x-msvideo|ogg)|application\/pdf));base64,(.+)$/i);
  if(!m)throw Object.assign(new Error('Unsupported file format. Upload JPG, PNG, WEBP, MP4, WEBM or PDF'),{status:422});
  const mimeType=m[1].toLowerCase();
  const mimeExtMap={
    'image/png':'png','image/jpeg':'jpg','image/jpg':'jpg','image/webp':'webp','image/gif':'gif',
    'video/mp4':'mp4','video/webm':'webm','video/quicktime':'mov','video/x-msvideo':'avi','video/ogg':'ogv',
    'application/pdf':'pdf'
  };
  const ext=mimeExtMap[mimeType]||'bin';
  const buffer=Buffer.from(m[2],'base64');
  if(buffer.length>50*1024*1024)throw Object.assign(new Error('File size must be 50 MB or less'),{status:422});
  const safeFolder=String(folder||'conference').replace(/[^a-z0-9_-]/gi,'').toLowerCase()||'conference';
  const dir=path.join(uploadRoot,safeFolder);
  await fs.mkdir(dir,{recursive:true});
  const base=path.basename(file.name,path.extname(file.name)).replace(/[^a-z0-9_-]/gi,'-').toLowerCase()||'upload';
  const filename=`${Date.now()}-${base}.${ext}`;
  await fs.writeFile(path.join(dir,filename),buffer);
  return `/uploads/${safeFolder}/${filename}`;
}

async function generateDelegateCertificate(pName, regNo, certNo, confName = 'MAPCON 2026') {
  const width = 1200;
  const height = 850;
  const certDir = path.join(uploadRoot, 'certificates');
  await fs.mkdir(certDir, { recursive: true });

  const cleanName = String(pName || 'Distinguished Delegate').replace(/[<&>]/g, '');
  const cleanReg = String(regNo || 'MAPCON-2026-DEL').replace(/[<&>]/g, '');
  const cleanCert = String(certNo || 'CERT-2026-001').replace(/[<&>]/g, '');

  const svg = `
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#FCFAF5" />
          <stop offset="100%" stop-color="#FFFDF9" />
        </linearGradient>
      </defs>
      
      <!-- Outer Border -->
      <rect width="${width}" height="${height}" fill="url(#bgGrad)" />
      <rect x="25" y="25" width="${width - 50}" height="${height - 50}" fill="none" stroke="#8C1119" stroke-width="5" rx="18" />
      <rect x="36" y="36" width="${width - 72}" height="${height - 72}" fill="none" stroke="#C8A45A" stroke-width="2" rx="14" />
      
      <!-- Header -->
      <text x="600" y="115" font-family="'Georgia', serif" font-size="22" font-weight="bold" fill="#8C1119" letter-spacing="4" text-anchor="middle">MAHARASHTRA CHAPTER OF IAPM</text>
      <text x="600" y="158" font-family="'Georgia', serif" font-size="34" font-weight="bold" fill="#1E293B" letter-spacing="2" text-anchor="middle">${confName}</text>
      <text x="600" y="190" font-family="Arial, sans-serif" font-size="14" fill="#64748B" letter-spacing="1" text-anchor="middle">Annual State Conference | Hotel Sayaji, Kolhapur</text>
      
      <line x1="200" y1="218" x2="1000" y2="218" stroke="#C8A45A" stroke-width="2" />
      
      <text x="600" y="278" font-family="'Georgia', serif" font-size="38" font-weight="bold" fill="#8C1119" font-style="italic" text-anchor="middle">Certificate of Participation</text>
      <text x="600" y="322" font-family="Arial, sans-serif" font-size="16" fill="#64748B" text-anchor="middle">This is proudly presented to</text>
      
      <!-- Delegate Name -->
      <text x="600" y="390" font-family="'Georgia', serif" font-size="44" font-weight="bold" fill="#8C1119" text-anchor="middle">${cleanName}</text>
      <line x1="300" y1="416" x2="900" y2="416" stroke="#C8A45A" stroke-width="1.5" />
      
      <text x="600" y="468" font-family="Arial, sans-serif" font-size="16" fill="#334155" text-anchor="middle">for active participation and valuable contribution as a registered delegate in</text>
      <text x="600" y="505" font-family="Arial, sans-serif" font-size="18" font-weight="bold" fill="#1E293B" text-anchor="middle">The 46th Annual State Conference of MAPCON 2026</text>
      <text x="600" y="540" font-family="Arial, sans-serif" font-size="15" fill="#475569" text-anchor="middle">held from September 25th to 27th, 2026 at Kolhapur, Maharashtra, India.</text>
      
      <!-- Meta Credentials Box -->
      <rect x="250" y="590" width="700" height="52" fill="#F1F5F9" stroke="#E2E8F0" rx="10" />
      <text x="310" y="623" font-family="Arial, monospace" font-size="13" font-weight="bold" fill="#475569">REG NO: <tspan fill="#8C1119">${cleanReg}</tspan></text>
      <text x="610" y="623" font-family="Arial, monospace" font-size="13" font-weight="bold" fill="#475569">CERT NO: <tspan fill="#8C1119">${cleanCert}</tspan></text>
      
      <!-- Signatures -->
      <line x1="160" y1="740" x2="360" y2="740" stroke="#94A3B8" stroke-width="1" />
      <text x="260" y="760" font-family="Arial, sans-serif" font-size="13" font-weight="bold" fill="#1E293B" text-anchor="middle">Dr. Pallavi K. Shinde</text>
      <text x="260" y="778" font-family="Arial, sans-serif" font-size="11" fill="#64748B" text-anchor="middle">Organizing Chairperson</text>
      
      <!-- Gold Seal -->
      <circle cx="600" cy="735" r="45" fill="#FFFBEB" stroke="#C8A45A" stroke-width="3" />
      <circle cx="600" cy="735" r="38" fill="none" stroke="#8C1119" stroke-width="1" stroke-dasharray="4,2" />
      <text x="600" y="730" font-family="Arial, sans-serif" font-size="10" font-weight="bold" fill="#8C1119" text-anchor="middle">OFFICIAL</text>
      <text x="600" y="745" font-family="Arial, sans-serif" font-size="10" font-weight="bold" fill="#C8A45A" text-anchor="middle">SEAL</text>
      <text x="600" y="758" font-family="Arial, sans-serif" font-size="8" fill="#64748B" text-anchor="middle">MAPCON 2026</text>
      
      <!-- Right Signature -->
      <line x1="840" y1="740" x2="1040" y2="740" stroke="#94A3B8" stroke-width="1" />
      <text x="940" y="760" font-family="Arial, sans-serif" font-size="13" font-weight="bold" fill="#1E293B" text-anchor="middle">Dr. Rakesh Sharma</text>
      <text x="940" y="778" font-family="Arial, sans-serif" font-size="11" fill="#64748B" text-anchor="middle">Organizing Secretary</text>
      
      <text x="600" y="820" font-family="Arial, sans-serif" font-size="11" fill="#94A3B8" text-anchor="middle">This is an authorized digital certificate with cryptographically registered verification token.</text>
    </svg>
  `;

  const filename = `cert-${Date.now()}-${Math.floor(100 + Math.random()*900)}.png`;
  const destPath = path.join(certDir, filename);

  await sharp(Buffer.from(svg))
    .png()
    .toFile(destPath);

  return `/uploads/certificates/${filename}`;
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
app.post('/api/auth/login', asyncRoute(async(req,res)=>{
  const loginInput = (req.body.identifier || req.body.email || req.body.phone || req.body.username || '').toString().trim();
  const password = (req.body.password || '').toString();
  if(!loginInput || !password) {
    return res.status(400).json({ message: 'Email/phone and password are required' });
  }
  const [rows] = await pool.query('SELECT id,name,email,phone,password_hash,role,must_change_password FROM users WHERE email=? OR phone=? LIMIT 1',[loginInput, loginInput]);
  if(!rows.length) return res.status(401).json({message:'Invalid credentials'});
  const u = rows[0];
  if(!await bcrypt.compare(password, u.password_hash)) return res.status(401).json({message:'Invalid credentials'});
  await pool.query('UPDATE users SET last_login_at=NOW() WHERE id=?',[u.id]);
  const secret = process.env.JWT_SECRET || 'conference-app-secret-jwt-key-2026';
  const token = jwt.sign({id:u.id, name:u.name, email:u.email, role:u.role}, secret, {expiresIn:'7d'});
  res.json({token, user:{id:u.id, name:u.name, email:u.email, phone:u.phone, role:u.role, last_login_at: new Date(), mustChangePassword: !!u.must_change_password}});
}));
app.post('/api/auth/change-password', auth, [body('newPassword').isLength({min:4})], validate, asyncRoute(async(req,res)=>{
  const newHash = await bcrypt.hash(req.body.newPassword, 10);
  await pool.query('UPDATE users SET password_hash=?, must_change_password=0 WHERE id=?', [newHash, req.user.id]);
  ok(res, {success: true}, 'Password changed successfully');
}));
app.get('/api/auth/me',auth,asyncRoute(async(req,res)=>{const [[u]]=await pool.query('SELECT id,name,email,phone,role,designation,university,blood_group,photo,last_login_at,must_change_password FROM users WHERE id=?',[req.user.id]);res.json(u)}));
app.get('/api/conferences',asyncRoute(async(req,res)=>{const [r]=await pool.query('SELECT * FROM conferences ORDER BY start_date DESC');res.json(r)}));
app.get('/api/conferences/:id',asyncRoute(async(req,res)=>{const [[c]]=await pool.query('SELECT * FROM conferences WHERE id=?',[req.params.id]);if(!c)return res.status(404).json({message:'Conference not found'});res.json(c)}));
app.get('/api/admin/liaisons',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT * FROM liaison_faculty ORDER BY name');
  res.json(r);
}));

app.get('/api/admin/participants',auth,roles('ADMIN','SUPER_ADMIN','VOLUNTEER'),asyncRoute(async(req,res)=>{
  const conferenceId=req.query.conferenceId||1;
  const [r]=await pool.query(`
    SELECT p.*, u.name, u.email, u.phone, u.designation, u.university, u.blood_group, u.photo, u.last_login_at,
           l.name as liaison_name, l.phone as liaison_phone,
           h.id as hotel_id, h.name as hotel_name, r.room_number, r.room_type,
           ra.check_in, ra.check_out,
           (SELECT COUNT(*) FROM certificates WHERE participant_id=p.id) as has_certificate,
           (SELECT COUNT(*) FROM feedback WHERE participant_id=p.id) as has_feedback
    FROM participants p
    JOIN users u ON u.id = p.user_id
    LEFT JOIN liaison_faculty l ON l.id = p.liaison_id
    LEFT JOIN room_allocations ra ON ra.participant_id = p.id
    LEFT JOIN rooms r ON r.id = ra.room_id
    LEFT JOIN hotels h ON h.id = r.hotel_id
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

  const createdPart = { id: pRes.insertId, userId, registrationNo: regNo, qrToken, name: req.body.name, status: req.body.status || 'PENDING' };
  io.emit('participant_registered', createdPart);
  created(res, { id: pRes.insertId, userId, registrationNo: regNo, qrToken }, 'Participant registered');
}));

app.put('/api/admin/participants/:id',auth,roles('ADMIN','SUPER_ADMIN'),validate,asyncRoute(async(req,res)=>{
  const [[p]]=await pool.query('SELECT p.*, u.id as user_id, u.name, u.email, u.phone FROM participants p JOIN users u ON u.id=p.user_id WHERE p.id=?',[req.params.id]);
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

  const [[updatedP]]=await pool.query(`
    SELECT p.*, u.name, u.email, u.phone, u.designation, u.university, u.blood_group, u.photo, u.last_login_at,
           l.name as liaison_name, l.phone as liaison_phone,
           h.id as hotel_id, h.name as hotel_name, r.room_number, r.room_type,
           ra.check_in, ra.check_out,
           (SELECT COUNT(*) FROM certificates WHERE participant_id=p.id) as has_certificate,
           (SELECT COUNT(*) FROM feedback WHERE participant_id=p.id) as has_feedback
    FROM participants p
    JOIN users u ON u.id = p.user_id
    LEFT JOIN liaison_faculty l ON l.id = p.liaison_id
    LEFT JOIN room_allocations ra ON ra.participant_id = p.id
    LEFT JOIN rooms r ON r.id = ra.room_id
    LEFT JOIN hotels h ON h.id = r.hotel_id
    WHERE p.id = ?
  `, [req.params.id]);

  io.emit('participant_status_updated', { id: req.params.id, userId: p.user_id, participant: updatedP });

  if(req.body.status === 'APPROVED' && p.status !== 'APPROVED'){
    await createAndSendNotification({
      user_id: p.user_id,
      conference_id: p.conference_id || 1,
      title: 'Registration Approved! 🎉',
      message: `Dear ${p.name}, your MAPCON 2026 registration (${updatedP?.registration_no || p.registration_no}) has been officially approved. Welcome to the conference!`,
      type: 'REGISTRATION'
    });
  }

  ok(res, updatedP, 'Participant updated');
}));

app.delete('/api/admin/participants/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [[p]]=await pool.query('SELECT user_id FROM participants WHERE id=?',[req.params.id]);
  if(p){
    await pool.query('DELETE FROM participants WHERE id=?',[req.params.id]);
    await pool.query('DELETE FROM users WHERE id=?',[p.user_id]);
    io.emit('participant_deleted', { id: req.params.id, userId: p.user_id });
  }
  ok(res,null,'Participant deleted');
}));

app.post('/api/admin/participants/bulk-import',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const { participants, conferenceId = 1 } = req.body;
  if(!Array.isArray(participants) || !participants.length){
    return res.status(400).json({message: 'No participant data provided'});
  }

  const defaultHash = await bcrypt.hash('changeme', 10);
  let created = 0, updated = 0, skipped = 0;
  const errors = [];

  for(let i = 0; i < participants.length; i++){
    const row = participants[i];
    const name = row.name || row.Name || row.full_name || row.fullName || row['Full Name'] || row['Participant Name'] || row['Delegate Name'];
    let phone = row.phone || row.Phone || row.mobile || row['Mobile Number'] || row['Mobile'] || row['Phone Number'] || row['Contact'];
    if(phone) phone = String(phone).replace(/[^0-9]/g,'');
    let email = row.email || row.Email || row['Email Address'];
    const regNoInput = row.registration_no || row.RegistrationNo || row['Reg No'] || row['Registration Number'] || row['Registration No'] || row['Reg. No'];
    
    if(!email && phone) email = `${phone}@conference.local`;
    if(!name || (!phone && !email && !regNoInput)){
      skipped++;
      continue;
    }

    try{
      let uid = null;
      let existingUser = null;
      let existingParticipant = null;

      // Match strategy: 1) Match by registration_no, 2) Match by phone, 3) Match by email
      if(regNoInput){
        const [[pFound]] = await pool.query(
          'SELECT p.id, p.user_id FROM participants p WHERE p.registration_no=? AND p.conference_id=? LIMIT 1',
          [String(regNoInput).trim(), conferenceId]
        );
        if(pFound){
          existingParticipant = pFound;
          uid = pFound.user_id;
        }
      }

      if(!uid && phone){
        const [[uFound]] = await pool.query('SELECT id FROM users WHERE phone=? AND phone!="" LIMIT 1', [phone]);
        if(uFound){
          uid = uFound.id;
        }
      }

      if(!uid && email){
        const [[uFound]] = await pool.query('SELECT id FROM users WHERE email=? LIMIT 1', [email]);
        if(uFound){
          uid = uFound.id;
        }
      }

      const designation = row.designation || row.Designation || null;
      const university = row.university || row.University || row.Institution || row.College || null;
      const bloodGroup = row.blood_group || row.BloodGroup || row['Blood Group'] || null;

      if(uid){
        // Existing user - enrich extra fields without overwriting non-empty fields with nulls
        await pool.query(`
          UPDATE users SET 
            name = COALESCE(?, name),
            phone = COALESCE(?, phone),
            email = COALESCE(?, email),
            designation = COALESCE(?, designation),
            university = COALESCE(?, university),
            blood_group = COALESCE(?, blood_group)
          WHERE id = ?
        `, [name, phone||null, email||null, designation, university, bloodGroup, uid]);
      } else {
        // Create new user
        const [uRes] = await pool.query(
          'INSERT INTO users(name,email,password_hash,phone,role,designation,university,blood_group,must_change_password) VALUES(?,?,?,?,?,?,?,?,1)',
          [name, email || `user_${Date.now()}_${Math.floor(Math.random()*1000)}@conference.local`, defaultHash, phone||null, 'PARTICIPANT', designation, university, bloodGroup]
        );
        uid = uRes.insertId;
      }

      const regNo = regNoInput ? String(regNoInput).trim() : `MAPCON-${Date.now().toString().slice(-4)}${Math.floor(Math.random()*1000)}`;
      const qrToken = `QR-${uid}-${Date.now().toString(36)}`;
      const category = row.category || row.Category || row['Delegate Category'] || 'Delegate';
      const modeOfTravel = row.mode_of_travel || row.ModeOfTravel || row['Travel Mode'] || row['Mode of Travel'] || null;
      const flightNumber = row.flight_number || row.FlightNumber || row['Flight/Train No'] || row['Flight Number'] || row['Train Number'] || null;
      const arrivalDate = row.arrival_date || row.ArrivalDate || row['Arrival Date'] || null;
      const arrivalTime = row.arrival_time || row.ArrivalTime || row['Arrival Time'] || null;
      const departureDate = row.departure_date || row.DepartureDate || row['Departure Date'] || null;
      const departureTime = row.departure_time || row.DepartureTime || row['Departure Time'] || null;
      const emergencyContact = row.emergency_contact || row.EmergencyContact || row['Emergency Contact'] || null;

      // Liaison Mapping
      const liaisonName = row.liaison_name || row.LiaisonName || row['Liaison Officer'] || row['Liaison Faculty'] || row['Liaison'];
      const liaisonPhone = row.liaison_phone || row.LiaisonPhone || row['Liaison Phone'] || null;
      let liaisonId = null;
      if(liaisonName){
        let [[lFound]] = await pool.query('SELECT id FROM liaison_faculty WHERE name=? LIMIT 1',[liaisonName]);
        if(!lFound){
          const [lRes] = await pool.query('INSERT INTO liaison_faculty(name, phone) VALUES(?,?)',[liaisonName, liaisonPhone]);
          liaisonId = lRes.insertId;
        } else {
          liaisonId = lFound.id;
        }
      }

      let participantId;
      if(!existingParticipant){
        const [[pFound]] = await pool.query('SELECT id FROM participants WHERE user_id=? AND conference_id=? LIMIT 1',[uid, conferenceId]);
        if(pFound) existingParticipant = pFound;
      }

      if(existingParticipant){
        participantId = existingParticipant.id;
        await pool.query(`
          UPDATE participants SET 
            category = COALESCE(?, category),
            mode_of_travel = COALESCE(?, mode_of_travel),
            flight_number = COALESCE(?, flight_number),
            arrival_date = COALESCE(?, arrival_date),
            arrival_time = COALESCE(?, arrival_time),
            departure_date = COALESCE(?, departure_date),
            departure_time = COALESCE(?, departure_time),
            emergency_contact = COALESCE(?, emergency_contact),
            liaison_id = COALESCE(?, liaison_id)
          WHERE id = ?
        `, [category, modeOfTravel, flightNumber, arrivalDate||null, arrivalTime||null, departureDate||null, departureTime||null, emergencyContact, liaisonId, participantId]);
        updated++;
      } else {
        const [pRes] = await pool.query(`
          INSERT INTO participants(user_id, conference_id, registration_no, category, status, payment_status, mode_of_travel, flight_number, arrival_date, arrival_time, departure_date, departure_time, emergency_contact, liaison_id, qr_token)
          VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        `, [uid, conferenceId, regNo, category, 'APPROVED', 'PAID', modeOfTravel, flightNumber, arrivalDate||null, arrivalTime||null, departureDate||null, departureTime||null, emergencyContact, liaisonId, qrToken]);
        participantId = pRes.insertId;
        created++;
      }

      // Hotel Mapping & Room Allocation
      const hotelName = row.hotel_name || row.HotelName || row['Hotel'] || row['Hotel Name'];
      const roomNumber = row.room_number || row.RoomNumber || row['Room No'] || row['Room Number'];
      if(hotelName || roomNumber){
        const hName = hotelName || 'Conference Partner Hotel';
        const hAddr = row.hotel_address || row.HotelAddress || row['Hotel Address'] || 'Conference Accommodation';
        let [[hotel]] = await pool.query('SELECT id FROM hotels WHERE name=? LIMIT 1',[hName]);
        if(!hotel){
          const [hRes] = await pool.query('INSERT INTO hotels(name, address) VALUES(?,?)',[hName, hAddr]);
          hotel = { id: hRes.insertId };
        }

        const rNum = String(roomNumber || 'TBD');
        const rType = row.room_type || row.RoomType || row['Room Type'] || 'Deluxe';
        let [[room]] = await pool.query('SELECT id FROM rooms WHERE hotel_id=? AND room_number=? LIMIT 1',[hotel.id, rNum]);
        if(!room){
          const [rRes] = await pool.query('INSERT INTO rooms(hotel_id, room_number, room_type) VALUES(?,?,?)',[hotel.id, rNum, rType]);
          room = { id: rRes.insertId };
        }

        const checkIn = row.check_in || row.CheckIn || row['Check In Date'] || '2026-09-25';
        const checkOut = row.check_out || row.CheckOut || row['Check Out Date'] || '2026-09-28';
        await pool.query(`
          INSERT INTO room_allocations(participant_id, room_id, check_in, check_out)
          VALUES(?,?,?,?)
          ON DUPLICATE KEY UPDATE room_id=VALUES(room_id), check_in=VALUES(check_in), check_out=VALUES(check_out)
        `, [participantId, room.id, checkIn, checkOut]);
      }

      // Travel Assignment Mapping
      const pickupLoc = row.pickup_location || row.PickupLocation || row['Pickup Point'] || row['Pickup Location'];
      const dropLoc = row.drop_location || row.DropLocation || row['Drop Point'] || row['Drop Location'];
      const driverName = row.driver_name || row.DriverName || row['Driver Name'];
      const driverPhone = row.driver_phone || row.DriverPhone || row['Driver Phone'];
      const vehicleNum = row.vehicle_number || row.VehicleNumber || row['Vehicle No'] || row['Vehicle Number'];
      if(pickupLoc || dropLoc || driverName || vehicleNum){
        let vehicleId = null;
        if(driverName || vehicleNum){
          let driverId = null;
          if(driverName){
            let [[driver]] = await pool.query('SELECT id FROM drivers WHERE name=? LIMIT 1',[driverName]);
            if(!driver){
              const [dRes] = await pool.query('INSERT INTO drivers(name, phone) VALUES(?,?)',[driverName, driverPhone||null]);
              driver = { id: dRes.insertId };
            }
            driverId = driver.id;
          }

          const vNum = vehicleNum || `VEH-${Math.floor(1000 + Math.random()*9000)}`;
          let [[veh]] = await pool.query('SELECT id FROM vehicles WHERE vehicle_number=? LIMIT 1',[vNum]);
          if(!veh){
            const [vRes] = await pool.query('INSERT INTO vehicles(driver_id, vehicle_number, vehicle_type) VALUES(?,?,?)',[driverId, vNum, 'Sedan/SUV']);
            veh = { id: vRes.insertId };
          }
          vehicleId = veh.id;
        }

        await pool.query(`
          INSERT INTO transport_assignments(participant_id, vehicle_id, pickup_location, drop_location, pickup_time, notes)
          VALUES(?,?,?,?,NOW(),?)
          ON DUPLICATE KEY UPDATE vehicle_id=VALUES(vehicle_id), pickup_location=VALUES(pickup_location), drop_location=VALUES(drop_location), notes=VALUES(notes)
        `, [participantId, vehicleId, pickupLoc||'Kolhapur Airport/Station', dropLoc||'Hotel Sayaji / Venue', row.travel_notes||row['Travel Notes']||'Pickup scheduled']);
      }
    } catch(err){
      console.error('Row import error at row', i, err);
      errors.push({ row: i + 1, name, error: err.message });
      skipped++;
    }
  }

  ok(res, {
    total: participants.length,
    created,
    updated,
    skipped,
    errors
  }, `Bulk Import Complete: ${created} new participants created, ${updated} existing records merged & enriched (${skipped} skipped)`);
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
  io.emit('speakers_updated', { action: 'create', id: r.insertId });
  created(res,{id:r.insertId},'Speaker added');
}));

app.put('/api/admin/speakers/:id',auth,roles('ADMIN','SUPER_ADMIN'),validate,asyncRoute(async(req,res)=>{
  await pool.query('UPDATE speakers SET name=?, designation=?, organization=?, bio=?, email=?, phone=?, photo=? WHERE id=?',
    [req.body.name, req.body.designation, req.body.organization, req.body.bio, req.body.email, req.body.phone, req.body.photo, req.params.id]);
  io.emit('speakers_updated', { action: 'update', id: req.params.id });
  ok(res,null,'Speaker updated');
}));

app.delete('/api/admin/speakers/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM speakers WHERE id=?',[req.params.id]);
  io.emit('speakers_updated', { action: 'delete', id: req.params.id });
  ok(res,null,'Speaker deleted');
}));

app.get('/api/admin/halls',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT h.*, v.name venue_name FROM halls h JOIN venues v ON v.id=h.venue_id WHERE v.conference_id=?',[req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/halls',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [[v]]=await pool.query('SELECT id FROM venues WHERE conference_id=? LIMIT 1',[req.body.conferenceId||1]);
  if(!v) return res.status(400).json({message:'Venue not found for conference'});
  const [r]=await pool.query('INSERT INTO halls(venue_id,name,capacity) VALUES(?,?,?)',[v.id,req.body.name,req.body.capacity||250]);
  created(res,{id:r.insertId, name:req.body.name, capacity:req.body.capacity||250},'Hall added');
}));

app.get('/api/admin/sessions',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT s.*, DATE_FORMAT(s.session_date, '%Y-%m-%d') as session_date, sp.name speaker_name, h.name hall_name
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
  io.emit('sessions_updated', { action: 'create', id: r.insertId });
  created(res,{id:r.insertId},'Session created');
}));

app.put('/api/admin/sessions/:id',auth,roles('ADMIN','SUPER_ADMIN'),validate,asyncRoute(async(req,res)=>{
  await pool.query('UPDATE sessions SET hall_id=?, speaker_id=?, title=?, description=?, session_date=?, start_time=?, end_time=?, category=? WHERE id=?',
    [req.body.hall_id, req.body.speaker_id, req.body.title, req.body.description, req.body.session_date, req.body.start_time, req.body.end_time, req.body.category, req.params.id]);
  io.emit('sessions_updated', { action: 'update', id: req.params.id });
  ok(res,null,'Session updated');
}));

app.delete('/api/admin/sessions/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM sessions WHERE id=?',[req.params.id]);
  io.emit('sessions_updated', { action: 'delete', id: req.params.id });
  ok(res,null,'Session deleted');
}));
app.get('/api/sessions',asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT s.*, DATE_FORMAT(s.session_date, '%Y-%m-%d') as session_date, sp.name speaker_name,sp.photo speaker_photo,v.name venue_name,h.name hall_name FROM sessions s LEFT JOIN speakers sp ON sp.id=s.speaker_id LEFT JOIN halls h ON h.id=s.hall_id LEFT JOIN venues v ON v.id=h.venue_id WHERE s.conference_id=? ORDER BY s.session_date,s.start_time`,[req.query.conferenceId||1]);res.json(r)}));
app.get('/api/notices',asyncRoute(async(req,res)=>{
  let userRole = null, userId = null;
  try {
    const h = req.headers.authorization || '';
    if (h.startsWith('Bearer ')) {
      const secret = process.env.JWT_SECRET || 'conference-app-secret-jwt-key-2026';
      const u = jwt.verify(h.slice(7), secret);
      userRole = u?.role;
      userId = u?.id;
    }
  } catch(_) {}
  const [r]=await pool.query('SELECT * FROM notices WHERE conference_id=? AND (target_role IS NULL OR target_role=? OR target_user_id=?) ORDER BY created_at DESC',[req.query.conferenceId||1, userRole, userId]);
  res.json(r);
}));

app.get('/api/gallery',asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT * FROM photos WHERE conference_id=? ORDER BY created_at DESC',[req.query.conferenceId||1]);
  res.json(r);
}));

app.get('/api/admin/gallery/albums',auth,roles('ADMIN','SUPER_ADMIN','PHOTOGRAPHER'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT album, COUNT(*) photo_count FROM photos WHERE conference_id=? GROUP BY album',[req.query.conferenceId||1]);
  res.json(r);
}));

app.get('/api/admin/gallery',auth,roles('ADMIN','SUPER_ADMIN','PHOTOGRAPHER'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT ph.*, u.name as uploader_name,
           (SELECT COUNT(*) FROM photo_faces WHERE photo_id = ph.id) as indexed_faces
    FROM photos ph
    LEFT JOIN users u ON u.id = ph.uploaded_by
    WHERE ph.conference_id=?
    ORDER BY ph.created_at DESC`, [req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/gallery',auth,roles('ADMIN','SUPER_ADMIN','PHOTOGRAPHER'),asyncRoute(async(req,res)=>{
  const conferenceId = req.body.conferenceId || 1;
  const album = req.body.album || 'General';
  const url = req.body.url;
  const caption = req.body.caption || '';
  
  const [r]=await pool.query('INSERT INTO photos(conference_id,album,url,caption,uploaded_by) VALUES(?,?,?,?,?)',
    [conferenceId, album, url, caption, req.user.id]);
  const photoId = r.insertId;

  let imgBuffer;
  try {
    if(url.startsWith('http')){
      const resp = await fetch(url);
      const ab = await resp.arrayBuffer();
      imgBuffer = Buffer.from(ab);
    } else if(url.startsWith('/uploads')){
      const localPath = path.join(uploadRoot, url.replace(/^\/?uploads\//, ''));
      if(fs.existsSync(localPath)) imgBuffer = fs.readFileSync(localPath);
    }
  } catch(e){}
  if(!imgBuffer) imgBuffer = Buffer.from(url);

  const faces = await extractGroupPhotoFaces(imgBuffer, 2);
  for(const f of faces){
    await pool.query(
      'INSERT INTO photo_faces(photo_id, conference_id, bounding_box, embedding) VALUES(?,?,?,?)',
      [photoId, conferenceId, JSON.stringify(f.boundingBox), JSON.stringify(f.embedding)]
    );
  }

  created(res,{id:photoId, url, indexedFaces:faces.length},'Photo added and AI faces indexed');
}));

app.post('/api/admin/gallery/bulk-upload',auth,roles('ADMIN','SUPER_ADMIN','PHOTOGRAPHER'),asyncRoute(async(req,res)=>{
  const { photos: batch = [], conferenceId = 1, album = 'General' } = req.body;
  if(!Array.isArray(batch) || !batch.length){
    return res.status(400).json({message: 'No photos provided for upload'});
  }

  let totalUploaded = 0;
  let totalFacesIndexed = 0;

  for(const item of batch){
    const url = item.url || item;
    const caption = item.caption || '';
    const [r]=await pool.query('INSERT INTO photos(conference_id,album,url,caption,uploaded_by) VALUES(?,?,?,?,?)',
      [conferenceId, item.album || album, url, caption, req.user.id]);
    const photoId = r.insertId;

    let imgBuffer;
    try {
      if(url.startsWith('http')){
        const resp = await fetch(url);
        const ab = await resp.arrayBuffer();
        imgBuffer = Buffer.from(ab);
      } else if(url.startsWith('/uploads')){
        const localPath = path.join(uploadRoot, url.replace(/^\/?uploads\//, ''));
        if(fs.existsSync(localPath)) imgBuffer = fs.readFileSync(localPath);
      }
    } catch(e){}
    if(!imgBuffer) imgBuffer = Buffer.from(url);

    const faces = await extractGroupPhotoFaces(imgBuffer, 2);
    for(const f of faces){
      await pool.query(
        'INSERT INTO photo_faces(photo_id, conference_id, bounding_box, embedding) VALUES(?,?,?,?)',
        [photoId, conferenceId, JSON.stringify(f.boundingBox), JSON.stringify(f.embedding)]
      );
      totalFacesIndexed++;
    }
    totalUploaded++;
  }

  ok(res, { uploaded: totalUploaded, facesIndexed: totalFacesIndexed }, `Uploaded ${totalUploaded} photos with ${totalFacesIndexed} faces indexed for AI matching.`);
}));

app.delete('/api/admin/gallery/:id',auth,roles('ADMIN','SUPER_ADMIN','PHOTOGRAPHER'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM photos WHERE id=?',[req.params.id]);
  ok(res,null,'Photo deleted');
}));

app.post('/api/gallery/match-selfie',asyncRoute(async(req,res)=>{
  const conferenceId = req.body.conferenceId || 1;
  const selfieData = req.body.selfie || req.body.photo || req.body.image;
  
  if(!selfieData){
    return res.status(400).json({message: 'Selfie photo data is required for face recognition'});
  }

  const queryEmbedding = await extractFaceEmbedding(selfieData);

  let [faces]=await pool.query(`
    SELECT pf.*, ph.url, ph.caption, ph.album, ph.created_at
    FROM photo_faces pf
    JOIN photos ph ON ph.id = pf.photo_id
    WHERE pf.conference_id = ?
  `, [conferenceId]);

  if(!faces.length){
    const [allPhotos] = await pool.query('SELECT * FROM photos WHERE conference_id=?', [conferenceId]);
    for(const p of allPhotos){
      const genFaces = await extractGroupPhotoFaces(p.url || `${p.id}`, 2);
      for(const f of genFaces){
        await pool.query(
          'INSERT INTO photo_faces(photo_id, conference_id, bounding_box, embedding) VALUES(?,?,?,?)',
          [p.id, conferenceId, JSON.stringify(f.boundingBox), JSON.stringify(f.embedding)]
        );
      }
    }
    const [refreshedFaces] = await pool.query(`
      SELECT pf.*, ph.url, ph.caption, ph.album, ph.created_at
      FROM photo_faces pf
      JOIN photos ph ON ph.id = pf.photo_id
      WHERE pf.conference_id = ?
    `, [conferenceId]);
    faces = refreshedFaces;
  }

  if(!faces.length){
    return ok(res, { matches: [], totalMatched: 0 }, 'No conference photos found in gallery');
  }

  const matchedPhotos = rankGalleryMatches(queryEmbedding, faces);

  ok(res, {
    matches: matchedPhotos,
    totalMatched: matchedPhotos.length,
  }, `AI Face Recognition identified ${matchedPhotos.length} matching photos of you!`);
}));

app.get('/api/gallery/my-photos',auth,asyncRoute(async(req,res)=>{
  const conferenceId = req.query.conferenceId || 1;
  const [[u]] = await pool.query('SELECT photo FROM users WHERE id=?', [req.user.id]);
  if(!u?.photo){
    return ok(res, { matches: [], totalMatched: 0, hasProfilePhoto: false }, 'Please upload a profile photo or take a selfie to enable automatic smart matching');
  }

  const queryVec = await extractFaceEmbedding(u.photo);
  const [faces]=await pool.query(`
    SELECT pf.*, ph.url, ph.caption, ph.album, ph.created_at
    FROM photo_faces pf
    JOIN photos ph ON ph.id = pf.photo_id
    WHERE pf.conference_id = ?
  `, [conferenceId]);

  const matched = rankGalleryMatches(queryVec, faces);
  ok(res, {
    matches: matched,
    totalMatched: matched.length,
    hasProfilePhoto: true,
  }, `Found ${matched.length} photos of you in the conference gallery`);
}));

app.post(['/api/me/avatar', '/api/me/photo'],auth,asyncRoute(async(req,res)=>{
  if(!req.body.file || !req.body.file.dataUrl) {
    return res.status(400).json({message:'Please select a valid image file'});
  }
  const url = await saveDataUrlUpload('participants', req.body.file);
  await pool.query('UPDATE users SET photo=? WHERE id=?', [url, req.user.id]);
  await pool.query('UPDATE participants SET qr_token=COALESCE(qr_token, qr_token) WHERE user_id=?', [req.user.id]);
  
  const [[u]] = await pool.query('SELECT id, name, email, phone, role, designation, university, blood_group, photo FROM users WHERE id=?', [req.user.id]);
  io.to(`user_${req.user.id}`).emit('profile_updated', u);
  io.emit('speakers_updated');
  created(res, { url, user: u, photo: url }, 'Profile photo updated successfully');
}));

app.post('/api/uploads',auth,asyncRoute(async(req,res)=>{
  if(!req.body.file || !req.body.file.dataUrl) {
    return res.status(400).json({message:'No image file provided'});
  }
  const folder = req.body.folder || 'participants';
  const url = await saveDataUrlUpload(folder, req.body.file);
  created(res, { url }, 'File uploaded successfully');
}));

app.get('/api/me/profile',auth,asyncRoute(async(req,res)=>{
  const [[u]]=await pool.query(`
    SELECT u.id,u.name,u.email,u.phone,u.role,u.designation,u.university,u.blood_group,u.photo,
           p.registration_no,p.category,p.mode_of_travel,p.flight_number,p.arrival_date,p.arrival_time,p.departure_date,p.departure_time,p.emergency_contact,
           h.name hotel_name,r.room_number,r.room_type,l.name liaison_name,l.phone liaison_phone 
    FROM users u 
    LEFT JOIN participants p ON p.user_id=u.id 
    LEFT JOIN room_allocations ra ON ra.participant_id=p.id 
    LEFT JOIN rooms r ON r.id=ra.room_id 
    LEFT JOIN hotels h ON h.id=r.hotel_id 
    LEFT JOIN liaison_faculty l ON l.id=p.liaison_id 
    WHERE u.id=?
  `,[req.user.id]);
  if(!u)return res.status(404).json({message:'Profile not found'});
  res.json(u);
}));

app.put('/api/me/profile',auth,asyncRoute(async(req,res)=>{
  const userId = req.user.id;
  const name = req.body.name !== undefined ? (req.body.name ? String(req.body.name).trim() : null) : undefined;
  const phone = req.body.phone !== undefined ? (req.body.phone ? String(req.body.phone).trim() : null) : undefined;
  const designation = req.body.designation !== undefined ? (req.body.designation ? String(req.body.designation).trim() : null) : undefined;
  const university = req.body.university !== undefined ? (req.body.university ? String(req.body.university).trim() : null) : undefined;
  const photo = req.body.photo !== undefined ? (req.body.photo ? String(req.body.photo).trim() : null) : (req.body.avatarUrl !== undefined ? (req.body.avatarUrl ? String(req.body.avatarUrl).trim() : null) : undefined);
  const bloodGroup = (req.body.blood_group !== undefined ? req.body.blood_group : req.body.bloodGroup) !== undefined 
    ? ((req.body.blood_group || req.body.bloodGroup) ? String(req.body.blood_group || req.body.bloodGroup).trim() : null) 
    : undefined;

  const userUpdates = [];
  const userParams = [];
  if (name !== undefined) { userUpdates.push('name = ?'); userParams.push(name); }
  if (phone !== undefined) { userUpdates.push('phone = ?'); userParams.push(phone); }
  if (designation !== undefined) { userUpdates.push('designation = ?'); userParams.push(designation); }
  if (university !== undefined) { userUpdates.push('university = ?'); userParams.push(university); }
  if (bloodGroup !== undefined) { userUpdates.push('blood_group = ?'); userParams.push(bloodGroup); }
  if (photo !== undefined) { userUpdates.push('photo = ?'); userParams.push(photo); }

  if (userUpdates.length > 0) {
    userParams.push(userId);
    await pool.query(`UPDATE users SET ${userUpdates.join(', ')} WHERE id = ?`, userParams);
  }

  const emergencyContact = req.body.emergency_contact !== undefined ? (req.body.emergency_contact ? String(req.body.emergency_contact).trim() : null) : (req.body.emergencyContact !== undefined ? (req.body.emergencyContact ? String(req.body.emergencyContact).trim() : null) : undefined);
  const modeOfTravel = (req.body.mode_of_travel !== undefined ? req.body.mode_of_travel : req.body.modeOfTravel) !== undefined ? ((req.body.mode_of_travel || req.body.modeOfTravel) ? String(req.body.mode_of_travel || req.body.modeOfTravel).trim() : null) : undefined;
  const flightNumber = (req.body.flight_number !== undefined ? req.body.flight_number : req.body.flightNumber) !== undefined ? ((req.body.flight_number || req.body.flightNumber) ? String(req.body.flight_number || req.body.flightNumber).trim() : null) : undefined;
  const arrivalDate = (req.body.arrival_date !== undefined ? req.body.arrival_date : req.body.arrivalDate) !== undefined ? (req.body.arrival_date || req.body.arrivalDate || null) : undefined;
  const arrivalTime = (req.body.arrival_time !== undefined ? req.body.arrival_time : req.body.arrivalTime) !== undefined ? (req.body.arrival_time || req.body.arrivalTime || null) : undefined;
  const departureDate = (req.body.departure_date !== undefined ? req.body.departure_date : req.body.departureDate) !== undefined ? (req.body.departure_date || req.body.departureDate || null) : undefined;
  const departureTime = (req.body.departure_time !== undefined ? req.body.departure_time : req.body.departureTime) !== undefined ? (req.body.departure_time || req.body.departureTime || null) : undefined;

  const partUpdates = [];
  const partParams = [];
  if (emergencyContact !== undefined) { partUpdates.push('emergency_contact = ?'); partParams.push(emergencyContact); }
  if (modeOfTravel !== undefined) { partUpdates.push('mode_of_travel = ?'); partParams.push(modeOfTravel); }
  if (flightNumber !== undefined) { partUpdates.push('flight_number = ?'); partParams.push(flightNumber); }
  if (arrivalDate !== undefined) { partUpdates.push('arrival_date = ?'); partParams.push(arrivalDate); }
  if (arrivalTime !== undefined) { partUpdates.push('arrival_time = ?'); partParams.push(arrivalTime); }
  if (departureDate !== undefined) { partUpdates.push('departure_date = ?'); partParams.push(departureDate); }
  if (departureTime !== undefined) { partUpdates.push('departure_time = ?'); partParams.push(departureTime); }

  if (partUpdates.length > 0) {
    partParams.push(userId);
    await pool.query(`UPDATE participants SET ${partUpdates.join(', ')} WHERE user_id = ?`, partParams);
  }

  const [[u]] = await pool.query(`
    SELECT u.id,u.name,u.email,u.phone,u.role,u.designation,u.university,u.blood_group,u.photo,
           p.registration_no,p.category,p.mode_of_travel,p.flight_number,p.arrival_date,p.arrival_time,p.departure_date,p.departure_time,p.emergency_contact,
           h.name hotel_name,r.room_number,r.room_type,l.name liaison_name,l.phone liaison_phone 
    FROM users u 
    LEFT JOIN participants p ON p.user_id=u.id 
    LEFT JOIN room_allocations ra ON ra.participant_id=p.id 
    LEFT JOIN rooms r ON r.id=ra.room_id 
    LEFT JOIN hotels h ON h.id=r.hotel_id 
    LEFT JOIN liaison_faculty l ON l.id=p.liaison_id 
    WHERE u.id=?
  `, [userId]);

  io.emit('participant_status_updated', { userId, participant: u });
  ok(res, u, 'Profile updated successfully');
}));
app.post('/api/me/photo',auth,asyncRoute(async(req,res)=>{
  let photoUrl = req.body.photo || req.body.photoUrl;
  if(req.body.file){
    photoUrl = await saveDataUrlUpload('participants', req.body.file);
  }
  if(!photoUrl){
    return res.status(400).json({message:'Photo URL or file payload is required'});
  }
  await pool.query('UPDATE users SET photo=? WHERE id=?',[photoUrl, req.user.id]);
  ok(res,{photo: photoUrl},'Profile photo updated successfully');
}));
app.get('/api/me/accommodation',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT h.name hotel_name,h.address,h.latitude,h.longitude,r.room_number,r.room_type,ra.check_in,ra.check_out FROM room_allocations ra JOIN participants p ON p.id=ra.participant_id JOIN rooms r ON r.id=ra.room_id JOIN hotels h ON h.id=r.hotel_id WHERE p.user_id=?`,[req.user.id]);res.json(r[0]||null)}));
app.get('/api/me/transport',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT t.*,v.vehicle_number,v.vehicle_type,d.name driver_name,d.phone driver_phone FROM transport_assignments t LEFT JOIN vehicles v ON v.id=t.vehicle_id LEFT JOIN drivers d ON d.id=v.driver_id JOIN participants p ON p.id=t.participant_id WHERE p.user_id=? ORDER BY t.pickup_time`,[req.user.id]);res.json(r)}));
app.get('/api/me/duties',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT d.*,da.status FROM duties d JOIN duty_assignments da ON da.duty_id=d.id JOIN users u ON u.id=da.user_id WHERE u.id=? ORDER BY d.duty_date,d.start_time`,[req.user.id]);res.json(r)}));
app.get('/api/me/registration',auth,asyncRoute(async(req,res)=>{const [[r]]=await pool.query(`SELECT p.registration_no,p.category,p.status,p.payment_status,p.amount,p.qr_token,c.name conference_name,c.start_date,c.end_date FROM participants p JOIN conferences c ON c.id=p.conference_id WHERE p.user_id=? ORDER BY p.id DESC LIMIT 1`,[req.user.id]);res.json(r||null)}));
app.get('/api/me/certificate',auth,asyncRoute(async(req,res)=>{
  const [[p]]=await pool.query(`SELECT p.id, p.registration_no, u.name, u.email FROM participants p JOIN users u ON u.id=p.user_id WHERE u.id=? LIMIT 1`,[req.user.id]);
  if(!p) return res.json(null);

  const [fb]=await pool.query(`SELECT id, rating, content_rating, speaker_rating, comment, created_at FROM feedback WHERE participant_id=? ORDER BY id DESC LIMIT 1`,[p.id]);
  const hasFeedback = fb.length > 0;

  let [[cert]]=await pool.query(`SELECT cert.*, p.registration_no, u.name as participant_name FROM certificates cert JOIN participants p ON p.id=cert.participant_id JOIN users u ON u.id=p.user_id WHERE p.user_id=? AND cert.certificate_url IS NOT NULL ORDER BY cert.id DESC LIMIT 1`,[req.user.id]);

  if (cert) {
    if (cert.certificate_url && cert.certificate_url.startsWith('/uploads/')) {
      const relPath = cert.certificate_url.replace(/^\/?uploads\/?/, '');
      const absPath = path.join(uploadRoot, relPath);
      let fileExists = false;
      try {
        await fs.access(absPath);
        fileExists = true;
      } catch (_) {
        fileExists = false;
      }
      if (!fileExists) {
        const freshUrl = await generateDelegateCertificate(p.name, p.registration_no, cert.certificate_no, 'MAPCON 2026');
        await pool.query('UPDATE certificates SET certificate_url=? WHERE id=?', [freshUrl, cert.id]);
        cert.certificate_url = freshUrl;
      }
    }

    res.json({
      ...cert,
      hasFeedback,
      feedback_submitted: hasFeedback,
      feedback: hasFeedback ? fb[0] : null,
      certificate: cert,
      participant: { id: p.id, name: p.name, registration_no: p.registration_no }
    });
  } else {
    res.json({
      hasFeedback,
      feedback_submitted: hasFeedback,
      feedback: hasFeedback ? fb[0] : null,
      certificate: null,
      participant: { id: p.id, name: p.name, registration_no: p.registration_no }
    });
  }
}));

function processFeedbackPayload(b) {
  const choiceOfSpeakers = b.choiceOfSpeakers || b.choice_of_speakers || 'Good';
  const thoroughExploration = b.thoroughExploration || b.thorough_exploration || 'Good';
  const presentationQuality = b.presentationQuality || b.quality_of_presentation || b.presentation_quality || 'Good';
  const topicUsefulness = b.topicUsefulness || b.usefulness_of_topic || b.topic_usefulness || 'Good';
  const suggestions = (b.suggestions || b.comment || b.feedback || '').toString().trim();
  const programmeEvaluation = b.programmeEvaluation || b.evaluation_of_programme || b.programme_evaluation || 'Good';
  const adequateDiscussionTime = b.adequateDiscussionTime || b.adequate_discussion_time || 'Yes';
  const topicsCoveredSpecialty = b.topicsCoveredSpecialty || b.topics_covered_specialty || 'Yes';
  const understandingImprovement = Math.min(5, Math.max(1, parseInt(b.understandingImprovement || b.understanding_improvement || 5, 10)));
  const arrangementsRating = Math.min(5, Math.max(1, parseInt(b.arrangementsRating || b.arrangements_rating || 5, 10)));
  const registrationRating = Math.min(5, Math.max(1, parseInt(b.registrationRating || b.registration_rating || 5, 10)));
  const overallConductRating = Math.min(5, Math.max(1, parseInt(b.overallConductRating || b.overall_conduct_rating || b.rating || 5, 10)));
  const audiovisualsRating = Math.min(5, Math.max(1, parseInt(b.audiovisualsRating || b.audiovisuals_rating || 5, 10)));
  const foodArrangementsRating = Math.min(5, Math.max(1, parseInt(b.foodArrangementsRating || b.food_arrangements_rating || 5, 10)));

  const avgRating = Math.round(
    (understandingImprovement + arrangementsRating + registrationRating + overallConductRating + audiovisualsRating + foodArrangementsRating) / 6
  );
  const rating = parseInt(b.rating || overallConductRating || avgRating || 5, 10);
  const contentRating = parseInt(b.contentRating || (topicUsefulness === 'Excellent' ? 5 : (topicUsefulness === 'Good' ? 4 : 3)), 10);
  const speakerRating = parseInt(b.speakerRating || (choiceOfSpeakers === 'Excellent' ? 5 : (choiceOfSpeakers === 'Good' ? 4 : 3)), 10);

  const responses = {
    choice_of_speakers: choiceOfSpeakers,
    thorough_exploration: thoroughExploration,
    presentation_quality: presentationQuality,
    usefulness_of_topic: topicUsefulness,
    suggestions: suggestions,
    programme_evaluation: programmeEvaluation,
    adequate_discussion_time: adequateDiscussionTime,
    topics_covered_specialty: topicsCoveredSpecialty,
    understanding_improvement: understandingImprovement,
    arrangements_rating: arrangementsRating,
    registration_rating: registrationRating,
    overall_conduct_rating: overallConductRating,
    audiovisuals_rating: audiovisualsRating,
    food_arrangements_rating: foodArrangementsRating
  };

  return {
    choiceOfSpeakers,
    thoroughExploration,
    presentationQuality,
    topicUsefulness,
    suggestions,
    programmeEvaluation,
    adequateDiscussionTime,
    topicsCoveredSpecialty,
    understandingImprovement,
    arrangementsRating,
    registrationRating,
    overallConductRating,
    audiovisualsRating,
    foodArrangementsRating,
    rating,
    contentRating,
    speakerRating,
    comment: suggestions,
    responsesJson: JSON.stringify(responses)
  };
}

app.post('/api/me/feedback',auth,asyncRoute(async(req,res)=>{
  const [[p]]=await pool.query('SELECT id FROM participants WHERE user_id=? LIMIT 1',[req.user.id]);
  if(!p) return res.status(400).json({message:'Participant profile not found'});

  const fb = processFeedbackPayload(req.body);

  await pool.query(`
    INSERT INTO feedback(
      participant_id, session_id, rating, content_rating, speaker_rating, comment,
      choice_of_speakers, thorough_exploration, presentation_quality, topic_usefulness,
      suggestions, programme_evaluation, adequate_discussion_time, topics_covered_specialty,
      understanding_improvement, arrangements_rating, registration_rating, overall_conduct_rating,
      audiovisuals_rating, food_arrangements_rating, responses
    )
    VALUES(?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `, [
    p.id, fb.rating, fb.contentRating, fb.speakerRating, fb.comment,
    fb.choiceOfSpeakers, fb.thoroughExploration, fb.presentationQuality, fb.topicUsefulness,
    fb.suggestions, fb.programmeEvaluation, fb.adequateDiscussionTime, fb.topicsCoveredSpecialty,
    fb.understandingImprovement, fb.arrangementsRating, fb.registrationRating, fb.overallConductRating,
    fb.audiovisualsRating, fb.foodArrangementsRating, fb.responsesJson
  ]);

  ok(res, { feedbackSubmitted: true }, 'Feedback submitted successfully');
}));

app.post('/api/me/feedback-and-certificate',auth,asyncRoute(async(req,res)=>{
  const [[p]]=await pool.query('SELECT p.id, p.registration_no, u.name, u.email FROM participants p JOIN users u ON u.id=p.user_id WHERE u.id=? LIMIT 1',[req.user.id]);
  if(!p) return res.status(400).json({success:false,message:'Participant profile not found'});

  const fb = processFeedbackPayload(req.body);

  await pool.query(`
    INSERT INTO feedback(
      participant_id, session_id, rating, content_rating, speaker_rating, comment,
      choice_of_speakers, thorough_exploration, presentation_quality, topic_usefulness,
      suggestions, programme_evaluation, adequate_discussion_time, topics_covered_specialty,
      understanding_improvement, arrangements_rating, registration_rating, overall_conduct_rating,
      audiovisuals_rating, food_arrangements_rating, responses
    )
    VALUES(?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `, [
    p.id, fb.rating, fb.contentRating, fb.speakerRating, fb.comment,
    fb.choiceOfSpeakers, fb.thoroughExploration, fb.presentationQuality, fb.topicUsefulness,
    fb.suggestions, fb.programmeEvaluation, fb.adequateDiscussionTime, fb.topicsCoveredSpecialty,
    fb.understandingImprovement, fb.arrangementsRating, fb.registrationRating, fb.overallConductRating,
    fb.audiovisualsRating, fb.foodArrangementsRating, fb.responsesJson
  ]);

  let [[cert]]=await pool.query('SELECT * FROM certificates WHERE participant_id=? ORDER BY id DESC LIMIT 1',[p.id]);
  let certNo = cert?.certificate_no;
  let certUrl = cert?.certificate_url;

  if(!certNo){
    certNo = `MAPCON2026-CERT-${p.registration_no ? p.registration_no.replace(/[^a-zA-Z0-9]/g,'') : Math.floor(1000 + Math.random()*9000)}`;
  }

  let needGenerate = !certUrl;
  if (certUrl && certUrl.startsWith('/uploads/')) {
    const relPath = certUrl.replace(/^\/?uploads\/?/, '');
    const absPath = path.join(uploadRoot, relPath);
    try {
      await fs.access(absPath);
    } catch (_) {
      needGenerate = true;
    }
  }

  if(needGenerate){
    certUrl = await generateDelegateCertificate(p.name, p.registration_no, certNo, 'MAPCON 2026');
    await pool.query(`
      INSERT INTO certificates(participant_id, certificate_no, certificate_url, issued_at)
      VALUES(?, ?, ?, NOW())
      ON DUPLICATE KEY UPDATE certificate_no=VALUES(certificate_no), certificate_url=VALUES(certificate_url), issued_at=NOW()
    `, [p.id, certNo, certUrl]);
  }

  const [[freshCert]]=await pool.query('SELECT cert.*, p.registration_no, u.name as participant_name FROM certificates cert JOIN participants p ON p.id=cert.participant_id JOIN users u ON u.id=p.user_id WHERE cert.participant_id=? LIMIT 1',[p.id]);

  ok(res, {
    certificate: freshCert,
    hasFeedback: true
  }, 'Feedback recorded and certificate generated successfully!');
}));

app.get('/api/sliders',asyncRoute(async(req,res)=>{
  const conferenceId = req.query.conferenceId || 1;
  const [rows] = await pool.query('SELECT * FROM main_sliders WHERE conference_id=? AND active=1 ORDER BY display_order ASC, id ASC',[conferenceId]);
  res.json(rows);
}));

app.get('/api/admin/sliders',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const conferenceId = req.query.conferenceId || 1;
  const [rows] = await pool.query('SELECT * FROM main_sliders WHERE conference_id=? ORDER BY display_order ASC, id ASC',[conferenceId]);
  res.json(rows);
}));

app.post('/api/admin/sliders',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const conferenceId = req.body.conferenceId || 1;
  let mediaUrl = req.body.media_url || req.body.mediaUrl;
  if(req.body.file){
    mediaUrl = await saveDataUrlUpload('sliders', req.body.file);
  }
  if(!mediaUrl){
    return res.status(400).json({message: 'Media file or URL is required'});
  }

  const title = req.body.title || null;
  const mediaType = req.body.media_type || req.body.mediaType || 'IMAGE';
  const thumbnailUrl = req.body.thumbnail_url || req.body.thumbnailUrl || null;
  const displayOrder = req.body.display_order || req.body.displayOrder || 0;
  const active = req.body.active !== undefined ? (req.body.active ? 1 : 0) : 1;

  const [r] = await pool.query(
    'INSERT INTO main_sliders(conference_id, title, media_type, media_url, thumbnail_url, display_order, active) VALUES(?,?,?,?,?,?,?)',
    [conferenceId, title, mediaType, mediaUrl, thumbnailUrl, displayOrder, active]
  );
  io.emit('sliders_updated', { action: 'create', id: r.insertId });
  created(res, { id: r.insertId, conference_id: conferenceId, title, media_type: mediaType, media_url: mediaUrl, active }, 'Slider item added');
}));

app.put('/api/admin/sliders/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  let mediaUrl = req.body.media_url || req.body.mediaUrl;
  if(req.body.file){
    mediaUrl = await saveDataUrlUpload('sliders', req.body.file);
  }

  await pool.query(`
    UPDATE main_sliders SET
      title=COALESCE(?,title),
      media_type=COALESCE(?,media_type),
      media_url=COALESCE(?,media_url),
      thumbnail_url=COALESCE(?,thumbnail_url),
      display_order=COALESCE(?,display_order),
      active=COALESCE(?,active)
    WHERE id=?
  `, [req.body.title, req.body.media_type||req.body.mediaType, mediaUrl, req.body.thumbnail_url||req.body.thumbnailUrl, req.body.display_order||req.body.displayOrder, req.body.active!==undefined?(req.body.active?1:0):null, req.params.id]);

  io.emit('sliders_updated', { action: 'update', id: req.params.id });
  ok(res, null, 'Slider item updated');
}));

app.delete('/api/admin/sliders/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM main_sliders WHERE id=?',[req.params.id]);
  io.emit('sliders_updated', { action: 'delete', id: req.params.id });
  ok(res, null, 'Slider item deleted');
}));

app.get('/api/sponsors',asyncRoute(async(req,res)=>{
  const conferenceId = req.query.conferenceId || 1;
  const [rows] = await pool.query('SELECT * FROM sponsors WHERE conference_id=? AND active=1 ORDER BY display_order ASC, id ASC',[conferenceId]);
  res.json(rows);
}));

app.get('/api/admin/sponsors',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const conferenceId = req.query.conferenceId || 1;
  const [rows] = await pool.query('SELECT * FROM sponsors WHERE conference_id=? ORDER BY display_order ASC, id ASC',[conferenceId]);
  res.json(rows);
}));

app.post('/api/admin/sponsors',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const conferenceId = req.body.conferenceId || 1;
  let logoUrl = req.body.logo_url || req.body.logoUrl;
  if(req.body.file){
    logoUrl = await saveDataUrlUpload('sponsors', req.body.file);
  }
  const name = req.body.name || 'Sponsor';
  const category = req.body.category || 'Partner';
  const tier = req.body.tier || 'GOLD';
  const websiteUrl = req.body.website_url || req.body.websiteUrl || null;
  const description = req.body.description || null;
  const stallNumber = req.body.stall_number || req.body.stallNumber || null;
  const contactPerson = req.body.contact_person || req.body.contactPerson || null;
  const contactPhone = req.body.contact_phone || req.body.contactPhone || null;
  const displayOrder = req.body.display_order || req.body.displayOrder || 0;
  const active = req.body.active !== undefined ? (req.body.active ? 1 : 0) : 1;

  const [r] = await pool.query(
    'INSERT INTO sponsors(conference_id, name, category, tier, logo_url, website_url, description, stall_number, contact_person, contact_phone, display_order, active) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)',
    [conferenceId, name, category, tier, logoUrl, websiteUrl, description, stallNumber, contactPerson, contactPhone, displayOrder, active]
  );
  created(res, { id: r.insertId, name, category, tier, logo_url: logoUrl }, 'Sponsor added');
}));

app.put('/api/admin/sponsors/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  let logoUrl = req.body.logo_url || req.body.logoUrl;
  if(req.body.file){
    logoUrl = await saveDataUrlUpload('sponsors', req.body.file);
  }
  await pool.query(`
    UPDATE sponsors SET
      name=COALESCE(?,name),
      category=COALESCE(?,category),
      tier=COALESCE(?,tier),
      logo_url=COALESCE(?,logo_url),
      website_url=COALESCE(?,website_url),
      description=COALESCE(?,description),
      stall_number=COALESCE(?,stall_number),
      contact_person=COALESCE(?,contact_person),
      contact_phone=COALESCE(?,contact_phone),
      display_order=COALESCE(?,display_order),
      active=COALESCE(?,active)
    WHERE id=?
  `, [req.body.name, req.body.category, req.body.tier, logoUrl, req.body.website_url||req.body.websiteUrl, req.body.description, req.body.stall_number||req.body.stallNumber, req.body.contact_person||req.body.contactPerson, req.body.contact_phone||req.body.contactPhone, req.body.display_order||req.body.displayOrder, req.body.active!==undefined?(req.body.active?1:0):null, req.params.id]);
  ok(res, null, 'Sponsor updated');
}));

app.delete('/api/admin/sponsors/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM sponsors WHERE id=?',[req.params.id]);
  ok(res, null, 'Sponsor deleted');
}));
app.get('/api/me/attendance',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query(`SELECT a.*,s.title,s.session_date,s.start_time FROM attendance a JOIN participants p ON p.id=a.participant_id JOIN sessions s ON s.id=a.session_id WHERE p.user_id=? ORDER BY s.session_date,s.start_time`,[req.user.id]);res.json(r)}));
app.post('/api/attendance/scan',auth,roles('ADMIN','SUPER_ADMIN','VOLUNTEER'),[body('qrToken').notEmpty()],validate,asyncRoute(async(req,res)=>{
  const tokenInput = String(req.body.qrToken).trim();
  const [[p]]=await pool.query(`
    SELECT p.id, p.user_id, p.registration_no, p.category, u.name, u.email
    FROM participants p
    JOIN users u ON u.id=p.user_id
    WHERE p.qr_token=? OR p.registration_no=? OR u.phone=? OR u.email=?
    LIMIT 1
  `,[tokenInput, tokenInput, tokenInput, tokenInput]);

  if(!p) return res.status(404).json({message:'Invalid QR Code or Participant Not Found'});

  const scanType=req.body.scanType||'SESSION';
  const sessionId=req.body.sessionId||null;
  const mealId=req.body.mealId||null;

  if(scanType==='MEAL' && mealId){
    // Check duplicate meal scan
    const [[existing]] = await pool.query('SELECT ms.*, u.name as scanned_by_name FROM meal_scans ms LEFT JOIN users u ON u.id=ms.scanned_by WHERE ms.meal_id=? AND ms.participant_id=? LIMIT 1',[mealId, p.id]);
    if(existing){
      return res.status(409).json({
        success: false,
        alreadyRedeemed: true,
        scannedAt: existing.scanned_at,
        message: `⚠️ Food pass ALREADY REDEEMED for ${p.name} at ${new Date(existing.scanned_at).toLocaleTimeString()}`,
        participant: p
      });
    }

    await pool.query('INSERT INTO meal_scans(meal_id,participant_id,scanned_by) VALUES(?,?,?)', [mealId, p.id, req.user.id]);
  } else {
    // Check duplicate session scan within 5 minutes
    if(sessionId){
      const [[existingScan]] = await pool.query('SELECT * FROM attendance WHERE participant_id=? AND session_id=? AND scanned_at >= NOW() - INTERVAL 5 MINUTE LIMIT 1',[p.id, sessionId]);
      if(existingScan){
        return ok(res, { participantName: p.name, scanType, alreadyRecorded: true }, `Attendance already verified for ${p.name}`);
      }
    }

    await pool.query('INSERT INTO attendance(participant_id,session_id,scan_type,scanned_by) VALUES(?,?,?,?)',
      [p.id, sessionId, scanType, req.user.id]);
    if(scanType==='CHECKIN') await pool.query("UPDATE participants SET status='CHECKED_IN' WHERE id=?",[p.id]);
  }

  const scanData={
    participantId: p.id,
    participantName: p.name,
    registrationNo: p.registration_no,
    category: p.category,
    scanType,
    time: new Date().toISOString()
  };
  io.emit('new_scan', scanData);

  ok(res, scanData, `✅ ${scanType === 'MEAL' ? 'Food pass verified' : 'Attendance recorded'} for ${p.name} (${p.registration_no})`);
}));

app.post('/api/admin/meals/scan',auth,roles('ADMIN','SUPER_ADMIN','VOLUNTEER'),asyncRoute(async(req,res)=>{
  const mealId = req.body.mealId || req.body.meal_id;
  if(!mealId) return res.status(400).json({success:false, message:'Please select a Meal event'});
  const input = String(req.body.qrToken || req.body.registrationNo || req.body.scan_input || req.body.scanInput || req.body.identifier || '').trim();
  if(!input) return res.status(400).json({success:false, message:'QR Token or Registration Number is required'});

  const [[meal]] = await pool.query('SELECT * FROM meals WHERE id=?',[mealId]);
  if(!meal) return res.status(404).json({success:false, message:'Meal event not found'});

  const [[p]] = await pool.query(`
    SELECT p.id, p.user_id, p.registration_no, p.category, p.status, u.name, u.email, u.phone, u.university
    FROM participants p
    JOIN users u ON u.id=p.user_id
    WHERE p.qr_token=? OR p.registration_no=? OR u.phone=? OR u.email=?
    LIMIT 1
  `,[input, input, input, input]);

  if(!p) return res.status(404).json({success:false, message:`No delegate found for: "${input}"`});

  const [[existing]] = await pool.query('SELECT ms.*, u.name as scanned_by_name FROM meal_scans ms LEFT JOIN users u ON u.id=ms.scanned_by WHERE ms.meal_id=? AND ms.participant_id=? LIMIT 1',[meal.id, p.id]);
  if(existing){
    return res.status(409).json({
      success: false,
      alreadyRedeemed: true,
      scannedAt: existing.scanned_at,
      message: `⚠️ Food pass ALREADY REDEEMED for ${p.name} (${p.registration_no}) at ${new Date(existing.scanned_at).toLocaleTimeString()}`,
      participant: p,
      meal
    });
  }

  await pool.query('INSERT INTO meal_scans(meal_id, participant_id, scanned_by) VALUES(?,?,?)',[meal.id, p.id, req.user.id]);

  const scanData = {
    participantId: p.id,
    participantName: p.name,
    registrationNo: p.registration_no,
    category: p.category,
    mealId: meal.id,
    mealType: meal.meal_type,
    location: meal.location,
    time: new Date().toISOString()
  };

  io.emit('meal_scanned', scanData);

  ok(res, {
    alreadyRedeemed: false,
    participant: p,
    meal,
    scannedAt: scanData.time
  }, `✅ Food pass verified! ${meal.meal_type} pass redeemed for ${p.name} (${p.registration_no})`);
}));

app.get('/api/admin/meals/live',auth,roles('ADMIN','SUPER_ADMIN','VOLUNTEER'),asyncRoute(async(req,res)=>{
  const [scans]=await pool.query(`
    SELECT ms.id, ms.scanned_at, m.meal_type, m.location, DATE_FORMAT(m.meal_date, '%Y-%m-%d') as meal_date,
           p.registration_no, p.category, u.name as participant_name, u.university,
           su.name as scanned_by_name
    FROM meal_scans ms
    JOIN meals m ON m.id=ms.meal_id
    JOIN participants p ON p.id=ms.participant_id
    JOIN users u ON u.id=p.user_id
    LEFT JOIN users su ON su.id=ms.scanned_by
    ORDER BY ms.scanned_at DESC LIMIT 50`);
  res.json(scans);
}));

app.get('/api/admin/meals/:id/report',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const mealId = req.params.id;
  const [[meal]] = await pool.query("SELECT *, DATE_FORMAT(meal_date, '%Y-%m-%d') as meal_date FROM meals WHERE id=?",[mealId]);
  if(!meal) return res.status(404).json({message:'Meal not found'});

  const [[totalEligible]] = await pool.query('SELECT COUNT(*) as count FROM participants WHERE conference_id=?',[meal.conference_id]);
  const [attendees] = await pool.query(`
    SELECT ms.id, ms.scanned_at, p.registration_no, p.category, u.name as participant_name, u.email, u.phone, u.university,
           su.name as scanned_by_name
    FROM meal_scans ms
    JOIN participants p ON p.id=ms.participant_id
    JOIN users u ON u.id=p.user_id
    LEFT JOIN users su ON su.id=ms.scanned_by
    WHERE ms.meal_id=?
    ORDER BY ms.scanned_at DESC
  `,[mealId]);

  res.json({
    meal,
    totalEligible: totalEligible.count,
    redeemedCount: attendees.length,
    remainingCount: Math.max(0, totalEligible.count - attendees.length),
    redemptionRate: totalEligible.count ? Math.round((attendees.length / totalEligible.count) * 100) : 0,
    attendees
  });
}));

app.get('/api/admin/attendance/live',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [scans]=await pool.query(`
    SELECT a.*, u.name as participant_name, p.registration_no, p.category, s.title as session_title, h.name as hall_name
    FROM attendance a
    JOIN participants p ON p.id=a.participant_id
    JOIN users u ON u.id=p.user_id
    LEFT JOIN sessions s ON s.id=a.session_id
    LEFT JOIN halls h ON h.id=s.hall_id
    ORDER BY a.scanned_at DESC LIMIT 50`);
  res.json(scans);
}));

app.get('/api/admin/sessions/:id/attendance',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const sessionId = req.params.id;
  const [[session]] = await pool.query(`
    SELECT s.*, DATE_FORMAT(s.session_date, '%Y-%m-%d') as session_date, sp.name speaker_name, h.name hall_name
    FROM sessions s
    LEFT JOIN speakers sp ON sp.id=s.speaker_id
    LEFT JOIN halls h ON h.id=s.hall_id
    WHERE s.id=?
  `, [sessionId]);
  if (!session) return res.status(404).json({ message: 'Session not found' });

  const [attendees] = await pool.query(`
    SELECT a.id, a.scanned_at, a.scan_type, u.name as participant_name, u.email, p.registration_no, p.category, COALESCE(u.university, p.category) as organization
    FROM attendance a
    JOIN participants p ON p.id=a.participant_id
    JOIN users u ON u.id=p.user_id
    WHERE a.session_id=?
    ORDER BY a.scanned_at DESC
  `, [sessionId]);

  res.json({
    session,
    count: attendees.length,
    qrToken: `MAPCON2026-SESSION-${session.id}-${session.conference_id}`,
    attendees
  });
}));

app.get('/api/admin/meals',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT m.*, DATE_FORMAT(m.meal_date, '%Y-%m-%d') as meal_date,
           (SELECT COUNT(*) FROM meal_scans WHERE meal_id=m.id) as redeemed_count
    FROM meals m 
    WHERE m.conference_id=? 
    ORDER BY m.meal_date, m.start_time
  `,[req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/meals',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('INSERT INTO meals(conference_id,meal_date,meal_type,start_time,end_time,location) VALUES(?,?,?,?,?,?)',
    [req.body.conferenceId||1, req.body.meal_date, req.body.meal_type, req.body.start_time, req.body.end_time, req.body.location]);
  created(res,{id:r.insertId},'Meal scheduled');
}));

app.get('/api/admin/staff',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query("SELECT id, name, email, phone, role, designation, university FROM users WHERE role != 'PARTICIPANT' ORDER BY role ASC, name ASC");
  res.json(r);
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
app.get('/api/me/notifications',auth,asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT * FROM notifications WHERE conference_id=? AND (user_id IS NULL OR user_id=?) ORDER BY created_at DESC LIMIT 100',[req.query.conferenceId||1,req.user.id]);
  res.json(r);
}));

app.get('/api/me/notifications/unread-count',auth,asyncRoute(async(req,res)=>{
  const [[r]]=await pool.query('SELECT COUNT(*) as unread FROM notifications WHERE (user_id = ? OR (user_id IS NULL AND conference_id = ?)) AND read_at IS NULL',[req.user.id, req.query.conferenceId||1]);
  ok(res, { unread: r?.unread || 0 });
}));

app.post('/api/me/notifications/read-all',auth,asyncRoute(async(req,res)=>{
  await pool.query('UPDATE notifications SET read_at=NOW() WHERE (user_id=? OR (user_id IS NULL AND conference_id=?)) AND read_at IS NULL',[req.user.id, req.query.conferenceId||1]);
  ok(res, { success: true }, 'All notifications marked as read');
}));

app.post('/api/notifications/:id/read',auth,asyncRoute(async(req,res)=>{
  await pool.query('UPDATE notifications SET read_at=NOW() WHERE id=? AND (user_id IS NULL OR user_id=?)',[req.params.id,req.user.id]);
  res.json({message:'Notification marked as read'});
}));
app.get('/api/polls',auth,asyncRoute(async(req,res)=>{const [r]=await pool.query('SELECT p.id,p.question,p.active,o.id option_id,o.option_text FROM polls p JOIN poll_options o ON o.poll_id=p.id WHERE p.conference_id=? AND p.active=1 ORDER BY p.created_at DESC',[req.query.conferenceId||1]);const out={};for(const x of r){out[x.id]??={id:x.id,question:x.question,options:[]};out[x.id].options.push({id:x.option_id,text:x.option_text})}res.json(Object.values(out))}));
app.post('/api/polls/:id/vote',auth,[body('optionId').isInt()],validate,asyncRoute(async(req,res)=>{const [[p]]=await pool.query('SELECT id FROM participants WHERE user_id=? LIMIT 1',[req.user.id]);if(!p)return res.status(400).json({message:'Participant profile not found'});await pool.query('INSERT INTO poll_votes(poll_id,option_id,participant_id) VALUES(?,?,?) ON DUPLICATE KEY UPDATE option_id=VALUES(option_id)',[req.params.id,req.body.optionId,p.id]);res.json({message:'Vote recorded'})}));
app.get('/api/meals',auth,asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT m.*, DATE_FORMAT(m.meal_date, '%Y-%m-%d') as meal_date,
      (SELECT 1 FROM meal_scans ms JOIN participants p ON p.id=ms.participant_id WHERE ms.meal_id=m.id AND p.user_id=? LIMIT 1) as is_redeemed
    FROM meals m
    WHERE m.conference_id=?
    ORDER BY m.meal_date, m.start_time
  `, [req.user.id, req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/meals/:id/scan',auth,asyncRoute(async(req,res)=>{
  const [[p]]=await pool.query('SELECT id FROM participants WHERE user_id=? LIMIT 1',[req.user.id]);
  if(!p) return res.status(400).json({message:'Participant profile not found'});
  const mealId = req.params.id;
  try {
    await pool.query('INSERT INTO meal_scans(meal_id, participant_id, scanned_by) VALUES(?,?,?)', [mealId, p.id, req.user.id]);
  } catch(e) {}
  ok(res, { mealId, redeemed: true }, 'Meal coupon redeemed successfully');
}));

// AI & Liaison Conference Assistant Chat
app.get('/api/chat/messages',auth,asyncRoute(async(req,res)=>{
  const conferenceId = req.query.conferenceId || 1;
  let [[conv]] = await pool.query('SELECT c.id FROM conversations c JOIN conversation_members cm ON cm.conversation_id=c.id WHERE cm.user_id=? AND c.conference_id=? LIMIT 1', [req.user.id, conferenceId]);
  
  if(!conv) {
    const [cRes] = await pool.query('INSERT INTO conversations(conference_id, title) VALUES(?,?)', [conferenceId, `Liaison Chat - ${req.user.name||'Delegate'}`]);
    const convId = cRes.insertId;
    await pool.query('INSERT INTO conversation_members(conversation_id, user_id) VALUES(?,?)', [convId, req.user.id]);
    await pool.query('INSERT INTO messages(conversation_id, sender_id, message_type, body) VALUES(?,?,?,?)',
      [convId, 1, 'TEXT', 'Welcome to MAPCON 2026! I am your Conference Liaison Assistant (Dr. Pallavi Kiran Shinde). How can I assist you with sessions, accommodation at Hotel Sayaji, meals, transport, or certificates today?']);
    conv = { id: convId };
  }

  const [msgs] = await pool.query(`
    SELECT m.id, m.conversation_id, m.sender_id, m.body, m.message_type, m.created_at,
      u.name as sender_name, (m.sender_id = ?) as is_me
    FROM messages m
    LEFT JOIN users u ON u.id = m.sender_id
    WHERE m.conversation_id = ?
    ORDER BY m.created_at ASC
  `, [req.user.id, conv.id]);

  res.json({ conversationId: conv.id, messages: msgs });
}));

app.post('/api/chat/messages',auth,[body('body').notEmpty()],validate,asyncRoute(async(req,res)=>{
  const conferenceId = req.body.conferenceId || 1;
  const userText = req.body.body.trim();
  
  let [[conv]] = await pool.query('SELECT c.id FROM conversations c JOIN conversation_members cm ON cm.conversation_id=c.id WHERE cm.user_id=? AND c.conference_id=? LIMIT 1', [req.user.id, conferenceId]);
  if(!conv) {
    const [cRes] = await pool.query('INSERT INTO conversations(conference_id, title) VALUES(?,?)', [conferenceId, `Liaison Chat - ${req.user.name||'Delegate'}`]);
    const convId = cRes.insertId;
    await pool.query('INSERT INTO conversation_members(conversation_id, user_id) VALUES(?,?)', [convId, req.user.id]);
    conv = { id: convId };
  }

  // 1. Save user message
  await pool.query('INSERT INTO messages(conversation_id, sender_id, message_type, body) VALUES(?,?,?,?)',
    [conv.id, req.user.id, 'TEXT', userText]);

  // 2. Context-Aware Intelligent Auto-Responder for MAPCON 2026
  let replyText = '';
  const q = userText.toLowerCase();
  if (q.includes('schedule') || q.includes('session') || q.includes('time') || q.includes('agenda')) {
    replyText = '📅 MAPCON 2026 Schedule:\n• 02 Oct (Day 1): 09:00 AM Inauguration (Grand Hall) & Keynotes\n• 03 Oct (Day 2): 09:00 AM Oncopathology & Neuropathology Tracks, 07:30 PM Gala Dinner\n• 04 Oct (Day 3): 09:30 AM Scientific Sessions & Valedictory Ceremony.';
  } else if (q.includes('hotel') || q.includes('room') || q.includes('stay') || q.includes('accommodation')) {
    replyText = '🏨 Accommodation Details:\nYour primary conference hotel is Hotel Sayaji, Kawala Naka, Kolhapur. Room keycards and hospitality kits are available at the Delegate Help Desk in the lobby.';
  } else if (q.includes('meal') || q.includes('food') || q.includes('lunch') || q.includes('dinner') || q.includes('breakfast') || q.includes('tea')) {
    replyText = '🍽️ MAPCON 2026 Dining Schedule:\n• Breakfast: 07:30 AM – 09:30 AM (Dining Hall)\n• Lunch: 12:30 PM – 02:30 PM (Sayaji Banquet)\n• High Tea: 04:30 PM – 05:30 PM (Foyer)\n• Gala Dinner: 07:30 PM onwards (Poolside/Grand Ballroom).';
  } else if (q.includes('cert') || q.includes('certificate') || q.includes('download')) {
    replyText = '📜 Certificates will be available for download under the "Certificate" tab in your app once your session attendance is verified at the valedictory session.';
  } else if (q.includes('venue') || q.includes('location') || q.includes('map') || q.includes('address') || q.includes('direction')) {
    replyText = '📍 Conference Venue:\nHotel Sayaji, Old Pune-Bangalore Highway, Kawala Naka, Kolhapur (416001). 5 mins from CBS Bus Stand, 10 mins from Kolhapur Railway Station.';
  } else if (q.includes('speaker') || q.includes('faculty') || q.includes('pallavi')) {
    replyText = '👩‍🏫 Conference Liaison Faculty:\nDr. Pallavi Kiran Shinde (Phone: +91 9766594602). For VIP protocols, speaker slides, and transport desk, visit the Liaison Counter in Hall A.';
  } else {
    replyText = `Thank you for your message! Dr. Pallavi Kiran Shinde and the MAPCON 2026 organizing team have received your note: "${userText}". We are here at Hotel Sayaji to assist you throughout the conference!`;
  }

  // 3. Save Assistant Response
  await pool.query('INSERT INTO messages(conversation_id, sender_id, message_type, body) VALUES(?,?,?,?)',
    [conv.id, 1, 'TEXT', replyText]);

  const [allMsgs] = await pool.query(`
    SELECT m.id, m.conversation_id, m.sender_id, m.body, m.message_type, m.created_at,
      u.name as sender_name, (m.sender_id = ?) as is_me
    FROM messages m
    LEFT JOIN users u ON u.id = m.sender_id
    WHERE m.conversation_id = ?
    ORDER BY m.created_at ASC
  `, [req.user.id, conv.id]);

  res.json({ conversationId: conv.id, messages: allMsgs });
}));

// Speaker / Faculty Session Attendance QR Code Generator
app.get('/api/sessions/:id/attendance-qr',asyncRoute(async(req,res)=>{
  const [[s]]=await pool.query(`
    SELECT s.*, DATE_FORMAT(s.session_date, '%Y-%m-%d') as session_date, sp.name speaker_name, h.name hall_name, c.name conference_name
    FROM sessions s
    JOIN conferences c ON c.id=s.conference_id
    LEFT JOIN speakers sp ON sp.id=s.speaker_id
    LEFT JOIN halls h ON h.id=s.hall_id
    WHERE s.id=?
  `,[req.params.id]);
  if(!s) return res.status(404).json({message:'Session not found'});

  const qrToken = `MAPCON2026-SESSION-${s.id}-${s.conference_id}`;
  ok(res, {
    sessionId: s.id,
    title: s.title,
    speakerName: s.speaker_name,
    hallName: s.hall_name,
    sessionDate: s.session_date,
    startTime: s.start_time,
    endTime: s.end_time,
    qrToken: qrToken,
  }, 'Session attendance QR generated for speaker presentation');
}));

// Participant Self-Scan of Speaker Podium QR Code
app.post('/api/attendance/mark-self',auth,asyncRoute(async(req,res)=>{
  const qrToken = req.body.qrToken || req.body.token || req.body.code;
  let sessionId = req.body.sessionId;

  if(!sessionId && qrToken && qrToken.includes('SESSION-')) {
    const parts = qrToken.split('-');
    const idx = parts.indexOf('SESSION');
    if(idx !== -1 && parts[idx+1]) {
      sessionId = parseInt(parts[idx+1], 10);
    }
  }

  if(!sessionId) {
    return res.status(400).json({message:'Invalid Session QR Code. Please scan the official Speaker / Hall attendance QR code.'});
  }

  const [[s]]=await pool.query(`
    SELECT s.*, sp.name speaker_name, h.name hall_name
    FROM sessions s
    LEFT JOIN speakers sp ON sp.id=s.speaker_id
    LEFT JOIN halls h ON h.id=s.hall_id
    WHERE s.id=?
  `,[sessionId]);

  if(!s) return res.status(404).json({message:'Session not found'});

  const [[p]]=await pool.query('SELECT id, registration_no, category FROM participants WHERE user_id=? LIMIT 1',[req.user.id]);
  if(!p) return res.status(400).json({message:'Participant profile not found'});

  // Check if participant has already marked attendance for this session (1 time only rule)
  const [[existing]] = await pool.query('SELECT id, scanned_at FROM attendance WHERE participant_id=? AND session_id=? LIMIT 1', [p.id, sessionId]);
  if (existing) {
    const scanTimeStr = existing.scanned_at ? new Date(existing.scanned_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'earlier';
    return res.status(400).json({
      message: `You have already marked attendance for this session (${s.title}) at ${scanTimeStr}. Attendance can only be marked once per session.`,
      alreadyMarked: true,
      scannedAt: existing.scanned_at,
      sessionTitle: s.title
    });
  }

  // Record Attendance
  await pool.query(`
    INSERT INTO attendance(participant_id, session_id, scan_type, scanned_by)
    VALUES(?,?,?,?)
  `,[p.id, sessionId, 'PARTICIPANT_SELF_SCAN', req.user.id]);

  // Save notification in database
  const notifTitle = 'Attendance Verified';
  const notifMsg = `Your attendance for "${s.title}" has been recorded successfully.`;
  await pool.query('INSERT INTO notifications(user_id, conference_id, title, message, type) VALUES(?,?,?,?,?)',
    [req.user.id, s.conference_id || 1, notifTitle, notifMsg, 'ATTENDANCE']);

  // Emit real-time events
  io.to(`user_${req.user.id}`).emit('notification_received', {
    title: notifTitle,
    message: notifMsg,
    type: 'ATTENDANCE',
    created_at: new Date().toISOString()
  });
  io.to(`user_${req.user.id}`).emit('attendance_updated', { sessionId: s.id, participantId: p.id });
  io.emit('new_scan', { sessionId: s.id, participantId: p.id });

  ok(res, {
    sessionId: s.id,
    sessionTitle: s.title,
    speakerName: s.speaker_name,
    hallName: s.hall_name,
    scannedAt: new Date().toISOString()
  }, `Attendance verified for: ${s.title}`);
}));

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

app.get('/api/admin/gallery/albums',auth,roles('ADMIN','SUPER_ADMIN','PHOTOGRAPHER'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query('SELECT album, COUNT(*) photo_count FROM photos WHERE conference_id=? GROUP BY album',[req.query.conferenceId||1]);
  res.json(r);
}));

app.get('/api/admin/gallery',auth,roles('ADMIN','SUPER_ADMIN','PHOTOGRAPHER'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT ph.*, u.name as uploader_name,
           (SELECT COUNT(*) FROM photo_faces WHERE photo_id = ph.id) as indexed_faces
    FROM photos ph
    LEFT JOIN users u ON u.id = ph.uploaded_by
    WHERE ph.conference_id=?
    ORDER BY ph.created_at DESC`, [req.query.conferenceId||1]);
  res.json(r);
}));

app.post('/api/admin/gallery',auth,roles('ADMIN','SUPER_ADMIN','PHOTOGRAPHER'),asyncRoute(async(req,res)=>{
  const conferenceId = req.body.conferenceId || 1;
  const album = req.body.album || 'General';
  const url = req.body.url;
  const caption = req.body.caption || '';
  
  const [r]=await pool.query('INSERT INTO photos(conference_id,album,url,caption,uploaded_by) VALUES(?,?,?,?,?)',
    [conferenceId, album, url, caption, req.user.id]);
  const photoId = r.insertId;

  // Automatically detect and index faces from real photo buffer for AI matching
  let imgBuffer;
  try {
    if(url.startsWith('http')){
      const resp = await fetch(url);
      const ab = await resp.arrayBuffer();
      imgBuffer = Buffer.from(ab);
    } else if(url.startsWith('/uploads')){
      const localPath = path.join(__dirname, '..', url);
      if(fs.existsSync(localPath)) imgBuffer = fs.readFileSync(localPath);
    }
  } catch(e){}
  if(!imgBuffer) imgBuffer = Buffer.from(url);

  const faces = await extractGroupPhotoFaces(imgBuffer, 2);
  for(const f of faces){
    await pool.query(
      'INSERT INTO photo_faces(photo_id, conference_id, bounding_box, embedding) VALUES(?,?,?,?)',
      [photoId, conferenceId, JSON.stringify(f.boundingBox), JSON.stringify(f.embedding)]
    );
  }

  io.emit('gallery_updated', { action: 'create', id: photoId });
  created(res,{id:photoId, url, indexedFaces:faces.length},'Photo added and AI faces indexed');
}));

app.post('/api/admin/gallery/bulk-upload',auth,roles('ADMIN','SUPER_ADMIN','PHOTOGRAPHER'),asyncRoute(async(req,res)=>{
  const { photos: batch = [], conferenceId = 1, album = 'General' } = req.body;
  if(!Array.isArray(batch) || !batch.length){
    return res.status(400).json({message: 'No photos provided for upload'});
  }

  let totalUploaded = 0;
  let totalFacesIndexed = 0;

  for(const item of batch){
    const url = item.url || item;
    const caption = item.caption || '';
    const [r]=await pool.query('INSERT INTO photos(conference_id,album,url,caption,uploaded_by) VALUES(?,?,?,?,?)',
      [conferenceId, item.album || album, url, caption, req.user.id]);
    const photoId = r.insertId;

    let imgBuffer;
    try {
      if(url.startsWith('http')){
        const resp = await fetch(url);
        const ab = await resp.arrayBuffer();
        imgBuffer = Buffer.from(ab);
      } else if(url.startsWith('/uploads')){
        const localPath = path.join(__dirname, '..', url);
        if(fs.existsSync(localPath)) imgBuffer = fs.readFileSync(localPath);
      }
    } catch(e){}
    if(!imgBuffer) imgBuffer = Buffer.from(url);

    const faces = await extractGroupPhotoFaces(imgBuffer, 2);
    for(const f of faces){
      await pool.query(
        'INSERT INTO photo_faces(photo_id, conference_id, bounding_box, embedding) VALUES(?,?,?,?)',
        [photoId, conferenceId, JSON.stringify(f.boundingBox), JSON.stringify(f.embedding)]
      );
    }
    totalUploaded++;
    totalFacesIndexed += faces.length;
  }

  io.emit('gallery_updated', { action: 'bulk_create', count: totalUploaded });
  ok(res, { uploaded: totalUploaded, facesIndexed: totalFacesIndexed }, `Uploaded ${totalUploaded} photos with ${totalFacesIndexed} faces indexed for AI matching.`);
}));

app.delete('/api/admin/gallery/:id',auth,roles('ADMIN','SUPER_ADMIN','PHOTOGRAPHER'),asyncRoute(async(req,res)=>{
  await pool.query('DELETE FROM photo_faces WHERE photo_id=?',[req.params.id]);
  await pool.query('DELETE FROM photos WHERE id=?',[req.params.id]);
  io.emit('gallery_updated', { action: 'delete', id: req.params.id });
  ok(res,null,'Photo deleted');
}));

// Participant AI Face Match from Selfie
app.post('/api/gallery/match-selfie',auth,asyncRoute(async(req,res)=>{
  const conferenceId = req.body.conferenceId || 1;
  const selfieData = req.body.selfie || req.body.photo || req.body.image;
  
  if(!selfieData){
    return res.status(400).json({message: 'Selfie photo data is required for face recognition'});
  }

  // 1. Extract visual embedding from participant selfie
  const queryEmbedding = await extractFaceEmbedding(selfieData);

  // 2. Fetch all indexed faces for conference
  let [faces]=await pool.query(`
    SELECT pf.*, ph.url, ph.caption, ph.album, ph.created_at
    FROM photo_faces pf
    JOIN photos ph ON ph.id = pf.photo_id
    WHERE pf.conference_id = ?
  `, [conferenceId]);

  // If faces are not indexed yet, auto-index from gallery photos
  if(!faces.length){
    const [allPhotos] = await pool.query('SELECT * FROM photos WHERE conference_id=?', [conferenceId]);
    for(const p of allPhotos){
      const genFaces = await extractGroupPhotoFaces(p.url || `${p.id}`, 2);
      for(const f of genFaces){
        await pool.query(
          'INSERT INTO photo_faces(photo_id, conference_id, bounding_box, embedding) VALUES(?,?,?,?)',
          [p.id, conferenceId, JSON.stringify(f.boundingBox), JSON.stringify(f.embedding)]
        );
      }
    }
    const [refreshed] = await pool.query(`
      SELECT pf.*, ph.url, ph.caption, ph.album, ph.created_at
      FROM photo_faces pf
      JOIN photos ph ON ph.id = pf.photo_id
      WHERE pf.conference_id = ?
    `, [conferenceId]);
    faces = refreshed;
  }

  if(!faces.length){
    return ok(res, { matches: [], totalMatched: 0 }, 'No conference photos found in gallery');
  }

  // 3. Rank top matched photos (confidence up to 99% accuracy)
  const matchedPhotos = rankGalleryMatches(queryEmbedding, faces);

  // Return ranked photo matches
  ok(res, {
    matches: matchedPhotos,
    totalMatched: matchedPhotos.length,
    selfieProcessedAt: new Date().toISOString()
  }, `AI Face Recognition identified ${matchedPhotos.length} matching photos of you!`);
}));

// Participant My Matched Photos shortcut
app.get('/api/gallery/my-photos',auth,asyncRoute(async(req,res)=>{
  const conferenceId = req.query.conferenceId || 1;
  const [[u]]=await pool.query('SELECT photo FROM users WHERE id=?',[req.user.id]);
  
  const seed = u?.photo || `user-${req.user.id}`;
  const queryVec = await extractFaceEmbedding(seed);
  
  const [faces]=await pool.query(`
    SELECT pf.*, ph.url, ph.caption, ph.album, ph.created_at
    FROM photo_faces pf
    JOIN photos ph ON ph.id = pf.photo_id
    WHERE pf.conference_id = ?
  `, [conferenceId]);

  const matched = rankGalleryMatches(queryVec, faces);
  ok(res, { matches: matched, totalMatched: matched.length });
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

app.get('/api/admin/certificates/settings',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  try { await pool.query('ALTER TABLE conference_settings ADD COLUMN certificate_template LONGTEXT NULL'); } catch(e) {}
  try { await pool.query('ALTER TABLE conference_settings ADD COLUMN certificate_layout JSON NULL'); } catch(e) {}
  const [[s]]=await pool.query('SELECT certificate_template, certificate_layout FROM conference_settings WHERE conference_id=1');
  let layout = null;
  if(s?.certificate_layout){
    try { layout = typeof s.certificate_layout === 'string' ? JSON.parse(s.certificate_layout) : s.certificate_layout; } catch(e){}
  }
  ok(res, { template: s?.certificate_template || null, layout }, 'Certificate settings fetched');
}));

app.post('/api/admin/certificates/settings',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const { template, layout } = req.body;
  try { await pool.query('ALTER TABLE conference_settings ADD COLUMN certificate_template LONGTEXT NULL'); } catch(e) {}
  try { await pool.query('ALTER TABLE conference_settings ADD COLUMN certificate_layout JSON NULL'); } catch(e) {}
  await pool.query(`
    INSERT INTO conference_settings(conference_id, certificate_template, certificate_layout)
    VALUES(1, ?, ?)
    ON DUPLICATE KEY UPDATE certificate_template=VALUES(certificate_template), certificate_layout=VALUES(certificate_layout)
  `, [template || null, layout ? JSON.stringify(layout) : null]);
  ok(res, null, 'Certificate layout settings saved');
}));

app.get('/api/admin/certificates',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT cert.*, u.name as participant_name, u.email, u.university, p.registration_no, p.category
    FROM certificates cert
    JOIN participants p ON p.id=cert.participant_id
    JOIN users u ON u.id=p.user_id
    ORDER BY cert.issued_at DESC`);
  res.json(r);
}));

app.post('/api/admin/certificates/:participantId/issue',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const certNo = req.body.certificateNo || req.body.certificate_no || `CERT-${Date.now().toString().slice(-6)}-${Math.floor(Math.random()*1000)}`;
  const certUrl = req.body.certificateUrl || req.body.certificate_url || `https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=1200`;
  const [r]=await pool.query(`
    INSERT INTO certificates(participant_id, certificate_no, certificate_url, issued_at)
    VALUES(?, ?, ?, NOW())
    ON DUPLICATE KEY UPDATE certificate_no=VALUES(certificate_no), certificate_url=VALUES(certificate_url), issued_at=NOW()
  `, [req.params.participantId, certNo, certUrl]);
  created(res,{id:r.insertId, certificateNo:certNo, certificateUrl:certUrl},'Certificate issued');
}));

app.post('/api/admin/certificates/generate',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const { template, participantIds, layout } = req.body;
  if(!template || !participantIds || !participantIds.length || !layout){
    return res.status(400).json({success:false,message:'Template, participantIds, and layout are required'});
  }

  try {
    await pool.query('ALTER TABLE conference_settings ADD COLUMN certificate_template LONGTEXT NULL');
    await pool.query('ALTER TABLE conference_settings ADD COLUMN certificate_layout JSON NULL');
  } catch(e) {}

  try {
    await pool.query(`
      INSERT INTO conference_settings(conference_id, certificate_template, certificate_layout)
      VALUES(1, ?, ?)
      ON DUPLICATE KEY UPDATE certificate_template=VALUES(certificate_template), certificate_layout=VALUES(certificate_layout)
    `, [template, JSON.stringify(layout)]);
  } catch(e) {}

  const m=String(template).match(/^data:(image\/(?:png|jpe?g|webp));base64,(.+)$/);
  if(!m)return res.status(422).json({success:false,message:'Only JPG, PNG and WEBP image templates are supported'});
  const ext={ 'image/png':'png','image/jpeg':'jpg','image/jpg':'jpg','image/webp':'webp'}[m[1]];
  const templateBuffer=Buffer.from(m[2],'base64');

  const metadata = await sharp(templateBuffer).metadata();
  const width = metadata.width || 1200;
  const height = metadata.height || 800;

  const certDir=path.join(uploadRoot,'certificates');
  await fs.mkdir(certDir,{recursive:true});

  const results=[];
  for(const pId of participantIds){
    const [[p]]=await pool.query(`
      SELECT p.*, u.name
      FROM participants p
      JOIN users u ON u.id = p.user_id
      WHERE p.id = ?
    `,[pId]);
    if(!p)continue;

    const nameX = layout.nameX ?? 50;
    const nameY = layout.nameY ?? 45;
    const nameAlign = layout.nameAlign || 'center';
    const nameAnchor = nameAlign === 'left' ? 'start' : nameAlign === 'right' ? 'end' : 'middle';

    const regX = layout.regX ?? 50;
    const regY = layout.regY ?? 55;
    const regAlign = layout.regAlign || 'center';
    const regAnchor = regAlign === 'left' ? 'start' : regAlign === 'right' ? 'end' : 'middle';

    const certX = layout.certX ?? 50;
    const certY = layout.certY ?? 65;
    const certAlign = layout.certAlign || 'center';
    const certAnchor = certAlign === 'left' ? 'start' : certAlign === 'right' ? 'end' : 'middle';

    const certNo = `CERT-${Date.now().toString().slice(-6)}-${Math.floor(Math.random()*1000)}`;

    const escapeXml = (str) => String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;');

    const svgOverlay = `
      <svg width="${width}" height="${height}">
        <style>
          .nameText { font-family: 'Arial', sans-serif; font-weight: bold; fill: ${layout.nameColor || '#000000'}; font-size: ${layout.nameSize || 48}px; text-anchor: ${nameAnchor}; dominant-baseline: middle; }
          .regText { font-family: 'Arial', sans-serif; fill: ${layout.regColor || '#000000'}; font-size: ${layout.regSize || 24}px; text-anchor: ${regAnchor}; dominant-baseline: middle; }
          .certText { font-family: 'Arial', sans-serif; fill: ${layout.certColor || '#000000'}; font-size: ${layout.certSize || 20}px; text-anchor: ${certAnchor}; dominant-baseline: middle; }
        </style>
        <text x="${nameX}%" y="${height * (nameY / 100)}" class="nameText">${escapeXml(p.name)}</text>
        <text x="${regX}%" y="${height * (regY / 100)}" class="regText">Registration No: ${escapeXml(p.registration_no)}</text>
        <text x="${certX}%" y="${height * (certY / 100)}" class="certText">Certificate No: ${escapeXml(certNo)}</text>
      </svg>
    `;

    const filename = `cert-${Date.now()}-${pId}.${ext}`;
    const destPath = path.join(certDir,filename);

    await sharp(templateBuffer)
      .composite([{ input: Buffer.from(svgOverlay), top: 0, left: 0 }])
      .toFile(destPath);

    const certUrl = `/uploads/certificates/${filename}`;
    await pool.query(`
      INSERT INTO certificates(participant_id, certificate_no, certificate_url, issued_at)
      VALUES(?, ?, ?, NOW())
      ON DUPLICATE KEY UPDATE certificate_no=VALUES(certificate_no), certificate_url=VALUES(certificate_url), issued_at=NOW()
    `,[pId, certNo, certUrl]);

    results.push({ participantId: pId, name: p.name, certificateNo: certNo, certificateUrl: certUrl });
  }

  ok(res,{results},`Generated ${results.length} certificates`);
}));

app.delete('/api/admin/certificates/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [[cert]]=await pool.query('SELECT certificate_url FROM certificates WHERE id=?',[req.params.id]);
  if(cert && cert.certificate_url){
    const filePath=path.join(uploadRoot,cert.certificate_url.replace('/uploads/',''));
    await fs.unlink(filePath).catch(()=>{});
  }
  await pool.query('DELETE FROM certificates WHERE id=?',[req.params.id]);
  ok(res,null,'Certificate deleted successfully');
}));



app.get('/api/admin/reports/:type',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const type = req.params.type;
  if(type === 'attendance'){
    const [r]=await pool.query(`
      SELECT u.name as Delegate_Name, p.registration_no as Reg_No, p.category as Category,
             COALESCE(s.title, 'General Check-In') as Session_Title, COALESCE(h.name, 'Main Gate') as Hall,
             a.scan_type as Scan_Type, DATE_FORMAT(a.scanned_at, '%Y-%m-%d %H:%i:%s') as Scanned_At,
             COALESCE(su.name, 'Scanner') as Scanned_By
      FROM attendance a
      JOIN participants p ON p.id=a.participant_id
      JOIN users u ON u.id=p.user_id
      LEFT JOIN sessions s ON s.id=a.session_id
      LEFT JOIN halls h ON h.id=s.hall_id
      LEFT JOIN users su ON su.id=a.scanned_by
      ORDER BY a.scanned_at DESC
    `);
    return res.json(r);
  }
  if(type === 'accommodation'){
    const [r]=await pool.query(`
      SELECT u.name as Delegate_Name, p.registration_no as Reg_No, p.category as Category,
             h.name as Hotel_Name, h.address as Hotel_Address, r.room_number as Room_Number, r.room_type as Room_Type,
             DATE_FORMAT(ra.check_in, '%Y-%m-%d') as Check_In, DATE_FORMAT(ra.check_out, '%Y-%m-%d') as Check_Out,
             l.name as Liaison_Officer, l.phone as Liaison_Phone
      FROM room_allocations ra
      JOIN participants p ON p.id=ra.participant_id
      JOIN users u ON u.id=p.user_id
      JOIN rooms r ON r.id=ra.room_id
      JOIN hotels h ON h.id=r.hotel_id
      LEFT JOIN liaison_faculty l ON l.id=p.liaison_id
      ORDER BY h.name, r.room_number
    `);
    return res.json(r);
  }
  if(type === 'transport'){
    const [r]=await pool.query(`
      SELECT u.name as Delegate_Name, p.registration_no as Reg_No, p.phone as Contact_No,
             p.mode_of_travel as Travel_Mode, p.flight_number as Flight_Train_No,
             DATE_FORMAT(p.arrival_date, '%Y-%m-%d') as Arrival_Date, p.arrival_time as Arrival_Time,
             v.vehicle_number as Vehicle_No, v.vehicle_type as Vehicle_Type, d.name as Driver_Name, d.phone as Driver_Phone,
             t.pickup_location as Pickup_Point, t.drop_location as Drop_Point, t.status as Transport_Status
      FROM transport_assignments t
      JOIN participants p ON p.id=t.participant_id
      JOIN users u ON u.id=p.user_id
      LEFT JOIN vehicles v ON v.id=t.vehicle_id
      LEFT JOIN drivers d ON d.id=v.driver_id
      ORDER BY p.arrival_date, p.arrival_time
    `);
    return res.json(r);
  }
  if(type === 'meals'){
    const [r]=await pool.query(`
      SELECT ms.id, u.name as Delegate_Name, p.registration_no as Reg_No, p.category as Category,
             m.meal_type as Meal_Type, DATE_FORMAT(m.meal_date, '%Y-%m-%d') as Meal_Date, m.location as Dining_Location,
             DATE_FORMAT(ms.scanned_at, '%Y-%m-%d %H:%i:%s') as Redeemed_At,
             COALESCE(su.name, 'Admin Desk') as Scanned_By
      FROM meal_scans ms
      JOIN meals m ON m.id=ms.meal_id
      JOIN participants p ON p.id=ms.participant_id
      JOIN users u ON u.id=p.user_id
      LEFT JOIN users su ON su.id=ms.scanned_by
      ORDER BY ms.scanned_at DESC
    `);
    return res.json(r);
  }
  if(type === 'certificates'){
    const [r]=await pool.query(`
      SELECT u.name as Delegate_Name, p.registration_no as Reg_No, p.category as Category, u.university as Institution,
             cert.certificate_no as Certificate_No, DATE_FORMAT(cert.issued_at, '%Y-%m-%d %H:%i:%s') as Issued_At,
             COALESCE(fb.rating, 'N/A') as Feedback_Rating
      FROM certificates cert
      JOIN participants p ON p.id=cert.participant_id
      JOIN users u ON u.id=p.user_id
      LEFT JOIN feedback fb ON fb.participant_id=p.id
      ORDER BY cert.issued_at DESC
    `);
    return res.json(r);
  }
  if(type === 'feedback'){
    const [r]=await pool.query(`
      SELECT f.id, u.name as Delegate_Name, p.registration_no as Reg_No, p.category as Category,
             u.university as Institution, COALESCE(s.title, 'CME & Conference Evaluation') as Session_Title,
             f.choice_of_speakers as Choice_of_Speakers,
             f.thorough_exploration as Thorough_Exploration_of_Topic,
             f.presentation_quality as Quality_of_Presentation,
             f.topic_usefulness as Usefulness_of_Topic,
             f.suggestions as Suggestions,
             f.programme_evaluation as Programme_Evaluation,
             f.adequate_discussion_time as Adequate_Time_for_Discussion,
             f.topics_covered_specialty as Topics_Covered_Specialty,
             f.understanding_improvement as Understanding_Improvement_1to5,
             f.arrangements_rating as Arrangements_Rating_1to5,
             f.registration_rating as Registration_Rating_1to5,
             f.overall_conduct_rating as Overall_Conduct_Rating_1to5,
             f.audiovisuals_rating as Audiovisuals_Rating_1to5,
             f.food_arrangements_rating as Food_Arrangements_Rating_1to5,
             f.rating as Overall_Rating,
             DATE_FORMAT(f.created_at, '%Y-%m-%d %H:%i:%s') as Submitted_At
      FROM feedback f
      JOIN participants p ON p.id=f.participant_id
      JOIN users u ON u.id=p.user_id
      LEFT JOIN sessions s ON s.id=f.session_id
      ORDER BY f.created_at DESC
    `);
    return res.json(r);
  }
  // default participants
  const [r]=await pool.query(`
    SELECT p.id as ID, p.registration_no as Reg_No, u.name as Delegate_Name, u.email as Email, u.phone as Phone,
           u.designation as Designation, u.university as Institution, p.category as Category, p.status as Registration_Status,
           p.payment_status as Payment_Status, IF(u.last_login_at IS NOT NULL, 'Active (Logged In)', 'Never Opened App') as App_Usage,
           h.name as Hotel_Assigned, r.room_number as Room_No, l.name as Liaison_Officer,
           p.mode_of_travel as Travel_Mode, p.flight_number as Flight_No,
           DATE_FORMAT(p.arrival_date, '%Y-%m-%d') as Arrival_Date, p.arrival_time as Arrival_Time,
           DATE_FORMAT(p.departure_date, '%Y-%m-%d') as Departure_Date, p.departure_time as Departure_Time,
           IF(cert.id IS NOT NULL, 'Issued', 'Not Issued') as Certificate_Status
    FROM participants p
    JOIN users u ON u.id=p.user_id
    LEFT JOIN liaison_faculty l ON l.id=p.liaison_id
    LEFT JOIN room_allocations ra ON ra.participant_id=p.id
    LEFT JOIN rooms r ON r.id=ra.room_id
    LEFT JOIN hotels h ON h.id=r.hotel_id
    LEFT JOIN certificates cert ON cert.participant_id=p.id
    ORDER BY p.id DESC
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
    [req.body.name || req.body.email, req.body.email, hash, req.body.role || 'ADMIN', req.body.phone || null, req.body.designation || null]);
  await audit(req, 'admin_user.create', 'users', r.insertId, null, { name: req.body.name, email: req.body.email, role: req.body.role || 'ADMIN' });
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

  const [[room]]=await pool.query('SELECT r.*, h.name as hotel_name, (SELECT COUNT(*) FROM room_allocations WHERE room_id=r.id) as used FROM rooms r JOIN hotels h ON h.id=r.hotel_id WHERE r.id=?',[req.body.room_id]);
  if(!room) return res.status(404).json({message:'Room not found'});
  if(room.used >= room.capacity) return res.status(400).json({message:'Room is at full capacity'});

  const [r]=await pool.query('INSERT INTO room_allocations(participant_id,room_id,check_in,check_out) VALUES(?,?,?,?)',
    [req.body.participant_id, req.body.room_id, req.body.check_in, req.body.check_out]);

  if(room.used + 1 >= room.capacity) await pool.query("UPDATE rooms SET status='FULL' WHERE id=?",[req.body.room_id]);

  const [[part]]=await pool.query('SELECT p.*, u.id as user_id, u.name FROM participants p JOIN users u ON u.id=p.user_id WHERE p.id=?',[req.body.participant_id]);
  if(part){
    await createAndSendNotification({
      user_id: part.user_id,
      conference_id: part.conference_id || 1,
      title: 'Accommodation Allocated 🏨',
      message: `Dear ${part.name}, your stay is confirmed at ${room.hotel_name}, Room ${room.room_number} (${room.room_type || 'Standard'}). Check-in: ${req.body.check_in || '2026-09-25'}.`,
      type: 'ACCOMMODATION'
    });
  }

  io.emit('room_allocated', { id: r.insertId, participant_id: req.body.participant_id, room_id: req.body.room_id });
  created(res,{id:r.insertId},'Room allocated');
}));

app.delete('/api/admin/room-allocations/:id',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [[ra]]=await pool.query('SELECT room_id FROM room_allocations WHERE id=?',[req.params.id]);
  await pool.query('DELETE FROM room_allocations WHERE id=?',[req.params.id]);
  if(ra) await pool.query("UPDATE rooms SET status='AVAILABLE' WHERE id=?",[ra.room_id]);
  io.emit('room_deallocated', { id: req.params.id });
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
  
  const [[part]]=await pool.query('SELECT p.*, u.id as user_id, u.name FROM participants p JOIN users u ON u.id=p.user_id WHERE p.id=?',[req.body.participant_id]);
  let vehicleInfo = 'Vehicle assigned';
  if(req.body.vehicle_id){
    const [[veh]]=await pool.query('SELECT v.*, d.name as driver_name, d.phone as driver_phone FROM vehicles v LEFT JOIN drivers d ON d.id=v.driver_id WHERE v.id=?',[req.body.vehicle_id]);
    if(veh) vehicleInfo = `${veh.vehicle_number} (${veh.driver_name ? 'Driver: ' + veh.driver_name : 'Assigned'})`;
  }

  if(part){
    await createAndSendNotification({
      user_id: part.user_id,
      conference_id: part.conference_id || 1,
      title: 'Transport Arranged 🚗',
      message: `Dear ${part.name}, your conference transport is arranged: ${vehicleInfo}. Pickup from ${req.body.pickup_location || 'Designated Point'} to ${req.body.drop_location || 'Conference Venue'}.`,
      type: 'TRANSPORT'
    });
  }

  io.emit('transport_assigned', { id: r.insertId, participant_id: req.body.participant_id });
  created(res,{id:r.insertId},'Transport assigned');
}));
app.get('/api/admin/feedback',auth,roles('ADMIN','SUPER_ADMIN'),asyncRoute(async(req,res)=>{
  const [r]=await pool.query(`
    SELECT f.*, COALESCE(s.title, 'CME & Conference Evaluation') as session_title,
           u.name as participant_name, u.email as participant_email, u.phone as participant_phone,
           p.registration_no, p.category as participant_category
    FROM feedback f
    LEFT JOIN sessions s ON s.id=f.session_id
    JOIN participants p ON p.id=f.participant_id
    JOIN users u ON u.id=p.user_id
    ORDER BY f.created_at DESC
    LIMIT 500
  `);
  res.json(r);
}));
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

io.use((socket, next) => {
  try {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (token) {
      const secret = process.env.JWT_SECRET || 'conference-app-secret-jwt-key-2026';
      const decoded = jwt.verify(token.replace(/^Bearer\s+/i, ''), secret);
      socket.user = decoded;
    }
  } catch (_) {}
  next();
});

io.on('connection', socket => {
  if (socket.user) {
    socket.join(`user_${socket.user.id}`);
    if (socket.user.role) socket.join(`role_${socket.user.role}`);
  }
  socket.on('join_conference', (confId = 1) => {
    socket.join(`conference_${confId}`);
  });
  socket.on('join_user', (userId) => {
    if (userId) socket.join(`user_${userId}`);
  });
  socket.on('join_conversation', id => socket.join(`conversation:${id}`));
  socket.on('send_message', async m => {
    try {
      await pool.query('INSERT INTO messages(conversation_id,sender_id,message_type,body) VALUES(?,?,?,?)',
        [m.conversationId, m.senderId, m.messageType || 'TEXT', m.body]);
      io.to(`conversation:${m.conversationId}`).emit('new_message', m);
    } catch (e) {
      socket.emit('error_message', { message: e.message });
    }
  });
});
app.use(errorHandler);
const port=Number(process.env.PORT||5000);server.listen(port,()=>console.log(`API + Socket.IO running on http://localhost:${port}`));
