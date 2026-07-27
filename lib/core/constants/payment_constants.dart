import 'package:flutter/material.dart';

class PaymentConstants {
  PaymentConstants._();

  static const List<Map<String, dynamic>> paymentMethods = [
    {
      'name': 'UPI',
      'icon': Icons.account_balance,
      'desc': 'Google Pay, PhonePe, Paytm',
    },
    {
      'name': 'Card',
      'icon': Icons.credit_card,
      'desc': 'Credit or Debit card',
    },
    {
      'name': 'Net Banking',
      'icon': Icons.language,
      'desc': 'All major banks',
    },
  ];
}
