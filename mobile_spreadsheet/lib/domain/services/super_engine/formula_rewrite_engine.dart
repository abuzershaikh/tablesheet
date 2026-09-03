import 'ast.dart';
import 'parser.dart';
import 'tokenizer.dart';

class FormulaRewriteEngine {
  /// Rewrites a formula string for row/column insertions, deletions, copy-fill, or reordering.
  static String rewrite(
    String formula, {
    int insertedRow = -1,
    int insertedCol = -1,
    int deletedRow = -1,
    int deletedCol = -1,
    int deltaRow = 0,
    int deltaCol = 0,
    Map<int, int>? rowReorderMap,
    Map<int, int>? colReorderMap,
  }) {
    if (!formula.startsWith('=')) return formula;

    try {
      final tokenizer = Tokenizer(formula);
      final tokens = tokenizer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final rewrittenAst = _walkAndRewrite(
        ast,
        insertedRow: insertedRow,
        insertedCol: insertedCol,
        deletedRow: deletedRow,
        deletedCol: deletedCol,
        deltaRow: deltaRow,
        deltaCol: deltaCol,
        rowReorderMap: rowReorderMap,
        colReorderMap: colReorderMap,
      );

      return '=${rewrittenAst.toFormulaString()}';
    } catch (_) {
      // If formula parsing fails, return original formula untouched
      return formula;
    }
  }

  static AstNode _walkAndRewrite(
    AstNode node, {
    required int insertedRow,
    required int insertedCol,
    required int deletedRow,
    required int deletedCol,
    required int deltaRow,
    required int deltaCol,
    Map<int, int>? rowReorderMap,
    Map<int, int>? colReorderMap,
  }) {
    if (node is CellReferenceNode) {
      return _rewriteCellRef(
        node,
        insertedRow: insertedRow,
        insertedCol: insertedCol,
        deletedRow: deletedRow,
        deletedCol: deletedCol,
        deltaRow: deltaRow,
        deltaCol: deltaCol,
        rowReorderMap: rowReorderMap,
        colReorderMap: colReorderMap,
      );
    }

    if (node is RangeReferenceNode) {
      final newTopLeft = _walkAndRewrite(
        node.topLeft,
        insertedRow: insertedRow,
        insertedCol: insertedCol,
        deletedRow: deletedRow,
        deletedCol: deletedCol,
        deltaRow: deltaRow,
        deltaCol: deltaCol,
        rowReorderMap: rowReorderMap,
        colReorderMap: colReorderMap,
      );

      final newBottomRight = _walkAndRewrite(
        node.bottomRight,
        insertedRow: insertedRow,
        insertedCol: insertedCol,
        deletedRow: deletedRow,
        deletedCol: deletedCol,
        deltaRow: deltaRow,
        deltaCol: deltaCol,
        rowReorderMap: rowReorderMap,
        colReorderMap: colReorderMap,
      );

      if (newTopLeft is ErrorNode || newBottomRight is ErrorNode) {
        return const ErrorNode('#REF!');
      }

      if (newTopLeft is CellReferenceNode && newBottomRight is CellReferenceNode) {
        return RangeReferenceNode(newTopLeft, newBottomRight);
      }
      return const ErrorNode('#REF!');
    }

    if (node is BinaryOpNode) {
      final left = _walkAndRewrite(
        node.left,
        insertedRow: insertedRow,
        insertedCol: insertedCol,
        deletedRow: deletedRow,
        deletedCol: deletedCol,
        deltaRow: deltaRow,
        deltaCol: deltaCol,
        rowReorderMap: rowReorderMap,
        colReorderMap: colReorderMap,
      );
      final right = _walkAndRewrite(
        node.right,
        insertedRow: insertedRow,
        insertedCol: insertedCol,
        deletedRow: deletedRow,
        deletedCol: deletedCol,
        deltaRow: deltaRow,
        deltaCol: deltaCol,
        rowReorderMap: rowReorderMap,
        colReorderMap: colReorderMap,
      );
      return BinaryOpNode(left, node.operator, right);
    }

    if (node is UnaryOpNode) {
      final operand = _walkAndRewrite(
        node.operand,
        insertedRow: insertedRow,
        insertedCol: insertedCol,
        deletedRow: deletedRow,
        deletedCol: deletedCol,
        deltaRow: deltaRow,
        deltaCol: deltaCol,
        rowReorderMap: rowReorderMap,
        colReorderMap: colReorderMap,
      );
      return UnaryOpNode(node.operator, operand);
    }

    if (node is FunctionNode) {
      final newArgs = node.arguments.map((arg) {
        return _walkAndRewrite(
          arg,
          insertedRow: insertedRow,
          insertedCol: insertedCol,
          deletedRow: deletedRow,
          deletedCol: deletedCol,
          deltaRow: deltaRow,
          deltaCol: deltaCol,
          rowReorderMap: rowReorderMap,
          colReorderMap: colReorderMap,
        );
      }).toList();
      return FunctionNode(node.name, newArgs);
    }

    if (node is ArrayNode) {
      final newRows = node.rows.map((row) {
        return row.map((cell) {
          return _walkAndRewrite(
            cell,
            insertedRow: insertedRow,
            insertedCol: insertedCol,
            deletedRow: deletedRow,
            deletedCol: deletedCol,
            deltaRow: deltaRow,
            deltaCol: deltaCol,
            rowReorderMap: rowReorderMap,
            colReorderMap: colReorderMap,
          );
        }).toList();
      }).toList();
      return ArrayNode(newRows);
    }

    // NumberNode, StringNode, BooleanNode, ErrorNode remain untouched
    return node;
  }

  static AstNode _rewriteCellRef(
    CellReferenceNode node, {
    required int insertedRow,
    required int insertedCol,
    required int deletedRow,
    required int deletedCol,
    required int deltaRow,
    required int deltaCol,
    Map<int, int>? rowReorderMap,
    Map<int, int>? colReorderMap,
  }) {
    int r = node.row;
    int c = node.col;

    // Check row deletion
    if (deletedRow != -1 && r == deletedRow) {
      return const ErrorNode('#REF!');
    }
    // Check col deletion
    if (deletedCol != -1 && c == deletedCol) {
      return const ErrorNode('#REF!');
    }

    // Handle Row Insertion
    if (insertedRow != -1 && !node.isAbsoluteRow && r >= insertedRow) {
      r++;
    }
    // Handle Row Deletion shift
    else if (deletedRow != -1 && !node.isAbsoluteRow && r > deletedRow) {
      r--;
    }

    // Handle Col Insertion
    if (insertedCol != -1 && !node.isAbsoluteCol && c >= insertedCol) {
      c++;
    }
    // Handle Col Deletion shift
    else if (deletedCol != -1 && !node.isAbsoluteCol && c > deletedCol) {
      c--;
    }

    // Handle Drag / Copy Offset (deltaRow, deltaCol)
    if (deltaRow != 0 && !node.isAbsoluteRow) {
      r += deltaRow;
    }
    if (deltaCol != 0 && !node.isAbsoluteCol) {
      c += deltaCol;
    }

    // Check bounds out of range (< 0)
    if (r < 0 || c < 0) {
      return const ErrorNode('#REF!');
    }

    // Handle Reordering maps
    if (rowReorderMap != null && !node.isAbsoluteRow && rowReorderMap.containsKey(r)) {
      r = rowReorderMap[r]!;
    }
    if (colReorderMap != null && !node.isAbsoluteCol && colReorderMap.containsKey(c)) {
      c = colReorderMap[c]!;
    }

    return CellReferenceNode(
      rawName: node.rawName,
      row: r,
      col: c,
      isAbsoluteRow: node.isAbsoluteRow,
      isAbsoluteCol: node.isAbsoluteCol,
      sheetName: node.sheetName,
    );
  }
}
