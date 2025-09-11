import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      // The GoRouter redirect will handle navigation to the login screen.
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('tabs.settings'.tr()),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            subtitle: const Text('세션을 종료하고 로그인 화면으로 돌아갑니다.'),
            onTap: () => _signOut(context),
          ),
          // Add other settings options here in the future
        ],
      ),
    );
  }
}

