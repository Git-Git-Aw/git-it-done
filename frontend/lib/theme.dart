import 'package:flutter/material.dart';

/// Brand colours taken from the Git-Inside logo (deep purple to pink).
const Color brandDeep = Color(0xFF6D28D9);
const Color brandPurple = Color(0xFFA855F7);
const Color brandPink = Color(0xFFC026D3);

/// Neutral colours (Clean Slate): soft page background, dark ink for text,
/// and a quiet border, so the purple stays an accent.
const Color pageBackground = Color(0xFFF7F4FB);
const Color inkDark = Color(0xFF1F1635);
const Color inkSoft = Color(0xFF6B6480);
const Color lineSoft = Color(0xFFEAE2F5);

/// Spacing and corner sizes shared by the whole app.
const double spaceS = 8;
const double spaceM = 16;
const double spaceL = 24;
const double radiusM = 14;
const double radiusL = 20;

/// Widest a page may grow on a big screen (the side bar stays on the left).
const double pageMaxWidth = 1200;

/// Rounded look shared by pop-up dialogs.
const ShapeBorder dialogShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(radiusL)),
);

/// Title style shared by pop-up dialogs.
const TextStyle dialogTitleStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: inkDark,
);

const LinearGradient brandGradient = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [brandDeep, brandPurple, brandPink],
);

/// Soft purple shadow shared by cards.
const List<BoxShadow> softShadow = [
  BoxShadow(color: Color(0x146D28D9), blurRadius: 18, offset: Offset(0, 6)),
];

/// White rounded card look used across the app.
BoxDecoration cardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radiusL),
    border: Border.all(color: lineSoft),
    boxShadow: softShadow,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: brandPurple),
    scaffoldBackgroundColor: pageBackground,
  );
}

InputDecoration fieldDecoration(
  String label, {
  IconData? icon,
  Widget? suffix,
  String? hint,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: alignLabelWithHint,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusM),
      borderSide: const BorderSide(color: lineSoft),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusM),
      borderSide: const BorderSide(color: lineSoft),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusM),
      borderSide: const BorderSide(color: brandPurple, width: 2),
    ),
  );
}

/// App bar with the brand gradient, for screens opened on top of the app.
PreferredSizeWidget brandAppBar(String title) {
  return AppBar(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    foregroundColor: Colors.white,
    // Solid purple underneath, so the white title is readable even if the
    // gradient is not drawn. The gradient fills the whole bar on top of it.
    backgroundColor: brandDeep,
    scrolledUnderElevation: 0,
    flexibleSpace: const SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: brandGradient),
      ),
    ),
  );
}

/// The Git-Inside logo with rounded corners (no extra white ring around it).
class LogoTile extends StatelessWidget {
  const LogoTile({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset('assets/logo.png', fit: BoxFit.cover),
      ),
    );
  }
}
