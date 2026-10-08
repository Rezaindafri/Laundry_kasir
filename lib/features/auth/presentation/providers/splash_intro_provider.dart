import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Menahan redirect pertama sampai animasi splash selesai satu kali.
final splashIntroCompletedProvider = StateProvider<bool>((ref) => false);
