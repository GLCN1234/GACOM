import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/supabase_service.dart';

// ── Chess piece constants ─────────────────────────────────────────────────────
const empty = 0;
const wP=1;const wN=2;const wB=3;const wR=4;const wQ=5;const wK=6;
const bP=-1;const bN=-2;const bB=-3;const bR=-4;const bQ=-5;const bK=-6;

// ── Piece value table for AI evaluation ──────────────────────────────────────
const _pieceVal = {wP:100,wN:320,wB:330,wR:500,wQ:900,wK:20000,
  bP:-100,bN:-320,bB:-330,bR:-500,bQ:-900,bK:-20000};
// ── Piece-square tables — positional evaluation, not just material count.
// Indexed a8=0..h1=63 (matches this board's layout). Standard, widely-used
// values (chessprogramming.org simplified evaluation function).
const _pawnPST=[
  0,0,0,0,0,0,0,0,
  50,50,50,50,50,50,50,50,
  10,10,20,30,30,20,10,10,
  5,5,10,25,25,10,5,5,
  0,0,0,20,20,0,0,0,
  5,-5,-10,0,0,-10,-5,5,
  5,10,10,-20,-20,10,10,5,
  0,0,0,0,0,0,0,0];
const _knightPST=[
  -50,-40,-30,-30,-30,-30,-40,-50,
  -40,-20,0,0,0,0,-20,-40,
  -30,0,10,15,15,10,0,-30,
  -30,5,15,20,20,15,5,-30,
  -30,0,15,20,20,15,0,-30,
  -30,5,10,15,15,10,5,-30,
  -40,-20,0,5,5,0,-20,-40,
  -50,-40,-30,-30,-30,-30,-40,-50];
const _bishopPST=[
  -20,-10,-10,-10,-10,-10,-10,-20,
  -10,0,0,0,0,0,0,-10,
  -10,0,5,10,10,5,0,-10,
  -10,5,5,10,10,5,5,-10,
  -10,0,10,10,10,10,0,-10,
  -10,10,10,10,10,10,10,-10,
  -10,5,0,0,0,0,5,-10,
  -20,-10,-10,-10,-10,-10,-10,-20];
const _rookPST=[
  0,0,0,0,0,0,0,0,
  5,10,10,10,10,10,10,5,
  -5,0,0,0,0,0,0,-5,
  -5,0,0,0,0,0,0,-5,
  -5,0,0,0,0,0,0,-5,
  -5,0,0,0,0,0,0,-5,
  -5,0,0,0,0,0,0,-5,
  0,0,0,5,5,0,0,0];
const _queenPST=[
  -20,-10,-10,-5,-5,-10,-10,-20,
  -10,0,0,0,0,0,0,-10,
  -10,0,5,5,5,5,0,-10,
  -5,0,5,5,5,5,0,-5,
  0,0,5,5,5,5,0,-5,
  -10,5,5,5,5,5,0,-10,
  -10,0,5,0,0,0,0,-10,
  -20,-10,-10,-5,-5,-10,-10,-20];
const _kingPST=[
  -30,-40,-40,-50,-50,-40,-40,-30,
  -30,-40,-40,-50,-50,-40,-40,-30,
  -30,-40,-40,-50,-50,-40,-40,-30,
  -30,-40,-40,-50,-50,-40,-40,-30,
  -20,-30,-30,-40,-40,-30,-30,-20,
  -10,-20,-20,-20,-20,-20,-20,-10,
  20,20,0,0,0,0,20,20,
  20,30,10,0,0,10,30,20];

class ChessPracticeScreen extends StatefulWidget {
  const ChessPracticeScreen({super.key});
  @override State<ChessPracticeScreen> createState()=>_ChessPracticeState();
}

class _ChessPracticeState extends State<ChessPracticeScreen>{
  late List<int> board;
  bool whiteTurn=true;
  int? selected;
  List<int> legalMoves=[];
  String status='Your turn (White)';
  bool gameOver=false;
  int wScore=0,bScore=0;
  bool aiThinking=false;
  bool learnMode=true;
  bool voiceEnabled=true;
  String? lastExplanation;
  int moveCount=0;

  @override void initState(){
    super.initState();
    _reset();
    WidgetsBinding.instance.addPostFrameCallback((_){ if(learnMode&&mounted) _showWelcomeDialog(); });
  }
  void _showWelcomeDialog(){
    showDialog(context: context, builder: (dialogCtx) => AlertDialog(
      backgroundColor: GacomColors.cardDark,
      title: const Text('Welcome to Chess with Ryan', style: TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w800,color:GacomColors.textPrimary)),
      content: SizedBox(width: 320, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('The goal is to checkmate your opponent\'s king \u2014 trap it so it cannot escape capture. The highlighted squares below show exactly where each piece can move:',
          style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 14),
        _pieceLesson(wP, 'Pawn', 'Moves straight ahead one square (two on its very first move). It captures only diagonally, shown here by the highlighted squares.'),
        _pieceLesson(wN, 'Knight', 'Moves in an L-shape and can jump over other pieces \u2014 the only piece that can do that.'),
        _pieceLesson(wB, 'Bishop', 'Moves any distance, but only along diagonal lines.'),
        _pieceLesson(wR, 'Rook', 'Moves any distance in a straight line \u2014 forward, back, left, or right.'),
        _pieceLesson(wQ, 'Queen', 'The most powerful piece \u2014 moves any distance in any direction.'),
        _pieceLesson(wK, 'King', 'Moves only one square in any direction. Keep it safe \u2014 losing it means losing the game.'),
        const SizedBox(height: 8),
        const Text('Play your move whenever you\'re ready, and Ryan will explain what happened after every move you make.',
          style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Let\'s Play!', style: TextStyle(color: GacomColors.deepOrange, fontFamily:'Rajdhani',fontWeight:FontWeight.w800))),
      ],
    ));
  }
  Widget _pieceLesson(int pieceType, String name, String rule) => Padding(padding: const EdgeInsets.only(bottom:14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _pieceDemoBoard(pieceType),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(color: GacomColors.deepOrange, fontFamily:'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 4),
        Text(rule, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
      ])),
    ]));
  Widget _pieceDemoBoard(int pieceType){
    final demoBoard = List<int>.filled(64, empty);
    int centerSq = 27;
    if(pieceType==wP){
      centerSq = 52;
      demoBoard[52]=wP;
      demoBoard[43]=bP;
      demoBoard[45]=bP;
    } else {
      demoBoard[centerSq]=pieceType;
    }
    final moves=_movesFor(centerSq,demoBoard);
    return SizedBox(width:104, height:104, child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:8),
      itemCount:64,
      itemBuilder:(_, i){
        final light=((i~/8)+(i%8))%2==0;
        Color bg;
        if(i==centerSq) bg=GacomColors.deepOrange;
        else if(moves.contains(i)) bg=GacomColors.accentCyan.withOpacity(0.6);
        else bg=light?const Color(0xFFF0D9B5):const Color(0xFFB58863);
        return Container(color:bg,
          child: i==centerSq?Center(child:Text(_pieceGlyph[pieceType]??'',style:const TextStyle(fontSize:9,color:Colors.white))):null);
      },
    ));
  }

  void _reset(){
    board=List<int>.from(_startBoard);
    whiteTurn=true; selected=null; legalMoves=[]; gameOver=false;
    status='Your turn (White)'; aiThinking=false;
  }

  static final List<int> _startBoard=[
    bR,bN,bB,bQ,bK,bB,bN,bR,
    bP,bP,bP,bP,bP,bP,bP,bP,
    0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,
    wP,wP,wP,wP,wP,wP,wP,wP,
    wR,wN,wB,wQ,wK,wB,wN,wR,
  ];

  // ── Move generation ──────────────────────────────────────────────────────
  List<int> _movesFor(int sq, List<int> b){
    final p=b[sq]; if(p==empty)return[];
    final white=p>0;
    List<int> moves=[];

    void add(int t){ if(t>=0&&t<64&&(b[t]==empty||(b[t]<0)==white))moves.add(t); }
    void slide(List<int> dirs){
      for(final d in dirs){
        int t=sq;
        while(true){
          final prev=t; t+=d;
          if(t<0||t>=64)break;
          if((t%8-prev%8).abs()>2)break; // board edge wrap
          moves.add(t);
          if(b[t]!=empty)break;
        }
      }
      // filter captures of own pieces
      moves=moves.where((t)=>t>=0&&t<64&&!((b[t]>0)==white&&b[t]!=empty)).toList();
    }

    final r=sq~/8, c=sq%8;
    switch(p.abs()){
      case 1: // pawn
        final dir=white?-8:8;
        final start=white?6:1;
        if(sq~/8==start&&b[sq+dir]==empty&&b[sq+2*dir]==empty)moves.add(sq+2*dir);
        if(b[sq+dir]==empty)moves.add(sq+dir);
        for(final dc in [-1,1]){
          final t=sq+dir+(c+dc>=0&&c+dc<8?dc:0);
          if(t!=sq+dir&&t>=0&&t<64&&b[t]!=empty&&(b[t]<0)==white&&(t%8-sq%8).abs()==1)moves.add(t);
        }
        break;
      case 2: // knight
        for(final d in [-17,-15,-10,-6,6,10,15,17]){
          final t=sq+d;
          if(t<0||t>=64)continue;
          if((t%8-c).abs()>2)continue;
          if(b[t]==empty||(b[t]<0)==white)moves.add(t);
        }
        break;
      case 3: slide([-9,-7,7,9]); break; // bishop
      case 4: slide([-8,-1,1,8]); break;  // rook
      case 5: slide([-9,-8,-7,-1,1,7,8,9]); break; // queen
      case 6: // king
        for(final d in [-9,-8,-7,-1,1,7,8,9]){
          final t=sq+d;
          if(t<0||t>=64)continue;
          if((t%8-c).abs()>1)continue;
          if(b[t]==empty||(b[t]<0)==white)moves.add(t);
        }
        break;
    }
    return moves;
  }

  bool _inCheck(bool white, List<int> b){
    final king=white?wK:bK;
    final ksq=b.indexOf(king); if(ksq<0)return true;
    for(int sq=0;sq<64;sq++){
      final p=b[sq];
      if(p==empty)continue;
      if(white&&p>0)continue;
      if(!white&&p<0)continue;
      if(_movesFor(sq,b).contains(ksq))return true;
    }
    return false;
  }

  List<int> _legalMoves(int sq, List<int> b, bool white){
    final candidates=_movesFor(sq,b);
    return candidates.where((t){
      final nb=List<int>.from(b);
      nb[t]=nb[sq]; nb[sq]=empty;
      return !_inCheck(white,nb);
    }).toList();
  }

  bool _hasAnyMove(bool white, List<int> b){
    for(int sq=0;sq<64;sq++){
      final p=b[sq];
      if(p==empty)continue;
      if(white&&p<0)continue;
      if(!white&&p>0)continue;
      if(_legalMoves(sq,b,white).isNotEmpty)return true;
    }
    return false;
  }

  void _tap(int sq){
    if(gameOver||!whiteTurn||aiThinking)return;
    if(selected==null){
      if(board[sq]>0){
        setState((){selected=sq; legalMoves=_legalMoves(sq,board,true);});
      }
    } else {
      if(legalMoves.contains(sq)){
        _makeMove(selected!,sq);
      } else if(board[sq]>0){
        setState((){selected=sq; legalMoves=_legalMoves(sq,board,true);});
      } else {
        setState((){selected=null; legalMoves=[];});
      }
    }
  }

  void _makeMove(int from, int to){
    HapticFeedback.lightImpact();
    final wasStudentMove=whiteTurn;
    final beforeBoard=List<int>.from(board);
    final nb=List<int>.from(board);
    nb[to]=nb[from]; nb[from]=empty;
    // pawn promotion
    if(nb[to]==wP&&to<8){nb[to]=wQ;}
    if(nb[to]==bP&&to>=56){nb[to]=bQ;}
    if(learnMode&&wasStudentMove){
      lastExplanation='Ryan is thinking about how to explain this...';
      _fetchTutorExplanation(beforeBoard,from,to,nb);
    }
    // Ryan's own reply move deliberately does NOT clear lastExplanation —
    // the student needs time to actually read it before it's replaced by
    // their next move's explanation.
    setState((){board=nb; selected=null; legalMoves=[];});
    final nowWhite=!whiteTurn;
    if(!_hasAnyMove(nowWhite,board)){
      if(_inCheck(nowWhite,board)){
        final winner=whiteTurn?'White':'Black';
        setState((){gameOver=true; status='$winner wins by checkmate!';
          if(whiteTurn)wScore++;else bScore++;});
      } else {
        setState((){gameOver=true; status='Stalemate — draw!';});
      }
      return;
    }
    setState((){whiteTurn=nowWhite;});
    if(!whiteTurn){ // AI's turn
      setState((){aiThinking=true; status='Ryan is thinking...';});
      Future.delayed(const Duration(milliseconds:400),_aiMove);
    } else {
      setState((){status='Your turn (White)';});
    }
  }

  // ── Alpha-beta AI ───────────────────────────────────────────────────────────
  void _aiMove(){
    final move=_bestMove(board,false,3);
    if(move!=null){_makeMove(move.$1,move.$2);}
    setState((){aiThinking=false;});
  }

  List<(int,int)> _orderMoves(List<(int,int)> moves, List<int> b){
    moves.sort((a,c){
      final av=b[a.$2]!=empty?(_pieceVal[b[a.$2]]?.abs()??0):0;
      final cv=b[c.$2]!=empty?(_pieceVal[b[c.$2]]?.abs()??0):0;
      return cv.compareTo(av);
    });
    return moves;
  }
  (int,int)? _bestMove(List<int> b, bool white, int depth){
    List<(int,int)> moves=[];
    for(int sq=0;sq<64;sq++){
      final p=b[sq]; if(p==empty)continue;
      if(white&&p<0)continue;
      if(!white&&p>0)continue;
      for(final t in _legalMoves(sq,b,white)){moves.add((sq,t));}
    }
    if(moves.isEmpty)return null;
    moves=_orderMoves(moves,b);
    int best=white?-999999:999999;
    (int,int)? bestMove;
    for(final m in moves){
      final nb=List<int>.from(b);
      nb[m.$2]=nb[m.$1]; nb[m.$1]=empty;
      final score=_alphabeta(nb,depth-1,!white,-999999,999999);
      if(white&&score>best){best=score;bestMove=m;}
      if(!white&&score<best){best=score;bestMove=m;}
    }
    return bestMove??moves[Random().nextInt(moves.length)];
  }

  int _alphabeta(List<int> b, int depth, bool white, int alpha, int beta){
    if(depth==0)return _quiescence(b,white,alpha,beta);
    List<(int,int)> moves=[];
    for(int sq=0;sq<64;sq++){
      final p=b[sq]; if(p==empty)continue;
      if(white&&p<0)continue;
      if(!white&&p>0)continue;
      for(final t in _legalMoves(sq,b,white)){moves.add((sq,t));}
    }
    if(moves.isEmpty)return white?-30000:30000;
    moves=_orderMoves(moves,b);
    if(white){
      int val=-999999;
      for(final m in moves){
        final nb=List<int>.from(b);
        nb[m.$2]=nb[m.$1]; nb[m.$1]=empty;
        val=max(val,_alphabeta(nb,depth-1,false,alpha,beta));
        alpha=max(alpha,val);
        if(beta<=alpha)break;
      }
      return val;
    } else {
      int val=999999;
      for(final m in moves){
        final nb=List<int>.from(b);
        nb[m.$2]=nb[m.$1]; nb[m.$1]=empty;
        val=min(val,_alphabeta(nb,depth-1,true,alpha,beta));
        beta=min(beta,val);
        if(beta<=alpha)break;
      }
      return val;
    }
  }

  int _quiescence(List<int> b, bool white, int alpha, int beta, [int depth=0]){
    if(depth>=4)return _evaluate(b);
    final standPat=_evaluate(b);
    if(white){
      if(standPat>=beta)return beta;
      if(standPat>alpha)alpha=standPat;
    } else {
      if(standPat<=alpha)return alpha;
      if(standPat<beta)beta=standPat;
    }
    List<(int,int)> captures=[];
    for(int sq=0;sq<64;sq++){
      final p=b[sq]; if(p==empty)continue;
      if(white&&p<0)continue;
      if(!white&&p>0)continue;
      for(final t in _legalMoves(sq,b,white)){
        if(b[t]!=empty)captures.add((sq,t));
      }
    }
    captures=_orderMoves(captures,b);
    for(final m in captures){
      final nb=List<int>.from(b);
      nb[m.$2]=nb[m.$1]; nb[m.$1]=empty;
      final score=_quiescence(nb,!white,alpha,beta,depth+1);
      if(white){
        if(score>alpha)alpha=score;
        if(alpha>=beta)return beta;
      } else {
        if(score<beta)beta=score;
        if(beta<=alpha)return alpha;
      }
    }
    return white?alpha:beta;
  }
  Future<void> _fetchTutorExplanation(List<int> before, int from, int to, List<int> after) async {
    moveCount++;
    final movedPiece=before[from];
    final capturedPiece=before[to];
    final isHangingNow=_isHanging(to,after);
    final isCheckNow=_inCheck(false,after);
    try {
      final res = await SupabaseService.client.functions.invoke('chess-tutor', body: {
        'pieceName': _pieceName(movedPiece),
        'fromSquare': _sqName(from),
        'toSquare': _sqName(to),
        'capturedPiece': capturedPiece!=empty ? _pieceName(capturedPiece) : null,
        'moveNumber': moveCount,
        'isHanging': isHangingNow,
        'isCheck': isCheckNow,
      });
      final explanation = (res.data as Map?)?['explanation'] as String?;
      if(mounted) setState((){ lastExplanation = explanation ?? 'Good move \u2014 keep going!'; });
    } catch (_) {
      if(mounted) setState((){ lastExplanation = null; });
    }
  }
  String _sqName(int sq){
    final file=String.fromCharCode(97+sq%8);
    final rank=8-sq~/8;
    return '$file$rank';
  }
  String _explainMove(List<int> before, int from, int to, List<int> after){
    final movedPiece=before[from];
    final capturedPiece=before[to];
    final best=_bestMove(before,true,2);
    final actualEval=_evaluate(after);
    int bestEval=actualEval;
    if(best!=null&&best!=(from,to)){
      final nb2=List<int>.from(before);
      nb2[best.$2]=nb2[best.$1]; nb2[best.$1]=empty;
      bestEval=_evaluate(nb2);
    }
    final gap=bestEval-actualEval;
    final hanging=_isHanging(to,after);
    final fromRank=from~/8;
    final isDevelopingMove=(movedPiece.abs()==2||movedPiece.abs()==3)&&fromRank==7;
    final isEarlyQueenMove=movedPiece.abs()==5&&fromRank==7;

    if(hanging&&gap>150){
      return "That leaves your ${_pieceName(movedPiece)} on ${_sqName(to)} undefended \u2014 Ryan could capture it next turn.";
    }
    if(capturedPiece!=empty&&(_pieceVal[capturedPiece]?.abs()??0)>=300){
      return "Nice capture! You took Ryan's ${_pieceName(capturedPiece)}, and you're ahead in material now.";
    }
    if(gap>=300&&best!=null){
      return "There was a much stronger move here \u2014 moving your ${_pieceName(before[best.$1])} to ${_sqName(best.$2)} would have been better.";
    }
    if(gap>=100&&best!=null){
      return "Decent, but ${_sqName(best.$2)} would have been a slightly stronger square for your ${_pieceName(before[best.$1])}.";
    }
    if(isEarlyQueenMove){
      return "Careful \u2014 moving your queen out this early can expose her to attack. Try developing your knights and bishops first.";
    }
    if(isDevelopingMove){
      return "Good \u2014 developing your ${_pieceName(movedPiece)} early gets your pieces active.";
    }
    final toRow=to~/8, toCol=to%8;
    if((toRow==3||toRow==4)&&(toCol==3||toCol==4)&&movedPiece.abs()==1){
      return "Good \u2014 controlling the center with a pawn gives you more options later.";
    }
    return "Solid move \u2014 no immediate problems. Keep building your position.";
  }
  bool _isHanging(int sq, List<int> b){
    final p=b[sq]; if(p==empty)return false;
    final white=p>0;
    for(int s=0;s<64;s++){
      final q=b[s]; if(q==empty)continue;
      if(white&&q>0)continue; if(!white&&q<0)continue;
      if(_movesFor(s,b).contains(sq))return true;
    }
    return false;
  }
  String _pieceName(int p){
    switch(p.abs()){
      case 1: return 'pawn'; case 2: return 'knight'; case 3: return 'bishop';
      case 4: return 'rook'; case 5: return 'queen'; default: return 'king';
    }
  }
  int _evaluate(List<int> b){
    int score=0;
    for(int sq=0;sq<64;sq++){
      final p=b[sq]; if(p==empty)continue;
      score+=_pieceVal[p]??0;
      final white=p>0;
      final pstSq=white?sq:63-sq;
      int pstVal;
      switch(p.abs()){
        case 1: pstVal=_pawnPST[pstSq]; break;
        case 2: pstVal=_knightPST[pstSq]; break;
        case 3: pstVal=_bishopPST[pstSq]; break;
        case 4: pstVal=_rookPST[pstSq]; break;
        case 5: pstVal=_queenPST[pstSq]; break;
        default: pstVal=_kingPST[pstSq];
      }
      score+=white?pstVal:-pstVal;
    }
    return score;
  }

  static const _pieceGlyph={
    wK:'♔',wQ:'♕',wR:'♖',wB:'♗',wN:'♘',wP:'♙',
    bK:'♚',bQ:'♛',bR:'♜',bB:'♝',bN:'♞',bP:'♟',
  };

  @override
  Widget build(BuildContext ctx){
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('CHESS VS RYAN'), actions:[
        GestureDetector(
          onTap: (){
            setState((){learnMode=!learnMode; lastExplanation=null;});
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text(learnMode?'Learn mode — Ryan will explain your moves':'Play mode — full-strength Ryan, no hints'),
              duration: const Duration(seconds:2)));
          },
          child: Container(margin: const EdgeInsets.only(right:8), padding: const EdgeInsets.symmetric(horizontal:12,vertical:6),
            decoration: BoxDecoration(color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children:[
              Icon(learnMode?Icons.school_rounded:Icons.emoji_events_rounded, color: Colors.white, size: 16),
              const SizedBox(width:6),
              Text(learnMode?'LEARN':'PLAY', style: const TextStyle(color: Colors.white, fontFamily:'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12)),
            ])),
        ),
      ]),
      body: Column(children:[
        Padding(padding: const EdgeInsets.only(top:8), child: Center(
          child: Text('W $wScore — B $bScore', style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:14,color:GacomColors.textSecondary)))),
        Container(padding: const EdgeInsets.all(12),
          child: Text(status, style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:15,color:GacomColors.textPrimary), textAlign: TextAlign.center)),
        if(learnMode&&lastExplanation!=null)
          Container(margin: const EdgeInsets.symmetric(horizontal:16,vertical:4), padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxHeight: 90),
            decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.3))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
              const Icon(Icons.lightbulb_outline_rounded, color: GacomColors.accentCyan, size: 18),
              const SizedBox(width:8),
              Expanded(child: SingleChildScrollView(child: Text(lastExplanation!, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)))),
            ])),
        Expanded(child: Center(child: AspectRatio(aspectRatio:1,child:Padding(
          padding: const EdgeInsets.symmetric(horizontal:8),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:8),
            itemCount:64,
            itemBuilder:(_, i){
              final r=i~/8, c=i%8;
              final light=(r+c)%2==0;
              final isSelected=selected==i;
              final isLegal=legalMoves.contains(i);
              Color bg;
              if(isSelected) bg=GacomColors.deepOrange.withOpacity(0.7);
              else if(isLegal&&board[i]!=empty) bg=GacomColors.error.withOpacity(0.5);
              else if(isLegal) bg=GacomColors.deepOrange.withOpacity(0.3);
              else bg=light?const Color(0xFFF0D9B5):const Color(0xFFB58863);
              final p=board[i];
              return GestureDetector(onTap:()=>_tap(i),
                child: Container(color:bg,
                  child: p==empty?null:Center(child: Text(_pieceGlyph[p]??'',
                    style: TextStyle(fontSize:28,color: p>0?Colors.white:Colors.black,
                      shadows: const [Shadow(blurRadius:2,color:Colors.black38)])))));
            },
          ),
        )))),
        Padding(padding: const EdgeInsets.all(16), child: Row(children:[
          Expanded(child: OutlinedButton(onPressed: () => setState((){ _reset(); }),
            style: OutlinedButton.styleFrom(side: const BorderSide(color:GacomColors.deepOrange),shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('NEW GAME', style: TextStyle(color:GacomColors.deepOrange,fontFamily:'Rajdhani',fontWeight:FontWeight.w800)))),
        ])),
      ]),
    );
  }
}

// ChessPracticeScreen is the AI practice mode.
// The multiplayer ChessGame used by match_screen.dart lives in reaction_game.dart.
