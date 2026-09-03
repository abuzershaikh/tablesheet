#include <iostream>
#include <cassert>
#include <string>
#include <vector>

#include "../../android/app/src/main/cpp/data_engine/cleaning/extreme_cleaning_engine.h"
#include "../../android/app/src/main/cpp/data_engine/cleaning/data_cleaner.h"
#include "../../android/app/src/main/cpp/data_engine/cleaning/date_cleaner.h"
#include "../../android/app/src/main/cpp/data_engine/cleaning/row_aligner.h"
#include "../../android/app/src/main/cpp/data_engine/cluster/cluster_engine.h"
#include "../../android/app/src/main/cpp/data_engine/pattern_intelligence/repair_suggester.h"
#include "../../android/app/src/main/cpp/data_engine/pattern_intelligence/relational_pattern.h"
#include "../../android/app/src/main/cpp/data_engine/cleaning/mojibake_cleaner.h"
#include "../../android/app/src/main/cpp/data_engine/cleaning/unit_cleaner.h"
#include "../../android/app/src/main/cpp/data_engine/cleaning/address_cleaner.h"
#include "../../android/app/src/main/cpp/data_engine/cleaning/imputation_engine.h"

int main() {
    std::cout << "🧪 Starting SOTA Data Cleaning Engine Comprehensive Verification...\n\n";

    // 1. European & Accounting Numbers
    std::cout << "Testing European & Financial Currency Cleaner...\n";
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("1.234,56 €") == "1234.56");
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("$1,234.56") == "1234.56");
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("($1,200.50)") == "-1200.5");
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("1.5k") == "1500");
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("2.5M") == "2500000");
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("Rs. 500/-") == "500");
    std::cout << "  ✅ European & Financial Currency Tests Passed!\n";

    // 2. Date Column Consensus
    std::cout << "Testing Date Column-Level Consensus...\n";
    auto& dc = Filters::DateCleaner::getInstance();
    std::vector<std::string> dmyCol = {"25/06/2024", "05/06/2024", "12/01/2024"};
    auto pref1 = dc.learnColumnDateFormat(dmyCol);
    assert(pref1 == Filters::DateFormatPreference::PREFER_DMY);
    auto cleaned1 = dc.cleanColumn(dmyCol, Filters::DateOutputFormat::ISO_YYYY_MM_DD);
    assert(cleaned1[0] == "2024-06-25");
    assert(cleaned1[1] == "2024-06-05"); // June 5th

    std::vector<std::string> mdyCol = {"06/25/2024", "05/06/2024", "01/12/2024"};
    auto pref2 = dc.learnColumnDateFormat(mdyCol);
    assert(pref2 == Filters::DateFormatPreference::PREFER_MDY);
    auto cleaned2 = dc.cleanColumn(mdyCol, Filters::DateOutputFormat::ISO_YYYY_MM_DD);
    assert(cleaned2[0] == "2024-06-25");
    assert(cleaned2[1] == "2024-05-06"); // May 6th
    std::cout << "  ✅ Column Date Consensus Tests Passed!\n";

    // 3. Fast Inverted Index Clustering
    std::cout << "Testing Inverted Index Fuzzy Clustering...\n";
    auto& ce = Filters::ClusterEngine::getInstance();
    std::vector<std::string> items = {
        "Samsung Galaxy S23",
        "Samsung Glaxy S23",
        "Samsng Galaxy S23",
        "Apple iPhone 15",
        "Google Pixel 8",
        "Google Pixl 8"
    };
    auto clusRes = ce.cluster(items, "A", 0.80f);
    assert(!clusRes.clusters.empty());
    assert(clusRes.clusteredCount >= 2);
    std::cout << "  ✅ Inverted Index Clustering Tests Passed!\n";

    // 4. Shifted Row Alignment
    std::cout << "Testing Shifted Row Aligner & Multi-Value Splitter...\n";
    auto& ra = Filters::RowAligner::getInstance();
    std::vector<std::vector<std::string>> grid = {
        {"Name", "Email", "Phone", "Salary"},
        {"John Doe", "john@gmail.com", "+919876543210", "50000"},
        {"Jane Doe", "Apt 4B, Delhi", "jane@gmail.com", "+919876543211", "60000"}
    };
    auto shiftReports = ra.detectShiftedRows(grid, true);
    assert(!shiftReports.empty());
    assert(shiftReports[0].detectedShift == 1);
    assert(shiftReports[0].alignedRow[1] == "jane@gmail.com");
    assert(shiftReports[0].alignedRow[2] == "+919876543211");

    auto tokens = Filters::RowAligner::splitDelimitedCell("Alpha | Beta | Gamma", "|");
    assert(tokens.size() == 3);
    assert(tokens[0] == "Alpha" && tokens[1] == "Beta" && tokens[2] == "Gamma");
    std::cout << "  ✅ Shifted Row Alignment Tests Passed!\n";

    // 5. Pattern Intelligence & Number Words
    std::cout << "Testing Pattern Intelligence & Number-Word Parser...\n";
    std::vector<std::string> words = {"forty-five", "one hundred twenty", "thirty", "y", "n"};
    std::vector<std::string> refs = {"A1", "A2", "A3", "A4", "A5"};
    auto repairs = PatternIntelligence::RepairSuggester::suggestRepairs(words, refs);
    assert(repairs.size() >= 5);
    assert(repairs[0].suggestedValue == "45");
    assert(repairs[1].suggestedValue == "120");
    assert(repairs[2].suggestedValue == "30");
    assert(repairs[3].suggestedValue == "TRUE");
    assert(repairs[4].suggestedValue == "FALSE");

    // Relational Temporal Anomaly
    std::vector<std::string> d1 = {"15-05-2024"};
    std::vector<std::string> r1 = {"A1"};
    std::vector<std::string> d2 = {"10-05-2024"};
    std::vector<std::string> r2 = {"B1"};
    auto anomalies = PatternIntelligence::RelationalPattern::checkTemporalLogic(d1, r1, d2, r2);
    assert(anomalies.size() == 1);
    std::cout << "  ✅ Pattern Intelligence Tests Passed!\n";

    // 6. 10 Extreme Messy Real-World Benchmark Tests
    std::cout << "\n--- Testing 10 Extreme Messy Real-World Benchmark Scenarios ---\n";

    // 6.1 Mojibake & Encoding
    std::string dirtyEncoding = "\xEF\xBB\xBF\xE2\x80\x8B\xC2\xA0Â₹ 1.250,50/- \t";
    std::string cleanMojibake = Filters::MojibakeCleaner::getInstance().clean(dirtyEncoding);
    std::string cleanNumeric = Filters::ExtremeCleaningEngine::cleanNumericString(cleanMojibake);
    assert(cleanNumeric == "1250.5");

    // 6.2 Chaotic Mixed Cell Entity Extraction
    std::string chaoticMixed = "Zoë Müller CEO <zoe.muller+promo@company.com> +91 (98765) 43210 Flat 402, Sunrise Towers, Mumbai - 400001";
    Filters::ExtractedEntity entity = Filters::ExtremeCleaningEngine::extractMixedCellData(chaoticMixed);
    assert(entity.isValid);
    assert(entity.cleanEmail == "zoe.muller+promo@company.com");
    assert(!entity.cleanPhone.empty());

    // 6.3 Date Column Consensus under Mixed Formats
    std::vector<std::string> extremeDates = {
        "45424",           // Excel serial -> 2024-05-12
        "04/25/2024",      // Unambiguous MM/DD anchor -> proves US format
        "05/06/2024",      // Ambiguous -> MUST resolve to 2024-05-06 (May 6th)
        "15th Jan 2024",   // Text month -> 2024-01-15
        "20240512"         // Compact -> 2024-05-12
    };
    auto cleanedDates = dc.cleanColumn(extremeDates, Filters::DateOutputFormat::ISO_YYYY_MM_DD);
    assert(cleanedDates[0] == "2024-05-12");
    assert(cleanedDates[1] == "2024-04-25");
    assert(cleanedDates[2] == "2024-05-06"); // May 6th
    assert(cleanedDates[3] == "2024-01-15");
    assert(cleanedDates[4] == "2024-05-12");

    // 6.4 Financial Currencies & Accounting
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("($1,234.56 USD)") == "-1234.56");
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("Rs. 50,000/- DR") == "-50000");
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("10 Crore") == "100000000");

    // 6.5 Unit Normalization Across 4 Domains
    auto& uc = Filters::UnitCleaner::getInstance();
    auto parsedMass = uc.parse("1.5 Tonnes");
    assert(parsedMass.isValid && parsedMass.baseMagnitude == 1500.0);
    auto parsedVol = uc.parse("500 ml");
    assert(parsedVol.isValid && parsedVol.baseMagnitude == 0.5);
    auto parsedLen = uc.parse("100 cm");
    assert(parsedLen.isValid && parsedLen.baseMagnitude == 1.0);
    auto parsedCount = uc.parse("10 Boxes");
    assert(parsedCount.isValid && parsedCount.baseUnit == "pcs");

    // 6.6 Smart Linear Interpolation Imputation
    auto& ie = Filters::ImputationEngine::getInstance();
    std::vector<std::string> gapData = {"100", "NULL", "120", "n/a", "140"};
    auto impReport = ie.impute(gapData, Filters::ImputationMethod::LINEAR_INTERPOLATE);
    assert(impReport.filledCount == 2);
    assert(impReport.resultValues[1] == "110");
    assert(impReport.resultValues[3] == "130");

    // 6.7 Full Address Tokenization
    auto& ac = Filters::AddressCleaner::getInstance();
    auto addr = ac.parse("Flat 502, B-Wing, Lodha Bellissimo, NM Joshi Marg, Lower Parel, Mumbai, Maharashtra - 400013");
    assert(addr.isValid);
    assert(addr.pincode == "400013");
    assert(addr.city == "Mumbai");
    assert(addr.state == "Maharashtra");
    assert(addr.country == "India");

    // 6.8 Number-word parsing in dirty text
    assert(PatternIntelligence::RepairSuggester::suggestRepairs({"one thousand two hundred fifty"}, {"A1"})[0].suggestedValue == "1250");
    assert(PatternIntelligence::RepairSuggester::suggestRepairs({"ninety-nine"}, {"A2"})[0].suggestedValue == "99");

    // 6.9 Boolean Variations
    Filters::DataCleaner& cleaner = Filters::DataCleaner::getInstance();
    assert(cleaner.clean("CHECKED", Filters::DataType::BOOLEAN) == "TRUE");
    assert(cleaner.clean("PASS", Filters::DataType::BOOLEAN) == "TRUE");
    assert(cleaner.clean("DISABLED", Filters::DataType::BOOLEAN) == "FALSE");
    assert(cleaner.clean("UNCHECKED", Filters::DataType::BOOLEAN) == "FALSE");

    std::cout << "\n🎉 ALL SOTA Data Cleaning Engine Tests PASSED WITH 100% ACCURACY! 🎉\n";
    return 0;
}
