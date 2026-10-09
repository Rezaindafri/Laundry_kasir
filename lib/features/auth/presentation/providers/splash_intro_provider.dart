import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Menahan redirect pertama sampai animasi splash selesai satu kali.
final splashIntroCompletedProvider = StateProvider<bool>((ref) => false);

/// Menahan aplikasi di splash selama proses logout membersihkan sesi.
final logoutInProgressProvider = StateProvider<bool>((ref) => false);
