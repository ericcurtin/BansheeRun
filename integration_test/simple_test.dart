import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:banshee_run_app/src/rust/frb_generated.dart';
import 'package:banshee_run_app/src/app.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BansheeRunApp()));
    await tester.pumpAndSettle();
    expect(find.text('BansheeRun'), findsOneWidget);
  });
}
