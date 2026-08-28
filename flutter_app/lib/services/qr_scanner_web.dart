// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

const Color maroon = Color(0xFF8C1119);
const Color gold = Color(0xFFC8A45A);
const Color darkMaroon = Color(0xFF5C070D);
const Color slate = Color(0xFF1E293B);
const Color muted = Color(0xFF64748B);

Future<String?> scanQrCodeWithCamera(BuildContext context) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _QrCameraScannerDialog(),
  );
}

class _QrCameraScannerDialog extends StatefulWidget {
  const _QrCameraScannerDialog();
  @override
  State<_QrCameraScannerDialog> createState() => _QrCameraScannerDialogState();
}

class _QrCameraScannerDialogState extends State<_QrCameraScannerDialog>
    with SingleTickerProviderStateMixin {
  html.VideoElement? _videoElement;
  html.MediaStream? _stream;
  String? _viewId;
  bool _isReady = false;
  String? _errorMessage;
  Timer? _scanTimer;
  bool _scanned = false;
  late AnimationController _animController;
  final TextEditingController _manualInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initScanner();
  }

  @override
  void dispose() {
    _animController.dispose();
    _stopCamera();
    super.dispose();
  }

  void _stopCamera() {
    _scanTimer?.cancel();
    _scanTimer = null;
    if (_stream != null) {
      for (final track in _stream!.getTracks()) {
        track.stop();
      }
      _stream = null;
    }
  }

  Future<void> _initScanner() async {
    try {
      final viewType = 'qr-camera-view-${DateTime.now().millisecondsSinceEpoch}';
      _viewId = viewType;

      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..setAttribute('playsinline', 'true');

      _videoElement = video;

      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) => video,
      );

      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('Camera device is not available on this browser.');
      }

      html.MediaStream? stream;
      try {
        // Prefer environment (rear) camera on mobile phones
        stream = await mediaDevices.getUserMedia({
          'video': {
            'facingMode': {'ideal': 'environment'},
            'width': {'ideal': 640},
            'height': {'ideal': 640},
          },
          'audio': false,
        });
      } catch (_) {
        // Fallback to any user/webcam camera
        stream = await mediaDevices.getUserMedia({
          'video': true,
          'audio': false,
        });
      }

      _stream = stream;
      video.srcObject = stream;
      await video.play();

      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }

      // Start periodic QR scanner loop
      _startScanningLoop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera initialization: $e';
        });
      }
    }
  }

  void _startScanningLoop() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (_scanned || _videoElement == null || !_isReady) return;
      _decodeVideoFrame();
    });
  }

  void _decodeVideoFrame() {
    try {
      final v = _videoElement!;
      final width = v.videoWidth;
      final height = v.videoHeight;
      if (width <= 0 || height <= 0) return;

      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;
      ctx.drawImage(v, 0, 0);

      final imageData = ctx.getImageData(0, 0, width, height);

      final dynamic jsQRFunc = js_util.getProperty(html.window, 'jsQR');
      if (jsQRFunc != null) {
        final dynamic code = js_util.callMethod(html.window, 'jsQR', [
          imageData.data,
          width,
          height,
          js_util.jsify({'inversionAttempts': 'dontInvert'})
        ]);

        if (code != null) {
          final String? data = js_util.getProperty(code, 'data');
          if (data != null && data.trim().isNotEmpty && !_scanned) {
            _scanned = true;
            _stopCamera();
            if (mounted) {
              Navigator.pop(context, data.trim());
            }
          }
        }
      }
    } catch (_) {
      // Ignored for next frame
    }
  }

  void _scanFromGalleryImage() {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      final reader = html.FileReader();
      reader.readAsDataUrl(files[0]);
      reader.onLoadEnd.listen((_) {
        final imgUrl = reader.result as String?;
        if (imgUrl != null) {
          final img = html.ImageElement()..src = imgUrl;
          img.onLoad.listen((_) {
            final canvas = html.CanvasElement(width: img.width ?? 600, height: img.height ?? 600);
            final ctx = canvas.context2D;
            ctx.drawImage(img, 0, 0);
            final imageData = ctx.getImageData(0, 0, canvas.width!, canvas.height!);

            final dynamic jsQRFunc = js_util.getProperty(html.window, 'jsQR');
            if (jsQRFunc != null) {
              final dynamic code = js_util.callMethod(html.window, 'jsQR', [
                imageData.data,
                canvas.width!,
                canvas.height!,
              ]);

              if (code != null) {
                final String? data = js_util.getProperty(code, 'data');
                if (data != null && data.trim().isNotEmpty) {
                  _stopCamera();
                  if (mounted) {
                    Navigator.pop(context, data.trim());
                  }
                  return;
                }
              }
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No QR Code found in uploaded image. Please try another photo.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: slate,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: maroon.withOpacity(0.8), shape: BoxShape.circle),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan Attendance QR',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Align Speaker podium QR within box',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Camera Viewfinder Box
              Container(
                width: 320,
                height: 320,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: gold, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isReady && _viewId != null)
                        HtmlElementView(viewType: _viewId!)
                      else if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 40),
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      else
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: gold),
                            SizedBox(height: 12),
                            Text('Starting camera...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),

                      // Scanning Frame & Moving Laser Line
                      if (_isReady)
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return Positioned(
                              top: 40 + (_animController.value * 220),
                              left: 30,
                              right: 30,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.transparent, Colors.greenAccent, Colors.transparent],
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.greenAccent.withOpacity(0.8), blurRadius: 8),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      // Target Corner Reticles
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons: Scan from Gallery & Manual Code
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.photo_library_rounded, size: 18, color: gold),
                        label: const Text('From Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _scanFromGalleryImage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.keyboard_rounded, size: 18, color: gold),
                        label: const Text('Enter Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          _showManualCodeDialog();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enter Session QR Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: _manualInput,
          decoration: InputDecoration(
            hintText: 'e.g. MAPCON2026-SESSION-4-1',
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: maroon, foregroundColor: Colors.white),
            onPressed: () {
              final text = _manualInput.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                _stopCamera();
                Navigator.pop(context, text);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
