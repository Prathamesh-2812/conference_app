import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const envPaths = [
  path.resolve(process.cwd(), '.env'),
  path.resolve(__dirname, '..', '.env'),
  path.resolve(__dirname, '../..', '.env')
];

for (const p of envPaths) {
  if (fs.existsSync(p)) {
    dotenv.config({ path: p });
    break;
  }
}

import { pool } from './db.js';
import { extractGroupPhotoFaces } from './services/face_matching.js';

const uploadRoot = path.resolve(__dirname, '..', 'uploads');

async function reindexGallery() {
  console.log('--- Starting AI Face Re-Indexing for Conference Gallery ---');
  
  const connection = await pool.getConnection();
  try {
    const [photos] = await connection.query('SELECT id, conference_id, url, album FROM photos ORDER BY id ASC');
    console.log(`Found ${photos.length} photos in gallery database.`);

    if (photos.length === 0) {
      console.log('No photos to re-index.');
      return;
    }

    // Clear old approximate face embeddings
    await connection.query('TRUNCATE TABLE photo_faces');
    console.log('Cleared old photo_faces table.');

    let processed = 0;
    let facesIndexed = 0;

    for (const p of photos) {
      let imgBuffer = null;
      try {
        const url = (p.url || '').trim();
        if (url.startsWith('/uploads/') || url.startsWith('uploads/')) {
          const rel = url.replace(/^\/?uploads\//, '');
          const localFile = path.join(uploadRoot, rel);
          if (fs.existsSync(localFile)) {
            imgBuffer = fs.readFileSync(localFile);
          }
        } else if (url.startsWith('http')) {
          try {
            const resp = await fetch(url);
            const ab = await resp.arrayBuffer();
            imgBuffer = Buffer.from(ab);
          } catch (_) {}
        }
      } catch (e) {
        console.error(`Error loading photo ID ${p.id}:`, e.message);
      }

      if (imgBuffer) {
        try {
          const faces = await extractGroupPhotoFaces(imgBuffer, 4);
          for (const f of faces) {
            await connection.query(
              'INSERT INTO photo_faces (photo_id, conference_id, bounding_box, embedding) VALUES (?, ?, ?, ?)',
              [p.id, p.conference_id || 1, JSON.stringify(f.boundingBox), JSON.stringify(f.embedding)]
            );
            facesIndexed++;
          }
        } catch (err) {
          console.error(`Failed to extract faces for photo ${p.id}:`, err.message);
        }
      }

      processed++;
      if (processed % 50 === 0 || processed === photos.length) {
        console.log(`Progress: ${processed}/${photos.length} photos scanned (${facesIndexed} faces indexed)...`);
      }
    }

    console.log(`\n✅ Completed AI Face Re-Indexing! Total photos: ${processed}, Total faces indexed: ${facesIndexed}.`);
  } catch (err) {
    console.error('❌ Re-indexing error:', err);
  } finally {
    connection.release();
    await pool.end();
  }
}

reindexGallery();
