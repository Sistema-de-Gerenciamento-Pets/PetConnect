import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../pet/presentation/providers/pet_providers.dart';
import '../../../pet/presentation/widgets/pet_card.dart';
import '../../domain/usuario.dart';
import '../providers/auth_providers.dart';

/// Home do tutor: lista os pets vinculados à conta (RF11), com atalho para
/// cadastrar um novo (RF10) e acessar configurações.
///
/// A Home é a raiz da navegação autenticada — o botão físico/gesto de
/// voltar não fecha o app: encerra a sessão (com confirmação) e volta ao
/// login, mesmo fluxo do ícone de logout em Configurações.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _handleSair(BuildContext context, WidgetRef ref) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioAsync = ref.watch(currentUsuarioProvider);
    final petsAsync = ref.watch(petsProvider);
    final colors = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleSair(context, ref);
      },
      child: Scaffold(
        backgroundColor: colors.homeBackdrop,
        body: SafeArea(
          child: usuarioAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Text(
                'Não foi possível carregar seus dados.',
                style: TextStyle(color: colors.error),
              ),
            ),
            data: (usuario) => Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: _Cabecalho(usuario: usuario),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _AdicionarPetCta(
                          onTap: () => context.push('/pet/novo')),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Meus Pets',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: petsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => Center(
                          child: Text(
                            'Não foi possível carregar seus pets.',
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                        data: (pets) {
                          Future<void> atualizar() async {
                            ref.invalidate(petsProvider);
                            await ref.read(petsProvider.future);
                          }

                          if (pets.isEmpty) {
                            return RefreshIndicator(
                              onRefresh: atualizar,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 120),
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'Você ainda não cadastrou nenhum pet.\nToque em "Adicionar Novo Pet" para começar.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: colors.textMuted),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return RefreshIndicator(
                            onRefresh: atualizar,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                              itemCount: pets.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final pet = pets[index];
                                return PetCard(
                                  pet: pet,
                                  colorIndex: index,
                                  onTap: () => context.push('/pet/${pet.id}'),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _RodapeInfo(),
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

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.usuario});

  final Usuario? usuario;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final primeiroNome = usuario != null && usuario!.nome.isNotEmpty
        ? usuario!.nome.trim().split(' ').first
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: colors.background,
          backgroundImage:
              usuario?.foto != null ? NetworkImage(usuario!.foto!) : null,
          child: usuario?.foto == null
              ? Icon(Icons.person, size: 32, color: colors.brandMedium)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primeiroNome != null ? 'Olá, $primeiroNome!' : 'Olá!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecione um pet para acessar o perfil',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        _BotaoCircular(
          icon: Icons.settings_outlined,
          tooltip: 'Configurações',
          onTap: () => context.push('/configuracoes'),
        ),
      ],
    );
  }
}

class _BotaoCircular extends StatelessWidget {
  const _BotaoCircular(
      {required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: colors.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _AdicionarPetCta extends StatelessWidget {
  const _AdicionarPetCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Índice 2 da paleta cíclica é sempre o tom "verde" em qualquer modo —
    // reaproveita em vez de fixar uma cor própria só pra este card.
    final fundo = colors.petCardBackgrounds[2];
    final destaque = colors.petCardAccents[2];

    return Material(
      color: fundo,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.cardBackground,
                child: Icon(Icons.add, color: destaque),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adicionar Novo Pet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.success,
                      ),
                    ),
                    Text(
                      'Cadastre um novo pet no app',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: destaque),
            ],
          ),
        ),
      ),
    );
  }
}

class _RodapeInfo extends StatelessWidget {
  const _RodapeInfo();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.homeBackdrop,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: colors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Seus pets, cuidados e momentos especiais, todos em um só lugar.',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
          Icon(Icons.favorite, color: colors.success, size: 18),
        ],
      ),
    );
  }
}
