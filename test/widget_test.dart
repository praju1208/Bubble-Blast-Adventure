import 'package:flutter_test/flutter_test.dart';
import 'package:bubble_blast_adventure/main.dart';

void main() {
  testWidgets('Bubble Blast Adventure loads', (WidgetTester tester) async {
    await tester.pumpWidget(const BubbleBlastApp());

    expect(find.text('BUBBLE BLAST'), findsOneWidget);
  });
}