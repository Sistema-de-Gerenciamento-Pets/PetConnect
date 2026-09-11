import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/consulta.dart';
import '../../domain/consulta_alerta.dart';

class ConsultaTile extends StatelessWidget {
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
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    final proxima = consultaEstaProxima(consulta);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
              if (onMarcarRealizada != null || onCancelar != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (onMarcarRealizada != null)
                      TextButton.icon(
                        onPressed: onMarcarRealizada,
                        icon: const Icon(Icons.check_circle_outline,
                            size: 18, color: Colors.green),
                        label: const Text('Marcar realizada',
                            style: TextStyle(color: Colors.green)),
                      ),
                    if (onCancelar != null)
                      TextButton.icon(
                        onPressed: onCancelar,
                        icon: const Icon(Icons.cancel_outlined,
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
