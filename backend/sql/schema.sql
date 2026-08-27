CREATE DATABASE IF NOT EXISTS conference_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE conference_management;

SET FOREIGN_KEY_CHECKS=0;
DROP TABLE IF EXISTS audit_logs, emergency_contacts, messages, conversations, notifications, documents, certificates, poll_votes, poll_options, polls, feedback, meal_scans, meals, attendance, photos, notices, duty_assignments, duties, transport_assignments, vehicles, drivers, room_allocations, rooms, hotels, participants, liaison_faculty, sessions, halls, venues, speakers, conferences, users;
SET FOREIGN_KEY_CHECKS=1;

CREATE TABLE users (
 id INT AUTO_INCREMENT PRIMARY KEY,
 name VARCHAR(150) NOT NULL,
 email VARCHAR(190) NOT NULL UNIQUE,
 password_hash VARCHAR(255) NOT NULL,
 phone VARCHAR(30), role ENUM('SUPER_ADMIN','ADMIN','PARTICIPANT','SPEAKER','VOLUNTEER','LIAISON','TRANSPORT_ADMIN') DEFAULT 'PARTICIPANT',
 designation VARCHAR(150), university VARCHAR(200), blood_group VARCHAR(10), photo TEXT,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE conferences (
 id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255) NOT NULL, short_name VARCHAR(100), description TEXT,
 welcome_message TEXT, about_conference TEXT, start_date DATE, end_date DATE, registration_start_date DATE, registration_end_date DATE,
 contact_person VARCHAR(150), contact_phone VARCHAR(30), contact_email VARCHAR(190), website VARCHAR(255), organizer VARCHAR(255),
 host_institution VARCHAR(255), theme VARCHAR(150), status ENUM('DRAFT','PUBLISHED','ARCHIVED','ACTIVE','INACTIVE') DEFAULT 'ACTIVE',
 venue VARCHAR(255), address TEXT, banner_url TEXT, logo_url TEXT,
 active TINYINT(1) DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP
);
CREATE TABLE conference_settings (
 id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL UNIQUE,
 enable_registration TINYINT(1) DEFAULT 1, enable_chat TINYINT(1) DEFAULT 1, enable_gallery TINYINT(1) DEFAULT 1,
 enable_attendance TINYINT(1) DEFAULT 1, enable_qr TINYINT(1) DEFAULT 1, enable_push_notifications TINYINT(1) DEFAULT 0,
 enable_certificates TINYINT(1) DEFAULT 1, enable_polls TINYINT(1) DEFAULT 0, enable_feedback TINYINT(1) DEFAULT 1,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
 FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE
);
CREATE TABLE conference_branding (
 id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL UNIQUE,
 conference_logo TEXT, organizer_logo TEXT, banner TEXT, splash_screen TEXT, favicon TEXT,
 primary_color VARCHAR(20) DEFAULT '#8C1119', secondary_color VARCHAR(20) DEFAULT '#C8A45A',
 accent_color VARCHAR(20) DEFAULT '#2E6F95', background_color VARCHAR(20) DEFAULT '#FCFAF5',
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
 FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE
);
CREATE TABLE venues (id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL UNIQUE, name VARCHAR(150), address TEXT, city VARCHAR(100), state VARCHAR(100), country VARCHAR(100), pincode VARCHAR(20), latitude DECIMAL(10,7), longitude DECIMAL(10,7), google_maps_url TEXT, parking_information TEXT, directions TEXT, contact_number VARCHAR(30), FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE);
CREATE TABLE halls (id INT AUTO_INCREMENT PRIMARY KEY, venue_id INT NOT NULL, name VARCHAR(150), capacity INT, FOREIGN KEY(venue_id) REFERENCES venues(id) ON DELETE CASCADE);
CREATE TABLE speakers (id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL, user_id INT NULL, name VARCHAR(150), designation VARCHAR(200), organization VARCHAR(255), bio TEXT, photo TEXT, email VARCHAR(190), phone VARCHAR(30), FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL);
CREATE TABLE sessions (id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL, hall_id INT NULL, speaker_id INT NULL, title VARCHAR(255), description TEXT, session_date DATE, start_time TIME, end_time TIME, category VARCHAR(100), FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE, FOREIGN KEY(hall_id) REFERENCES halls(id) ON DELETE SET NULL, FOREIGN KEY(speaker_id) REFERENCES speakers(id) ON DELETE SET NULL);
CREATE TABLE liaison_faculty (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(150), phone VARCHAR(30), email VARCHAR(190));
CREATE TABLE participants (
 id INT AUTO_INCREMENT PRIMARY KEY, user_id INT UNIQUE NOT NULL, conference_id INT NOT NULL, registration_no VARCHAR(60) UNIQUE, category VARCHAR(100),
 status ENUM('PENDING','APPROVED','CHECKED_IN','CANCELLED') DEFAULT 'PENDING', payment_status ENUM('PENDING','PAID','REFUNDED') DEFAULT 'PENDING', amount DECIMAL(12,2) DEFAULT 0,
 mode_of_travel VARCHAR(50), flight_number VARCHAR(50), arrival_date DATE, arrival_time TIME, departure_date DATE, departure_time TIME,
 emergency_contact VARCHAR(100), liaison_id INT NULL, qr_token VARCHAR(120) UNIQUE,
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE, FOREIGN KEY(liaison_id) REFERENCES liaison_faculty(id) ON DELETE SET NULL
);
CREATE TABLE hotels (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(200), address TEXT, latitude DECIMAL(10,7), longitude DECIMAL(10,7));
CREATE TABLE rooms (id INT AUTO_INCREMENT PRIMARY KEY, hotel_id INT NOT NULL, room_number VARCHAR(30), room_type VARCHAR(50), capacity INT DEFAULT 1, status ENUM('AVAILABLE','FULL','MAINTENANCE') DEFAULT 'AVAILABLE', FOREIGN KEY(hotel_id) REFERENCES hotels(id) ON DELETE CASCADE, UNIQUE(hotel_id,room_number));
CREATE TABLE room_allocations (id INT AUTO_INCREMENT PRIMARY KEY, participant_id INT UNIQUE NOT NULL, room_id INT NOT NULL, check_in DATE, check_out DATE, FOREIGN KEY(participant_id) REFERENCES participants(id) ON DELETE CASCADE, FOREIGN KEY(room_id) REFERENCES rooms(id) ON DELETE CASCADE);
CREATE TABLE drivers (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(150), phone VARCHAR(30), license_no VARCHAR(80));
CREATE TABLE vehicles (id INT AUTO_INCREMENT PRIMARY KEY, driver_id INT NULL, vehicle_number VARCHAR(40) UNIQUE, vehicle_type VARCHAR(60), capacity INT, status ENUM('AVAILABLE','ASSIGNED','IN_TRANSIT','MAINTENANCE') DEFAULT 'AVAILABLE', FOREIGN KEY(driver_id) REFERENCES drivers(id) ON DELETE SET NULL);
CREATE TABLE transport_assignments (id INT AUTO_INCREMENT PRIMARY KEY, participant_id INT NOT NULL, vehicle_id INT NULL, pickup_location VARCHAR(255), drop_location VARCHAR(255), pickup_time DATETIME, status ENUM('ASSIGNED','STARTED','ARRIVING','PICKED_UP','COMPLETED','CANCELLED') DEFAULT 'ASSIGNED', notes TEXT, FOREIGN KEY(participant_id) REFERENCES participants(id) ON DELETE CASCADE, FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE SET NULL);
CREATE TABLE duties (id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL, title VARCHAR(255), location VARCHAR(255), duty_date DATE, start_time TIME, end_time TIME, supervisor VARCHAR(150), notes TEXT, FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE);
CREATE TABLE duty_assignments (id INT AUTO_INCREMENT PRIMARY KEY, duty_id INT NOT NULL, user_id INT NOT NULL, status VARCHAR(40) DEFAULT 'ASSIGNED', FOREIGN KEY(duty_id) REFERENCES duties(id) ON DELETE CASCADE, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, UNIQUE(duty_id,user_id));
CREATE TABLE notices (id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL, title VARCHAR(255), message TEXT, type VARCHAR(50) DEFAULT 'GENERAL', target_role VARCHAR(50), target_user_id INT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE, FOREIGN KEY(target_user_id) REFERENCES users(id) ON DELETE CASCADE);
CREATE TABLE photos (id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL, album VARCHAR(150), url TEXT, caption TEXT, uploaded_by INT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE, FOREIGN KEY(uploaded_by) REFERENCES users(id) ON DELETE SET NULL);
CREATE TABLE attendance (id BIGINT AUTO_INCREMENT PRIMARY KEY, participant_id INT NOT NULL, session_id INT NOT NULL, scan_type VARCHAR(30), scanned_by INT NULL, scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(participant_id) REFERENCES participants(id) ON DELETE CASCADE, FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE, FOREIGN KEY(scanned_by) REFERENCES users(id) ON DELETE SET NULL, INDEX(participant_id,session_id));
CREATE TABLE meals (id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL, meal_date DATE, meal_type ENUM('BREAKFAST','LUNCH','TEA','DINNER'), start_time TIME, end_time TIME, location VARCHAR(255), FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE);
CREATE TABLE meal_scans (id BIGINT AUTO_INCREMENT PRIMARY KEY, meal_id INT NOT NULL, participant_id INT NOT NULL, scanned_by INT NULL, scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE(meal_id,participant_id), FOREIGN KEY(meal_id) REFERENCES meals(id) ON DELETE CASCADE, FOREIGN KEY(participant_id) REFERENCES participants(id) ON DELETE CASCADE, FOREIGN KEY(scanned_by) REFERENCES users(id) ON DELETE SET NULL);
CREATE TABLE feedback (id BIGINT AUTO_INCREMENT PRIMARY KEY, participant_id INT NOT NULL, session_id INT NOT NULL, rating TINYINT NOT NULL, content_rating TINYINT, speaker_rating TINYINT, comment TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(participant_id) REFERENCES participants(id) ON DELETE CASCADE, FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE);
CREATE TABLE polls (id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL, question TEXT, active TINYINT(1) DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE);
CREATE TABLE poll_options (id INT AUTO_INCREMENT PRIMARY KEY, poll_id INT NOT NULL, option_text VARCHAR(255), FOREIGN KEY(poll_id) REFERENCES polls(id) ON DELETE CASCADE);
CREATE TABLE poll_votes (id BIGINT AUTO_INCREMENT PRIMARY KEY, poll_id INT NOT NULL, option_id INT NOT NULL, participant_id INT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE(poll_id,participant_id), FOREIGN KEY(poll_id) REFERENCES polls(id) ON DELETE CASCADE, FOREIGN KEY(option_id) REFERENCES poll_options(id) ON DELETE CASCADE, FOREIGN KEY(participant_id) REFERENCES participants(id) ON DELETE CASCADE);
CREATE TABLE certificates (id INT AUTO_INCREMENT PRIMARY KEY, participant_id INT NOT NULL, certificate_no VARCHAR(100) UNIQUE, certificate_url TEXT, issued_at TIMESTAMP NULL, FOREIGN KEY(participant_id) REFERENCES participants(id) ON DELETE CASCADE);
CREATE TABLE documents (id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL, title VARCHAR(255), url TEXT, visibility VARCHAR(50) DEFAULT 'ALL', created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE);
CREATE TABLE notifications (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id INT NULL, conference_id INT NOT NULL, title VARCHAR(255), message TEXT, type VARCHAR(50), read_at TIMESTAMP NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE);
CREATE TABLE conversations (id BIGINT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL, title VARCHAR(255), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE);
CREATE TABLE conversation_members (conversation_id BIGINT NOT NULL, user_id INT NOT NULL, PRIMARY KEY(conversation_id,user_id), FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE);
CREATE TABLE messages (id BIGINT AUTO_INCREMENT PRIMARY KEY, conversation_id BIGINT NOT NULL, sender_id INT NOT NULL, message_type VARCHAR(30) DEFAULT 'TEXT', body TEXT, attachment_url TEXT, read_at TIMESTAMP NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE, FOREIGN KEY(sender_id) REFERENCES users(id) ON DELETE CASCADE);
CREATE TABLE emergency_contacts (id INT AUTO_INCREMENT PRIMARY KEY, conference_id INT NOT NULL, name VARCHAR(150), type VARCHAR(50), phone VARCHAR(30), FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE);
CREATE TABLE audit_logs (id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id INT NULL, action VARCHAR(100), entity VARCHAR(100), entity_id BIGINT, details JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL);

INSERT INTO conferences(name,short_name,description,welcome_message,about_conference,start_date,end_date,registration_start_date,registration_end_date,contact_person,contact_phone,contact_email,website,organizer,host_institution,theme,status,venue,address,banner_url,logo_url,active) VALUES ('100th DPU AIU VC Conference 2026','DPU AIU VC 2026','100th AIU Annual General Body Meet & National Conference of Vice Chancellors','DPU welcomes you to the 100th AIU Annual General Body Meet & National Conference of Vice Chancellors.','A national higher education leadership conference hosted by Dr. D. Y. Patil Vidyapeeth, Pimpri, Pune.','2026-04-27','2026-04-30','2026-01-01','2026-04-15','Conference Help Desk','1800123456','admin@conference.local','https://dpu.edu.in','Dr. D. Y. Patil Vidyapeeth','Dr. D. Y. Patil Vidyapeeth, Pimpri, Pune','Higher education leadership','ACTIVE','Dr. D. Y. Patil Vidyapeeth, Pimpri, Pune','Pimpri, Pune, Maharashtra','https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1600','/uploads/branding/logo.png',1);
INSERT INTO conference_settings(conference_id,enable_registration,enable_chat,enable_gallery,enable_attendance,enable_qr,enable_push_notifications,enable_certificates,enable_polls,enable_feedback) VALUES (1,1,1,1,1,1,0,1,0,1);
INSERT INTO conference_branding(conference_id,conference_logo,banner,primary_color,secondary_color,accent_color,background_color) VALUES (1,'/uploads/branding/logo.png','https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1600','#8C1119','#C8A45A','#2E6F95','#FCFAF5');
INSERT INTO venues(conference_id,name,address,city,state,country,pincode,latitude,longitude,google_maps_url,parking_information,directions,contact_number) VALUES (1,'D.Y. Patil Vidyapeeth','Pimpri, Pune, Maharashtra','Pune','Maharashtra','India','411018',18.6275,73.8009,'https://www.google.com/maps/search/?api=1&query=Dr.+D.+Y.+Patil+Vidyapeeth+Pimpri+Pune','Parking assistance is available near the main entrance.','Use the main Pimpri campus entrance and follow conference signage.','1800123456');
INSERT INTO halls(venue_id,name,capacity) VALUES (1,'Main Auditorium',1200),(1,'Conference Hall A',300),(1,'Conference Hall B',300);
INSERT INTO speakers(conference_id,name,designation,organization,bio,email,phone) VALUES
(1,'Dr. Rakesh Kumar Sharma','Vice Chancellor','D.Y. Patil University','Distinguished academic leader and conference host','vc@dypatilkolhapur.org','9820619211'),
(1,'Dr. Pallavi Kiran Shinde','Liaison Faculty','DPU','Conference liaison and delegate support','pallavi.shinde@dpu.edu.in','9766594602');
INSERT INTO sessions(conference_id,hall_id,speaker_id,title,description,session_date,start_time,end_time,category) VALUES
(1,1,1,'Inauguration Ceremony','Opening ceremony and welcome address','2026-04-28','10:00:00','11:30:00','Ceremony'),
(1,2,1,'Vice Chancellor Leadership Session','Leadership, innovation and higher education','2026-04-28','14:00:00','15:00:00','Keynote'),
(1,3,2,'Delegate Orientation','Conference logistics and support briefing','2026-04-28','15:30:00','16:15:00','Orientation');
INSERT INTO liaison_faculty(name,phone,email) VALUES ('Dr. Pallavi Kiran Shinde','9766594602','pallavi.shinde@dpu.edu.in');
INSERT INTO hotels(name,address,latitude,longitude) VALUES ('Hyatt Regency Pune & Residences','Weikfield IT Citi Info Park, Pune Nagar Rd, Sakore Nagar, Viman Nagar, Pune, Maharashtra 411014',18.5627,73.9160);
INSERT INTO rooms(hotel_id,room_number,room_type,capacity) VALUES (1,'504','Deluxe',2),(1,'505','Deluxe',2),(1,'506','Suite',2);
INSERT INTO drivers(name,phone,license_no) VALUES ('Rajesh Patil','9876543210','MH12-DRV-001'),('Amit Jadhav','9876543211','MH12-DRV-002');
INSERT INTO vehicles(driver_id,vehicle_number,vehicle_type,capacity) VALUES (1,'MH12AB1234','Tempo Traveller',12),(2,'MH12CD5678','Sedan',4);
INSERT INTO notices(conference_id,title,message,type) VALUES (1,'Welcome to the Conference','Please check your personalized schedule, accommodation and transport details before arrival.','GENERAL'),(1,'Registration Desk','Registration desk will be open from 08:00 AM at the main entrance.','INFO');
INSERT INTO photos(conference_id,album,url,caption) VALUES (1,'Opening Day','https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1200','Opening ceremony'),(1,'Opening Day','https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=1200','Conference hall'),(1,'Delegates','https://images.unsplash.com/photo-1511578314322-379afb476865?w=1200','Delegates networking');
INSERT INTO duties(conference_id,title,location,duty_date,start_time,end_time,supervisor,notes) VALUES (1,'Airport Reception','Pune Airport','2026-04-27','08:00:00','14:00:00','Conference Control Room','Welcome and transport coordination'),(1,'Registration Desk','Main Entrance','2026-04-28','08:00:00','12:00:00','Registration Manager','Verify QR IDs');
INSERT INTO meals(conference_id,meal_date,meal_type,start_time,end_time,location) VALUES (1,'2026-04-28','BREAKFAST','07:00:00','09:00:00','Hyatt Regency'),(1,'2026-04-28','LUNCH','12:30:00','14:00:00','Conference Dining Hall'),(1,'2026-04-28','TEA','16:00:00','17:00:00','Foyer'),(1,'2026-04-28','DINNER','19:30:00','21:30:00','Hyatt Regency');
INSERT INTO emergency_contacts(conference_id,name,type,phone) VALUES (1,'Conference Help Desk','Help Desk','1800123456'),(1,'Medical Emergency','Medical','108'),(1,'Security Desk','Security','100');
