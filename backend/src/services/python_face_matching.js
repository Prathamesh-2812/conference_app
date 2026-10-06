import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const pythonScriptPath = path.resolve(__dirname, '..', 'ai_face_engine.py');

/**
 * Execute Python deep-learning face matcher
 * Returns Promise<{ status: string, matches: Array, totalMatched: number } | null>
 */
export async function matchSelfieWithPython(selfieData, tolerance = 0.55) {
  return new Promise((resolve) => {
    try {
      if (!fs.existsSync(pythonScriptPath)) {
        return resolve(null);
      }

      // Try python3 first, then python
      const pyProcess = spawn('python3', [pythonScriptPath, 'match', '--tolerance', String(tolerance)], {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      let stdout = '';
      let stderr = '';

      pyProcess.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      pyProcess.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      pyProcess.on('error', (err) => {
        // Python3 not found or failed, try 'python'
        try {
          const fallbackPy = spawn('python', [pythonScriptPath, 'match', '--tolerance', String(tolerance)], {
            stdio: ['pipe', 'pipe', 'pipe']
          });

          let fbStdout = '';
          let fbStderr = '';

          fallbackPy.stdout.on('data', (d) => { fbStdout += d.toString(); });
          fallbackPy.stderr.on('data', (d) => { fbStderr += d.toString(); });

          fallbackPy.on('close', (code) => {
            if (code === 0 && fbStdout.trim()) {
              try {
                const parsed = JSON.parse(fbStdout.trim());
                return resolve(parsed);
              } catch (_) {}
            }
            resolve(null);
          });

          fallbackPy.on('error', () => resolve(null));

          fallbackPy.stdin.write(selfieData);
          fallbackPy.stdin.end();
        } catch (_) {
          resolve(null);
        }
      });

      pyProcess.on('close', (code) => {
        if (code === 0 && stdout.trim()) {
          try {
            const parsed = JSON.parse(stdout.trim());
            return resolve(parsed);
          } catch (_) {}
        }
        // If Python output couldn't be parsed, fallback
        resolve(null);
      });

      pyProcess.stdin.write(selfieData);
      pyProcess.stdin.end();
    } catch (err) {
      resolve(null);
    }
  });
}
