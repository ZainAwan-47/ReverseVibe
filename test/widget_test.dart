import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_vibe/app/app.dart';

void main() {
  testWidgets('shows the ReverseVibe home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ReverseVibeApp());

    expect(find.text('ReverseVibe'), findsOneWidget);
    expect(find.text('Hear it backwards.\nGuess it forwards.'), findsOneWidget);
    expect(find.text('Make a sound'), findsOneWidget);
    expect(find.text('Guess the original'), findsOneWidget);
  });
}
