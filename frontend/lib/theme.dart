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

/// Soft purple shadow shared by cards.
const List<BoxShadow> softShadow = [
  BoxShadow(color: Color(0x146D28D9), blurRadius: 14, offset: Offset(0, 4)),
];

/// White rounded card look used across the app.
BoxDecoration cardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFEDE4F7)),
    boxShadow: softShadow,
  );
}

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
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

/// App bar with the brand gradient, for screens opened on top of the app.
PreferredSizeWidget brandAppBar(String title) {
  return AppBar(
    title: Text(title),
    foregroundColor: Colors.white,
    backgroundColor: Colors.transparent,
    scrolledUnderElevation: 0,
    flexibleSpace: const DecoratedBox(
      decoration: BoxDecoration(gradient: brandGradient),
    ),
  );
}
