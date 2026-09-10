import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../core/theme/app_theme.dart';

/// PROOF-OF-CONCEPT screen only — validates that a converted FBX→GLB
/// asset renders correctly, interactively (rotate/zoom/pan), on a real
/// device, before any of the 8 planned games get built on this foundation.
/// Safe to delete once the foundation is confirmed working.
class Poc3dScreen extends StatelessWidget {
  const Poc3dScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(
      title: const Text('3D Asset Proof of Concept',
        style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
    ),
    body: Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: GacomColors.cardDark,
        child: const Text(
          'Converted from a CraftPix hammer FBX → self-contained GLB (texture embedded, '
          'no external file dependencies). Drag to rotate, pinch to zoom. If this renders '
          'smoothly here, the 3D foundation is validated for building the full game set on.',
          style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.4),
        ),
      ),
      Expanded(
        child: ModelViewer(
          backgroundColor: GacomColors.obsidian,
          src: 'assets/models_3d/hammer_1.glb',
          alt: 'A low-poly hammer model',
          ar: false,
          autoRotate: true,
          cameraControls: true,
          disableZoom: false,
        ),
      ),
    ]),
  );
}
