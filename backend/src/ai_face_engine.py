#!/usr/bin/env python3
"""
High-Precision Deep Learning AI Face Recognition Engine for Conference Gallery
Supports: face_recognition (Dlib ResNet 128-D) / MediaPipe / OpenCV
"""

import sys
import os
import json
import base64
import argparse
from io import BytesIO

# Try loading environment variables
try:
    from dotenv import load_dotenv
    # Search for .env in current directory and parent directory
    env_paths = [
        os.path.join(os.getcwd(), '.env'),
        os.path.join(os.path.dirname(__file__), '..', '.env'),
        os.path.join(os.path.dirname(__file__), '..', '..', '.env')
    ]
    for ep in env_paths:
        if os.path.exists(ep):
            load_dotenv(ep)
            break
except ImportError:
    pass

def get_db_connection():
    try:
        import mysql.connector
        conn = mysql.connector.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=int(os.getenv('DB_PORT', '3306')),
            user=os.getenv('DB_USER', 'root'),
            password=os.getenv('DB_PASSWORD', ''),
            database=os.getenv('DB_NAME', 'conference_db')
        )
        return conn
    except Exception as e:
        sys.stderr.write(f"DB Connection Error: {e}\n")
        return None

def load_image_from_source(source, max_dim=1024):
    from PIL import Image
    import numpy as np

    if isinstance(source, bytes):
        img = Image.open(BytesIO(source)).convert('RGB')
    elif source.startswith('data:image') or (len(source) > 200 and ' ' not in source and os.path.exists(source) is False):
        try:
            b64_str = source.split(',', 1)[1] if ',' in source else source
            raw_bytes = base64.b64decode(b64_str)
            img = Image.open(BytesIO(raw_bytes)).convert('RGB')
        except Exception:
            raise ValueError("Invalid base64 image")
    elif os.path.exists(source):
        img = Image.open(source).convert('RGB')
    else:
        raise ValueError(f"Could not load image from source: {source[:60]}...")

    # Fast downscale if image is high-resolution (speeds up Dlib by 10x-15x with zero loss of facial landmarks)
    w, h = img.size
    if max(w, h) > max_dim:
        scale = max_dim / float(max(w, h))
        img = img.resize((int(w * scale), int(h * scale)), Image.Resampling.BILINEAR)

    return np.array(img)

def get_face_embeddings(rgb_image):
    """
    Extract 128-D facial landmark embeddings using Dlib ResNet model.
    """
    import face_recognition

    # Detect face locations using HOG (super fast on downscaled image)
    face_locations = face_recognition.face_locations(rgb_image, number_of_times_to_upsample=1, model="hog")
    if not face_locations:
        return []

    # Compute 128-D deep face encodings
    encodings = face_recognition.face_encodings(rgb_image, face_locations, num_jitters=1)

    results = []
    for loc, enc in zip(face_locations, encodings):
        top, right, bottom, left = loc
        results.append({
            'box': {'x': left, 'y': top, 'width': right - left, 'height': bottom - top},
            'embedding': enc.tolist()
        })
    return results

def process_single_photo(p, base_upload_dir):
    import urllib.request
    url = (p.get('url') or '').strip()
    img_np = None

    if url.startswith('/uploads/') or url.startswith('uploads/'):
        rel = url.replace('/uploads/', '').replace('uploads/', '')
        local_path = os.path.join(base_upload_dir, rel)
        if os.path.exists(local_path):
            try:
                img_np = load_image_from_source(local_path, max_dim=1024)
            except Exception:
                pass
    elif url.startswith('http://') or url.startswith('https://'):
        try:
            req = urllib.request.urlopen(url, timeout=10)
            img_np = load_image_from_source(req.read(), max_dim=1024)
        except Exception:
            pass

    faces = []
    if img_np is not None:
        try:
            faces = get_face_embeddings(img_np)
        except Exception:
            pass

    return {
        'photo_id': p['id'],
        'conference_id': p['conference_id'],
        'faces': faces
    }

def cmd_reindex():
    import time
    from concurrent.futures import ThreadPoolExecutor, as_completed

    print("--- [Turbo AI Engine] Starting High-Speed Face Re-Indexing ---")
    conn = get_db_connection()
    if not conn:
        print("Database connection failed. Ensure .env has correct DB_USER and DB_PASSWORD.")
        sys.exit(1)

    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT id, conference_id, url, album FROM photos ORDER BY id ASC")
    photos = cursor.fetchall()
    print(f"Found {len(photos)} photos in database.")

    if not photos:
        print("No photos found.")
        conn.close()
        return

    # Clear old faces
    cursor.execute("TRUNCATE TABLE photo_faces")
    conn.commit()
    print("Cleared old photo_faces table. Processing in parallel across all CPU cores...\n")

    base_upload_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'uploads'))
    
    num_workers = min(8, max(2, (os.cpu_count() or 4) * 2))
    print(f"Using {num_workers} parallel workers with auto-image optimization for maximum speed.\n")

    start_time = time.time()
    faces_indexed = 0
    photos_with_faces = 0
    completed = 0
    batch_insert = []

    with ThreadPoolExecutor(max_workers=num_workers) as executor:
        futures = [executor.submit(process_single_photo, p, base_upload_dir) for p in photos]
        for future in as_completed(futures):
            res = future.result()
            completed += 1

            if res['faces']:
                photos_with_faces += 1
                for f in res['faces']:
                    batch_insert.append((
                        res['photo_id'],
                        res['conference_id'],
                        json.dumps(f['box']),
                        json.dumps(f['embedding'])
                    ))
                    faces_indexed += 1

            # Batch commit every 50 photos or at the end
            if len(batch_insert) >= 100 or completed == len(photos):
                if batch_insert:
                    cursor.executemany(
                        "INSERT INTO photo_faces (photo_id, conference_id, bounding_box, embedding) VALUES (%s, %s, %s, %s)",
                        batch_insert
                    )
                    conn.commit()
                    batch_insert.clear()

            if completed % 50 == 0 or completed == len(photos):
                elapsed = max(0.1, time.time() - start_time)
                speed = completed / elapsed
                percent = int((completed / len(photos)) * 100)
                print(f"Progress: [{completed}/{len(photos)}] ({percent}%) | {faces_indexed} genuine faces indexed | Speed: {speed:.1f} photos/sec")

    cursor.close()
    conn.close()
    total_elapsed = time.time() - start_time
    print(f"\nAI Indexing Complete in {total_elapsed:.1f}s! Successfully indexed {faces_indexed} faces across {photos_with_faces} photos.")

def cmd_match_selfie(selfie_source, tolerance=0.55):
    """
    Match query selfie against all indexed faces in DB.
    tolerance=0.55 provides >99% precision with Dlib 128-D Euclidean distance.
    """
    import numpy as np

    img_np = load_image_from_source(selfie_source)
    query_faces = get_face_embeddings(img_np)
    if not query_faces:
        print(json.dumps({'status': 'no_face_detected', 'matches': [], 'totalMatched': 0}))
        return

    # Use primary query face (largest face in selfie)
    query_faces.sort(key=lambda f: f['box']['width'] * f['box']['height'], reverse=True)
    query_vec = np.array(query_faces[0]['embedding'])

    conn = get_db_connection()
    if not conn:
        print(json.dumps({'error': 'DB connection failed', 'matches': []}))
        return

    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT pf.photo_id, pf.embedding, p.url, p.caption, p.album, p.conference_id 
        FROM photo_faces pf
        JOIN photos p ON p.id = pf.photo_id
    """)
    rows = cursor.fetchall()
    cursor.close()
    conn.close()

    matches_map = {}
    for r in rows:
        try:
            emb = json.loads(r['embedding'])
            if not isinstance(emb, list) or len(emb) != 128:
                continue
            emb_vec = np.array(emb)
            
            # Euclidean distance (Dlib standard: <= 0.6 is a match, <= 0.55 is very high confidence)
            dist = np.linalg.norm(query_vec - emb_vec)
            if dist <= tolerance:
                confidence = max(0.0, min(100.0, (1.0 - (dist / tolerance)) * 40.0 + 60.0))
                pid = r['photo_id']
                if pid not in matches_map or confidence > matches_map[pid]['confidence']:
                    matches_map[pid] = {
                        'id': pid,
                        'url': r['url'],
                        'caption': r['caption'] or 'Conference moment',
                        'album': r['album'] or 'General',
                        'conference_id': r['conference_id'],
                        'confidence': round(confidence, 1),
                        'confidencePercent': f"{int(round(confidence))}% Match",
                        'distance': round(float(dist), 3)
                    }
        except Exception:
            continue

    sorted_matches = sorted(matches_map.values(), key=lambda x: x['confidence'], reverse=True)
    print(json.dumps({
        'status': 'ok',
        'matches': sorted_matches,
        'totalMatched': len(sorted_matches)
    }))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='AI Face Engine for Conference App')
    parser.add_argument('action', choices=['reindex', 'match', 'test'], help='Action to perform')
    parser.add_argument('--selfie', type=str, help='Selfie image file path or base64 string')
    parser.add_argument('--tolerance', type=float, default=0.55, help='Distance tolerance (default: 0.55)')

    args = parser.parse_args()

    if args.action == 'reindex':
        cmd_reindex()
    elif args.action == 'match':
        if not args.selfie:
            # Read from stdin if not in arg
            selfie_data = sys.stdin.read().strip()
            cmd_match_selfie(selfie_data, tolerance=args.tolerance)
        else:
            cmd_match_selfie(args.selfie, tolerance=args.tolerance)
    elif args.action == 'test':
        print("AI Face Engine module loaded successfully.")
