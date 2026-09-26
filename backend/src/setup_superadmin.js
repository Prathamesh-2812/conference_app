import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import { pool } from './db.js';

dotenv.config();

async function setupSuperAdmin() {
  console.log('--- Setting up Single Super Admin Account ---');

  const connection = await pool.getConnection();
  try {
    const superPassword = 'superadmin@dypesconf';
    const passwordHash = await bcrypt.hash(superPassword, 10);

    // 1. Remove previous demo admins
    const [delStaff] = await connection.query(`DELETE FROM conference_staff WHERE user_id IN (SELECT id FROM users WHERE email IN ('admin@conference.local', 'admin@dpu.edu.in', 'superadmin@conference.local'))`);
    const [delAdmins] = await connection.query(`DELETE FROM users WHERE email IN ('admin@conference.local', 'admin@dpu.edu.in', 'superadmin@conference.local')`);
    console.log(`✓ Removed old demo admin accounts.`);

    // 2. Insert or update the new Super Admin account
    // We insert/update both 'dypesconf.superadmin' and 'dypesconf.superadmin@dypesconf.io' if needed, or primary identifier
    await connection.query(`
      INSERT INTO users (name, email, password_hash, phone, role, designation, university, must_change_password)
      VALUES ('DY Patil Super Admin', 'dypesconf.superadmin', ?, '9999999999', 'SUPER_ADMIN', 'Chief Super Administrator', 'D.Y. Patil Education Society', 0)
      ON DUPLICATE KEY UPDATE 
        name = 'DY Patil Super Admin',
        password_hash = VALUES(password_hash),
        role = 'SUPER_ADMIN',
        must_change_password = 0
    `, [passwordHash]);

    // Also alias dypesconf.superadmin@dypesconf.io to same credentials
    await connection.query(`
      INSERT INTO users (name, email, password_hash, phone, role, designation, university, must_change_password)
      VALUES ('DY Patil Super Admin', 'dypesconf.superadmin@dypesconf.io', ?, '9999999998', 'SUPER_ADMIN', 'Chief Super Administrator', 'D.Y. Patil Education Society', 0)
      ON DUPLICATE KEY UPDATE 
        name = 'DY Patil Super Admin',
        password_hash = VALUES(password_hash),
        role = 'SUPER_ADMIN',
        must_change_password = 0
    `, [passwordHash]);

    console.log('\n✅ Super Admin account setup completed successfully!');
    console.log('----------------------------------------------------');
    console.log('👤 Username / Email : dypesconf.superadmin');
    console.log('🔑 Password          : superadmin@dypesconf');
    console.log('👑 Role              : SUPER_ADMIN');
    console.log('----------------------------------------------------');
  } catch (err) {
    console.error('❌ Error creating Super Admin:', err.message);
  } finally {
    connection.release();
    await pool.end();
  }
}

setupSuperAdmin();
