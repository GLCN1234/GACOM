import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  /// Initialise a Paystack transaction via the Paystack API directly.
  /// The authorization_url returned is opened in browser.
  /// Public key is NOT embedded in a URL — it is sent as an Authorization header.
  Future<void> _initiatePaystack(double amount) async {
    final userEmail = SupabaseService.currentUser?.email ?? '';
    final reference =
        'GAC_${const Uuid().v4().substring(0, 8).toUpperCase()}';
    final amountKobo = (amount * 100).toInt();

    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse('https://api.paystack.co/transaction/initialize'),
        headers: {
          'Authorization': 'Bearer ${AppConstants.paystackPublicKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': userEmail,
          'amount': amountKobo,
          'reference': reference,
          'callback_url': 'https://gacom.netlify.app/wallet',
          'metadata': {
            'user_id': SupabaseService.currentUserId,
            'custom_fields': [
              {
                'display_name': 'Platform',
                'variable_name': 'platform',
                'value': 'GACOM'
              }
            ]
          }
        }),
      );

      if (mounted) setState(() => _loading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final authUrl = data['data']?['authorization_url'] as String?;
        if (authUrl != null) {
          final uri = Uri.parse(authUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            // Record pending transaction in DB
            await SupabaseService.client
                .from('wallet_transactions')
                .insert({
              'user_id': SupabaseService.currentUserId,
              'type': 'deposit',
              'amount': amount,
              'reference': reference,
              'status': 'pending',
              'description': 'Wallet funding via Paystack',
            });
          }
        }
      } else {
        if (mounted) {
          GacomSnackbar.show(context, 'Payment init failed. Try again.',
              isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        GacomSnackbar.show(context, 'Network error. Check connection.',
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance =
        (_profile?['wallet_balance'] as num?)?.toDouble() ?? 0;
    final locked =
        (_profile?['wallet_locked_balance'] as num?)?.toDouble() ?? 0;
    final winnings =
        (_profile?['total_winnings'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('WALLET')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : RefreshIndicator(
              color: GacomColors.deepOrange,
              onRefresh: () async {
                setState(() => _loading = true);
                await _loadData();
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Balance card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: GacomColors.orangeGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: GacomColors.deepOrange.withOpacity(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Balance',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontFamily: 'Rajdhani')),
                        const SizedBox(height: 8),
                        Text('₦${balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 20),
                        Row(children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('In Competitions',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                              Text('₦${locked.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Rajdhani')),
                            ],
                          ),
                          const SizedBox(width: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Winnings',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                              Text('₦${winnings.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Rajdhani')),
                            ],
                          ),
                        ]),
                      ],
                    ),
                  ).animate().fadeIn(),

                  const SizedBox(height: 20),

                  // Action buttons — always visible, not hidden
                  Row(children: [
                    Expanded(
                        child: _QuickAction(
                      icon: Icons.add_rounded,
                      label: 'Fund Wallet',
                      color: GacomColors.deepOrange,
                      onTap: () => _showFundSheet(context),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _QuickAction(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Withdraw',
                      color: GacomColors.info,
                      onTap: () => _showWithdrawSheet(context),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _QuickAction(
                      icon: Icons.history_rounded,
                      label: 'History',
                      color: GacomColors.success,
                      onTap: () {},
                    )),
                  ]),

                  const SizedBox(height: 28),
                  const Text('Recent Transactions',
                      style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: GacomColors.textPrimary)),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No transactions yet',
                                style: TextStyle(
                                    color: GacomColors.textMuted))))
                  else
                    ..._transactions
                        .map((t) => _TransactionItem(transaction: t)),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: GacomColors.deepOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: GacomColors.deepOrange),
              ),
              const SizedBox(width: 12),
              const Text('Fund Wallet',
                  style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: GacomColors.textPrimary)),
            ]),
            const SizedBox(height: 6),
            const Text('Secure payment via Paystack',
                style:
                    TextStyle(color: GacomColors.textMuted, fontSize: 13)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [500, 1000, 2000, 5000, 10000]
                  .map((a) => GestureDetector(
                        onTap: () => amountCtrl.text = a.toString(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                              color: GacomColors.surfaceDark,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                  color: GacomColors.border)),
                          child: Text('₦$a',
                              style: const TextStyle(
                                  color: GacomColors.textPrimary,
                                  fontFamily: 'Rajdhani',
                                  fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            GacomTextField(
                controller: amountCtrl,
                label: 'Amount (₦)',
                hint: 'Enter amount',
                prefixIcon: Icons.attach_money_rounded,
                keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            GacomButton(
              label: 'PAY WITH PAYSTACK',
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount < 500) {
                  GacomSnackbar.show(ctx, 'Minimum is ₦500',
                      isError: true);
                  return;
                }
                Navigator.pop(ctx);
                _initiatePaystack(amount);
              },
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lock_rounded,
                  size: 12, color: GacomColors.textMuted),
              const SizedBox(width: 4),
              const Text('Secured by Paystack',
                  style: TextStyle(
                      color: GacomColors.textMuted, fontSize: 11)),
            ]),
          ],
        ),
      ),
    );
  }

  void _showWithdrawSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Withdraw Funds',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: GacomColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Processed within 24 hours.',
                style:
                    TextStyle(color: GacomColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            GacomTextField(
                controller: amountCtrl,
                label: 'Amount (₦)',
                hint: 'Min ₦1,000',
                prefixIcon: Icons.attach_money_rounded,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            GacomTextField(
                controller: accountCtrl,
                label: 'Account Number',
                hint: '0123456789',
                prefixIcon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            GacomTextField(
                controller: bankCtrl,
                label: 'Bank Name',
                hint: 'e.g. Opay, GTBank',
                prefixIcon: Icons.account_balance_rounded),
            const SizedBox(height: 24),
            GacomButton(
              label: 'REQUEST WITHDRAWAL',
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount < 1000) {
                  GacomSnackbar.show(ctx, 'Minimum withdrawal is ₦1,000',
                      isError: true);
                  return;
                }
                try {
                  await SupabaseService.client
                      .from('withdrawal_requests')
                      .insert({
                    'user_id': SupabaseService.currentUserId,
                    'amount': amount,
                    'account_number': accountCtrl.text.trim(),
                    'bank_name': bankCtrl.text.trim(),
                    'status': 'pending',
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    GacomSnackbar.show(context,
                        'Withdrawal request submitted ✅',
                        isSuccess: true);
                  }
                } catch (_) {
                  GacomSnackbar.show(ctx, 'Failed. Try again.',
                      isError: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
              color: GacomColors.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GacomColors.border, width: 0.5)),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: GacomColors.textPrimary),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _TransactionItem extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const _TransactionItem({required this.transaction});
  @override
  Widget build(BuildContext context) {
    final type = transaction['type'] as String? ?? '';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
    final isCredit =
        ['deposit', 'competition_win', 'refund'].contains(type);
    final createdAt =
        DateTime.tryParse(transaction['created_at'] ?? '') ??
            DateTime.now();
    final status = transaction['status'] as String? ?? 'success';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GacomColors.border, width: 0.5)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: (isCredit ? GacomColors.success : GacomColors.error)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(
              isCredit
                  ? Icons.add_circle_outline_rounded
                  : Icons.remove_circle_outline_rounded,
              color:
                  isCredit ? GacomColors.success : GacomColors.error,
              size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(transaction['description'] ?? type,
                  style: const TextStyle(
                      color: GacomColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              Row(children: [
                Text(
                    '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                    style: const TextStyle(
                        color: GacomColors.textMuted, fontSize: 12)),
                if (status == 'pending') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: GacomColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('PENDING',
                        style: TextStyle(
                            color: GacomColors.warning,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  )
                ],
              ]),
            ])),
        Text('${isCredit ? '+' : '-'}₦${amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color:
                    isCredit ? GacomColors.success : GacomColors.error)),
      ]),
    );
  }
}
