/// Os três modos de aparência do app. "Padrão" é a identidade visual
/// oficial do PetConnect (não é "seguir o sistema") — ver
/// docs/features/theme-and-settings-menu.md.
enum AppThemeMode {
  padrao,
  claro,
  escuro;

  String get rotulo {
    switch (this) {
      case AppThemeMode.padrao:
        return 'Padrão';
      case AppThemeMode.claro:
        return 'Claro';
      case AppThemeMode.escuro:
        return 'Escuro';
    }
  }
}
