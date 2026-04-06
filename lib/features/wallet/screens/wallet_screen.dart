import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_button.dart';
import '../../../shared/widgets/gacom_text_field.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('wallet_balance, wallet_locked_balance, total_winnings')
          .eq('id', userId)
          .single();
      final txns = await SupabaseService.client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _profile = profile;
          _transactions = List<Map<String, dynamic>>.from(txns);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = (_profile?['wallet_balance'] as num?)?.toDouble() ?? 0;
    final locked = (_profile?['wallet_locked_balance'] as num?)?.toDouble() ?? 0;
    final winnings = (_profile?['total_winnings'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('WALLET')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : RefreshIndicator(
              color: GacomColors.deepOrange,
              onRefresh: () async { setState(() => _loading = true); await _loadData(); },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Balance Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: GacomColors.orangeGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: GacomColors.deepOrange.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Rajdhani')),
                        const SizedBox(height: 8),
                        Text(
                          '₦${_formatAmount(balance)}',
                          style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _BalanceItem(label: 'In Competitions', value: locked),
                            const SizedBox(width: 24),
                            _BalanceItem(label: 'Total Winnings', value: winnings),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),

                  const SizedBox(height: 20),

                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.add_rounded,
                          label: 'Fund Wallet',
                          onTap: () => _showFundSheet(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Withdraw',
                          onTap: () => _showWithdrawSheet(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.history_rounded,
                          label: 'History',
                          onTap: () {},
                        ),
                      ),
                    ],
                  ).animate(delay: 200.ms).fadeIn(),

                  const SizedBox(height: 28),

                  // Transactions
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GacomColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_transactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No transactions yet', style: TextStyle(color: GacomColors.textMuted)),
                      ),
                    )
                  else
                    ..._transactions.asMap().entries.map((e) =>
                      _TransactionItem(transaction: e.value)
                          .animate(delay: (e.key * 60).ms)
                          .fadeIn()
                          .slideX(begin: 0.2, end: 0),
                    ),
                ],
              ),
            ),
    );
  }

  void _showFundSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fund Wallet', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Minimum deposit: ₦500', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
            const SizedBox(height: 20),
            // Quick amounts
            Wrap(
              spacing: 8,
              children: [500, 1000, 2000, 5000, 10000].map((a) => GestureDetector(
                onTap: () => amountCtrl.text = a.toString(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: GacomColors.surfaceDark,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: GacomColors.border),
                  ),
                  child: Text('₦$a', style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            GacomTextField(
              controller: amountCtrl,
              label: 'Amount (₦)',
              hint: 'Enter amount',
              prefixIcon: Icons.attach_money_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            GacomButton(
              label: 'PROCEED TO PAY',
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount < 500) {
                  GacomSnackbar.show(ctx, 'Minimum deposit is ₦500', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                _initiatePaystack(amount);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _initiatePaystack(double amount) {
    final userId = SupabaseService.currentUserId;
    final userEmail = SupabaseService.currentUser?.email ?? '';
    final reference = 'GAC_${const Uuid().v4().substring(0, 8).toUpperCase()}';
    final amountKobo = (amount * 100).toInt();

    final paystackUrl = Uri.https('checkout.paystack.com', '/pay', {
      'key': AppConstants.paystackPublicKey,
      'email': userEmail,
      'amount': amountKobo.toString(),
      'reference': reference,
      'callback_url': 'https://gamicom.net/wallet/verify',
    }).toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PaystackWebView(
          url: paystackUrl,
          reference: reference,
          amount: amount,
          onSuccess: () => _verifyPayment(reference, amount),
        ),
      ),
    );
  }

  Future<void> _verifyPayment(String reference, double amount) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('wallet_balance')
          .eq('id', userId)
          .single();
      final currentBalance = (profile['wallet_balance'] as num).toDouble();
      final newBalance = currentBalance + amount;

      await SupabaseService.client.from('profiles').update({'wallet_balance': newBalance}).eq('id', userId);
      await SupabaseService.client.from('wallet_transactions').insert({
        'user_id': userId,
        'type': 'deposit',
        'amount': amount,
        'balance_before': currentBalance,
        'balance_after': newBalance,
        'status': 'success',
        'reference': reference,
        'description': 'Wallet funding via Paystack',
      });

      if (mounted) {
        GacomSnackbar.show(context, '₦${amount.toStringAsFixed(0)} added to wallet!', isSuccess: true);
        _loadData();
      }
    } catch (e) {
      if (mounted) GacomSnackbar.show(context, 'Payment verification failed', isError: true);
    }
  }

  void _showWithdrawSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Withdraw Funds', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.w700, color: GacomColors.textPrimary)),
            const SizedBox(height: 20),
            GacomTextField(
              controller: amountCtrl,
              label: 'Amount (₦)',
              hint: 'Minimum ₦1,000',
              prefixIcon: Icons.attach_money_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text('Withdraw to your registered bank account.\nProcessed within 24 hours.', style: TextStyle(color: GacomColors.textMuted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            GacomButton(label: 'REQUEST WITHDRAWAL', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(2)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(2)}K';
    return amount.toStringAsFixed(2);
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final double value;
  const _BalanceItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Rajdhani')),
        Text('₦${value.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Rajdhani')),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GacomColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GacomColors.deepOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: GacomColors.deepOrange, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 12, color: GacomColors.textPrimary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final type = transaction['type'] as String? ?? '';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
    final status = transaction['status'] as String? ?? '';
    final isCredit = ['deposit', 'competition_win', 'refund'].contains(type);
    final createdAt = DateTime.tryParse(transaction['created_at'] ?? '') ?? DateTime.now();

    IconData icon;
    switch (type) {
      case 'deposit': icon = Icons.add_circle_outline_rounded; break;
      case 'withdrawal': icon = Icons.arrow_circle_up_outlined; break;
      case 'competition_entry': icon = Icons.sports_esports_rounded; break;
      case 'competition_win': icon = Icons.emoji_events_rounded; break;
      case 'purchase': icon = Icons.shopping_bag_outlined; break;
      default: icon = Icons.swap_horiz_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GacomColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isCredit ? GacomColors.success : GacomColors.error).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isCredit ? GacomColors.success : GacomColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['description'] ?? _typeLabel(type),
                  style: const TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${createdAt.day}/${createdAt.month}/${createdAt.year} · $status',
                  style: const TextStyle(color: GacomColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}₦${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isCredit ? GacomColors.success : GacomColors.error,
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'deposit': return 'Wallet Funding';
      case 'withdrawal': return 'Withdrawal';
      case 'competition_entry': return 'Competition Entry';
      case 'competition_win': return 'Competition Win';
      case 'purchase': return 'Store Purchase';
      case 'refund': return 'Refund';
      default: return type;
    }
  }
}

class _PaystackWebView extends StatefulWidget {
  final String url;
  final String reference;
  final double amount;
  final VoidCallback onSuccess;

  const _PaystackWebView({
    required this.url,
    required this.reference,
    required this.amount,
    required this.onSuccess,
  });

  @override
  State<_PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<_PaystackWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          if (req.url.contains('wallet/verify') || req.url.contains('reference=${widget.reference}')) {
            Navigator.pop(context);
            widget.onSuccess();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('SECURE PAYMENT'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
