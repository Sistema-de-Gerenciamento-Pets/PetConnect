import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/upload_error.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/pet.dart';
import '../providers/anexo_providers.dart';
import '../providers/pet_providers.dart';
import '../widgets/pet_cover_image.dart';

const _tamanhoMaximoCapa = 5 * 1024 * 1024; // 5MB — ver docs/seguranca.md.

/// Configurações de um pet específico — nunca do tutor. Corrige o bug em
/// que "Configurações" no perfil do pet abria a tela de conta do tutor
/// (prompt_correcao_configuracoes_perfil_pet.md, 2026-09-13): esta tela
/// recebe o [petId] e mantém esse contexto o tempo todo, então
/// "Configurações da Felícia" nunca mostra ou mexe nos dados do Aleks (ou
/// do tutor).
///
/// Editar e excluir, que antes ficavam expostos na tela principal do
/// perfil, moram só aqui agora.
class PetSettingsScreen extends ConsumerStatefulWidget {
  const PetSettingsScreen({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<PetSettingsScreen> createState() => _PetSettingsScreenState();
}

class _PetSettingsScreenState extends ConsumerState<PetSettingsScreen> {
  bool _enviandoCapa = false;
  bool _removendoCapa = false;
  bool _excluindo = false;
  String? _error;

  Future<void> _alterarCapa(Pet pet) async {
    final arquivo = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (arquivo == null) return;

    final bytes = await arquivo.readAsBytes();
    if (bytes.length > _tamanhoMaximoCapa) {
      setState(() => _error = 'A foto excede o tamanho máximo de 5MB.');
      return;
    }

    final uid = ref.read(currentUsuarioProvider).valueOrNull?.id;
    if (uid == null) return;

    setState(() {
      _error = null;
      _enviandoCapa = true;
    });

    final anexos = ref.read(anexoRepositoryProvider);
    final capaAntiga = pet.capa;

    try {
      final path =
          'pets/capas/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await anexos.upload(
          path: path, bytes: bytes, contentType: 'image/jpeg');
      await ref.read(petRepositoryProvider).updatePet(pet.copyWith(capa: url));

      // Limpeza best-effort da capa antiga — não impede a troca se falhar
      // (mesmo comportamento tolerante já usado em histórico médico).
      if (capaAntiga != null && capaAntiga.isNotEmpty) {
        unawaited(anexos.delete(capaAntiga));
      }

      ref.invalidate(petProvider(pet.id));
      ref.invalidate(petsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _error = describirErroUpload(e, item: 'a capa'));
      }
    } finally {
      if (mounted) setState(() => _enviandoCapa = false);
    }
  }

  Future<void> _removerCapa(Pet pet) async {
    final capaAtual = pet.capa;
    if (capaAtual == null || capaAtual.isEmpty) return;

    setState(() {
      _error = null;
      _removendoCapa = true;
    });

    try {
      // String vazia (não null) limpa o campo de verdade — ver
      // UpdatePetRequest no backend (null = não altera).
      await ref.read(petRepositoryProvider).updatePet(pet.copyWith(capa: ''));
      unawaited(ref.read(anexoRepositoryProvider).delete(capaAtual));
      ref.invalidate(petProvider(pet.id));
      ref.invalidate(petsProvider);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Não foi possível remover a capa. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _removendoCapa = false);
    }
  }

  Future<void> _confirmarExclusao(Pet pet) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir perfil do pet'),
        content: Text(
            'Excluir o perfil de ${pet.nome}? Esta ação não pode ser desfeita.'),
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

    if (confirmou != true || _excluindo) return;

    setState(() => _excluindo = true);

    try {
      await ref.read(petRepositoryProvider).deletePet(pet.id);
      ref.invalidate(petsProvider);
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        setState(() => _excluindo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Não foi possível excluir o pet. Tente novamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petProvider(widget.petId));
    final pet = petAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          pet != null ? 'Configurações de ${pet.nome}' : 'Configurações do Pet',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
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
            if (pet == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Pet não encontrado.',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              );
            }

            final temCapa = pet.capa != null && pet.capa!.isNotEmpty;

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined,
                      color: AppColors.textPrimary),
                  title: const Text('Editar perfil',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text('Dados de ${pet.nome}',
                      style: const TextStyle(color: AppColors.textMuted)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textMuted),
                  onTap: () =>
                      context.push('/pet/${pet.id}/editar', extra: pet),
                ),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Foto de capa',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PetCoverImage(capaUrl: pet.capa, height: 100),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _enviandoCapa || _removendoCapa
                              ? null
                              : () => _alterarCapa(pet),
                          icon: _enviandoCapa
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.image_outlined),
                          label: Text(temCapa ? 'Alterar' : 'Adicionar capa'),
                        ),
                      ),
                      if (temCapa) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _enviandoCapa || _removendoCapa
                                ? null
                                : () => _removerCapa(pet),
                            icon: _removendoCapa
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.error),
                                  )
                                : const Icon(Icons.delete_outline,
                                    color: AppColors.error),
                            label: const Text('Remover',
                                style: TextStyle(color: AppColors.error)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13)),
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
                  title: const Text('Excluir perfil do pet',
                      style: TextStyle(color: AppColors.error)),
                  subtitle: Text('Remove ${pet.nome} do aplicativo',
                      style: const TextStyle(color: AppColors.textMuted)),
                  onTap: _excluindo ? null : () => _confirmarExclusao(pet),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
