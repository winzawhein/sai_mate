import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _restore();
  }

  static const _key = 'sai_mate_theme_mode';

  Future<void> _restore() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    if (!mounted || value == null) return;
    state = ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setDark(bool enabled) async {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
    await (await SharedPreferences.getInstance()).setString(_key, state.name);
  }
}
