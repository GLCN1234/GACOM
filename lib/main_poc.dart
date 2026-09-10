// STANDALONE TEST ENTRY POINT — bypasses the entire app (no Supabase init,
// no auth, no splash screen, no router). This exists solely to prove out
// whether the FBX→GLB conversion pipeline actually renders, in isolation,
// so a hang/crash here can only mean one thing: the 3D asset or the
// model_viewer_plus package itself, nothing else in the app.
//
// Run with:  flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 -t lib/main_poc.dart
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

void main() => runApp(const Poc3dTestApp());

class Poc3dTestApp extends StatelessWidget {
  const Poc3dTestApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.red,
      appBar: AppBar(title: const Text('Isolated 3D Test — no app, no auth, just this')),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.grey[900],
          child: const Text(
            'Background is RED on purpose right now — this is a diagnostic step. '
            'If you see red, the app renders fine and the 3D model specifically is '
            'the problem. If you still see black, the 3D component never loaded at all.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: ModelViewer(
            backgroundColor: Colors.blue,
            src: Uri.base.resolve('assets/assets/models_3d/hammer_1.glb').toString(),
            alt: 'A low-poly hammer model',
            ar: false,
            autoRotate: true,
            cameraControls: true,
            disableZoom: false,
          ),
        ),
      ]),
    ),
  );
}
