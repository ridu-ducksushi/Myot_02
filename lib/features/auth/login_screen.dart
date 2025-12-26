
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // 단일 진실의 원천: 공통 상수
  static const double _appNameFontSize = 60.0;
  static const double _spacingSmall = 16.0;
  static const double _spacingMedium = 24.0;
  static const double _spacingLarge = 48.0;

  // DRY 원칙: 공통 인증 처리 로직
  Future<void> _handleAuth({
    required Future<void> Function() authAction,
    required String successMessageKey,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await authAction();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessageKey.tr())),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth.login_failed'.tr(namedArgs: {'error': e.message}))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth.login_error'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    await _handleAuth(
      authAction: () => Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ),
      successMessageKey: 'auth.login_success',
    );
  }

  Future<void> _loginAsGuest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 게스트 로그인 시도 중...');
      final response = await Supabase.instance.client.auth.signInAnonymously();
      print('✅ 게스트 로그인 성공: ${response.user?.id}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth.guest_login_success'.tr())),
        );
      }
    } on AuthException catch (e) {
      final errorMessage = '게스트 로그인 실패: ${e.message} (코드: ${e.statusCode})';
      print('❌ 게스트 로그인 AuthException: $errorMessage');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      final errorMessage = '게스트 로그인 에러: $e';
      print('❌ 게스트 로그인 에러: $errorMessage');
      print('스택 트레이스: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 크로스플랫폼 대응: 논리적 위치 사용
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('auth.login'.tr()),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(_spacingMedium),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'app_name'.tr(),
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: _appNameFontSize,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isCompact ? _spacingMedium : _spacingLarge),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'auth.email'.tr(),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty || !value.contains('@')) {
                          return 'auth.email_required'.tr();
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: _spacingSmall),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'auth.password'.tr(),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'auth.password_required'.tr();
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: _spacingMedium),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _login,
                            child: Text('auth.login'.tr()),
                          ),
                    SizedBox(height: _spacingSmall),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: Text('auth.signup_link'.tr()),
                    ),
                    SizedBox(height: _spacingMedium),
                    const Divider(),
                    SizedBox(height: _spacingMedium),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loginAsGuest,
                      icon: const Icon(Icons.person_outline),
                      label: Text('auth.guest_login'.tr()),
                    ),
                    SizedBox(height: _spacingSmall / 2),
                    Text(
                      'auth.guest_login_description'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
