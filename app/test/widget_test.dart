import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_nas/main.dart';

void main() {
  testWidgets('Cloud NAS app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CloudNASApp());
    expect(find.text('CLOUD NAS'), findsOneWidget);
  });
}
