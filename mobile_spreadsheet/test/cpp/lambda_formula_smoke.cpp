#include <cmath>
#include <iostream>
#include <string>
#include <variant>
#include <vector>

#include "../../android/app/src/main/cpp/function_registry.h"
#include "../../android/app/src/main/cpp/evaluator.h"
#include "../../android/app/src/main/cpp/parser.h"

static long long expectedRowSum(int rowIndex1Based, int cols) {
    long long sum = 0;
    for (int c = 1; c <= cols; ++c) {
        long long x = 1LL * rowIndex1Based * c;
        if (x % 2 == 0) {
            sum += x * x;
        } else {
            sum += x * x * x;
        }
    }
    return sum;
}

static std::string evalToString(const EvalResult& result) {
    if (std::holds_alternative<double>(result)) {
        double value = std::get<double>(result);
        if (std::llround(value) == value) {
            return std::to_string(static_cast<long long>(std::llround(value)));
        }
        return std::to_string(value);
    }
    if (std::holds_alternative<std::string>(result)) return std::get<std::string>(result);
    if (std::holds_alternative<bool>(result)) return std::get<bool>(result) ? "TRUE" : "FALSE";
    if (std::holds_alternative<CellError>(result)) return std::get<CellError>(result).type;
    if (std::holds_alternative<Blank>(result)) return "";
    return "#ARRAY";
}

int main() {
    const std::string formula =
        "=LET("
        "a,MAKEARRAY(300,300,LAMBDA(r,c,r*c)),"
        "b,MAP(a,LAMBDA(x,IF(ISEVEN(x),x^2,x^3))),"
        "BYROW(b,LAMBDA(r,SUM(r)))"
        ")";

    Evaluator eval;
    Tokenizer tokenizer(formula);
    auto tokens = tokenizer.tokenize();
    Parser parser(std::move(tokens));
    auto ast = parser.parse();

    EvalResult result = eval.evaluate(ast.get());
    if (!std::holds_alternative<ArrayVal>(result)) {
        std::cerr << "FAIL: expected ArrayVal, got " << evalToString(result) << "\n";
        return 1;
    }

    const auto& matrix = std::get<ArrayVal>(result).matrix;
    if (matrix.size() != 300) {
        std::cerr << "FAIL: expected 300 rows, got " << matrix.size() << "\n";
        return 1;
    }

    for (const auto& row : matrix) {
        if (row.size() != 1) {
            std::cerr << "FAIL: expected 1 column in BYROW output, got " << row.size() << "\n";
            return 1;
        }
    }

    const long long first = expectedRowSum(1, 300);
    const long long middle = expectedRowSum(150, 300);
    const long long last = expectedRowSum(300, 300);

    const auto firstActual = std::get<double>(matrix.front().front());
    const auto middleActual = std::get<double>(matrix[149].front());
    const auto lastActual = std::get<double>(matrix.back().front());

    if (std::llround(firstActual) != first) {
        std::cerr << "FAIL: row 1 sum mismatch. expected " << first << " got " << firstActual << "\n";
        return 1;
    }
    if (std::llround(middleActual) != middle) {
        std::cerr << "FAIL: row 150 sum mismatch. expected " << middle << " got " << middleActual << "\n";
        return 1;
    }
    if (std::llround(lastActual) != last) {
        std::cerr << "FAIL: row 300 sum mismatch. expected " << last << " got " << lastActual << "\n";
        return 1;
    }

    std::cout << "PASS: LET + MAKEARRAY + MAP + BYROW smoke test succeeded\n";
    std::cout << "Rows: " << matrix.size() << ", Cols: " << matrix.front().size() << "\n";
    std::cout << "Samples: row1=" << firstActual << ", row150=" << middleActual << ", row300=" << lastActual << "\n";
    return 0;
}
