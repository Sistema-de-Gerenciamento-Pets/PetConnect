import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Ações secundárias do perfil do pet — Localização/avistamento (RF31-32) e
/// Configurações **do pet** (nunca do tutor — bug corrigido em
/// prompt_correcao_configuracoes_perfil_pet.md, 2026-09-13: antes este
/// botão abria as configurações da conta). O briefing de layout original
/// sugeria também "Ajuda" e "Acessibilidade", mas nenhuma das duas tem uma
/// tela real no app ainda; criar um item que não leva a lugar nenhum seria
/// uma feature falsa, então ficam de fora por ora (ver sugestão de roadmap
/// no relatório da PR).
class PetSecondaryActions extends StatelessWidget {
  const PetSecondaryActions({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          _SecondaryActionTile(
            icon: Icons.location_on_outlined,
            label: 'Localização',
            onTap: () => context.push('/pet/$petId/localizacao'),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _SecondaryActionTile(
            icon: Icons.settings_outlined,
            label: 'Configurações',
            onTap: () => context.push('/pet/$petId/configuracoes'),
          ),
        ],
      ),
    );
  }
}

class _SecondaryActionTile extends StatelessWidget {
  const _SecondaryActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
