// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Future<String?> captureWebcamSelfie(BuildContext context) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _WebcamDialog(),
  );
}

class _WebcamDialog extends StatefulWidget {
  const _WebcamDialog();
  @override
  State<_WebcamDialog> createState() => _WebcamDialogState();
}

class _WebcamDialogState extends State<_WebcamDialog> {
  html.VideoElement? _videoElement;
  html.MediaStream? _stream;
  String? _viewId;
  bool _isReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebcam();
  }

  Future<void> _initWebcam() async {
    try {
      final viewType = 'webcam-view-${DateTime.now().millisecondsSinceEpoch}';
      _viewId = viewType;

      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)' // Mirror selfie preview
        ..setAttribute('playsinline', 'true');

      _videoElement = video;

      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) => video,
      );

      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('Camera device not available on this browser.');
      }

      final stream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 720},
          'height': {'ideal': 720}
        },
        'audio': false,
      });

      _stream = stream;
      video.srcObject = stream;
      await video.play();

      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera access error: $e';
        });
      }
    }
  }

  void _capture() {
    if (_videoElement == null) return;
    try {
      final v = _videoElement!;
      final width = v.videoWidth > 0 ? v.videoWidth : 640;
      final height = v.videoHeight > 0 ? v.videoHeight : 480;

      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;

      // Flip horizontally to match mirror preview
      ctx.translate(width, 0);
      ctx.scale(-1, 1);
      ctx.drawImage(v, 0, 0);

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
      _cleanup();
      Navigator.of(context).pop(dataUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture snapshot: $e')),
      );
    }
  }

  void _cleanup() {
    try {
      _stream?.getTracks().forEach((track) => track.stop());
      _videoElement?.pause();
      _videoElement?.srcObject = null;
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color maroon = Color(0xFF8C1119);
    const Color gold = Color(0xFFC8A45A);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [maroon, Color(0xFF5B0A0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Live Camera Selfie',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    onPressed: () {
                      _cleanup();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),

            // Camera Viewport / Error
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Container(
                      height: 260,
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_off, size: 48, color: Colors.red.shade600),
                          const SizedBox(height: 12),
                          const Text(
                            'Camera Permission Required',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please grant camera permission in your browser address bar to use live selfie capture.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    )
                  else
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 320,
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: gold.withOpacity(0.6), width: 2),
                          ),
                          child: _isReady && _viewId != null
                              ? HtmlElementView(viewType: _viewId!)
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(color: gold),
                                      SizedBox(height: 12),
                                      Text(
                                        'Starting Camera...',
                                        style: TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        // Oval Face Guide Overlay
                        if (_isReady)
                          IgnorePointer(
                            child: Container(
                              width: 170,
                              height: 230,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(90),
                                border: Border.all(
                                  color: gold.withOpacity(0.85),
                                  width: 2.5,
                                  style: BorderStyle.solid,
                                ),
                              ),
                            ),
                          ),
                        if (_isReady)
                          Positioned(
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Position your face inside the oval',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Action Controls
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: maroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.camera, size: 22, color: gold),
                          label: const Text(
                            '📸 Capture & Scan Face',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          onPressed: _isReady ? _capture : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
