import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import { pool } from './db.js';
dotenv.config();
const adminHash=await bcrypt.hash('Admin@123',10); const userHash=await bcrypt.hash('Demo@123',10);
await pool.query(`INSERT INTO users(name,email,password_hash,phone,role,designation,university) VALUES
('Conference Administrator','admin@conference.local',?,'9999999999','SUPER_ADMIN','System Administrator','DPU'),
('Dr. Rakesh Kumar Sharma','participant@conference.local',?,'9820619211','PARTICIPANT','Vice Chancellor','D.Y. Patil University')
ON DUPLICATE KEY UPDATE password_hash=VALUES(password_hash)`,[adminHash,userHash]);
const [[u]]=await pool.query('SELECT id FROM users WHERE email=?',['participant@conference.local']);
await pool.query(`INSERT INTO participants(user_id,conference_id,registration_no,category,status,payment_status,amount,mode_of_travel,arrival_date,arrival_time,departure_date,departure_time,emergency_contact,liaison_id,qr_token)
VALUES(?,1,'DPU-0001','VC','APPROVED','PAID',0,'Road','2026-04-27','10:30:00','2026-04-30','18:00:00','9999999999',1,'DPU-QR-0001')
ON DUPLICATE KEY UPDATE registration_no=VALUES(registration_no)`,[u.id]);
const [[p]]=await pool.query('SELECT id FROM participants WHERE user_id=?',[u.id]);
await pool.query(`INSERT IGNORE INTO room_allocations(participant_id,room_id,check_in,check_out) VALUES(?,1,'2026-04-27','2026-04-30')`,[p.id]);
await pool.query(`INSERT IGNORE INTO transport_assignments(participant_id,vehicle_id,pickup_location,drop_location,pickup_time,status) VALUES(?,1,'Pune Airport','Hyatt Regency Pune','2026-04-27 10:30:00','ASSIGNED')`,[p.id]);
await pool.query(`INSERT IGNORE INTO certificates(participant_id,certificate_no,issued_at) VALUES(?, 'DPU-CERT-0001', NOW())`,[p.id]);
console.log('Seed complete'); await pool.end();
