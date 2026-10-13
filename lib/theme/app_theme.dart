import 'package:flutter/material.dart';

/// Colores y estilo de la app, en un solo lugar.
///
/// Tema neutro (grises puros, sin tinte de color), como en el diseño elegido
/// (docs/diseno/propuestas-interfaz-v1). El color lo ponen los grupos;
/// la app en sí no compite con ellas. Los botones principales son del color
/// del texto: blanco en oscuro, casi negro en claro.
///
/// Más adelante (idea #10 del usuario) aquí vivirán varios temas a elegir.
class AppTheme {
  AppTheme._();

  /// Tema claro.
  static ThemeData light() => _build(_lightScheme);

  /// Tema oscuro.
  static ThemeData dark() => _build(_darkScheme);

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF808080),
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
  ).copyWith(
    // Fondo y superficies, de más hundido a más elevado.
    surface: const Color(0xFF121214),
    surfaceContainerLowest: const Color(0xFF0E0E10),
    surfaceContainerLow: const Color(0xFF18181B),
    surfaceContainer: const Color(0xFF1C1C20),
    surfaceContainerHigh: const Color(0xFF222227),
    surfaceContainerHighest: const Color(0xFF2A2A30),
    onSurface: const Color(0xFFEDEDEF),
    onSurfaceVariant: const Color(0xFFA0A0AB),
    outline: const Color(0xFF3A3A42),
    outlineVariant: const Color(0xFF2C2C32),
    // Botones principales: claros sobre fondo oscuro.
    primary: const Color(0xFFEDEDEF),
    onPrimary: const Color(0xFF121214),
    primaryContainer: const Color(0xFF2E2E35),
    onPrimaryContainer: const Color(0xFFEDEDEF),
    secondary: const Color(0xFFC8C8D0),
    onSecondary: const Color(0xFF121214),
    secondaryContainer: const Color(0xFF2E2E35),
    onSecondaryContainer: const Color(0xFFEDEDEF),
    error: const Color(0xFFFF8A80),
    onError: const Color(0xFF2B0A08),
    inverseSurface: const Color(0xFFEDEDEF),
    onInverseSurface: const Color(0xFF121214),
    surfaceTint: Colors.transparent,
  );

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF808080),
    brightness: Brightness.light,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
  ).copyWith(
    surface: const Color(0xFFF6F6F7),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFFFFFFF),
    surfaceContainer: const Color(0xFFEFEFF1),
    surfaceContainerHigh: const Color(0xFFFFFFFF),
    surfaceContainerHighest: const Color(0xFFE4E4E7),
    onSurface: const Color(0xFF18181B),
    onSurfaceVariant: const Color(0xFF52525B),
    outline: const Color(0xFFC4C4CA),
    outlineVariant: const Color(0xFFE4E4E7),
    primary: const Color(0xFF18181B),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFE4E4E7),
    onPrimaryContainer: const Color(0xFF18181B),
    secondary: const Color(0xFF3F3F46),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFE4E4E7),
    onSecondaryContainer: const Color(0xFF18181B),
    error: const Color(0xFFC62828),
    onError: const Color(0xFFFFFFFF),
    inverseSurface: const Color(0xFF18181B),
    onInverseSurface: const Color(0xFFF6F6F7),
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      // Botón "Nueva nota": píldora ancha y alta, fácil de alcanzar.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
        extendedSizeConstraints:
            const BoxConstraints.tightFor(height: 60),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 28),
        extendedIconLabelSpacing: 10,
        extendedTextStyle:
            const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    );
  }
}
