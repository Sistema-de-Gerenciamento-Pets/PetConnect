import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/auth_error_translator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/auth_header.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';

class CadastroScreen extends ConsumerStatefulWidget {
  const CadastroScreen({super.key});

  @override
  ConsumerState<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends ConsumerState<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _handleCadastro() async {
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_senhaController.text != _confirmarSenhaController.text) {
      setState(() => _error = 'As senhas não coincidem.');
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(usuarioRepositoryProvider).signUp(
            nome: _nomeController.text.trim(),
            email: _emailController.text.trim(),
            password: _senhaController.text,
            telefone: _telefoneController.text.trim(),
            // Data de nascimento não é mais pedida no cadastro — fica para
            // a edição de perfil (RF08), mantendo o formulário curto.
            dataNascimento: '',
          );
      // Navegação para /home é feita pelo redirect do go_router.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = translateAuthError(e.code));
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Não foi possível completar a operação. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeader(onBack: () => context.pop()),
              // Margem horizontal + cantos arredondados nos 4 lados: o card
              // fica mais estreito que a tela, deixando o fundo branco do
              // Scaffold aparecer nas laterais.
              Transform.translate(
                offset: const Offset(0, -32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.all(Radius.circular(32)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Crie sua conta',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Cadastre seus dados para começar a cuidar e proteger seus pets.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 24),
                          _CampoComRotulo(
                            rotulo: 'Nome completo',
                            hint: 'Ex: Maria Silva',
                            controller: _nomeController,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Informe seu nome.'
                                    : null,
                          ),
                          const SizedBox(height: 14),
                          _CampoComRotulo(
                            rotulo: 'E-mail',
                            hint: 'seu@email.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Informe seu e-mail.';
                              }
                              if (!value.contains('@')) {
                                return 'E-mail inválido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _CampoComRotulo(
                            rotulo: 'Telefone',
                            hint: '(00) 00000-0000',
                            controller: _telefoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          _CampoComRotulo(
                            rotulo: 'Senha',
                            hint: 'Mínimo 8 caracteres',
                            controller: _senhaController,
                            obscureText: !_senhaVisivel,
                            validator: (value) =>
                                (value == null || value.length < 8)
                                    ? 'Mínimo de 8 caracteres.'
                                    : null,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _senhaVisivel
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              tooltip:
                                  _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                              onPressed: () => setState(
                                  () => _senhaVisivel = !_senhaVisivel),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _CampoComRotulo(
                            rotulo: 'Confirmar senha',
                            hint: 'Repita a senha',
                            controller: _confirmarSenhaController,
                            obscureText: !_confirmarSenhaVisivel,
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Confirme sua senha.'
                                    : null,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _confirmarSenhaVisivel
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              tooltip: _confirmarSenhaVisivel
                                  ? 'Ocultar senha'
                                  : 'Mostrar senha',
                              onPressed: () => setState(() =>
                                  _confirmarSenhaVisivel =
                                      !_confirmarSenhaVisivel),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _submitting ? null : _handleCadastro,
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textOnBrand,
                                    ),
                                  )
                                : const Text('CRIAR CONTA'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo no estilo do mockup: rótulo fixo à esquerda e exemplo/valor à
/// direita, dentro de uma mesma "pílula" branca arredondada — diferente do
/// padrão "rótulo acima do campo" usado no resto do app.
class _CampoComRotulo extends StatelessWidget {
  const _CampoComRotulo({
    required this.rotulo,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final String rotulo;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            rotulo,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              textAlign: TextAlign.right,
              validator: validator,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                suffixIcon: suffixIcon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
