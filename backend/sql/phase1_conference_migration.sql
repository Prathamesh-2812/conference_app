USE conference_management;

ALTER TABLE conferences
  ADD COLUMN IF NOT EXISTS welcome_message TEXT AFTER description,
  ADD COLUMN IF NOT EXISTS about_conference TEXT AFTER welcome_message,
  ADD COLUMN IF NOT EXISTS registration_start_date DATE AFTER end_date,
  ADD COLUMN IF NOT EXISTS registration_end_date DATE AFTER registration_start_date,
  ADD COLUMN IF NOT EXISTS contact_person VARCHAR(150) AFTER registration_end_date,
  ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(30) AFTER contact_person,
  ADD COLUMN IF NOT EXISTS contact_email VARCHAR(190) AFTER contact_phone,
  ADD COLUMN IF NOT EXISTS website VARCHAR(255) AFTER contact_email,
  ADD COLUMN IF NOT EXISTS organizer VARCHAR(255) AFTER website,
  ADD COLUMN IF NOT EXISTS host_institution VARCHAR(255) AFTER organizer,
  ADD COLUMN IF NOT EXISTS theme VARCHAR(150) AFTER host_institution,
  ADD COLUMN IF NOT EXISTS status ENUM('DRAFT','PUBLISHED','ARCHIVED','ACTIVE','INACTIVE') DEFAULT 'ACTIVE' AFTER theme,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP AFTER created_at;

UPDATE conferences
SET
  welcome_message = COALESCE(welcome_message, 'DPU welcomes you to the 100th AIU Annual General Body Meet & National Conference of Vice Chancellors.'),
  about_conference = COALESCE(about_conference, description),
  registration_start_date = COALESCE(registration_start_date, '2026-01-01'),
  registration_end_date = COALESCE(registration_end_date, '2026-04-15'),
  contact_person = COALESCE(contact_person, 'Conference Help Desk'),
  contact_phone = COALESCE(contact_phone, '1800123456'),
  contact_email = COALESCE(contact_email, 'admin@conference.local'),
  organizer = COALESCE(organizer, 'Dr. D. Y. Patil Vidyapeeth'),
  host_institution = COALESCE(host_institution, 'Dr. D. Y. Patil Vidyapeeth, Pimpri, Pune'),
  theme = COALESCE(theme, 'Higher education leadership'),
  status = COALESCE(status, 'ACTIVE')
WHERE id = 1;

CREATE TABLE IF NOT EXISTS conference_settings (
 id INT AUTO_INCREMENT PRIMARY KEY,
 conference_id INT NOT NULL UNIQUE,
 enable_registration TINYINT(1) DEFAULT 1,
 enable_chat TINYINT(1) DEFAULT 1,
 enable_gallery TINYINT(1) DEFAULT 1,
 enable_attendance TINYINT(1) DEFAULT 1,
 enable_qr TINYINT(1) DEFAULT 1,
 enable_push_notifications TINYINT(1) DEFAULT 0,
 enable_certificates TINYINT(1) DEFAULT 1,
 enable_polls TINYINT(1) DEFAULT 0,
 enable_feedback TINYINT(1) DEFAULT 1,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
 FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS conference_branding (
 id INT AUTO_INCREMENT PRIMARY KEY,
 conference_id INT NOT NULL UNIQUE,
 conference_logo TEXT,
 organizer_logo TEXT,
 banner TEXT,
 splash_screen TEXT,
 favicon TEXT,
 primary_color VARCHAR(20) DEFAULT '#8C1119',
 secondary_color VARCHAR(20) DEFAULT '#C8A45A',
 accent_color VARCHAR(20) DEFAULT '#2E6F95',
 background_color VARCHAR(20) DEFAULT '#FCFAF5',
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
 FOREIGN KEY(conference_id) REFERENCES conferences(id) ON DELETE CASCADE
);

ALTER TABLE venues
  ADD COLUMN IF NOT EXISTS city VARCHAR(100) AFTER address,
  ADD COLUMN IF NOT EXISTS state VARCHAR(100) AFTER city,
  ADD COLUMN IF NOT EXISTS country VARCHAR(100) AFTER state,
  ADD COLUMN IF NOT EXISTS pincode VARCHAR(20) AFTER country,
  ADD COLUMN IF NOT EXISTS google_maps_url TEXT AFTER longitude,
  ADD COLUMN IF NOT EXISTS parking_information TEXT AFTER google_maps_url,
  ADD COLUMN IF NOT EXISTS directions TEXT AFTER parking_information,
  ADD COLUMN IF NOT EXISTS contact_number VARCHAR(30) AFTER directions;

INSERT INTO conference_settings(conference_id)
SELECT id FROM conferences
ON DUPLICATE KEY UPDATE conference_id = VALUES(conference_id);

INSERT INTO conference_branding(conference_id,conference_logo,banner,primary_color,secondary_color,accent_color,background_color)
SELECT id,logo_url,banner_url,'#8C1119','#C8A45A','#2E6F95','#FCFAF5' FROM conferences
ON DUPLICATE KEY UPDATE
  conference_logo = COALESCE(conference_branding.conference_logo, VALUES(conference_logo)),
  banner = COALESCE(conference_branding.banner, VALUES(banner));

UPDATE venues
SET
  city = COALESCE(city, 'Pune'),
  state = COALESCE(state, 'Maharashtra'),
  country = COALESCE(country, 'India'),
  pincode = COALESCE(pincode, '411018'),
  google_maps_url = COALESCE(google_maps_url, 'https://www.google.com/maps/search/?api=1&query=Dr.+D.+Y.+Patil+Vidyapeeth+Pimpri+Pune'),
  parking_information = COALESCE(parking_information, 'Parking assistance is available near the main entrance.'),
  directions = COALESCE(directions, 'Use the main Pimpri campus entrance and follow conference signage.'),
  contact_number = COALESCE(contact_number, '1800123456')
WHERE conference_id = 1;
