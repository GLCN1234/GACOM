/// Piece codes: low 3 bits are the type, bit 3 is the colour (0 white, 1 black).
const int kPawn = 1;
const int kKnight = 2;
const int kBishop = 3;
const int kRook = 4;
const int kQueen = 5;
const int kKing = 6;

int mkPiece(int type, int color) => type | (color << 3);
int pieceType(int p) => p & 7;
int pieceColor(int p) => p >> 3;

class ChessMove {
  final int from;
  final int to;
  final int promo; // 0 none, 2 knight, 3 bishop, 4 rook, 5 queen
  const ChessMove(this.from, this.to, [this.promo = 0]);

  static String sqName(int i) => String.fromCharCode(97 + (i % 8)) + (8 - (i ~/ 8)).toString();

  String get uci => sqName(from) + sqName(to) + (promo == 0 ? '' : 'nbrq'[promo - 2]);
}

/// Squares are indexed row * 8 + column with row 0 = rank 8 (the order a
/// FEN lists them), column 0 = file a.
class ChessPos {
  List<int> sq;
  int turn; // 0 white, 1 black
  int castle; // bits: 1 white king side, 2 white queen side, 4 black king side, 8 black queen side
  int ep; // en passant target square, or -1
  ChessPos(this.sq, this.turn, this.castle, this.ep);

  ChessPos clone() => ChessPos(List<int>.from(sq), turn, castle, ep);

  static ChessPos fromFen(String fen) {
    final parts = fen.split(' ');
    final sq = List<int>.filled(64, 0);
    final rows = parts[0].split('/');
    for (int r = 0; r < 8; r++) {
      int c = 0;
      for (final ch in rows[r].split('')) {
        final d = int.tryParse(ch);
        if (d != null) {
          c += d;
          continue;
        }
        final lower = ch.toLowerCase();
        final type = 'pnbrqk'.indexOf(lower) + 1;
        sq[r * 8 + c] = mkPiece(type, ch == lower ? 1 : 0);
        c++;
      }
    }
    final turn = parts[1] == 'w' ? 0 : 1;
    int castle = 0;
    final cs = parts.length > 2 ? parts[2] : '-';
    if (cs.contains('K')) { castle |= 1; }
    if (cs.contains('Q')) { castle |= 2; }
    if (cs.contains('k')) { castle |= 4; }
    if (cs.contains('q')) { castle |= 8; }
    int ep = -1;
    if (parts.length > 3 && parts[3] != '-') {
      ep = (8 - int.parse(parts[3][1])) * 8 + (parts[3].codeUnitAt(0) - 97);
    }
    return ChessPos(sq, turn, castle, ep);
  }

  static const List<List<int>> _knightD = [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]];
  static const List<List<int>> _kingD = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]];
  static const List<List<int>> _diag = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
  static const List<List<int>> _orth = [[-1, 0], [1, 0], [0, -1], [0, 1]];

  static bool _on(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  /// Is square [idx] attacked by a piece of colour [by]?
  static bool attacked(List<int> sq, int idx, int by) {
    final r = idx ~/ 8;
    final c = idx % 8;
    final pr = by == 0 ? r + 1 : r - 1;
    for (final dc in const [-1, 1]) {
      final nc = c + dc;
      if (_on(pr, nc) && sq[pr * 8 + nc] == mkPiece(kPawn, by)) return true;
    }
    for (final d in _knightD) {
      final nr = r + d[0];
      final nc = c + d[1];
      if (_on(nr, nc) && sq[nr * 8 + nc] == mkPiece(kKnight, by)) return true;
    }
    for (final d in _kingD) {
      final nr = r + d[0];
      final nc = c + d[1];
      if (_on(nr, nc) && sq[nr * 8 + nc] == mkPiece(kKing, by)) return true;
    }
    for (final d in _diag) {
      int nr = r + d[0];
      int nc = c + d[1];
      while (_on(nr, nc)) {
        final p = sq[nr * 8 + nc];
        if (p != 0) {
          if (p == mkPiece(kBishop, by) || p == mkPiece(kQueen, by)) return true;
          break;
        }
        nr += d[0];
        nc += d[1];
      }
    }
    for (final d in _orth) {
      int nr = r + d[0];
      int nc = c + d[1];
      while (_on(nr, nc)) {
        final p = sq[nr * 8 + nc];
        if (p != 0) {
          if (p == mkPiece(kRook, by) || p == mkPiece(kQueen, by)) return true;
          break;
        }
        nr += d[0];
        nc += d[1];
      }
    }
    return false;
  }

  int kingIndex(int color) {
    final k = mkPiece(kKing, color);
    for (int i = 0; i < 64; i++) {
      if (sq[i] == k) return i;
    }
    return -1;
  }

  bool get inCheck {
    final k = kingIndex(turn);
    return k >= 0 && attacked(sq, k, 1 - turn);
  }

  void _addPawn(List<ChessMove> out, int from, int to, bool promotes) {
    if (promotes) {
      for (final pr in const [kQueen, kRook, kBishop, kKnight]) { out.add(ChessMove(from, to, pr)); }
    } else {
      out.add(ChessMove(from, to));
    }
  }

  List<ChessMove> _pseudo() {
    final out = <ChessMove>[];
    final me = turn;
    for (int i = 0; i < 64; i++) {
      final p = sq[i];
      if (p == 0 || pieceColor(p) != me) continue;
      final t = pieceType(p);
      final r = i ~/ 8;
      final c = i % 8;
      if (t == kPawn) {
        final dr = me == 0 ? -1 : 1;
        final startRow = me == 0 ? 6 : 1;
        final lastRow = me == 0 ? 0 : 7;
        final nr = r + dr;
        if (nr >= 0 && nr < 8) {
          if (sq[nr * 8 + c] == 0) {
            _addPawn(out, i, nr * 8 + c, nr == lastRow);
            if (r == startRow && sq[(r + 2 * dr) * 8 + c] == 0) { out.add(ChessMove(i, (r + 2 * dr) * 8 + c)); }
          }
          for (final dc in const [-1, 1]) {
            final nc = c + dc;
            if (nc < 0 || nc > 7) continue;
            final to = nr * 8 + nc;
            final tp = sq[to];
            if (tp != 0 && pieceColor(tp) != me) {
              _addPawn(out, i, to, nr == lastRow);
            } else if (tp == 0 && ep != -1 && to == ep) {
              out.add(ChessMove(i, to));
            }
          }
        }
      } else if (t == kKnight || t == kKing) {
        for (final d in (t == kKnight ? _knightD : _kingD)) {
          final nr = r + d[0];
          final nc = c + d[1];
          if (!_on(nr, nc)) continue;
          final tp = sq[nr * 8 + nc];
          if (tp == 0 || pieceColor(tp) != me) { out.add(ChessMove(i, nr * 8 + nc)); }
        }
        if (t == kKing) {
          if (me == 0 && i == 60) {
            if ((castle & 1) != 0 && sq[61] == 0 && sq[62] == 0 && sq[63] == mkPiece(kRook, 0) &&
                !attacked(sq, 60, 1) && !attacked(sq, 61, 1) && !attacked(sq, 62, 1)) {
              out.add(const ChessMove(60, 62));
            }
            if ((castle & 2) != 0 && sq[59] == 0 && sq[58] == 0 && sq[57] == 0 && sq[56] == mkPiece(kRook, 0) &&
                !attacked(sq, 60, 1) && !attacked(sq, 59, 1) && !attacked(sq, 58, 1)) {
              out.add(const ChessMove(60, 58));
            }
          }
          if (me == 1 && i == 4) {
            if ((castle & 4) != 0 && sq[5] == 0 && sq[6] == 0 && sq[7] == mkPiece(kRook, 1) &&
                !attacked(sq, 4, 0) && !attacked(sq, 5, 0) && !attacked(sq, 6, 0)) {
              out.add(const ChessMove(4, 6));
            }
            if ((castle & 8) != 0 && sq[3] == 0 && sq[2] == 0 && sq[1] == 0 && sq[0] == mkPiece(kRook, 1) &&
                !attacked(sq, 4, 0) && !attacked(sq, 3, 0) && !attacked(sq, 2, 0)) {
              out.add(const ChessMove(4, 2));
            }
          }
        }
      } else {
        final dirs = t == kBishop ? _diag : (t == kRook ? _orth : _kingD);
        for (final d in dirs) {
          int nr = r + d[0];
          int nc = c + d[1];
          while (_on(nr, nc)) {
            final tp = sq[nr * 8 + nc];
            if (tp == 0) {
              out.add(ChessMove(i, nr * 8 + nc));
            } else {
              if (pieceColor(tp) != me) { out.add(ChessMove(i, nr * 8 + nc)); }
              break;
            }
            nr += d[0];
            nc += d[1];
          }
        }
      }
    }
    return out;
  }

  ChessPos apply(ChessMove m) {
    final n = clone();
    final piece = n.sq[m.from];
    final t = pieceType(piece);
    final col = pieceColor(piece);
    final captured = n.sq[m.to];
    if (t == kPawn && ep != -1 && m.to == ep && captured == 0 && (m.from % 8) != (m.to % 8)) {
      n.sq[(m.from ~/ 8) * 8 + (m.to % 8)] = 0; // en passant removes the passed pawn
    }
    if (t == kKing && (m.to - m.from).abs() == 2) {
      if (m.to > m.from) {
        n.sq[m.from + 1] = n.sq[m.from + 3];
        n.sq[m.from + 3] = 0;
      } else {
        n.sq[m.from - 1] = n.sq[m.from - 4];
        n.sq[m.from - 4] = 0;
      }
    }
    n.sq[m.to] = m.promo != 0 ? mkPiece(m.promo, col) : piece;
    n.sq[m.from] = 0;
    int newEp = -1;
    if (t == kPawn && (m.to - m.from).abs() == 16) { newEp = (m.from + m.to) ~/ 2; }
    int cr = castle;
    if (t == kKing) { cr &= col == 0 ? ~3 : ~12; }
    for (final s in [m.from, m.to]) {
      if (s == 63) { cr &= ~1; }
      if (s == 56) { cr &= ~2; }
      if (s == 7) { cr &= ~4; }
      if (s == 0) { cr &= ~8; }
    }
    n.castle = cr;
    n.ep = newEp;
    n.turn = 1 - turn;
    return n;
  }

  List<ChessMove> legalMoves() {
    final res = <ChessMove>[];
    for (final m in _pseudo()) {
      final n = apply(m);
      final k = n.kingIndex(turn);
      if (k >= 0 && !attacked(n.sq, k, 1 - turn)) { res.add(m); }
    }
    return res;
  }

  bool get isCheckmate => inCheck && legalMoves().isEmpty;

  /// The legal move matching a UCI string such as e2e4 or e7e8q, or null.
  ChessMove? moveFromUci(String u) {
    final from = (8 - int.parse(u[1])) * 8 + (u.codeUnitAt(0) - 97);
    final to = (8 - int.parse(u[3])) * 8 + (u.codeUnitAt(2) - 97);
    int promo = 0;
    if (u.length > 4) { promo = 'nbrq'.indexOf(u[4]) + 2; }
    for (final m in legalMoves()) {
      if (m.from == from && m.to == to && m.promo == promo) return m;
    }
    return null;
  }
}
