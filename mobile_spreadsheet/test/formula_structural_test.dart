import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_spreadsheet/domain/services/super_engine/formula_rewrite_engine.dart';
import 'package:mobile_spreadsheet/domain/services/super_engine/ast.dart';
import 'package:mobile_spreadsheet/domain/services/super_engine/parser.dart';
import 'package:mobile_spreadsheet/domain/services/super_engine/tokenizer.dart';

void main() {
  group('FormulaRewriteEngine Structural Tests', () {
    test('Insert Row shifts relative references below insertion point', () {
      final formula = '=A2+B5';
      final rewritten = FormulaRewriteEngine.rewrite(formula, insertedRow: 1); // Insert at Row 2 (0-index 1)
      expect(rewritten, '=A3+B6');
    });

    test('Insert Row leaves references above insertion point untouched', () {
      final formula = '=A1+B2';
      final rewritten = FormulaRewriteEngine.rewrite(formula, insertedRow: 2); // Insert at Row 3 (0-index 2)
      expect(rewritten, '=A1+B2');
    });

    test('Insert Row preserves absolute row references (\$)', () {
      final formula = r'=A$1+$B$1+C2';
      final rewritten = FormulaRewriteEngine.rewrite(formula, insertedRow: 0);
      expect(rewritten, r'=A$1+$B$1+C3');
    });

    test('Insert Column shifts relative col references to the right', () {
      final formula = '=A1+B1';
      final rewritten = FormulaRewriteEngine.rewrite(formula, insertedCol: 0); // Insert at Col A
      expect(rewritten, '=B1+C1');
    });

    test('Insert Column preserves absolute column references (\$)', () {
      final formula = r'=$A1+$A$5+B1';
      final rewritten = FormulaRewriteEngine.rewrite(formula, insertedCol: 0);
      expect(rewritten, r'=$A1+$A$5+C1');
    });

    test('Delete Row converts direct target reference to #REF!', () {
      final formula = '=A2+B3';
      final rewritten = FormulaRewriteEngine.rewrite(formula, deletedRow: 1); // Delete Row 2 (0-index 1)
      expect(rewritten, '=#REF!+B2');
    });

    test('Delete Column converts direct target reference to #REF!', () {
      final formula = '=B1+C1';
      final rewritten = FormulaRewriteEngine.rewrite(formula, deletedCol: 1); // Delete Col B (0-index 1)
      expect(rewritten, '=#REF!+B1');
    });

    test('Range references update correctly on insert', () {
      final formula = '=SUM(A1:B5)';
      final rewritten = FormulaRewriteEngine.rewrite(formula, insertedRow: 0);
      expect(rewritten, '=SUM(A2:B6)');
    });

    test('Quoted string literals remain untouched', () {
      final formula = '="A1" & A1';
      final rewritten = FormulaRewriteEngine.rewrite(formula, insertedRow: 0);
      expect(rewritten, '="A1"&A2');
    });

    test('Copy / Drag fill applies deltaRow and deltaCol to relative references', () {
      final formula = r'=A1+$B$1';
      final rewritten = FormulaRewriteEngine.rewrite(formula, deltaRow: 2, deltaCol: 1);
      expect(rewritten, r'=B3+$B$1');
    });

    test('Parses omitted function arguments with double commas cleanly', () {
      final formula = '=CHAR(SEQUENCE(6,,97))';
      final rewritten = FormulaRewriteEngine.rewrite(formula, insertedRow: 0);
      expect(rewritten, '=CHAR(SEQUENCE(6,,97))');
    });
  });
}
