import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme_mode.dart';
import '../../../../core/theme/theme_providers.dart';

/// Seleção do modo de aparência do app (Padrão/Claro/Escuro) — só existe
/// em Configurações do Tutor; o tema é preferência do app, não do pet.
class TemaScreen extends ConsumerWidget {
  const TemaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modoAtual = ref.watch(themeModeProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Tema do aplicativo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: AppThemeMode.values
              .map((modo) => _OpcaoDeTema(
                    modo: modo,
                    selecionado: modo == modoAtual,
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).definir(modo),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _OpcaoDeTema extends StatelessWidget {
  const _OpcaoDeTema({
    required this.modo,
    required this.selecionado,
    required this.onTap,
  });

  final AppThemeMode modo;
  final bool selecionado;
  final VoidCallback onTap;

  IconData get _icone => switch (modo) {
        AppThemeMode.padrao => Icons.pets_outlined,
        AppThemeMode.claro => Icons.light_mode_outlined,
        AppThemeMode.escuro => Icons.dark_mode_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Nunca só a cor: o rótulo de acessibilidade e o ícone de check
    // avisam o estado selecionado também.
    return Semantics(
      label: selecionado ? 'Tema ${modo.rotulo}, selecionado' : null,
      button: true,
      selected: selecionado,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(_icone,
                        color:
                            selecionado ? colors.brandDark : colors.textMuted,
                        size: 22),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        modo.rotulo,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selecionado ? FontWeight.bold : FontWeight.w600,
                          color: selecionado
                              ? colors.textPrimary
                              : colors.textMuted,
                        ),
                      ),
                    ),
                    if (selecionado)
                      Icon(Icons.check_circle, color: colors.brandDark)
                    else
                      Icon(Icons.circle_outlined, color: colors.textMuted),
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
