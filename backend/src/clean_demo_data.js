import dotenv from 'dotenv';
import { pool } from './db.js';

dotenv.config();

async function cleanDemoData() {
  console.log('--- Cleaning Demo Data (Participants, Hotels, Rooms, Allocations) ---');

  const connection = await pool.getConnection();
  try {
    await connection.query('SET FOREIGN_KEY_CHECKS = 0');

    // 1. Delete Room Allocations
    const [allocResult] = await connection.query('DELETE FROM room_allocations');
    console.log(`✓ Deleted ${allocResult.affectedRows} room allocations.`);

    // 2. Delete Transport Assignments
    const [transResult] = await connection.query('DELETE FROM transport_assignments');
    console.log(`✓ Deleted ${transResult.affectedRows} transport assignments.`);

    // 3. Delete Certificates
    const [certResult] = await connection.query('DELETE FROM certificates');
    console.log(`✓ Deleted ${certResult.affectedRows} certificates.`);

    // 4. Delete Attendance & Meal Scans & Feedback
    const [attResult] = await connection.query('DELETE FROM attendance');
    const [mealResult] = await connection.query('DELETE FROM meal_scans');
    const [fbResult] = await connection.query('DELETE FROM feedback');
    console.log(`✓ Deleted ${attResult.affectedRows} attendance, ${mealResult.affectedRows} meal scans, ${fbResult.affectedRows} feedback records.`);

    // 5. Delete Participants
    const [partResult] = await connection.query('DELETE FROM participants');
    console.log(`✓ Deleted ${partResult.affectedRows} participants.`);

    // 6. Delete Participant Users (keeping ADMIN, SUPER_ADMIN, EVENT_MANAGER, STAFF)
    const [userResult] = await connection.query(`
      DELETE FROM users 
      WHERE role = 'PARTICIPANT' 
        AND id NOT IN (SELECT user_id FROM conference_staff WHERE user_id IS NOT NULL)
    `);
    console.log(`✓ Deleted ${userResult.affectedRows} demo participant user accounts.`);

    // 7. Delete Rooms & Hotels
    const [roomResult] = await connection.query('DELETE FROM rooms');
    const [hotelResult] = await connection.query('DELETE FROM hotels');
    console.log(`✓ Deleted ${roomResult.affectedRows} rooms and ${hotelResult.affectedRows} hotels.`);

    await connection.query('SET FOREIGN_KEY_CHECKS = 1');

    console.log('\n✅ Demo cleanup completed successfully! Dashboard counts will now show 0.');
  } catch (err) {
    console.error('❌ Error during cleanup:', err.message);
  } finally {
    connection.release();
    await pool.end();
  }
}

cleanDemoData();
