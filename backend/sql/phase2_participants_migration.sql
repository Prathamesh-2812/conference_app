USE conference_management;

ALTER TABLE users
ADD COLUMN gender VARCHAR(20) AFTER phone,
ADD COLUMN dob DATE AFTER gender,
ADD COLUMN department VARCHAR(150) AFTER university;

ALTER TABLE participants
ADD COLUMN address TEXT AFTER emergency_contact,
ADD COLUMN city VARCHAR(100) AFTER address,
ADD COLUMN state VARCHAR(100) AFTER city,
ADD COLUMN country VARCHAR(100) AFTER state,
ADD COLUMN pincode VARCHAR(20) AFTER country,
ADD COLUMN emergency_phone VARCHAR(30) AFTER pincode,
ADD COLUMN participant_type VARCHAR(50) AFTER emergency_phone,
ADD COLUMN train_number VARCHAR(50) AFTER flight_number,
ADD COLUMN special_requirements TEXT AFTER train_number,
ADD COLUMN notes TEXT AFTER special_requirements;

ALTER TABLE participants
MODIFY COLUMN status ENUM('PENDING','APPROVED','CHECKED_IN','CANCELLED','REJECTED') DEFAULT 'PENDING';
