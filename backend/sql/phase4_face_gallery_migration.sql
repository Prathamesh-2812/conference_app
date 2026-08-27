-- Phase 4: AI Smart Face Matching Event Gallery Schema
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
);

-- Add PHOTOGRAPHER role to users if needed
ALTER TABLE users MODIFY COLUMN role ENUM('SUPER_ADMIN','ADMIN','EVENT_MANAGER','TRANSPORT_ADMIN','VOLUNTEER','PARTICIPANT','PHOTOGRAPHER') DEFAULT 'PARTICIPANT';
