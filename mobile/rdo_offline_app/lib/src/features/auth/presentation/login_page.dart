import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../application/auth_session_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.controller,
    required this.deviceName,
    required this.platform,
    super.key,
  });

  final AuthSessionController controller;
  final String deviceName;
  final String platform;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _bgTop = Color(0xFFFAFBFC);
  static const Color _bgBottom = Colors.white;
  static const Color _surface = Colors.white;
  static const Color _surfaceBorder = Color(0xFFE1E6EA);
  static const Color _fieldFill = Colors.white;
  static const Color _fieldBorder = Color(0xFFD0D8DF);
  static const Color _textMain = Color(0xFF111111);
  static const Color _textMuted = Color(0xFF5F6770);

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    await widget.controller.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      deviceName: widget.deviceName,
      platform: widget.platform,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.busy;
        final message = widget.controller.message;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[_bgTop, _bgBottom],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 420,
                          minHeight: constraints.maxHeight - 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 20),
                            _buildHeader(),
                            const SizedBox(height: 28),
                            _buildLoginCard(busy: busy, message: message),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.supervisorDeep,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF101010)),
          ),
          child: const Icon(
            Icons.anchor_rounded,
            color: AppTheme.supervisorLime,
            size: 28,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Synchro',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.supervisorDeep,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard({required bool busy, required String? message}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceBorder),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F00101F),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _FieldLabel(text: 'Usuário'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              enabled: !busy,
              textInputAction: TextInputAction.next,
              style: const TextStyle(
                color: _textMain,
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: _decoration(hintText: 'Entre com seu login'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Informe o usuário.';
                }
                return null;
              },
            ),
            const SizedBox(height: 13),
            _FieldLabel(text: 'Senha'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              enabled: !busy,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: _textMain,
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: _decoration(
                hintText: 'Digite sua senha',
                suffixIcon: IconButton(
                  onPressed: busy
                      ? null
                      : () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _textMuted,
                    size: 20,
                  ),
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return 'Informe a senha.';
                }
                return null;
              },
            ),
            if (message != null && message.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _ErrorBanner(message: message),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.supervisorLime,
                  disabledBackgroundColor: const Color(0xFF6A7E12),
                  foregroundColor: const Color(0xFF101E00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF101E00),
                        ),
                      )
                    : const Text('Entrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration({required String hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: _textMuted.withValues(alpha: 0.7),
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: _fieldFill,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppTheme.supervisorLime,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE11D48)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.2),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFB42318),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _LoginPageState._textMuted,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Color(0xFFB42318),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
