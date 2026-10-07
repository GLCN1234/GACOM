import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import '../realm_shell.dart';
import 'windward_logic.dart';
import 'windward_painter.dart';

class WindwardScreen extends StatelessWidget {
  const WindwardScreen({super.key, this.config = const RealmConfig()});

  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    return RealmShell(
      gameName: 'Windward',
      title: 'Windward',
      story: 'The old trade winds are waking, and every island needs what another one grows. The harbour masters will only deal with captains who know their lessons. Read the wind, bring your cargo home, and make your name along the trade lanes.',
      howTo: 'Drag to steer: the ship turns toward where you point. Sail fastest with the wind behind you and never straight into it (the red wedge). TRIM gives a short burst of speed. Beside a port, tap ANCHOR to dock. At the quay, answer the harbour master to buy or sell: a right answer gets a better price, a wrong one a worse price. Take a contract, deliver the cargo and follow the gold arrow. Avoid reefs, rocks and storm clouds. The season lasts 12 minutes.',
      icon: Icons.sailing_rounded,
      accent: const Color(0xFF29B6F6),
      config: config,
      create: (RealmContent c) => WindwardLogic(c),
      painter: (RealmLogic l, Listenable r) => WindwardPainter(l as WindwardLogic, repaint: r),
      hud: _hud,
      actions: const <RealmAction>[
        RealmAction(0, Icons.bolt_rounded, 'TRIM'),
        RealmAction(1, Icons.anchor_rounded, 'ANCHOR'),
      ],
      background: const Color(0xFF1565A0),
    );
  }

  static const TextStyle _head = TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white, fontSize: 20, letterSpacing: 0.5);
  static const TextStyle _small = TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3);

  Widget _hud(BuildContext context, RealmLogic base, VoidCallback refresh) {
    final WindwardLogic l = base as WindwardLogic;
    final WindwardPort? p = l.harbour;
    if (p == null || l.over) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final OdySubject subj = l.content.subject(p.subjectId);
    final Color accent = realmLighten(subj.color, 0.12);
    final OdyQuestion? q = l.question;
    final Widget body = q != null ? _askPanel(l, p, q, subj, accent, refresh) : _quay(l, p, subj, accent, refresh);
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: body),
            ),
          ),
        ),
      ),
    );
  }

  Widget _askPanel(WindwardLogic l, WindwardPort p, OdyQuestion q, OdySubject subj, Color accent, VoidCallback refresh) {
    final String verb = l.tradeBuy ? 'Buying' : 'Selling';
    final String gn = windwardGoods[l.tradeGood].name.toLowerCase();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          '$verb 1 $gn. A right answer wins you a better price, a wrong one a worse price.',
          textAlign: TextAlign.center,
          style: _small,
        ),
      ),
      RealmQuestionPanel(
        question: q,
        accent: accent,
        header: 'Harbour master of ${p.name} - ${subj.label}',
        chosen: l.chosen,
        onPick: (int i) {
          l.answerTrade(i);
          refresh();
        },
        onContinue: () {
          l.continueTrade();
          refresh();
        },
        continueLabel: 'BACK TO THE QUAY',
        resultLine: l.resultLine,
      ),
    ]);
  }

  Widget _quay(WindwardLogic l, WindwardPort p, OdySubject subj, Color accent, VoidCallback refresh) {
    final WindwardContract? offer = l.offerAt(p);
    final WindwardContract? ac = l.active;
    final List<Widget> rows = <Widget>[];
    for (int g = 0; g < windwardGoods.length; g++) {
      rows.add(_goodRow(l, p, g, refresh));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xEE0B0B0F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent, width: 1.4),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _head.copyWith(fontSize: 24))),
          Text('${l.gold} gold', style: _head.copyWith(color: const Color(0xFFFFD54F))),
        ]),
        Row(children: <Widget>[
          Container(width: 9, height: 9, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text('Harbour master: ${subj.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _small)),
          Text('Hold ${l.cargoCount}/$windwardHold   Hull ${l.hull}/$windwardMaxHull', style: _small),
        ]),
        const SizedBox(height: 8),
        ...rows,
        if (l.harbourMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(l.harbourMsg, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFE082), fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        const SizedBox(height: 4),
        _contractCard(l, p, offer, ac, refresh),
        const SizedBox(height: 8),
        Row(children: <Widget>[
          Expanded(
            child: _wide(
              'Repair hull (${windwardRepairCost} gold)',
              l.hull < windwardMaxHull && l.gold >= windwardRepairCost,
              () {
                l.buyRepair();
                refresh();
              },
              secondary: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _wide('SET SAIL', true, () {
              l.leaveHarbour();
              refresh();
            }),
          ),
        ]),
      ]),
    );
  }

  Widget _goodRow(WindwardLogic l, WindwardPort p, int g, VoidCallback refresh) {
    final WindwardGood good = windwardGoods[g];
    final int buy = l.buyQuote(p, g);
    final int sell = l.sellQuote(p, g);
    final bool canBuy = l.canBuy(p, g);
    final bool canSell = l.canSell(g);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: <Widget>[
        Container(width: 8, height: 36, decoration: BoxDecoration(color: good.color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(good.name, style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
            Text('In hold: ${l.cargo[g]}', style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
          ]),
        ),
        _small44('Buy $buy', canBuy, () {
          l.beginTrade(true, g);
          refresh();
        }),
        const SizedBox(width: 6),
        _small44('Sell $sell', canSell, () {
          l.beginTrade(false, g);
          refresh();
        }),
      ]),
    );
  }

  Widget _small44(String label, bool enabled, VoidCallback onTap) {
    return SizedBox(
      width: 82,
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          disabledBackgroundColor: Colors.white12,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: enabled ? onTap : null,
        child: Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: enabled ? Colors.white : Colors.white38)),
      ),
    );
  }

  Widget _wide(String label, bool enabled, VoidCallback onTap, {bool secondary = false}) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondary ? Colors.white24 : const Color(0xFFFF6A00),
          disabledBackgroundColor: Colors.white12,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        ),
        onPressed: enabled ? onTap : null,
        child: Text(label, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13.5, color: enabled ? Colors.white : Colors.white38)),
      ),
    );
  }

  Widget _contractCard(WindwardLogic l, WindwardPort p, WindwardContract? offer, WindwardContract? ac, VoidCallback refresh) {
    final List<Widget> kids = <Widget>[];
    final bool atTarget = ac != null && ac.toKey == p.key;
    if (ac != null) {
      kids.add(Text('Active contract: ${ac.text}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)));
      kids.add(Text('Reward ${ac.reward} gold and a hull repair.', style: _small));
      if (atTarget) {
        final int have = l.cargo[ac.good];
        kids.add(const SizedBox(height: 6));
        kids.add(_wide(
          l.canDeliver ? 'DELIVER CARGO' : 'Need ${ac.qty} ${windwardGoods[ac.good].name.toLowerCase()} (have $have)',
          l.canDeliver,
          () {
            l.deliverContract();
            refresh();
          },
        ));
      } else {
        kids.add(Text('Follow the gold arrow to ${ac.toName}.', style: _small));
        kids.add(const SizedBox(height: 4));
        kids.add(SizedBox(
          height: 44,
          child: TextButton(
            onPressed: () {
              l.abandonContract();
              refresh();
            },
            child: const Text('Drop this contract', style: TextStyle(color: Colors.white54)),
          ),
        ));
      }
    } else if (offer == null) {
      kids.add(const Text('No contract is posted here today.', style: _small));
    } else if (l.doneOffers.contains(offer.id)) {
      kids.add(const Text('You have filled this port\'s contract. Check other ports for new work.', style: _small));
    } else {
      kids.add(Text('Posted: ${offer.text}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)));
      kids.add(Text('Reward ${offer.reward} gold and a hull repair.', style: _small));
      kids.add(const SizedBox(height: 6));
      kids.add(_wide('ACCEPT CONTRACT', true, () {
        l.acceptContract();
        refresh();
      }));
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
    );
  }
}
