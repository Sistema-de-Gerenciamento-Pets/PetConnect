import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/vacina.dart';
import '../../domain/vacina_alerta.dart';

class VacinaTile extends StatelessWidget {
  const VacinaTile(
      {super.key,
      required this.vacina,
      required this.onTap,
      required this.onDelete});

  final Vacina vacina;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final alerta = calcularAlerta(vacina);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vacina.nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aplicada em ${vacina.dataAplicacao}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                    if (vacina.proximaDose != null &&
                        vacina.proximaDose!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Próxima dose: ${vacina.proximaDose}',
                        style: TextStyle(
                          color: alerta == VacinaAlerta.nenhum
                              ? AppColors.textMuted
                              : _corAlerta(alerta),
                          fontSize: 13,
                          fontWeight: alerta == VacinaAlerta.nenhum
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (alerta != VacinaAlerta.nenhum) ...[
                Icon(Icons.warning_amber_rounded, color: _corAlerta(alerta)),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.textMuted),
                tooltip: 'Excluir vacina',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _corAlerta(VacinaAlerta alerta) {
    return alerta == VacinaAlerta.vencida ? AppColors.error : Colors.orange;
  }
}
