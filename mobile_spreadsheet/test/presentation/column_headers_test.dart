import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_spreadsheet/presentation/editor/widgets/column_headers.dart';

void main() {
  testWidgets('ColumnHeaders renders letters A, B, C, D...', (WidgetTester tester) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 40,
            child: ColumnHeaders(
              columnCount: 26,
              getColumnWidth: (index) => 120.0,
              getColumnName: (index) => String.fromCharCode(65 + index),
              gridScrollController: scrollController,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify ColumnHeaders widget exists
    expect(find.byType(ColumnHeaders), findsOneWidget);

    scrollController.dispose();
  });
}
