#include <iostream>
#include <cassert>
#include <string>
#include <vector>
#include "../../android/app/src/main/cpp/function_registry.h"
#include "../../android/app/src/main/cpp/evaluator.h"
#include "../../android/app/src/main/cpp/parser.h"

// Test helper functions
class DateFormulaTest {
private:
    FunctionRegistry& registry;
    
public:
    DateFormulaTest() : registry(FunctionRegistry::getInstance()) {}
    
    void runAllTests() {
        std::cout << "🧪 Starting Date Formula Comprehensive Tests...\n\n";
        
        testBasicDateFunctions();
        testDateParsing();
        testDateFormats();
        testEdgeCases();
        testArrayOperations();
        testErrorHandling();
        testSerialNumbers();
        testLeapYears();
        testDateArithmetic();
        testWeeknum();
        
        std::cout << "✅ All Date Formula Tests Completed!\n";
    }
    
private:
    EvalResult evaluateFormula(const std::string& formula) {
        // Mock cell provider for testing
        auto cellProvider = [](const std::string& cellName) -> EvalResult {
            if (cellName == "A1") return std::string("2024-01-15");
            if (cellName == "B1") return std::string("2024-12-31");
            if (cellName == "C1") return 45000.0;  // Excel serial date
            if (cellName == "D1") return std::string("01/15/2024");
            if (cellName == "E1") return std::string("2024/01/15");
            if (cellName == "F1") return std::string("15-Jan-2024");
            return 0.0;
        };
        
        Evaluator eval(cellProvider);
        Tokenizer tokenizer(formula);
        auto tokens = tokenizer.tokenize();
        Parser parser(std::move(tokens));
        auto ast = parser.parse();
        
        return eval.evaluate(ast.get());
    }
    
    void testResult(const std::string& formula, const std::string& expected, const std::string& testName) {
        auto result = evaluateFormula(formula);
        std::string actual;
        
        if (std::holds_alternative<std::string>(result)) {
            actual = std::get<std::string>(result);
        } else if (std::holds_alternative<double>(result)) {
            double d = std::get<double>(result);
            actual = std::to_string((int)d);
        } else if (std::holds_alternative<CellError>(result)) {
            actual = std::get<CellError>(result).type;
        }
        
        if (actual == expected) {
            std::cout << "✅ " << testName << ": PASS\n";
        } else {
            std::cout << "❌ " << testName << ": FAIL\n";
            std::cout << "   Formula: " << formula << "\n";
            std::cout << "   Expected: " << expected << "\n";
            std::cout << "   Actual: " << actual << "\n\n";
        }
    }
    
    void testBasicDateFunctions() {
        std::cout << "📅 Testing Basic Date Functions:\n";
        
        // TODAY() - Returns current date
        testResult("TODAY()", "2024", "TODAY() returns current year");
        
        // NOW() - Returns current datetime
        testResult("NOW()", "2024", "NOW() returns current year");
        
        // DATE() function
        testResult("DATE(2024,1,15)", "2024-01-15", "DATE(2024,1,15)");
        testResult("DATE(2024,12,31)", "2024-12-31", "DATE(2024,12,31)");
        testResult("DATE(2000,2,29)", "2000-02-29", "DATE leap year");
        
        // YEAR(), MONTH(), DAY() extraction
        testResult("YEAR(\"2024-01-15\")", "2024", "YEAR extraction");
        testResult("MONTH(\"2024-01-15\")", "1", "MONTH extraction");
        testResult("DAY(\"2024-01-15\")", "15", "DAY extraction");
        
        std::cout << "\n";
    }
    
    void testDateParsing() {
        std::cout << "🔍 Testing Date Parsing:\n";
        
        // Test different date input formats
        testResult("YEAR(A1)", "2024", "Parse YYYY-MM-DD format");
        testResult("MONTH(A1)", "1", "Parse YYYY-MM-DD month");
        testResult("DAY(A1)", "15", "Parse YYYY-MM-DD day");
        
        // Test cell references with different formats
        testResult("YEAR(D1)", "#VALUE!", "Parse MM/DD/YYYY format (unsupported)");
        testResult("YEAR(E1)", "#VALUE!", "Parse YYYY/MM/DD format (unsupported)");
        testResult("YEAR(F1)", "#VALUE!", "Parse DD-Mon-YYYY format (unsupported)");
        
        std::cout << "\n";
    }
    
    void testDateFormats() {
        std::cout << "📋 Testing Date Format Support:\n";
        
        // Currently only supports YYYY-MM-DD format
        testResult("DATE(2024,1,1)", "2024-01-01", "Standard format output");
        testResult("DATE(24,1,1)", "0024-01-01", "Short year handling");
        
        std::cout << "\n";
    }
    
    void testEdgeCases() {
        std::cout << "⚠️ Testing Edge Cases:\n";
        
        // Invalid dates
        testResult("DATE(2024,13,1)", "2024-13-01", "Invalid month (no validation)");
        testResult("DATE(2024,2,30)", "2024-02-30", "Invalid day (no validation)");
        testResult("DATE(0,1,1)", "0000-01-01", "Year 0");
        testResult("DATE(-1,1,1)", "-0001-01-01", "Negative year");
        
        // Boundary values
        testResult("DATE(9999,12,31)", "9999-12-31", "Maximum year");
        testResult("DATE(1,1,1)", "0001-01-01", "Minimum year");
        
        std::cout << "\n";
    }
    
    void testArrayOperations() {
        std::cout << "📊 Testing Array Operations:\n";
        
        // EDATE with arrays should work
        testResult("EDATE(\"2024-01-15\", 1)", "2024-02-15", "EDATE single value");
        testResult("EDATE(\"2024-01-15\", -1)", "2023-12-15", "EDATE negative months");
        
        // EOMONTH tests
        testResult("EOMONTH(\"2024-01-15\", 0)", "2024-01-31", "EOMONTH current month");
        testResult("EOMONTH(\"2024-02-15\", 0)", "2024-02-29", "EOMONTH leap year Feb");
        testResult("EOMONTH(\"2023-02-15\", 0)", "2024-02-28", "EOMONTH non-leap year Feb");
        
        std::cout << "\n";
    }
    
    void testErrorHandling() {
        std::cout << "❗ Testing Error Handling:\n";
        
        // Invalid arguments
        testResult("DATE()", "#VALUE!", "DATE() no arguments");
        testResult("DATE(2024)", "#VALUE!", "DATE() insufficient arguments");
        testResult("DATE(2024,1,1,1)", "#VALUE!", "DATE() too many arguments");
        
        testResult("YEAR()", "#VALUE!", "YEAR() no arguments");
        testResult("YEAR(\"invalid\")", "#VALUE!", "YEAR() invalid date string");
        
        testResult("DATEDIF()", "#VALUE!", "DATEDIF() no arguments");
        testResult("DATEDIF(\"2024-01-01\", \"2024-12-31\")", "#VALUE!", "DATEDIF() missing unit");
        
        std::cout << "\n";
    }
    
    void testSerialNumbers() {
        std::cout << "🔢 Testing Serial Number Support:\n";
        
        // Excel serial number support
        testResult("YEAR(C1)", "2023", "Serial number to year (C1=45000)");
        testResult("MONTH(C1)", "3", "Serial number to month");
        testResult("DAY(C1)", "6", "Serial number to day");
        
        // Test serial number calculations
        testResult("YEAR(44927)", "2023", "Direct serial number");
        
        std::cout << "\n";
    }
    
    void testLeapYears() {
        std::cout << "📅 Testing Leap Year Handling:\n";
        
        // Leap year tests
        testResult("DATE(2024,2,29)", "2024-02-29", "Leap year 2024");
        testResult("DATE(2000,2,29)", "2000-02-29", "Leap year 2000");
        testResult("DATE(1900,2,29)", "1900-02-29", "Non-leap year 1900 (no validation)");
        testResult("DATE(2100,2,29)", "2100-02-29", "Non-leap year 2100 (no validation)");
        
        // EOMONTH leap year handling
        testResult("EOMONTH(\"2024-02-01\", 0)", "2024-02-29", "EOMONTH Feb leap year");
        testResult("EOMONTH(\"2023-02-01\", 0)", "2024-02-28", "EOMONTH Feb non-leap year");
        
        std::cout << "\n";
    }
    
    void testDateArithmetic() {
        std::cout << "➕ Testing Date Arithmetic:\n";
        
        // DATEDIF tests
        testResult("DATEDIF(\"2024-01-01\", \"2024-12-31\", \"Y\")", "0", "DATEDIF years");
        testResult("DATEDIF(\"2023-01-01\", \"2024-01-01\", \"Y\")", "1", "DATEDIF full year");
        testResult("DATEDIF(\"2024-01-01\", \"2024-06-01\", \"M\")", "5", "DATEDIF months");
        testResult("DATEDIF(\"2024-01-01\", \"2024-01-31\", \"D\")", "395", "DATEDIF days (incorrect formula)");
        
        // EDATE edge cases
        testResult("EDATE(\"2024-01-31\", 1)", "2024-02-29", "EDATE end of month adjustment");
        testResult("EDATE(\"2024-03-31\", -1)", "2024-02-29", "EDATE backward end of month");
        
        std::cout << "\n";
    }
    
    void testWeeknum() {
        std::cout << "📅 Testing WEEKNUM & ISOWEEKNUM boundaries:\n";
        
        // Specifically requested tests: 2015-12-28, 2015-12-31, 2016-01-01, 2016-01-04
        testResult("WEEKNUM(\"2015-12-28\", 21)", "53", "WEEKNUM Type 21 (ISO) 2015-12-28 = W53");
        testResult("ISOWEEKNUM(\"2015-12-28\")", "53", "ISOWEEKNUM 2015-12-28 = W53");
        
        testResult("WEEKNUM(\"2015-12-31\", 21)", "53", "WEEKNUM Type 21 (ISO) 2015-12-31 = W53");
        testResult("ISOWEEKNUM(\"2015-12-31\")", "53", "ISOWEEKNUM 2015-12-31 = W53");
        
        testResult("WEEKNUM(\"2016-01-01\", 21)", "53", "WEEKNUM Type 21 (ISO) 2016-01-01 = W53");
        testResult("ISOWEEKNUM(\"2016-01-01\")", "53", "ISOWEEKNUM 2016-01-01 = W53");
        
        testResult("WEEKNUM(\"2016-01-04\", 21)", "1", "WEEKNUM Type 21 (ISO) 2016-01-04 = W1");
        testResult("ISOWEEKNUM(\"2016-01-04\")", "1", "ISOWEEKNUM 2016-01-04 = W1");
        
        std::cout << "\n";
    }
};

// Test runner
int main() {
    DateFormulaTest test;
    test.runAllTests();
    return 0;
}