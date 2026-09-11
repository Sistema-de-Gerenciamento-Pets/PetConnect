import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/localizacao.dart';

class LocalizacaoTile extends StatelessWidget {
  const LocalizacaoTile({super.key, required this.localizacao});

  final Localizacao localizacao;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.brandMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizacao.data,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(localizacao.descricao,
                    style: const TextStyle(color: AppColors.textPrimary)),
                if (localizacao.contatoReportante != null &&
                    localizacao.contatoReportante!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Contato: ${localizacao.contatoReportante}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
