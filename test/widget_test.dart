import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nida_flutter/app.dart';
import 'package:nida_flutter/contexts/theme_provider.dart';
import 'package:nida_flutter/contexts/navigation_bar_provider.dart';

void main() {
  testWidgets('App loads with homepage', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => NavigationBarProvider()),
        ],
        child: const NidaFlutterApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Next: Dhuhr'), findsOneWidget);
  });
}
