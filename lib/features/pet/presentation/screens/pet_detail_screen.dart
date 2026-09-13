import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/pet.dart';
import '../providers/pet_providers.dart';
import '../widgets/pet_feature_grid.dart';
import '../widgets/pet_profile_header.dart';
import '../widgets/pet_secondary_actions.dart';

/// Perfil de um único pet (RF15), com atalhos para editar (RF13) e excluir
/// (RF14). Só mostra dados se o pet pertencer ao tutor autenticado — RF12,
/// reforçado aqui além das regras de segurança do Firestore.
///
/// Layout em cards (ver docs/next-stage e prompt_claude_perfil_pet_layout.md,
/// 2026-09-12): identidade do pet em destaque no topo, as 4 funcionalidades
/// principais em [PetFeatureGrid], ações secundárias reais em
/// [PetSecondaryActions], e editar/excluir preservados como já eram —
/// mesmos widgets e textos de antes, só reposicionados.
class PetDetailScreen extends ConsumerWidget {
  const PetDetailScreen({super.key, required this.petId});

  final String petId;

  Future<void> _confirmarExclusao(
      BuildContext context, WidgetRef ref, Pet pet) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir pet'),
        content: Text(
            'Tem certeza que deseja excluir ${pet.nome}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Excluir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    await ref.read(petRepositoryProvider).deletePet(pet.id);
    ref.invalidate(petsProvider);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(petProvider(petId));
    final uid = ref.watch(currentUsuarioProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: petAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Não foi possível carregar este pet.',
                style: TextStyle(color: AppColors.error)),
          ),
          data: (pet) {
            if (pet == null || pet.userId != uid) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Pet não encontrado.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PetProfileHeader(pet: pet),
                  const SizedBox(height: 28),
                  PetFeatureGrid(pet: pet),
                  const SizedBox(height: 20),
                  PetSecondaryActions(petId: pet.id),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/pet/${pet.id}/editar', extra: pet),
                    icon: const Icon(Icons.edit),
                    label: const Text('EDITAR'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _confirmarExclusao(context, ref, pet),
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                    label: const Text('EXCLUIR',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
