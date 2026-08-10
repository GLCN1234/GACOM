import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CONNECT FOUR
// ═══════════════════════════════════════════════════════════════════════════
class ConnectFourGame extends StatefulWidget {
  const ConnectFourGame({super.key});
  @override State<ConnectFourGame> createState() => _ConnectFourState();
}
class _ConnectFourState extends State<ConnectFourGame> {
  static const rows=6, cols=7;
  List<List<int>> board = List.generate(rows, (_)=>List.filled(cols,0));
  int turn=1; String status='Your turn'; bool over=false;
  int wScore=0,aScore=0;

  void _drop(int col){
    if(over||turn!=1)return;
    for(int r=rows-1;r>=0;r--){
      if(board[r][col]==0){ board[r][col]=1; break; }
    }
    if(_checkWin(1)){setState((){status='You win!'; over=true; wScore++;}); return;}
    if(_full()){setState((){status='Draw!'; over=true;}); return;}
    setState((){turn=2; status='AI thinking...';});
    Future.delayed(const Duration(milliseconds:350),_aiMove);
  }

  void _aiMove(){
    int best=-1,bestScore=-999;
    for(int c=0;c<cols;c++){
      if(_canDrop(c)){
        final b2=_clone(); _doMove(b2,c,2);
        final s=_score(b2,2)-_score(b2,1);
        if(s>bestScore){bestScore=s;best=c;}
      }
    }
    if(best<0){for(int c=0;c<cols;c++){if(_canDrop(c)){best=c;break;}}}
    _doMove(board,best,2);
    if(_checkWin(2)){setState((){status='AI wins!'; over=true; aScore++;}); return;}
    if(_full()){setState((){status='Draw!'; over=true;}); return;}
    setState((){turn=1; status='Your turn';});
  }

  bool _canDrop(int c)=>board[0][c]==0;
  bool _full()=>!List.generate(cols,(c)=>_canDrop(c)).contains(true);
  List<List<int>> _clone()=>board.map((r)=>List<int>.from(r)).toList();
  void _doMove(List<List<int>> b, int col, int p){
    for(int r=rows-1;r>=0;r--){if(b[r][col]==0){b[r][col]=p;return;}}
  }
  int _score(List<List<int>> b, int p){
    int s=0;
    for(int r=0;r<rows;r++)for(int c=0;c<cols-3;c++){
      final w=[b[r][c],b[r][c+1],b[r][c+2],b[r][c+3]];
      s+=w.where((x)=>x==p).length*w.where((x)=>x==p).length;
    }
    return s;
  }
  bool _checkWin(int p){
    for(int r=0;r<rows;r++)for(int c=0;c<cols;c++){
      if(c+3<cols&&board[r][c]==p&&board[r][c+1]==p&&board[r][c+2]==p&&board[r][c+3]==p)return true;
      if(r+3<rows&&board[r][c]==p&&board[r+1][c]==p&&board[r+2][c]==p&&board[r+3][c]==p)return true;
      if(r+3<rows&&c+3<cols&&board[r][c]==p&&board[r+1][c+1]==p&&board[r+2][c+2]==p&&board[r+3][c+3]==p)return true;
      if(r+3<rows&&c-3>=0&&board[r][c]==p&&board[r+1][c-1]==p&&board[r+2][c-2]==p&&board[r+3][c-3]==p)return true;
    }
    return false;
  }
  void _reset(){setState((){board=List.generate(rows,(_)=>List.filled(cols,0));turn=1;over=false;status='Your turn';});}

  @override
  Widget build(BuildContext ctx)=>Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('CONNECT FOUR'), actions:[
      Text('You $wScore — AI $aScore',style:const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:13,color:GacomColors.textSecondary)),
      const SizedBox(width:12),
    ]),
    body: Column(children:[
      Padding(padding: const EdgeInsets.all(12),child: Text(status,style:const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:16,color:GacomColors.textPrimary),textAlign:TextAlign.center)),
      Expanded(child: Center(child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF0033AA), borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisSize:MainAxisSize.min, children:[
          Row(mainAxisAlignment:MainAxisAlignment.center, children: List.generate(cols,(c)=>
            GestureDetector(onTap:()=>_drop(c),child: Container(width:44,height:44,
              decoration: BoxDecoration(color: _canDrop(c)?GacomColors.deepOrange.withOpacity(0.3):Colors.transparent, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.arrow_drop_down_rounded,color:Colors.white70,size:28))))),
          ...List.generate(rows,(r)=>Row(mainAxisSize:MainAxisSize.min, children: List.generate(cols,(c){
            final v=board[r][c];
            return Container(width:44,height:44,margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape:BoxShape.circle,
                color: v==0?GacomColors.obsidian:v==1?GacomColors.deepOrange:const Color(0xFF3399FF)));
          }))),
          const SizedBox(height:8),
        ]),
      ))),
      Padding(padding: const EdgeInsets.all(16),child: SizedBox(width:double.infinity,
        child: ElevatedButton(onPressed:_reset,style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('NEW GAME',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,color:Colors.white))))),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// REVERSI / OTHELLO
// ═══════════════════════════════════════════════════════════════════════════
class ReversiGame extends StatefulWidget {
  const ReversiGame({super.key});
  @override State<ReversiGame> createState()=>_ReversiState();
}
class _ReversiState extends State<ReversiGame>{
  List<int> board=List.filled(64,0);
  bool playerBlack=true; String status=''; bool over=false;

  @override void initState(){super.initState();_reset();}

  void _reset(){
    board=List.filled(64,0);
    board[27]=2;board[28]=1;board[35]=1;board[36]=2;
    playerBlack=true; over=false; _updateStatus();
  }

  List<int> _valid(List<int> b, int p){
    final opp=p==1?2:1;
    final dirs=[-9,-8,-7,-1,1,7,8,9];
    List<int> moves=[];
    for(int sq=0;sq<64;sq++){
      if(b[sq]!=0)continue;
      for(final d in dirs){
        int t=sq+d; bool found=false;
        while(t>=0&&t<64&&(t%8-((t-d)%8)).abs()<=1&&b[t]==opp){t+=d;found=true;}
        if(found&&t>=0&&t<64&&b[t]==p&&(t%8-((t-d)%8)).abs()<=1)moves.add(sq);
      }
    }
    return moves.toSet().toList();
  }

  void _flip(List<int> b, int sq, int p){
    b[sq]=p;
    final opp=p==1?2:1;
    final dirs=[-9,-8,-7,-1,1,7,8,9];
    for(final d in dirs){
      List<int> toFlip=[];
      int t=sq+d;
      while(t>=0&&t<64&&(t%8-((t-d)%8)).abs()<=1&&b[t]==opp){toFlip.add(t);t+=d;}
      if(toFlip.isNotEmpty&&t>=0&&t<64&&b[t]==p&&(t%8-((t-d)%8)).abs()<=1){
        for(final f in toFlip){b[f]=p;}
      }
    }
  }

  void _move(int sq){
    if(over||!_valid(board,1).contains(sq))return;
    _flip(board,sq,1);
    if(_valid(board,2).isNotEmpty){
      setState((){playerBlack=false; _updateStatus();});
      Future.delayed(const Duration(milliseconds:400),_aiMove);
    } else if(_valid(board,1).isEmpty){
      setState((){over=true; _updateStatus();});
    } else {
      setState((){_updateStatus();});
    }
  }

  void _aiMove(){
    final moves=_valid(board,2);
    if(moves.isEmpty){setState((){playerBlack=true; _updateStatus();}); return;}
    int best=-1,bestScore=-999;
    for(final m in moves){
      final b2=List<int>.from(board); _flip(b2,m,2);
      final s=b2.where((x)=>x==2).length-b2.where((x)=>x==1).length;
      if(s>bestScore){bestScore=s;best=m;}
    }
    _flip(board,best,2);
    if(_valid(board,1).isNotEmpty){setState((){playerBlack=true; _updateStatus();});}
    else if(_valid(board,2).isEmpty){setState((){over=true; _updateStatus();});}
    else{setState((){_updateStatus();});}
  }

  void _updateStatus(){
    final b=board.where((x)=>x==1).length;
    final w=board.where((x)=>x==2).length;
    if(over||_valid(board,1).isEmpty&&_valid(board,2).isEmpty){
      over=true;
      status=b>w?'You win! $b — $w':b<w?'AI wins! $b — $w':'Draw! $b — $w';
    } else {
      status=playerBlack?'Your turn | You $b — AI $w':'AI thinking... $b — $w';
    }
  }

  @override
  Widget build(BuildContext ctx){
    final valid=_valid(board,1);
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('REVERSI')),
      body: Column(children:[
        Padding(padding: const EdgeInsets.all(12),child: Text(status,style:const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:15,color:GacomColors.textPrimary),textAlign:TextAlign.center)),
        Expanded(child: Center(child: AspectRatio(aspectRatio:1,child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF006600),borderRadius: BorderRadius.circular(8)),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:8,mainAxisSpacing:2,crossAxisSpacing:2),
            itemCount:64,
            itemBuilder:(_,i){
              final v=board[i]; final isV=valid.contains(i);
              return GestureDetector(onTap:()=>_move(i),
                child: Container(margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(color: const Color(0xFF008800),borderRadius: BorderRadius.circular(4)),
                  child: Center(child: v==0?(isV?Container(width:12,height:12,decoration: BoxDecoration(shape:BoxShape.circle,color:Colors.white.withOpacity(0.3))):null)
                    : Container(width:32,height:32,decoration: BoxDecoration(shape:BoxShape.circle,
                      color:v==1?Colors.black:const Color(0xFF3399FF),
                      boxShadow: const [BoxShadow(color:Colors.black38,blurRadius:3)]))),
                ));
            },
          ),
        )))),
        Padding(padding: const EdgeInsets.all(16),child: SizedBox(width:double.infinity,
          child: ElevatedButton(onPressed:_reset,style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
            child: const Text('NEW GAME',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,color:Colors.white))))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MEMORY MATCH
// ═══════════════════════════════════════════════════════════════════════════
class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});
  @override State<MemoryMatchGame> createState()=>_MemoryMatchState();
}
class _MemoryMatchState extends State<MemoryMatchGame>{
  static const _emojis=['🎮','🏆','⚡','🎯','🔥','💎','🚀','🎲','⭐','🎪','🎭','🎸'];
  late List<String> cards;
  List<bool> revealed=[], matched=[];
  int? first; bool waiting=false; int moves=0; int pairs=0;

  @override void initState(){super.initState();_reset();}
  void _reset(){
    final e=[..._emojis,..._emojis]..shuffle();
    setState((){cards=e;revealed=List.filled(24,false);matched=List.filled(24,false);first=null;waiting=false;moves=0;pairs=0;});
  }
  void _tap(int i){
    if(waiting||revealed[i]||matched[i])return;
    setState((){revealed[i]=true;});
    if(first==null){setState((){first=i;});}
    else{
      moves++;
      if(cards[first!]==cards[i]){
        setState((){matched[first!]=matched[i]=true;pairs++;first=null;});
      } else {
        waiting=true;
        Future.delayed(const Duration(milliseconds:800),(){
          setState((){revealed[first!]=revealed[i]=false;first=null;waiting=false;});
        });
      }
    }
  }
  @override
  Widget build(BuildContext ctx)=>Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('MEMORY MATCH'), actions:[
      Padding(padding: const EdgeInsets.only(right:12),child: Center(child: Text('Moves: $moves  Pairs: $pairs/12',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:13,color:GacomColors.textSecondary)))),
    ]),
    body: Column(children:[
      if(pairs==12) Padding(padding: const EdgeInsets.all(16),child: Text('Solved in $moves moves!',style:const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:18,color:GacomColors.deepOrange),textAlign:TextAlign.center)),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:4,crossAxisSpacing:8,mainAxisSpacing:8),
        itemCount:24,
        itemBuilder:(_,i)=>GestureDetector(onTap:()=>_tap(i),
          child: AnimatedContainer(duration: const Duration(milliseconds:200),
            decoration: BoxDecoration(
              color: matched[i]?GacomColors.success.withOpacity(0.2):revealed[i]?GacomColors.elevatedCard:GacomColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: matched[i]?GacomColors.success:GacomColors.border)),
            child: Center(child: Text(revealed[i]||matched[i]?cards[i]:'?',style: TextStyle(fontSize: revealed[i]||matched[i]?28:22,color: revealed[i]||matched[i]?null:GacomColors.textMuted))))),
      )),
      Padding(padding: const EdgeInsets.all(16),child: SizedBox(width:double.infinity,
        child: ElevatedButton(onPressed:_reset,style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('NEW GAME',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,color:Colors.white))))),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// WORD SCRAMBLE
// ═══════════════════════════════════════════════════════════════════════════
class WordScrambleGame extends StatefulWidget {
  const WordScrambleGame({super.key});
  @override State<WordScrambleGame> createState()=>_WordScrambleState();
}
class _WordScrambleState extends State<WordScrambleGame>{
  static const _words=['FLUTTER','GAMING','GACOM','ARENA','CHAMPION','BATTLE','STRATEGY','VICTORY','PUZZLE','ARCADE','TROPHY','LEGEND'];
  late String word, scrambled;
  final _ctrl=TextEditingController();
  String msg=''; int score=0; int streak=0;

  @override void initState(){super.initState();_next();}
  void _next(){
    word=_words[Random().nextInt(_words.length)];
    final l=word.split('')..shuffle();
    scrambled=l.join();
    _ctrl.clear(); setState((){msg='';});
  }
  void _check(){
    if(_ctrl.text.toUpperCase()==word){
      score+=10+streak*2; streak++;
      setState((){msg='Correct! +${10+streak*2} pts';});
      Future.delayed(const Duration(milliseconds:800),_next);
    } else {
      streak=0; setState((){msg='Try again!';});
    }
  }
  @override
  Widget build(BuildContext ctx)=>Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('WORD SCRAMBLE'), actions:[
      Padding(padding: const EdgeInsets.only(right:12),child: Center(child: Text('Score: $score',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:14,color:GacomColors.deepOrange)))),
    ]),
    body: Padding(padding: const EdgeInsets.all(16),child: Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Text('Unscramble this word:',style: const TextStyle(color:GacomColors.textMuted,fontSize:14)),
      const SizedBox(height:16),
      Text(scrambled,style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:42,color:GacomColors.deepOrange,letterSpacing:8)),
      const SizedBox(height:8),
      Text('${word.length} letters',style: const TextStyle(color:GacomColors.textMuted,fontSize:12)),
      const SizedBox(height:32),
      TextField(controller:_ctrl,textCapitalization:TextCapitalization.characters,
        style: const TextStyle(color:GacomColors.textPrimary,fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:24,letterSpacing:4),
        textAlign:TextAlign.center,
        decoration: InputDecoration(hintText:'TYPE HERE',hintStyle: const TextStyle(color:GacomColors.textMuted),
          filled:true,fillColor:GacomColors.elevatedCard,border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),borderSide: const BorderSide(color:GacomColors.border)))),
      const SizedBox(height:16),
      if(msg.isNotEmpty) Text(msg,style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:16,color:msg.startsWith('Correct')?GacomColors.success:GacomColors.error)),
      const SizedBox(height:16),
      SizedBox(width:double.infinity,child: ElevatedButton(onPressed:_check,
        style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,padding: const EdgeInsets.symmetric(vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
        child: const Text('CHECK',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:16,color:Colors.white)))),
      const SizedBox(height:8),
      TextButton(onPressed:_next,child: const Text('SKIP',style:TextStyle(color:GacomColors.textMuted,fontFamily:'Rajdhani',fontWeight:FontWeight.w700))),
    ])),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 2048
// ═══════════════════════════════════════════════════════════════════════════
class Game2048 extends StatefulWidget {
  const Game2048({super.key});
  @override State<Game2048> createState()=>_Game2048State();
}
class _Game2048State extends State<Game2048>{
  List<List<int>> board=[];
  int score=0; bool over=false;

  @override void initState(){super.initState();_reset();}

  void _reset(){
    board=List.generate(4,(_)=>List.filled(4,0));
    score=0; over=false;
    _addTile(); _addTile();
    setState((){});
  }

  void _addTile(){
    final empty=[];
    for(int r=0;r<4;r++)for(int c=0;c<4;c++)if(board[r][c]==0)empty.add([r,c]);
    if(empty.isEmpty)return;
    final pos=empty[Random().nextInt(empty.length)];
    board[pos[0]][pos[1]]=Random().nextDouble()<0.9?2:4;
  }

  bool _slide(String dir){
    final prev=board.map((r)=>List<int>.from(r)).toList();
    List<List<int>> rows=[];
    if(dir=='left'||dir=='right')rows=board;
    else rows=List.generate(4,(c)=>List.generate(4,(r)=>board[r][c]));
    bool changed=false;
    for(final row in rows){
      final rev=dir=='right'||dir=='down';
      if(rev)row.setAll(0,row.reversed.toList());
      final nums=row.where((x)=>x!=0).toList();
      final merged=<int>[];
      int i=0;
      while(i<nums.length){
        if(i+1<nums.length&&nums[i]==nums[i+1]){merged.add(nums[i]*2);score+=nums[i]*2;i+=2;}
        else{merged.add(nums[i]);i++;}
      }
      while(merged.length<4)merged.add(0);
      if(rev)merged.setAll(0,merged.reversed.toList());
      row.setAll(0,merged);
    }
    if(dir=='up'||dir=='down'){
      for(int r=0;r<4;r++)for(int c=0;c<4;c++)board[r][c]=rows[c][r];
    }
    for(int r=0;r<4;r++)for(int c=0;c<4;c++)if(board[r][c]!=prev[r][c])changed=true;
    return changed;
  }

  Color _tileColor(int v){
    const colors={0:Color(0xFF1A1A22),2:Color(0xFF3D3D4A),4:Color(0xFF5A3E2B),8:Color(0xFFD44C00),
      16:Color(0xFFE05C00),32:Color(0xFFEA6C10),64:Color(0xFFF07C20),128:Color(0xFFF5C518),
      256:Color(0xFFF7CE18),512:Color(0xFFF9D418),1024:Color(0xFFEDC53F),2048:Color(0xFFECC22E)};
    return colors[v]??const Color(0xFF3F3F4A);
  }

  @override
  Widget build(BuildContext ctx)=>GestureDetector(
    onHorizontalDragEnd:(d){if(d.primaryVelocity!>0)_doSlide('right');else _doSlide('left');},
    onVerticalDragEnd:(d){if(d.primaryVelocity!>0)_doSlide('down');else _doSlide('up');},
    child: Scaffold(backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('2048'), actions:[
        Padding(padding: const EdgeInsets.only(right:12),child: Center(child: Text('Score: $score',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:14,color:GacomColors.deepOrange)))),
      ]),
      body: Column(children:[
        if(over) const Padding(padding: EdgeInsets.all(12),child: Text('Game Over!',style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:20,color:GacomColors.error))),
        Expanded(child: Center(child: AspectRatio(aspectRatio:1,child: Container(
          margin: const EdgeInsets.all(12),padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: GacomColors.cardDark,borderRadius: BorderRadius.circular(16)),
          child: GridView.builder(physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:4,crossAxisSpacing:6,mainAxisSpacing:6),
            itemCount:16,
            itemBuilder:(_,i){
              final v=board[i~/4][i%4];
              return AnimatedContainer(duration: const Duration(milliseconds:100),
                decoration: BoxDecoration(color:_tileColor(v),borderRadius: BorderRadius.circular(8)),
                child: Center(child: v==0?null:Text('$v',style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:v>=1000?16:v>=100?20:24,color: v<=4?GacomColors.textSecondary:Colors.white))));
            }),
        )))),
        Padding(padding: const EdgeInsets.all(8),child: const Text('Swipe to move tiles',style: TextStyle(color:GacomColors.textMuted,fontSize:12))),
        Padding(padding: const EdgeInsets.fromLTRB(16,0,16,16),child: SizedBox(width:double.infinity,
          child: ElevatedButton(onPressed:_reset,style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
            child: const Text('NEW GAME',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,color:Colors.white))))),
      ]),
    ),
  );

  void _doSlide(String dir){
    if(over)return;
    final changed=_slide(dir);
    if(changed){_addTile();}
    bool hasMove=false;
    for(final r in board)for(final v in r)if(v==0)hasMove=true;
    if(!hasMove)for(int r=0;r<4;r++)for(int c=0;c<4;c++){
      if(c+1<4&&board[r][c]==board[r][c+1])hasMove=true;
      if(r+1<4&&board[r][c]==board[r+1][c])hasMove=true;
    }
    setState((){if(!hasMove)over=true;});
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HANGMAN
// ═══════════════════════════════════════════════════════════════════════════
class HangmanGame extends StatefulWidget {
  const HangmanGame({super.key});
  @override State<HangmanGame> createState()=>_HangmanState();
}
class _HangmanState extends State<HangmanGame>{
  static const _words=['FLUTTER','GAMING','CHAMPION','STRATEGY','GACOM','ARENA','VICTORY','PUZZLE'];
  late String word;
  Set<String> guessed={};
  int wrong=0; int score=0;

  @override void initState(){super.initState();_next();}
  void _next(){word=_words[Random().nextInt(_words.length)];guessed={};wrong=0;setState((){}); }

  void _guess(String l){
    if(guessed.contains(l))return;
    setState((){guessed.add(l);if(!word.contains(l))wrong++;});
    if(_solved){score+=10;Future.delayed(const Duration(milliseconds:600),_next);}
    if(wrong>=7){Future.delayed(const Duration(milliseconds:800),_next);}
  }

  bool get _solved=>word.split('').every((l)=>guessed.contains(l));

  static const _stages=[
    '😵','😨','😰','😟','😐','🙂','😄','🎉'
  ];

  @override
  Widget build(BuildContext ctx){
    final display=word.split('').map((l)=>guessed.contains(l)?l:'_').join(' ');
    return Scaffold(backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('HANGMAN'), actions:[
        Padding(padding: const EdgeInsets.only(right:12),child: Center(child: Text('Score: $score',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:14,color:GacomColors.deepOrange)))),
      ]),
      body: Padding(padding: const EdgeInsets.all(16),child: Column(children:[
        Text(_stages[min(7-wrong,7)],style: const TextStyle(fontSize:80)),
        const SizedBox(height:8),
        Text('${7-wrong} lives left',style: const TextStyle(color:GacomColors.textMuted,fontSize:13)),
        const SizedBox(height:24),
        Text(display,style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:32,color:GacomColors.textPrimary,letterSpacing:4)),
        const SizedBox(height:32),
        Wrap(spacing:8,runSpacing:8,alignment:WrapAlignment.center,
          children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((l){
            final used=guessed.contains(l);
            final correct=used&&word.contains(l);
            return GestureDetector(onTap:()=>_guess(l),
              child: AnimatedContainer(duration: const Duration(milliseconds:150),
                width:38,height:38,
                decoration: BoxDecoration(
                  color: used?(correct?GacomColors.success.withOpacity(0.2):GacomColors.error.withOpacity(0.2)):GacomColors.elevatedCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: used?(correct?GacomColors.success:GacomColors.error):GacomColors.border)),
                child: Center(child: Text(l,style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:14,color: used?(correct?GacomColors.success:GacomColors.error):GacomColors.textPrimary)))));
          }).toList()),
        const Spacer(),
        SizedBox(width:double.infinity,child: ElevatedButton(onPressed:_next,
          style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('NEW WORD',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,color:Colors.white)))),
      ])),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SPEED MATH
// ═══════════════════════════════════════════════════════════════════════════
class SpeedMathGame extends StatefulWidget {
  const SpeedMathGame({super.key});
  @override State<SpeedMathGame> createState()=>_SpeedMathState();
}
class _SpeedMathState extends State<SpeedMathGame>{
  int a=0,b=0,score=0,streak=0,timeLeft=30;
  String op='+'; int answer=0;
  final _ctrl=TextEditingController();
  Timer? _timer; bool started=false;

  void _start(){
    started=true; timeLeft=30; score=0; streak=0;
    _timer=Timer.periodic(const Duration(seconds:1),(_){
      setState((){timeLeft--;});
      if(timeLeft<=0){_timer?.cancel();setState((){started=false;});}
    });
    _next();
  }

  void _next(){
    final ops=['+','-','×'];
    op=ops[Random().nextInt(3)];
    a=Random().nextInt(20)+1; b=Random().nextInt(20)+1;
    if(op=='-'&&b>a){final t=a;a=b;b=t;}
    answer=op=='+'?a+b:op=='-'?a-b:a*b;
    _ctrl.clear(); setState((){});
  }

  void _check(){
    final v=int.tryParse(_ctrl.text);
    if(v==answer){streak++;score+=10+streak;_next();}
    else{streak=0;_ctrl.clear();}
  }

  @override void dispose(){_timer?.cancel();_ctrl.dispose();super.dispose();}

  @override
  Widget build(BuildContext ctx)=>Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('SPEED MATH')),
    body: Padding(padding: const EdgeInsets.all(16),child: Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      if(!started)...[
        const Text('Speed Math',style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:28,color:GacomColors.deepOrange)),
        const SizedBox(height:8),
        Text('Score: $score',style: const TextStyle(fontFamily:'Rajdhani',fontSize:18,color:GacomColors.textSecondary)),
        const SizedBox(height:32),
        SizedBox(width:double.infinity,child: ElevatedButton(onPressed:_start,
          style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,padding: const EdgeInsets.symmetric(vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('START',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:18,color:Colors.white)))),
      ] else ...[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          Text('Score: $score',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:16,color:GacomColors.deepOrange)),
          Text('⏱ ${timeLeft}s',style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:16,color:timeLeft<=10?GacomColors.error:GacomColors.textPrimary)),
        ]),
        const SizedBox(height:48),
        Text('$a $op $b = ?',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:52,color:GacomColors.textPrimary)),
        const SizedBox(height:32),
        TextField(controller:_ctrl,keyboardType:TextInputType.number,autofocus:true,onSubmitted:(_)=>_check(),
          style: const TextStyle(color:GacomColors.textPrimary,fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:32),
          textAlign:TextAlign.center,
          decoration: InputDecoration(hintText:'?',hintStyle: const TextStyle(color:GacomColors.textMuted),
            filled:true,fillColor:GacomColors.elevatedCard,border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),borderSide: const BorderSide(color:GacomColors.border)))),
        const SizedBox(height:16),
        SizedBox(width:double.infinity,child: ElevatedButton(onPressed:_check,
          style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,padding: const EdgeInsets.symmetric(vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('SUBMIT',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:18,color:Colors.white)))),
      ],
    ])),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// SIMON SAYS
// ═══════════════════════════════════════════════════════════════════════════
class SimonSaysGame extends StatefulWidget {
  const SimonSaysGame({super.key});
  @override State<SimonSaysGame> createState()=>_SimonSaysState();
}
class _SimonSaysState extends State<SimonSaysGame>{
  static const _colors=[Colors.red,Colors.green,Colors.blue,Colors.yellow];
  static const _labels=['🔴','🟢','🔵','🟡'];
  List<int> sequence=[]; List<int> input=[]; bool showing=false; int active=-1; int score=0; bool started=false;

  void _start(){setState((){started=true;sequence=[];input=[];score=0;_addAndShow();});}

  void _addAndShow(){
    sequence.add(Random().nextInt(4));
    input=[]; showing=true;
    _playSequence();
  }

  void _playSequence() async {
    await Future.delayed(const Duration(milliseconds:600));
    for(final s in sequence){
      setState((){active=s;});
      await Future.delayed(const Duration(milliseconds:500));
      setState((){active=-1;});
      await Future.delayed(const Duration(milliseconds:300));
    }
    setState((){showing=false;});
  }

  void _tap(int i){
    if(showing)return;
    input.add(i);
    if(input[input.length-1]!=sequence[input.length-1]){
      setState((){started=false;});
      return;
    }
    if(input.length==sequence.length){
      score+=sequence.length;
      setState((){showing=true;});
      Future.delayed(const Duration(milliseconds:600),_addAndShow);
    }
  }

  @override
  Widget build(BuildContext ctx)=>Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('SIMON SAYS'), actions:[
      Padding(padding: const EdgeInsets.only(right:12),child: Center(child: Text('Score: $score',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:14,color:GacomColors.deepOrange)))),
    ]),
    body: Padding(padding: const EdgeInsets.all(24),child: Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      if(!started)...[
        const Text('Simon Says',style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:28,color:GacomColors.deepOrange)),
        const SizedBox(height:8),
        Text('Last score: $score',style: const TextStyle(color:GacomColors.textMuted)),
        const SizedBox(height:32),
        SizedBox(width:double.infinity,child: ElevatedButton(onPressed:_start,
          style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,padding: const EdgeInsets.symmetric(vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('START',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:18,color:Colors.white)))),
      ] else ...[
        Text(showing?'Watch carefully...':'Your turn! Step ${input.length+1}/${sequence.length}',
          style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:16,color:GacomColors.textSecondary)),
        const SizedBox(height:48),
        GridView.count(crossAxisCount:2,shrinkWrap:true,mainAxisSpacing:16,crossAxisSpacing:16,children: List.generate(4,(i)=>
          GestureDetector(onTap:()=>_tap(i),
            child: AnimatedContainer(duration: const Duration(milliseconds:100),
              decoration: BoxDecoration(
                color: active==i?_colors[i]:_colors[i].withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _colors[i].withOpacity(0.6),width:2)),
              child: Center(child: Text(_labels[i],style: const TextStyle(fontSize:48))))))),
      ],
    ])),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// MINESWEEPER
// ═══════════════════════════════════════════════════════════════════════════
class MinesweeperGame extends StatefulWidget {
  const MinesweeperGame({super.key});
  @override State<MinesweeperGame> createState()=>_MinesweeperState();
}
class _MinesweeperState extends State<MinesweeperGame>{
  static const rows=9, cols=9, mines=10;
  List<bool> mine=[], revealed=[], flagged=[];
  bool over=false; bool won=false;

  @override void initState(){super.initState();_reset();}
  void _reset(){
    mine=List.filled(rows*cols,false);
    revealed=List.filled(rows*cols,false);
    flagged=List.filled(rows*cols,false);
    over=false; won=false;
    final positions=List.generate(rows*cols,(i)=>i)..shuffle();
    for(int i=0;i<mines;i++)mine[positions[i]]=true;
    setState((){});
  }

  int _adj(int i){
    int count=0;
    final r=i~/cols,c=i%cols;
    for(int dr=-1;dr<=1;dr++)for(int dc=-1;dc<=1;dc++){
      final nr=r+dr,nc=c+dc;
      if(nr>=0&&nr<rows&&nc>=0&&nc<cols&&mine[nr*cols+nc])count++;
    }
    return count;
  }

  void _reveal(int i){
    if(revealed[i]||flagged[i])return;
    revealed[i]=true;
    if(mine[i]){for(int j=0;j<mine.length;j++)if(mine[j])revealed[j]=true;over=true;return;}
    if(_adj(i)==0){
      final r=i~/cols,c=i%cols;
      for(int dr=-1;dr<=1;dr++)for(int dc=-1;dc<=1;dc++){
        final nr=r+dr,nc=c+dc;
        if(nr>=0&&nr<rows&&nc>=0&&nc<cols)_reveal(nr*cols+nc);
      }
    }
    if(revealed.where((x)=>x).length==rows*cols-mines)won=true;
  }

  Color _numColor(int n){
    const colors=[Colors.transparent,Colors.blue,Colors.green,Colors.red,Color(0xFF000080),Color(0xFF800000),Colors.teal,Colors.black,Colors.grey];
    return n<colors.length?colors[n]:Colors.grey;
  }

  @override
  Widget build(BuildContext ctx)=>Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('MINESWEEPER'), actions:[
      IconButton(icon: const Icon(Icons.refresh_rounded,color:GacomColors.deepOrange),onPressed:_reset),
    ]),
    body: Column(children:[
      Padding(padding: const EdgeInsets.all(12),child: Text(over?'Game Over!':won?'You won!':'Find all mines',
        style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:16,color:GacomColors.textPrimary),textAlign:TextAlign.center)),
      Expanded(child: Center(child: AspectRatio(aspectRatio:1,child: GridView.builder(
        padding: const EdgeInsets.all(4),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:cols,mainAxisSpacing:2,crossAxisSpacing:2),
        itemCount:rows*cols,
        itemBuilder:(_,i){
          final r=revealed[i]; final f=flagged[i]; final m=mine[i];
          final adj=r&&!m?_adj(i):0;
          return GestureDetector(
            onTap:(){if(!over&&!won){setState((){_reveal(i);});}},
            onLongPress:(){if(!over&&!won&&!revealed[i])setState((){flagged[i]=!flagged[i];});},
            child: Container(
              decoration: BoxDecoration(
                color: r?(m?GacomColors.error.withOpacity(0.4):GacomColors.elevatedCard):GacomColors.cardDark,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: r?GacomColors.border:GacomColors.textMuted.withOpacity(0.3))),
              child: Center(child: Text(
                f?'F':r?(m?'X':adj>0?'$adj':''):'',
                style: TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:_numColor(adj))))));
        },
      )))),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// BLACKJACK
// ═══════════════════════════════════════════════════════════════════════════
class BlackjackGame extends StatefulWidget {
  const BlackjackGame({super.key});
  @override State<BlackjackGame> createState()=>_BlackjackState();
}
class _BlackjackState extends State<BlackjackGame>{
  static const _suits=['♠','♥','♦','♣'];
  static const _ranks=['A','2','3','4','5','6','7','8','9','10','J','Q','K'];
  List<String> deck=[];
  List<String> pHand=[], dHand=[];
  bool playing=false; bool dRevealed=false;
  String msg=''; int pScore=0,dScore=0;

  List<String> _newDeck(){
    final d=<String>[];
    for(final s in _suits)for(final r in _ranks)d.add('$r$s');
    return d..shuffle();
  }
  int _val(List<String> hand){
    int v=0,aces=0;
    for(final c in hand){
      final r=c.replaceAll(RegExp(r'[♠♥♦♣]'),'');
      if(r=='A'){v+=11;aces++;}
      else if(['J','Q','K'].contains(r))v+=10;
      else v+=int.parse(r);
    }
    while(v>21&&aces>0){v-=10;aces--;}
    return v;
  }
  void _deal(){
    deck=_newDeck();
    pHand=[deck.removeLast(),deck.removeLast()];
    dHand=[deck.removeLast(),deck.removeLast()];
    setState((){playing=true;dRevealed=false;msg='';});
  }
  void _hit(){
    pHand.add(deck.removeLast());
    if(_val(pHand)>21){setState((){dScore++;msg='Bust! Dealer wins.';playing=false;dRevealed=true;});}
    else setState((){});
  }
  void _stand(){
    dRevealed=true;
    while(_val(dHand)<17)dHand.add(deck.removeLast());
    final pv=_val(pHand),dv=_val(dHand);
    if(dv>21||pv>dv){pScore++;msg='You win! $pv vs $dv';}
    else if(pv==dv){msg='Push! $pv vs $dv';}
    else{dScore++;msg='Dealer wins. $pv vs $dv';}
    setState((){playing=false;});
  }

  Widget _card(String c){
    final isRed=c.contains('♥')||c.contains('♦');
    return Container(margin: const EdgeInsets.only(right:4),padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color:Colors.white,borderRadius: BorderRadius.circular(8)),
      child: Text(c,style: TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:isRed?Colors.red:Colors.black)));
  }

  @override
  Widget build(BuildContext ctx)=>Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('BLACKJACK'), actions:[
      Padding(padding: const EdgeInsets.only(right:12),child: Center(child: Text('You $pScore — AI $dScore',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:13,color:GacomColors.textSecondary)))),
    ]),
    body: Padding(padding: const EdgeInsets.all(16),child: Column(children:[
      const Text('DEALER',style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:12,color:GacomColors.textMuted,letterSpacing:1)),
      const SizedBox(height:8),
      Row(children: playing&&!dRevealed?[_card(dHand.first),Container(margin: const EdgeInsets.only(right:4),padding: const EdgeInsets.all(8),decoration: BoxDecoration(color:GacomColors.elevatedCard,borderRadius: BorderRadius.circular(8)),child: const Text('🂠',style: TextStyle(fontSize:20)))]:dHand.map(_card).toList()),
      if(dRevealed||!playing) Text('Dealer: ${_val(dHand)}',style: const TextStyle(color:GacomColors.textMuted,fontSize:13)),
      const Spacer(),
      if(msg.isNotEmpty) Text(msg,style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:20,color:msg.contains('win!')&&msg.contains('You')?GacomColors.success:GacomColors.error),textAlign:TextAlign.center),
      const Spacer(),
      const Text('YOU',style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:12,color:GacomColors.textMuted,letterSpacing:1)),
      const SizedBox(height:8),
      Row(children: pHand.map(_card).toList()),
      if(pHand.isNotEmpty) Text('Total: ${_val(pHand)}',style: TextStyle(color:_val(pHand)>21?GacomColors.error:GacomColors.textSecondary,fontSize:13)),
      const SizedBox(height:24),
      if(!playing)
        SizedBox(width:double.infinity,child: ElevatedButton(onPressed:_deal,
          style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,padding: const EdgeInsets.symmetric(vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('DEAL',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:18,color:Colors.white))))
      else Row(children:[
        Expanded(child: OutlinedButton(onPressed:_hit,
          style:OutlinedButton.styleFrom(side: const BorderSide(color:GacomColors.deepOrange),padding: const EdgeInsets.symmetric(vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('HIT',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:16,color:GacomColors.deepOrange)))),
        const SizedBox(width:12),
        Expanded(child: ElevatedButton(onPressed:_stand,
          style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,padding: const EdgeInsets.symmetric(vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('STAND',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:16,color:Colors.white)))),
      ]),
    ])),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DOTS & BOXES
// ═══════════════════════════════════════════════════════════════════════════
class DotsAndBoxesGame extends StatefulWidget {
  const DotsAndBoxesGame({super.key});
  @override State<DotsAndBoxesGame> createState()=>_DotsBoxesState();
}
class _DotsBoxesState extends State<DotsAndBoxesGame>{
  static const n=4;
  // hLines[row][col]: row 0..n, col 0..n-1
  // vLines[row][col]: row 0..n-1, col 0..n
  List<List<bool>> hLines=[], vLines=[];
  List<List<int>> boxes=[];
  int turn=1,pScore=0,aScore=0; bool over=false;

  @override void initState(){super.initState();_reset();}
  void _reset(){
    hLines=List.generate(n+1,(_)=>List.filled(n,false));
    vLines=List.generate(n,(_)=>List.filled(n+1,false));
    boxes=List.generate(n,(_)=>List.filled(n,0));
    turn=1;pScore=0;aScore=0;over=false;setState((){});
  }

  bool _check(){
    bool scored=false;
    for(int r=0;r<n;r++)for(int c=0;c<n;c++){
      if(boxes[r][c]!=0)continue;
      if(hLines[r][c]&&hLines[r+1][c]&&vLines[r][c]&&vLines[r][c+1]){
        boxes[r][c]=turn;
        if(turn==1)pScore++;else aScore++;
        scored=true;
      }
    }
    return scored;
  }

  void _hLine(int r,int c){
    if(hLines[r][c]||over||turn!=1)return;
    hLines[r][c]=true;
    final s=_check();
    final total=boxes.expand((x)=>x).where((x)=>x!=0).length;
    if(total==n*n){setState((){over=true;});return;}
    if(!s)setState((){turn=2;});
    else setState((){});
    if(turn==2)Future.delayed(const Duration(milliseconds:400),_aiMove);
  }

  void _vLine(int r,int c){
    if(vLines[r][c]||over||turn!=1)return;
    vLines[r][c]=true;
    final s=_check();
    final total=boxes.expand((x)=>x).where((x)=>x!=0).length;
    if(total==n*n){setState((){over=true;});return;}
    if(!s)setState((){turn=2;});
    else setState((){});
    if(turn==2)Future.delayed(const Duration(milliseconds:400),_aiMove);
  }

  void _aiMove(){
    // Try to complete a box first, else pick random empty line
    List<Function()> complete=[],other=[];
    for(int r=0;r<=n;r++)for(int c=0;c<n;c++){
      if(!hLines[r][c]){
        int adj=0;
        if(r>0){final b=boxes[r-1][c];if(b==0){if(hLines[r-1][c])adj++;if(vLines[r-1][c])adj++;if(vLines[r-1][c+1])adj++;if(adj==3)complete.add(()=>hLines[r][c]=true);else other.add(()=>hLines[r][c]=true);}}
        else other.add(()=>hLines[r][c]=true);
      }
    }
    for(int r=0;r<n;r++)for(int c=0;c<=n;c++){
      if(!vLines[r][c])other.add(()=>vLines[r][c]=true);
    }
    void doMove(Function() m){m();final s=_check();final total=boxes.expand((x)=>x).where((x)=>x!=0).length;if(total==n*n){setState((){over=true;});return;}if(!s)setState((){turn=1;});else{setState((){});Future.delayed(const Duration(milliseconds:300),_aiMove);}}
    if(complete.isNotEmpty)doMove(complete.first);
    else if(other.isNotEmpty)doMove(other[Random().nextInt(other.length)]);
  }

  @override
  Widget build(BuildContext ctx){
    final w=(MediaQuery.of(ctx).size.width-32)/(n);
    return Scaffold(backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('DOTS & BOXES'), actions:[
        Padding(padding: const EdgeInsets.only(right:12),child: Center(child: Text('You $pScore — AI $aScore',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:13,color:GacomColors.textSecondary)))),
      ]),
      body: Column(children:[
        Padding(padding: const EdgeInsets.all(12),child: Text(over?(pScore>aScore?'You win!':pScore==aScore?'Draw!':'AI wins'):(turn==1?'Your turn':'AI thinking...'),
          style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:16,color:GacomColors.textPrimary),textAlign:TextAlign.center)),
        Expanded(child: Center(child: SizedBox(width:w*(n+0.5),height:w*(n+0.5),
          child: CustomPaint(painter:_DotsPainter(hLines,vLines,boxes,w),
            child: GestureDetector(onTapDown:(d){
              final x=d.localPosition.dx,y=d.localPosition.dy;
              for(int r=0;r<=n;r++)for(int c=0;c<n;c++){
                final lx=c*w+w*0.2,ly=r*w-8;
                if(x>lx&&x<lx+w*0.6&&y>ly&&y<ly+16){_hLine(r,c);return;}
              }
              for(int r=0;r<n;r++)for(int c=0;c<=n;c++){
                final lx=c*w-8,ly=r*w+w*0.2;
                if(x>lx&&x<lx+16&&y>ly&&y<ly+w*0.6){_vLine(r,c);return;}
              }
            }),
          ),
        ))),
        Padding(padding: const EdgeInsets.all(16),child: SizedBox(width:double.infinity,
          child: ElevatedButton(onPressed:_reset,style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
            child: const Text('NEW GAME',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,color:Colors.white))))),
      ]),
    );
  }
}

class _DotsPainter extends CustomPainter{
  final List<List<bool>> hLines,vLines;
  final List<List<int>> boxes;
  final double w;
  _DotsPainter(this.hLines,this.vLines,this.boxes,this.w);
  @override void paint(Canvas canvas,Size size){
    final n=boxes.length;
    for(int r=0;r<n;r++)for(int c=0;c<n;c++){
      if(boxes[r][c]!=0){
        canvas.drawRect(Rect.fromLTWH(c*w+4,r*w+4,w-8,w-8),
          Paint()..color=(boxes[r][c]==1?const Color(0xFFFF6A00):const Color(0xFF3399FF)).withOpacity(0.3));
      }
    }
    final lPaint=Paint()..strokeWidth=3..strokeCap=StrokeCap.round;
    for(int r=0;r<=n;r++)for(int c=0;c<n;c++){
      lPaint.color=hLines[r][c]?const Color(0xFFFF6A00):Colors.white12;
      canvas.drawLine(Offset(c*w+8,r*w),Offset((c+1)*w-8,r*w),lPaint);
    }
    for(int r=0;r<n;r++)for(int c=0;c<=n;c++){
      lPaint.color=vLines[r][c]?const Color(0xFFFF6A00):Colors.white12;
      canvas.drawLine(Offset(c*w,r*w+8),Offset(c*w,(r+1)*w-8),lPaint);
    }
    final dPaint=Paint()..color=Colors.white;
    for(int r=0;r<=n;r++)for(int c=0;c<=n;c++){
      canvas.drawCircle(Offset(c*w,r*w),5,dPaint);
    }
  }
  @override bool shouldRepaint(_)=>true;
}

// ═══════════════════════════════════════════════════════════════════════════
// NUMBER QUIZ (vs AI, 1v1 feel — fastest to answer wins)
// ═══════════════════════════════════════════════════════════════════════════
class NumberQuizGame extends StatefulWidget {
  const NumberQuizGame({super.key});
  @override State<NumberQuizGame> createState()=>_NumberQuizState();
}
class _NumberQuizState extends State<NumberQuizGame>{
  int a=0,b=0,answer=0,pScore=0,aScore=0;
  String op=''; final _ctrl=TextEditingController();
  String msg=''; bool answered=false;
  Timer? _aiTimer;

  @override void initState(){super.initState();_next();}
  @override void dispose(){_aiTimer?.cancel();_ctrl.dispose();super.dispose();}

  void _next(){
    _aiTimer?.cancel();
    final ops=['+','-','×','÷'];
    op=ops[Random().nextInt(ops.length)];
    if(op=='÷'){b=Random().nextInt(9)+1;a=b*(Random().nextInt(9)+1);}
    else{a=Random().nextInt(30)+1;b=Random().nextInt(30)+1;}
    answer=op=='+'?a+b:op=='-'?a-b:op=='×'?a*b:a~/b;
    if(op=='-'&&answer<0){answer=-answer;final t=a;a=b;b=t;}
    _ctrl.clear();answered=false;msg='';
    // AI answers in 2-4 seconds
    final delay=Duration(milliseconds:2000+Random().nextInt(2000));
    _aiTimer=Timer(delay,(){if(!answered){aScore++;setState((){msg='AI answered first!';answered=true;});Future.delayed(const Duration(milliseconds:1200),_next);}});
    setState((){});
  }

  void _submit(){
    if(answered)return;
    final v=int.tryParse(_ctrl.text);
    if(v==answer){_aiTimer?.cancel();answered=true;pScore++;setState((){msg='You got it first!';});Future.delayed(const Duration(milliseconds:1000),_next);}
    else{setState((){msg='Wrong!';_ctrl.clear();});}
  }

  @override
  Widget build(BuildContext ctx)=>Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('NUMBER DUEL'), actions:[
      Padding(padding: const EdgeInsets.only(right:12),child: Center(child: Text('You $pScore — AI $aScore',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:13,color:GacomColors.textSecondary)))),
    ]),
    body: Padding(padding: const EdgeInsets.all(24),child: Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      const Text('Race the AI — solve first!',style: TextStyle(color:GacomColors.textMuted,fontSize:13)),
      const SizedBox(height:32),
      Text('$a $op $b = ?',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:52,color:GacomColors.textPrimary)),
      const SizedBox(height:32),
      if(msg.isNotEmpty)Text(msg,style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:18,color:msg.contains('You')?GacomColors.success:GacomColors.error),textAlign:TextAlign.center),
      const SizedBox(height:16),
      if(!answered)...[
        TextField(controller:_ctrl,keyboardType:TextInputType.number,autofocus:true,onSubmitted:(_)=>_submit(),
          style: const TextStyle(color:GacomColors.textPrimary,fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:32),textAlign:TextAlign.center,
          decoration: InputDecoration(hintText:'Your answer',hintStyle: const TextStyle(color:GacomColors.textMuted),filled:true,fillColor:GacomColors.elevatedCard,border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),borderSide: const BorderSide(color:GacomColors.border)))),
        const SizedBox(height:16),
        SizedBox(width:double.infinity,child: ElevatedButton(onPressed:_submit,
          style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,padding: const EdgeInsets.symmetric(vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('SUBMIT',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:18,color:Colors.white)))),
      ],
    ])),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// SNAKE GAME (solo, classic)
// ═══════════════════════════════════════════════════════════════════════════
class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});
  @override State<SnakeGame> createState()=>_SnakeState();
}
class _SnakeState extends State<SnakeGame>{
  static const gridSize=20;
  List<List<int>> snake=[];
  List<int> food=[0,0];
  List<int> dir=[0,1];
  Timer? _timer; int score=0; bool over=false; bool started=false;

  void _start(){
    snake=[[10,10],[10,9],[10,8]];
    dir=[0,1]; score=0; over=false; started=true;
    _spawnFood();
    _timer?.cancel();
    _timer=Timer.periodic(const Duration(milliseconds:180),(_)=>_tick());
    setState((){});
  }

  void _spawnFood(){
    do{food=[Random().nextInt(gridSize),Random().nextInt(gridSize)];}
    while(snake.any((s)=>s[0]==food[0]&&s[1]==food[1]));
  }

  void _tick(){
    if(over)return;
    final head=[snake.first[0]+dir[0],snake.first[1]+dir[1]];
    if(head[0]<0||head[0]>=gridSize||head[1]<0||head[1]>=gridSize||snake.any((s)=>s[0]==head[0]&&s[1]==head[1])){
      _timer?.cancel(); setState((){over=true;});return;
    }
    snake.insert(0,head);
    if(head[0]==food[0]&&head[1]==food[1]){score+=10;_spawnFood();}
    else snake.removeLast();
    setState((){});
  }

  void _setDir(int r,int c){if(dir[0]!=(-r)||dir[1]!=(-c))setState((){dir=[r,c];});}

  @override void dispose(){_timer?.cancel();super.dispose();}

  @override
  Widget build(BuildContext ctx)=>Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('SNAKE'), actions:[
      Padding(padding: const EdgeInsets.only(right:12),child: Center(child: Text('Score: $score',style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:14,color:GacomColors.deepOrange)))),
    ]),
    body: Column(children:[
      Expanded(child: Center(child: AspectRatio(aspectRatio:1,child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: GacomColors.cardDark,borderRadius: BorderRadius.circular(8)),
        child: !started?Center(child: ElevatedButton(onPressed:_start,
          style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
          child: const Text('START',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:18,color:Colors.white))))
        :over?Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          const Text('Game Over!',style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,fontSize:24,color:GacomColors.error)),
          const SizedBox(height:8),
          Text('Score: $score',style: const TextStyle(fontFamily:'Rajdhani',fontSize:18,color:GacomColors.textSecondary)),
          const SizedBox(height:16),
          ElevatedButton(onPressed:_start,style:ElevatedButton.styleFrom(backgroundColor:GacomColors.deepOrange,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
            child: const Text('RETRY',style:TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,color:Colors.white))),
        ])
        :CustomPaint(painter:_SnakePainter(snake,food,gridSize)),
      )))),
      // D-pad
      Padding(padding: const EdgeInsets.all(12),child: Column(children:[
        ElevatedButton(onPressed:()=>_setDir(-1,0),style:ElevatedButton.styleFrom(backgroundColor:GacomColors.elevatedCard,shape: const CircleBorder(),padding: const EdgeInsets.all(14)),child: const Icon(Icons.arrow_upward_rounded,color:GacomColors.deepOrange)),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          ElevatedButton(onPressed:()=>_setDir(0,-1),style:ElevatedButton.styleFrom(backgroundColor:GacomColors.elevatedCard,shape: const CircleBorder(),padding: const EdgeInsets.all(14)),child: const Icon(Icons.arrow_back_rounded,color:GacomColors.deepOrange)),
          const SizedBox(width:16),
          ElevatedButton(onPressed:()=>_setDir(0,1),style:ElevatedButton.styleFrom(backgroundColor:GacomColors.elevatedCard,shape: const CircleBorder(),padding: const EdgeInsets.all(14)),child: const Icon(Icons.arrow_forward_rounded,color:GacomColors.deepOrange)),
        ]),
        ElevatedButton(onPressed:()=>_setDir(1,0),style:ElevatedButton.styleFrom(backgroundColor:GacomColors.elevatedCard,shape: const CircleBorder(),padding: const EdgeInsets.all(14)),child: const Icon(Icons.arrow_downward_rounded,color:GacomColors.deepOrange)),
      ])),
    ]),
  );
}
class _SnakePainter extends CustomPainter{
  final List<List<int>> snake;final List<int> food;final int g;
  _SnakePainter(this.snake,this.food,this.g);
  @override void paint(Canvas canvas,Size size){
    final cell=size.width/g;
    final fp=Paint()..color=GacomColors.deepOrange;
    canvas.drawCircle(Offset((food[1]+0.5)*cell,(food[0]+0.5)*cell),cell*0.4,fp);
    for(int i=0;i<snake.length;i++){
      final p=Paint()..color=i==0?GacomColors.success:GacomColors.success.withOpacity(0.6);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(snake[i][1]*cell+1,snake[i][0]*cell+1,cell-2,cell-2), const Radius.circular(3)),p);
    }
  }
  @override bool shouldRepaint(_)=>true;
}
