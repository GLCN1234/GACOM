import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../darkom/darkom_armory.dart';
import '../darkom/darkom_look.dart';
import 'character_view.dart';
import 'rig.dart';

/// Route: '/character'. Your fighter in 3D, wearing what you have equipped.
class CharacterStudioScreen extends StatefulWidget {
  const CharacterStudioScreen({super.key});

  @override
  State<CharacterStudioScreen> createState() => _CharacterStudioScreenState();
}

class _CharacterStudioScreenState extends State<CharacterStudioScreen> {
  static const Color _ink = Color(0xFF0B0F1C);
  static const Color _cyan = Color(0xFF2ED3E6);
  static const Color _amber = Color(0xFFFFD54F);

  CharLook? _look;
  DarkomArmory? _armory;
  String _name = 'Player';
  String _weapon = 'sword';
  String _anim = 'idle';
  bool _auto = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    DarkomLook d;
    DarkomArmory a;
    try {
      d = await DarkomLook.mine(weaponKind: _weapon);
    } catch (_) {
      return;
    }
    try {
      a = await DarkomArmory.load();
    } catch (_) {
      a = DarkomArmory.plain();
    }
    if (!mounted) return;
    setState(() {
      _armory = a;
      _name = d.name;
      _look = CharLook.from(
        skin: d.skinColor,
        hair: d.hairColor,
        shirt: d.shirtColor,
        pants: d.pantsColor,
        hairStyle: d.hairStyle,
        weapon: _weapon,
        weaponAsset: a.assetFor(_weapon),
        frameColors: d.frameColors,
      );
    });
  }

  void _pickWeapon(String kind) {
    final CharLook? l = _look;
    final DarkomArmory? a = _armory;
    if (l == null || a == null) return;
    setState(() {
      _weapon = kind;
      _look = l.withWeapon(kind, a.assetFor(kind));
    });
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _chip(String label, bool on, VoidCallback tap, {IconData? icon}) => GestureDetector(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: on ? _cyan.withValues(alpha: 0.18) : Colors.white10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? _cyan : Colors.white24, width: on ? 1.6 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            if (icon != null) ...<Widget>[Icon(icon, size: 15, color: on ? _cyan : Colors.white60), const SizedBox(width: 6)],
            Text(label, style: TextStyle(color: on ? Colors.white : Colors.white70, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.4)),
          ]),
        ),
      );

  Widget _panel() {
    final DarkomArmory? a = _armory;
    final String skin = a == null ? 'Standard issue' : a.skinNameFor(_weapon);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(_name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text('${_cap(_weapon)}  |  $skin', style: const TextStyle(color: _amber, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 16),
        const Text('MOVES', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final String an in CharAnims.names) _chip(CharAnims.label(an), _anim == an, () => setState(() => _anim = an)),
        ]),
        const SizedBox(height: 16),
        const Text('WEAPON', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final String k in <String>['sword', 'dagger', 'hammer', 'axe', 'staff', 'shield']) _chip(_cap(k), _weapon == k, () => _pickWeapon(k)),
        ]),
        const SizedBox(height: 16),
        _chip(_auto ? 'Auto turn: on' : 'Auto turn: off', _auto, () => setState(() => _auto = !_auto), icon: Icons.threed_rotation_rounded),
        const SizedBox(height: 14),
        const Text('Drag the fighter to turn it. Skins and looks you equip in the shop show up here and in Darkom City.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CharLook? look = _look;
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
        elevation: 0,
        title: const Text('CHARACTER STUDIO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.canPop() ? context.pop() : context.go('/arena')),
      ),
      body: look == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (BuildContext c, BoxConstraints bc) {
              final Widget view = Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const RadialGradient(center: Alignment(0, 0.3), radius: 1.0, colors: <Color>[Color(0xFF1A2742), Color(0xFF0B0F1C)]),
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Character3DView(look: look, anim: _anim, autoRotate: _auto),
                ),
              );
              if (bc.maxWidth > bc.maxHeight) {
                return Row(children: <Widget>[
                  Expanded(child: view),
                  SizedBox(width: 300, child: _panel()),
                ]);
              }
              return Column(children: <Widget>[
                Expanded(flex: 5, child: view),
                Expanded(flex: 4, child: _panel()),
              ]);
            }),
    );
  }
}
