import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/consulta.dart';
import '../../domain/consulta_alerta.dart';

class ConsultaTile extends StatefulWidget {
  const ConsultaTile({
    super.key,
    required this.consulta,
    required this.onTap,
    this.onMarcarRealizada,
    this.onCancelar,
  });

  final Consulta consulta;
  final VoidCallback onTap;

  /// Não nulos apenas para consultas agendadas (RF29) — concluídas e
  /// canceladas só podem ser reabertas editando a data/status manualmente.
  final VoidCallback? onMarcarRealizada;

  /// Cancela a consulta de verdade — quem chama (`ConsultaListScreen`) já
  /// aplicou `status: cancelada` e invalidou o provider; aqui só se decide
  /// **quando** chamar isso: depois de confirmação explícita, nunca no
  /// primeiro toque (correção de 2026-09-14 — um toque sem querer em
  /// "Cancelar" cancelava a consulta na hora, sem chance de voltar atrás).
  final Future<void> Function()? onCancelar;

  @override
  State<ConsultaTile> createState() => _ConsultaTileState();
}

class _ConsultaTileState extends State<ConsultaTile> {
  bool _cancelando = false;

  Future<void> _confirmarECancelar() async {
    final consulta = widget.consulta;
    final quando = consulta.horario != null && consulta.horario!.isNotEmpty
        ? '${consulta.data} às ${consulta.horario}'
        : consulta.data;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar consulta'),
        content: Text(
          'Cancelar a consulta de $quando${consulta.veterinario.isNotEmpty ? ' com ${consulta.veterinario}' : ''}? '
          'Você pode agendar uma nova consulta depois, se precisar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sim, cancelar',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    // _cancelando de novo aqui: proteção extra contra um segundo toque
    // enquanto o diálogo ainda estava fechando (double tap, seção 31 do
    // roadmap de prioridades).
    if (confirmou != true || _cancelando || widget.onCancelar == null) return;

    setState(() => _cancelando = true);
    try {
      await widget.onCancelar!();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Não foi possível cancelar a consulta. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consulta = widget.consulta;
    final proxima = consultaEstaProxima(consulta);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (proxima) ...[
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      consulta.horario != null && consulta.horario!.isNotEmpty
                          ? '${consulta.data} às ${consulta.horario}'
                          : consulta.data,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(consulta.veterinario,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
              if (consulta.motivo.isNotEmpty)
                Text(
                  consulta.motivo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              if (widget.onMarcarRealizada != null ||
                  widget.onCancelar != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.onMarcarRealizada != null)
                      TextButton.icon(
                        onPressed: widget.onMarcarRealizada,
                        icon: const Icon(Icons.check_circle_outline,
                            size: 18, color: Colors.green),
                        label: const Text('Marcar realizada',
                            style: TextStyle(color: Colors.green)),
                      ),
                    if (widget.onCancelar != null)
                      TextButton.icon(
                        onPressed: _cancelando ? null : _confirmarECancelar,
                        icon: _cancelando
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.error),
                              )
                            : const Icon(Icons.cancel_outlined,
                                size: 18, color: AppColors.error),
                        label: const Text('Cancelar',
                            style: TextStyle(color: AppColors.error)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
