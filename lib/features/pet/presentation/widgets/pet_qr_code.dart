import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/pet.dart';
import '../../domain/pet_qr_code.dart';

/// QR code de identificação do pet (RF16), exibido no perfil. Regeneração
/// (RF19) e a página pública que ele abre (RF17-RF18) ficam para uma
/// próxima etapa.
///
/// O fundo do QR em si fica sempre branco, em qualquer tema — não é uma
/// escolha de estilo, é o que garante contraste suficiente pra câmeras
/// conseguirem ler o código.
class PetQrCode extends StatelessWidget {
  const PetQrCode({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          QrImageView(
            data: publicPetUrl(pet),
            size: 180,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            'Quem encontrar ${pet.nome} pode escanear este código para ver como devolvê-lo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
