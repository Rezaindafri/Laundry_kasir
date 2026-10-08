import 'package:flutter/material.dart';

/// Palet warna resmi KarsaOne.
/// Jangan hardcode warna di luar file ini agar tema tetap konsisten.
abstract class AppColors {
  AppColors._();

  // Brand surfaces are white; blue remains the primary interaction color.
  static const Color primary = Color(0xFF0B55F6);
  static const Color primaryDark = Color(0xFF0738B8);
  static const Color primarySoft = Color(0xFFEAF1FF);
  static const Color secondary = Color(0xFFFFFFFF);
  static const Color secondaryDark = Color(0xFF0738B8);
  static const Color secondarySoft = Color(0xFFFFFFFF);
  static const Color profileAvatar = Color(0xFF90CAF9);
  static const Color profileAvatarText = Color(0xFF000000);
  static const Color splashBackground = Color(0xFFFFFFFF);

  // Surface
  static const Color background = Color(0xFFF5F8FF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFDCE6F4);

  // Text
  static const Color textPrimary = Color(0xFF10264A);
  static const Color textSecondary = Color(0xFF60748E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status Laundry
  static const Color statusDiterima = Color(0xFF318BFF);
  static const Color statusDicuci = Color(0xFF06B6D4);
  static const Color statusDikeringkan = Color(0xFFFFB74D);
  static const Color statusDisetrika = Color(0xFFFFA726);
  static const Color statusSelesai = Color(0xFF66BB6A);
  static const Color statusSudahDiambil = Color(0xFF9E9E9E);

  // Status Pembayaran
  static const Color belumBayar = Color(0xFFEF5350);
  static const Color dp = Color(0xFFFFA726);
  static const Color lunas = Color(0xFF66BB6A);

  // Semantic
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF087ED8);
}
