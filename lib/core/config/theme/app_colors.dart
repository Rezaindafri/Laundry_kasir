import 'package:flutter/material.dart';

/// Palet warna resmi aplikasi Laundry Management System.
/// Jangan hardcode warna di luar file ini agar tema tetap konsisten.
abstract class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF12355B);
  static const Color primaryDark = Color(0xFF0B2745);
  static const Color secondary = Color(0xFFB9DDF5);

  // Surface
  static const Color background = Color(0xFFF8FAFC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE5ECF3);

  // Text
  static const Color textPrimary = Color(0xFF102A43);
  static const Color textSecondary = Color(0xFF62758A);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status Laundry
  static const Color statusDiterima = Color(0xFF42A5F5);
  static const Color statusDicuci = Color(0xFF29B6F6);
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
  static const Color info = Color(0xFF0288D1);
}
