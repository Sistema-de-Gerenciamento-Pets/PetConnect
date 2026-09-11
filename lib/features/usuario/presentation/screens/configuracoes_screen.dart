import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_providers.dart';

/// Configurações do tutor: editar perfil (RF08) e excluir conta (RF09).
class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() =>
      _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen> {
  bool _excluindo = false;

  Future<void> _handleSair() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza que deseja sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmou == true) await ref.read(usuarioRepositoryProvider).signOut();
  }

  Future<void> _confirmarExclusaoConta() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Tem certeza que deseja excluir sua conta? Todos os seus pets e os dados associados a '
          'eles (vacinas, histórico médico) serão apagados permanentemente. Esta ação não pode ser '
          'desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir conta',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    setState(() => _excluindo = true);

    try {
      await ref.read(usuarioRepositoryProvider).deleteAccount();
      // Após a exclusão, o redirect do go_router leva de volta ao login
      // assim que authStateChangesProvider emitir null.
    } catch (_) {
      if (mounted) {
        setState(() => _excluindo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Não foi possível excluir a conta. Tente novamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAsync = ref.watch(currentUsuarioProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Configurações',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: usuarioAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Não foi possível carregar seus dados.',
                style: TextStyle(color: AppColors.error)),
          ),
          data: (usuario) {
            if (usuario == null) return const SizedBox.shrink();

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline,
                      color: AppColors.textPrimary),
                  title: const Text('Editar perfil',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Nome, telefone e foto',
                      style: TextStyle(color: AppColors.textMuted)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textMuted),
                  onTap: () => context.push('/configuracoes/editar-perfil',
                      extra: usuario),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.logout, color: AppColors.textPrimary),
                  title: const Text('Sair da conta',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: _handleSair,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: _excluindo
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.error),
                        )
                      : const Icon(Icons.delete_forever_outlined,
                          color: AppColors.error),
                  title: const Text('Excluir conta',
                      style: TextStyle(color: AppColors.error)),
                  subtitle: const Text(
                    'Remove sua conta e todos os seus pets permanentemente',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  onTap: _excluindo ? null : _confirmarExclusaoConta,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
