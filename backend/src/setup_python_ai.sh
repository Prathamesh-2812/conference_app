#!/bin/bash
# One-Click Setup Script for High-Precision Python AI Face Recognition Engine
set -e

echo "=== Installing Python AI Dependencies on VPS ==="
sudo apt-get update
sudo apt-get install -y python3-pip python3-dev build-essential cmake libopenblas-dev liblapack-dev

echo "=== Installing Python Libraries (face_recognition, dlib, mysql-connector, pillow) ==="
pip3 install --upgrade pip
pip3 install face_recognition mysql-connector-python python-dotenv pillow numpy

echo "=== Running AI Face Re-Indexing on Conference Gallery ==="
python3 /var/www/conference_app/backend/src/ai_face_engine.py reindex

echo "=== Python AI Face Engine Setup Complete! ==="
