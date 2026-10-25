import 'package:flutter/material.dart';

/// Brand colours taken from the Git-Inside logo (deep purple to pink).
const Color brandDeep = Color(0xFF6D28D9);
const Color brandPurple = Color(0xFFA855F7);
const Color brandPink = Color(0xFFC026D3);

const LinearGradient brandGradient = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [brandDeep, brandPurple, brandPink],
);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: brandPurple),
    scaffoldBackgroundColor: const Color(0xFFFAF7FD),
  );
}

InputDecoration fieldDecoration(String label, {IconData? icon, Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    border: const OutlineInputBorder(),
  );
}
