import mysql from 'mysql2/promise';
import { extractGroupPhotoFaces } from './services/face_matching.js';

const samplePhotos = [
  {
    album: 'Inauguration',
    caption: 'Dignitaries lighting the ceremonial lamp at the Grand Opening Ceremony',
    url: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1200&auto=format&fit=crop&q=80',
    faces: 3
  },
  {
    album: 'Inauguration',
    caption: 'Welcome address by the Vice Chancellor and Organizing Committee',
    url: 'https://images.unsplash.com/photo-1511578314322-379afb476865?w=1200&auto=format&fit=crop&q=80',
    faces: 2
  },
  {
    album: 'Keynote Sessions',
    caption: 'Keynote lecture on Advanced Molecular Diagnostics and Oncopathology',
    url: 'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=1200&auto=format&fit=crop&q=80',
    faces: 1
  },
  {
    album: 'Keynote Sessions',
    caption: 'Panel discussion on Human Brain Banking and Neuropathology Research',
    url: 'https://images.unsplash.com/photo-1515187029135-18ee286d815b?w=1200&auto=format&fit=crop&q=80',
    faces: 4
  },
  {
    album: 'Delegate Networking',
    caption: 'Delegates and faculty exchanging research insights during tea break',
    url: 'https://images.unsplash.com/photo-1528605248644-14dd04022da1?w=1200&auto=format&fit=crop&q=80',
    faces: 3
  },
  {
    album: 'Delegate Networking',
    caption: 'Interactive Q&A with young pathologists and researchers',
    url: 'https://images.unsplash.com/photo-1577495508048-b635879837f1?w=1200&auto=format&fit=crop&q=80',
    faces: 2
  },
  {
    album: 'Award Ceremony',
    caption: 'Presentation of the ISHBT Lifetime Achievement Award 2026',
    url: 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?w=1200&auto=format&fit=crop&q=80',
    faces: 2
  },
  {
    album: 'Gala Dinner',
    caption: 'Cultural evening and gala dinner celebration with international guests',
    url: 'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?w=1200&auto=format&fit=crop&q=80',
    faces: 4
  }
];

async function seedGallery() {
  const conn = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'conference_management'
  });

  console.log('Seeding Gallery Photos & Indexing AI Faces...');

  for (const p of samplePhotos) {
    const [res] = await conn.query(
      'INSERT INTO photos(conference_id, album, url, caption, uploaded_by) VALUES(1, ?, ?, ?, 1)',
      [p.album, p.url, p.caption]
    );
    const photoId = res.insertId;

    const faces = extractGroupPhotoFaces(p.url, p.faces);
    for (const f of faces) {
      await conn.query(
        'INSERT INTO photo_faces(photo_id, conference_id, bounding_box, embedding) VALUES(?, 1, ?, ?)',
        [photoId, JSON.stringify(f.boundingBox), JSON.stringify(f.embedding)]
      );
    }
    console.log(`Indexed photo #${photoId} [${p.album}] with ${faces.length} faces.`);
  }

  console.log('Gallery seeding completed successfully!');
  await conn.end();
}

seedGallery().catch(err => {
  console.error('Seeding error:', err);
  process.exit(1);
});
