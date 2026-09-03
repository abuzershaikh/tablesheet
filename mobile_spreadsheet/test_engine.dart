import 'package:mobile_spreadsheet/domain/services/super_engine/ffi_bridge.dart';

void main() {
  print("Initializing C++ Engine...");
  NativeEngine.initialize();

  const formula = '=LET(a,MAKEARRAY(300,300,LAMBDA(r,c,r*c)),b,MAP(a,LAMBDA(x,IF(ISEVEN(x),x^2,x^3))),BYROW(b,LAMBDA(r,SUM(r))))';
  print("Evaluating formula: $formula");

  final result = NativeEngine.evaluateFormula(formula);
  print("Result: $result");
  final isSpill = result.startsWith('{"type":"spill","data":');
  print("Spill result: ${isSpill ? "YES" : "NO"}");
  if (isSpill) {
    print("Smoke test passed");
  } else {
    print("Smoke test failed");
  }

  NativeEngine.dispose();
  print("Done.");
}
