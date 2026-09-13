import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Item padrão de qualquer menu de configurações do app (tutor ou pet):
/// ícone à esquerda, título, chevron à direita — uma linha, uma função,
/// sem subtítulo (a explicação fica na tela seguinte). Ver
/// docs/features/theme-and-settings-menu.md.
///
/// Reaproveitado em toda tela de configurações — não criar variações
/// quase idênticas na mão em cada tela.
class SettingsMenuTile extends StatelessWidget {
  const SettingsMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
    this.isEnabled = true,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  /// Substitui o chevron padrão (ex.: um spinner de carregamento).
  final Widget? trailing;

  final bool isDestructive;
  final bool isEnabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final habilitado = isEnabled && onTap != null;
    final corConteudo = !isEnabled
        ? colors.textMuted
        : isDestructive
            ? colors.error
            : colors.textPrimary;

    return Semantics(
      label: semanticLabel ?? title,
      button: true,
      enabled: habilitado,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: habilitado ? onTap : null,
          child: ConstrainedBox(
            // Toda a linha é clicável e tem no mínimo 48x48 de área de
            // toque (seção 20 do briefing de tema/menus).
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(icon, color: corConteudo, size: 22),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: corConteudo,
                        ),
                      ),
                    ),
                    trailing ??
                        Icon(Icons.chevron_right,
                            color: colors.textMuted, size: 22),
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

/// Título simples de seção dentro de um menu de configurações (ex.:
/// "PERFIL", "CONTA") — nunca um card, só um rótulo discreto.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: context.colors.textMuted,
        ),
      ),
    );
  }
}
