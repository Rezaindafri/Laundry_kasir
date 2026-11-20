import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A successful mutation invalidates audit readers, including an offstage
/// Owner dashboard. No polling, account data, or extra operational permissions.
final auditRevisionProvider = StateProvider<int>((ref) => 0);
