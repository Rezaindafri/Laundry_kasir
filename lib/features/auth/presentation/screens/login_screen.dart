import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Image.asset(
                  AppConstants.appLogoAsset,
                  width: 96,
                  height: 96,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text('Selamat Datang', style: AppTextStyles.displayLarge),
                const SizedBox(height: 6),
                Text(
                  'Masuk ke ${AppConstants.appName} untuk melanjutkan',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 32),
                const LoginForm(),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '${AppConstants.appName} · Powered by Indafri',
                    style: AppTextStyles.label,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
