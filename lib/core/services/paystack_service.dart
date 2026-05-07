import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import 'supabase_service.dart';
import '../../shared/widgets/gacom_snackbar.dart';

class PaystackService {
  /// Initialize a Paystack transaction via the Edge Function and open the
  /// returned authorization_url in the browser.
  ///
  /// Returns the reference string if the URL was opened successfully,
  /// or null on failure.
  static Future<String?> initializeAndPay({
    required BuildContext context,
    required double amountNaira,
    required String reference,
    String? callbackUrl,
  }) async {
    final email = SupabaseService.currentUser?.email ?? '';
    if (email.isEmpty) {
      GacomSnackbar.show(context, 'Please log in to continue', isError: true);
      return null;
    }

    try {
      // Call Supabase Edge Function — secret key stays server-side
      final response = await SupabaseService.client.functions.invoke(
        'paystack-init',
        body: {
          'email': email,
          'amount': (amountNaira * 100).round(), // convert to kobo
          'reference': reference,
          'callback_url': callbackUrl ?? 'https://gacom.netlify.app/store',
        },
      );

      if (response.status != 200) {
        final msg = response.data?['error'] ?? 'Payment initialization failed';
        if (context.mounted) {
          GacomSnackbar.show(context, msg.toString(), isError: true);
        }
        return null;
      }

      final authUrl = response.data?['authorization_url'] as String?;
      if (authUrl == null || authUrl.isEmpty) {
        if (context.mounted) {
          GacomSnackbar.show(context, 'Could not get payment link', isError: true);
        }
        return null;
      }

      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return reference;
      } else {
        if (context.mounted) {
          GacomSnackbar.show(context, 'Could not open payment page', isError: true);
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        GacomSnackbar.show(context, 'Payment error: ${e.toString()}', isError: true);
      }
      return null;
    }
  }
}
