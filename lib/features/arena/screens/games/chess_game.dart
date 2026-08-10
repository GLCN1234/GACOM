import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

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

  @override void initState(){ super.initState(); _reset(); }

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
    final nb=List<int>.from(board);
    nb[to]=nb[from]; nb[from]=empty;
    // pawn promotion
    if(nb[to]==wP&&to<8){nb[to]=wQ;}
    if(nb[to]==bP&&to>=56){nb[to]=bQ;}
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
    final move=_bestMove(board,false,4);
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

  int _quiescence(List<int> b, bool white, int alpha, int beta){
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
      final score=_quiescence(nb,!white,alpha,beta);
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
        Text('W $wScore — B $bScore', style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:14,color:GacomColors.textSecondary)),
        const SizedBox(width:12),
      ]),
      body: Column(children:[
        Container(padding: const EdgeInsets.all(12),
          child: Text(status, style: const TextStyle(fontFamily:'Rajdhani',fontWeight:FontWeight.w700,fontSize:15,color:GacomColors.textPrimary), textAlign: TextAlign.center)),
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
          Expanded(child: OutlinedButton(onPressed: _reset,
            style: OutlinedButton.styleFrom(side: const BorderSide(color:GacomColors.deepOrange),shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('NEW GAME', style: TextStyle(color:GacomColors.deepOrange,fontFamily:'Rajdhani',fontWeight:FontWeight.w800)))),
        ])),
      ]),
    );
  }
}

// ChessPracticeScreen is the AI practice mode.
// The multiplayer ChessGame used by match_screen.dart lives in reaction_game.dart.
