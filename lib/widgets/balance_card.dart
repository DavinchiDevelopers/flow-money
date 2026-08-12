import 'package:flutter/material.dart';
import '../utils/constants.dart';

class BalanceCard extends StatelessWidget {
  final double balance;

  const BalanceCard({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withAlpha((cs.primary.a * 0.75 * 255.0).round().clamp(0, 255))],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            'CURRENT BALANCE',
            style: TextStyle(
            color: Colors.white.withAlpha((Colors.white.a * 0.7 * 255.0).round().clamp(0, 255)),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppConstants.formatAmount(balance),
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((Colors.white.a * 0.18 * 255.0).round().clamp(0, 255)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              balance >= 0 ? 'Positive balance' : 'Negative balance',
              style: TextStyle(
                color: Colors.white.withAlpha((Colors.white.a * 0.9 * 255.0).round().clamp(0, 255)),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
