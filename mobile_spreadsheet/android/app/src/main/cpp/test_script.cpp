#include <iostream>
#include <string>
#include <vector>
#include <variant>
#include "evaluator.h"
#include "parser.h"

// Provide dummy DataProvider
class DummyDataProvider : public DataProvider {
public:
    EvalResult getCellValue(const std::string& ref) override {
        if (ref == "D2") return 10.0;
        if (ref == "E2") return 20.0;
        if (ref == "F2") return 30.0;
        if (ref == "D3") return 0.01;
        if (ref == "E3") return 12.0;
        if (ref == "F3") return -50000.0;
        if (ref == "D4") return std::string("Apple");
        if (ref == "E4") return std::string("Banana");
        if (ref == "F4") return std::string("Cherry");
        if (ref == "D5") return std::string("data-base-system");
        if (ref == "E5") return std::string("-");
        if (ref == "F5") return std::string("_");
        if (ref == "D6") return 78.0;
        if (ref == "B5") return 78.0; // Wait, IFS used B5
        
        return Blank{};
    }

    EvalResult getRangeValues(const std::string& rangeRef) override {
        if (rangeRef == "B2:D2") {
            return ArrayVal{{ std::string("Statistical"), std::string("TRIMMEAN"), 10.0 }};
        }
        if (rangeRef == "D2:F2") {
            return ArrayVal{{ 10.0, 20.0, 30.0 }};
        }
        if (rangeRef == "C3:E3") {
            return ArrayVal{{ std::string("PMT..."), 0.01, 12.0 }};
        }
        if (rangeRef == "B3:D3") {
            return ArrayVal{{ std::string("Financial"), std::string("PMT..."), 0.01 }};
        }
        if (rangeRef == "D4:F4") {
            return ArrayVal{{ std::string("Apple"), std::string("Banana"), std::string("Cherry") }};
        }
        return Blank{};
    }
};

void runTest(const std::string& expr) {
    try {
        Tokenizer tokenizer(expr);
        auto tokens = tokenizer.tokenize();
        Parser parser(tokens);
        auto ast = parser.parse();
        
        DummyDataProvider provider;
        Evaluator eval(&provider);
        auto res = eval.evaluate(ast.get());
        
        std::cout << "Expr: " << expr << " => ";
        if (std::holds_alternative<double>(res)) std::cout << std::get<double>(res) << "\n";
        else if (std::holds_alternative<std::string>(res)) std::cout << "\"" << std::get<std::string>(res) << "\"\n";
        else if (std::holds_alternative<bool>(res)) std::cout << (std::get<bool>(res) ? "TRUE" : "FALSE") << "\n";
        else if (std::holds_alternative<CellError>(res)) std::cout << std::get<CellError>(res).error << "\n";
        else std::cout << "[Other]\n";
    } catch (const std::exception& e) {
        std::cout << "Exception on " << expr << ": " << e.what() << "\n";
    }
}

int main() {
    runTest("=TRIMMEAN(D2:F2, 0.33)");
    runTest("=PMT(D3, E3, F3)");
    runTest("=PMT(0.12/12, 12, -50000)");
    runTest("=INDEX(D4:F4, MATCH(\"Banana\", D4:F4, 0))");
    runTest("=UPPER(SUBSTITUTE(D5, E5, F5))");
    runTest("=IFS(D6>=90, \"Grade A\", D6>=75, \"Grade B\", TRUE, \"Grade C\")");
    return 0;
}
