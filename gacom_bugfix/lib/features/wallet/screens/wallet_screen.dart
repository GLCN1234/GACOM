import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;
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

      List<Map<String, dynamic>> txns = [];
      try {
        final raw = await SupabaseService.client
            .from('wallet_transactions')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(30);
        txns = List<Map<String, dynamic>>.from(raw);
      } catch (_) {
        // 403 means RLS insert policy missing — still show balance
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _transactions = txns;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Initiates payment using Paystack Popup JS on web (no page redirect, no 404).
  /// On non-web builds it falls back to a direct API initialise call.
  Future<void> _initiatePaystack(double amount) async {
    final userId = SupabaseService.currentUserId;
    final userEmail = SupabaseService.currentUser?.email ?? '';
    final reference = 'GAC_${const Uuid().v4().substring(0, 8).toUpperCase()}';
    final amountKobo = (amount * 100).toInt();

    if (kIsWeb) {
      try {
        // Register success callback so Flutter knows payment was confirmed
        js.context['_paystackSuccessCallback'] = (String ref) async {
          // Mark the transaction as success in Supabase
          try {
            await SupabaseService.client.from('wallet_transactions').insert({
              'user_id': userId,
              'type': 'deposit',
              'amount': amount,
              'balance_before': (_profile?['wallet_balance'] as num?)?.toDouble() ?? 0,
              'balance_after': ((_profile?['wallet_balance'] as num?)?.toDouble() ?? 0) + amount,
              'reference': ref,
              'status': 'success',
              'description': 'Wallet funding via Paystack',
            });
            // Update wallet balance optimistically
            await SupabaseService.client.rpc('add_wallet_balance', params: {
              'p_user_id': userId,
              'p_amount': amount,
            });
          } catch (_) {}
          if (mounted) {
            GacomSnackbar.show(context, '₦${amount.toStringAsFixed(0)} added to wallet! 🎉',
                isSuccess: true);
            await _loadData();
          }
        };

        js.context['_paystackCloseCallback'] = () {
          if (mounted) {
            GacomSnackbar.show(context, 'Payment cancelled');
          }
        };

        // Call the paystackPay function defined in web/index.html
        js.context.callMethod('paystackPay', [
          AppConstants.paystackPublicKey,
          amountKobo,
          userEmail,
          reference,
          'https://gacom.netlify.app/wallet',
        ]);
      } catch (e) {
        if (mounted) {
          GacomSnackbar.show(context,
              'Payment error. Check your connection and try again.',
              isError: true);
        }
      }
    } else {
      // Mobile fallback — record pending and show instructions
      try {
        await SupabaseService.client.from('wallet_transactions').insert({
          'user_id': userId,
          'type': 'deposit',
          'amount': amount,
          'balance_before': (_profile?['wallet_balance'] as num?)?.toDouble() ?? 0,
          'balance_after': ((_profile?['wallet_balance'] as num?)?.toDouble() ?? 0) + amount,
          'reference': reference,
          'status': 'pending',
          'description': 'Wallet funding via Paystack',
        });
        if (mounted) {
          GacomSnackbar.show(
              context, 'Payment initiated. Ref: $reference', isSuccess: true);
          await _loadData();
        }
      } catch (e) {
        if (mounted) {
          GacomSnackbar.show(context, 'Could not initiate payment.', isError: true);
        }
      }
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
          ? const Center(
              child: CircularProgressIndicator(color: GacomColors.deepOrange))
          : RefreshIndicator(
              color: GacomColors.deepOrange,
              onRefresh: () async {
                setState(() => _loading = true);
                await _loadData();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
                                  fontSize: 13,
                                  fontFamily: 'Rajdhani',
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Text(
                            '₦${balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          Row(children: [
                            _BalanceSub(
                                label: 'In Competitions',
                                value: '₦${locked.toStringAsFixed(0)}'),
                            const SizedBox(width: 28),
                            _BalanceSub(
                                label: 'Total Winnings',
                                value: '₦${winnings.toStringAsFixed(0)}'),
                          ]),
                        ]),
                  ).animate().fadeIn(),

                  const SizedBox(height: 20),

                  // Quick action buttons — always visible
                  Row(children: [
                    Expanded(
                        child: _QuickAction(
                            icon: Icons.add_rounded,
                            label: 'Fund Wallet',
                            color: GacomColors.deepOrange,
                            onTap: () => _showFundSheet(context))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _QuickAction(
                            icon: Icons.arrow_upward_rounded,
                            label: 'Withdraw',
                            color: GacomColors.info,
                            onTap: () => _showWithdrawSheet(context))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _QuickAction(
                            icon: Icons.history_rounded,
                            label: 'History',
                            color: GacomColors.success,
                            onTap: () {})),
                  ]).animate(delay: 80.ms).fadeIn(),

                  const SizedBox(height: 28),

                  Row(children: [
                    const Text('Transactions',
                        style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: GacomColors.textPrimary)),
                    const Spacer(),
                    Text('${_transactions.length} total',
                        style: const TextStyle(
                            color: GacomColors.textMuted, fontSize: 12)),
                  ]),
                  const SizedBox(height: 12),

                  if (_transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: GacomDecorations.glassCard(radius: 16),
                      child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 48, color: GacomColors.border),
                            SizedBox(height: 12),
                            Text('No transactions yet',
                                style: TextStyle(
                                    color: GacomColors.textMuted,
                                    fontSize: 14,
                                    fontFamily: 'Rajdhani')),
                            Text('Fund your wallet to get started',
                                style: TextStyle(
                                    color: GacomColors.textMuted, fontSize: 12)),
                          ]),
                    )
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
            24, 28, 24, MediaQuery.of(ctx).viewInsets.bottom + 36),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 3,
                      decoration: BoxDecoration(
                          color: GacomColors.borderBright,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: GacomColors.deepOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: GacomColors.deepOrange,
                      size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fund Wallet',
                          style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: GacomColors.textPrimary)),
                      Text('Secure payment via Paystack',
                          style: TextStyle(
                              color: GacomColors.textMuted, fontSize: 12)),
                    ]),
              ]),
              const SizedBox(height: 20),

              // Quick amount pills
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [500, 1000, 2000, 5000, 10000]
                      .map((a) => GestureDetector(
                            onTap: () => amountCtrl.text = a.toString(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                  color: GacomColors.surfaceDark,
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                      color: GacomColors.border, width: 0.8)),
                              child: Text('₦$a',
                                  style: const TextStyle(
                                      color: GacomColors.textPrimary,
                                      fontFamily: 'Rajdhani',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ),
                          ))
                      .toList()),
              const SizedBox(height: 16),

              GacomTextField(
                  controller: amountCtrl,
                  label: 'Amount (₦)',
                  hint: 'Enter amount (min ₦500)',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: GacomButton(
                  label: 'PAY WITH PAYSTACK',
                  height: 54,
                  onPressed: () {
                    final amount = double.tryParse(
                        amountCtrl.text.replaceAll(',', ''));
                    if (amount == null || amount < 500) {
                      GacomSnackbar.show(
                          ctx, 'Minimum funding amount is ₦500',
                          isError: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    _initiatePaystack(amount);
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_rounded, size: 12, color: GacomColors.textMuted),
                SizedBox(width: 5),
                Text('Secured & encrypted by Paystack',
                    style:
                        TextStyle(color: GacomColors.textMuted, fontSize: 11)),
              ]),
            ]),
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
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 28, 24, MediaQuery.of(ctx).viewInsets.bottom + 36),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 3,
                      decoration: BoxDecoration(
                          color: GacomColors.borderBright,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Withdraw Funds',
                  style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: GacomColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Processed within 24 hours.',
                  style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
              const SizedBox(height: 20),
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
                  hint: 'e.g. Opay, GTBank, Moniepoint',
                  prefixIcon: Icons.account_balance_rounded),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: GacomButton(
                  label: 'REQUEST WITHDRAWAL',
                  height: 54,
                  onPressed: () async {
                    final amount = double.tryParse(
                        amountCtrl.text.replaceAll(',', ''));
                    if (amount == null || amount < 1000) {
                      GacomSnackbar.show(
                          ctx, 'Minimum withdrawal is ₦1,000',
                          isError: true);
                      return;
                    }
                    if (accountCtrl.text.trim().isEmpty ||
                        bankCtrl.text.trim().isEmpty) {
                      GacomSnackbar.show(
                          ctx, 'Please fill account and bank details',
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
                        GacomSnackbar.show(
                            context, 'Withdrawal request submitted ✅',
                            isSuccess: true);
                      }
                    } catch (_) {
                      GacomSnackbar.show(
                          ctx, 'Failed. Try again later.',
                          isError: true);
                    }
                  },
                ),
              ),
            ]),
      ),
    );
  }
}

// ── Sub widgets ───────────────────────────────────────────────────────────────

class _BalanceSub extends StatelessWidget {
  final String label, value;
  const _BalanceSub({required this.label, required this.value});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'Rajdhani')),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Rajdhani')),
      ]);
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
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
              color: GacomColors.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GacomColors.border, width: 0.6)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 7),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: GacomColors.textPrimary)),
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
        DateTime.tryParse(transaction['created_at'] ?? '') ?? DateTime.now();
    final status = transaction['status'] as String? ?? 'success';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: GacomDecorations.glassCard(radius: 14),
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
              color: isCredit ? GacomColors.success : GacomColors.error,
              size: 18),
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
                      fontSize: 13)),
              Row(children: [
                Text(
                    '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                    style: const TextStyle(
                        color: GacomColors.textMuted, fontSize: 11)),
                if (status == 'pending') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: GacomColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('PENDING',
                        style: TextStyle(
                            color: GacomColors.warning,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
            ])),
        Text(
          '${isCredit ? '+' : '-'}₦${amount.toStringAsFixed(0)}',
          style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isCredit ? GacomColors.success : GacomColors.error),
        ),
      ]),
    );
  }
}
