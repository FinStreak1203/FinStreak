/// Static asset paths for bank and wallet logos.
///
/// All paths point to files registered under `assets/images/banks/` and
/// `assets/images/wallets/` in pubspec.yaml.
class BankAssets {
  BankAssets._();

  static const String _bankDir = 'assets/images/banks';
  static const String _walletDir = 'assets/images/wallets';

  // ── Banks ──────────────────────────────────────────────
  static const String axis = '$_bankDir/AxisBank.jpg';
  static const String canara = '$_bankDir/CanaraBank.jpg';
  static const String hdfc = '$_bankDir/HdfcBank.png';
  static const String icici = '$_bankDir/IciciBank.png';
  static const String idbi = '$_bankDir/IdbiBank.png';
  static const String iob = '$_bankDir/IobBank.png';
  static const String kotak = '$_bankDir/KotakBank.png';
  static const String paytm = '$_bankDir/PaytmBank.png';
  static const String pnb = '$_bankDir/PngBank.png';
  static const String sbi = '$_bankDir/SbiBank.png';
  static const String yes = '$_bankDir/YesBank.png';

  // ── Wallets ────────────────────────────────────────────
  static const String gpay = '$_walletDir/GPay.jpg';
  static const String phonepe = '$_walletDir/PhonePe.jpg';

  static const String fallback = '$_bankDir/PngBank.png';

  /// Maps a bank name (short code OR full name) to its logo asset, or null if
  /// none matches. Handles full names like "State Bank of India" and "Indian
  /// Overseas Bank" that don't contain the short code as a substring.
  static String? matchOrNull(String bankName) {
    final name = bankName.toLowerCase();
    if (name.contains('hdfc')) return hdfc;
    if (name.contains('icici')) return icici;
    if (name.contains('axis')) return axis;
    if (name.contains('state bank') || name.contains('sbi')) return sbi;
    if (name.contains('kotak')) return kotak;
    if (name.contains('canara')) return canara;
    if (name.contains('idbi')) return idbi;
    if (name.contains('overseas') || name.contains('iob')) return iob;
    if (name.contains('paytm')) return paytm;
    if (name.contains('yes')) return yes;
    if (name.contains('punjab') || name.contains('pnb')) return pnb;
    return null;
  }

  /// Like [matchOrNull] but always returns a path (generic fallback). Callers
  /// must still use an `errorBuilder` for banks with no bundled asset.
  static String getImagePath(String bankName) =>
      matchOrNull(bankName) ?? fallback;
}
