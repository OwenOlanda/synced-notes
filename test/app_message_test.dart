import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synced_notes/theme/app_theme.dart';
import 'package:synced_notes/widgets/app_message.dart';

/// La "píldora" del aviso (el SnackBar ocupa todo el ancho; su Material
/// interior es lo que se ve).
Rect pill(WidgetTester tester) => tester.getRect(find
    .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
    .first);

void main() {
  Future<void> showIn(WidgetTester tester, Size screen,
      {bool isError = false}) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context)
                .showMessage('Nota guardada', isError: isError),
            child: const Text('mostrar'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mostrar'));
    await tester.pumpAndSettle();
  }

  testWidgets('en pantalla ancha ocupa la mitad del ancho, centrado',
      (tester) async {
    await showIn(tester, const Size(1200, 800));
    final box = pill(tester);
    expect(box.width, 600);
    expect(box.center.dx, 600); // centrado
    final text = tester.widget<Text>(find.text('Nota guardada'));
    expect(text.textAlign, TextAlign.center);
  });

  testWidgets('en teléfono no baja de 240 px', (tester) async {
    await showIn(tester, const Size(390, 844));
    expect(pill(tester).width, 240);
  });

  testWidgets('los errores usan el color de error', (tester) async {
    await showIn(tester, const Size(1200, 800), isError: true);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, AppTheme.light().colorScheme.error);
  });
}
