import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_provider.dart';

class SettingsState {
  final bool manualEntryEnabled;
  final bool smsParsing;
  final bool bankSyncConnected;
  final bool whatsappNotifs;
  final bool pushNotifs;
  final String alertFrequency;
  final bool biometricEnabled;
  final bool darkMode;
  final String currency;

  const SettingsState({
    this.manualEntryEnabled = true,
    this.smsParsing = true,
    this.bankSyncConnected = false,
    this.whatsappNotifs = false,
    this.pushNotifs = true,
    this.alertFrequency = 'Real-time',
    this.biometricEnabled = false,
    this.darkMode = false,
    this.currency = 'INR',
  });

  SettingsState copyWith({
    bool? manualEntryEnabled,
    bool? smsParsing,
    bool? bankSyncConnected,
    bool? whatsappNotifs,
    bool? pushNotifs,
    String? alertFrequency,
    bool? biometricEnabled,
    bool? darkMode,
    String? currency,
  }) =>
      SettingsState(
        manualEntryEnabled: manualEntryEnabled ?? this.manualEntryEnabled,
        smsParsing: smsParsing ?? this.smsParsing,
        bankSyncConnected: bankSyncConnected ?? this.bankSyncConnected,
        whatsappNotifs: whatsappNotifs ?? this.whatsappNotifs,
        pushNotifs: pushNotifs ?? this.pushNotifs,
        alertFrequency: alertFrequency ?? this.alertFrequency,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        darkMode: darkMode ?? this.darkMode,
        currency: currency ?? this.currency,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(const SettingsState()) {
    _load();
  }

  void _load() {
    state = SettingsState(
      manualEntryEnabled: _prefs.getBool('manualEntry') ?? true,
      smsParsing: _prefs.getBool('smsParsing') ?? true,
      bankSyncConnected: _prefs.getBool('bankSync') ?? false,
      whatsappNotifs: _prefs.getBool('whatsapp') ?? false,
      pushNotifs: _prefs.getBool('pushNotifs') ?? true,
      alertFrequency: _prefs.getString('alertFreq') ?? 'Real-time',
      biometricEnabled: _prefs.getBool('biometric') ?? false,
      darkMode: _prefs.getBool('darkMode') ?? false,
      currency: _prefs.getString('currency') ?? 'INR',
    );
  }

  void toggleManualEntry(bool v) {
    _prefs.setBool('manualEntry', v);
    state = state.copyWith(manualEntryEnabled: v);
  }

  void toggleSmsParsing(bool v) {
    _prefs.setBool('smsParsing', v);
    state = state.copyWith(smsParsing: v);
  }

  void toggleWhatsapp(bool v) {
    _prefs.setBool('whatsapp', v);
    state = state.copyWith(whatsappNotifs: v);
  }

  void togglePushNotifs(bool v) {
    _prefs.setBool('pushNotifs', v);
    state = state.copyWith(pushNotifs: v);
  }

  void toggleBiometric(bool v) {
    _prefs.setBool('biometric', v);
    state = state.copyWith(biometricEnabled: v);
  }

  void toggleDarkMode(bool v) {
    _prefs.setBool('darkMode', v);
    state = state.copyWith(darkMode: v);
  }

  void setAlertFrequency(String v) {
    _prefs.setString('alertFreq', v);
    state = state.copyWith(alertFrequency: v);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
