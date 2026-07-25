import 'package:flutter/material.dart';

/// Uniform square logo for a bank / wallet.
///
/// Every logo is rendered inside a fixed [size] x [size] rounded box with a
/// neutral background, so logos with different aspect ratios all appear the
/// same size. Falls back to a generic bank icon if the asset is missing.
class BankLogo extends StatelessWidget {
  final String imagePath;
  final double size;

  const BankLogo({super.key, required this.imagePath, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(size * 0.12),
      child: Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.account_balance,
          size: size * 0.6,
          color: const Color(0xFF3B82F6),
        ),
      ),
    );
  }
}

/// Small circular bank logo, designed to sit as a corner badge on a
/// transaction's category avatar. Renders nothing if the asset is missing.
class BankBadge extends StatelessWidget {
  final String imagePath;
  final double size;

  const BankBadge({super.key, required this.imagePath, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 2),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
