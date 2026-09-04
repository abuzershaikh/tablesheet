#include "test_runner.h"
#include "../engine/pipeline_validator.h"
#include "../engine/transaction_engine.h"
#include "../cleaning/extreme_cleaning_engine.h"
#include "../cleaning/data_cleaner.h"
#include "../cleaning/date_cleaner.h"
#include "../cleaning/row_aligner.h"
#include "../cleaning/mojibake_cleaner.h"
#include "../cleaning/unit_cleaner.h"
#include "../cleaning/address_cleaner.h"
#include "../cleaning/imputation_engine.h"
#include "../cleaning/record_stitcher.h"
#include "../cleaning/mixed_cell_demixer.h"
#include "../analyzer/subtotal_isolator.h"
#include "../cluster/cluster_engine.h"
#include "../pattern_intelligence/repair_suggester.h"
#include "../pattern_intelligence/relational_pattern.h"
#include "../../js_engine.h"
#include <iostream>
#include <cassert>

namespace DataPipeline {

void TestRunner::runAllTests() {
    std::cout << "Running DataPipeline Tests..." << std::endl;
    testPipelineValidator();
    testTransactionRollback();
    testLocaleNumberCleaning();
    testColumnDateConsensus();
    testInvertedIndexClustering();
    testRowAligner();
    testPatternIntelligence();
    testExtremeDataCleaningBenchmark();
    testJsEngineAndBundledLibraries();
    std::cout << "All DataPipeline & SOTA Cleaning Tests Passed Successfully!" << std::endl;
}

void TestRunner::testLocaleNumberCleaning() {
    // 1. European format: 1.234,56 € -> 1234.56
    std::string eu1 = Filters::ExtremeCleaningEngine::cleanNumericString("1.234,56 €");
    assert(eu1 == "1234.56");

    // 2. US format: $1,234.56 -> 1234.56
    std::string us1 = Filters::ExtremeCleaningEngine::cleanNumericString("$1,234.56");
    assert(us1 == "1234.56");

    // 3. Accounting negative: ($1,200.50) -> -1200.5
    std::string acc = Filters::ExtremeCleaningEngine::cleanNumericString("($1,200.50)");
    assert(acc == "-1200.5");

    // 4. Metric suffixes: 1.5k -> 1500, 2.5M -> 2500000
    std::string sufK = Filters::ExtremeCleaningEngine::cleanNumericString("1.5k");
    assert(sufK == "1500");
    std::string sufM = Filters::ExtremeCleaningEngine::cleanNumericString("2.5M");
    assert(sufM == "2500000");

    // 5. Indian notation: Rs. 500/- -> 500
    std::string inr = Filters::ExtremeCleaningEngine::cleanNumericString("Rs. 500/-");
    assert(inr == "500");
}

void TestRunner::testColumnDateConsensus() {
    auto& dc = Filters::DateCleaner::getInstance();

    // Column 1: Unambiguous European format (contains 25/06/2024)
    std::vector<std::string> dmyCol = {"25/06/2024", "05/06/2024", "12/01/2024"};
    auto pref1 = dc.learnColumnDateFormat(dmyCol);
    assert(pref1 == Filters::DateFormatPreference::PREFER_DMY);

    auto cleanedCol1 = dc.cleanColumn(dmyCol, Filters::DateOutputFormat::ISO_YYYY_MM_DD);
    assert(cleanedCol1[0] == "2024-06-25");
    assert(cleanedCol1[1] == "2024-06-05"); // 5th June!

    // Column 2: Unambiguous US format (contains 06/25/2024)
    std::vector<std::string> mdyCol = {"06/25/2024", "05/06/2024", "01/12/2024"};
    auto pref2 = dc.learnColumnDateFormat(mdyCol);
    assert(pref2 == Filters::DateFormatPreference::PREFER_MDY);

    auto cleanedCol2 = dc.cleanColumn(mdyCol, Filters::DateOutputFormat::ISO_YYYY_MM_DD);
    assert(cleanedCol2[0] == "2024-06-25");
    assert(cleanedCol2[1] == "2024-05-06"); // 6th May!
}

void TestRunner::testInvertedIndexClustering() {
    auto& ce = Filters::ClusterEngine::getInstance();
    std::vector<std::string> items = {
        "Samsung Galaxy S23",
        "Samsung Glaxy S23",
        "Samsng Galaxy S23",
        "Apple iPhone 15",
        "Apple iPhone 15 Pro",
        "Google Pixel 8",
        "Google Pixl 8"
    };

    auto res = ce.cluster(items, "A", 0.80f);
    assert(!res.clusters.empty());
    assert(res.clusteredCount >= 2);
}

void TestRunner::testRowAligner() {
    auto& ra = Filters::RowAligner::getInstance();

    std::vector<std::vector<std::string>> grid = {
        {"Name", "Email", "Phone", "Salary"},
        {"John Doe", "john@gmail.com", "+919876543210", "50000"},
        // Shifted row (extra address pushed email to col 2 and phone to col 3):
        {"Jane Doe", "Apt 4B, Delhi", "jane@gmail.com", "+919876543211", "60000"}
    };

    auto reports = ra.detectShiftedRows(grid, true);
    assert(!reports.empty());
    assert(reports[0].detectedShift == 1);
    assert(reports[0].alignedRow[1] == "jane@gmail.com");
    assert(reports[0].alignedRow[2] == "+919876543211");

    // Delimited cell splitter
    auto parts = Filters::RowAligner::splitDelimitedCell("Red | Green | Blue", "|");
    assert(parts.size() == 3);
    assert(parts[0] == "Red" && parts[1] == "Green" && parts[2] == "Blue");
}

void TestRunner::testPatternIntelligence() {
    // Number words
    std::vector<std::string> words = {"forty-five", "one hundred twenty", "thirty", "y", "n"};
    std::vector<std::string> refs = {"A1", "A2", "A3", "A4", "A5"};
    auto rep = PatternIntelligence::RepairSuggester::suggestRepairs(words, refs);
    assert(!rep.empty());
    assert(rep[0].suggestedValue == "45");
    assert(rep[1].suggestedValue == "120");
    assert(rep[2].suggestedValue == "30");
    assert(rep[3].suggestedValue == "TRUE");
    assert(rep[4].suggestedValue == "FALSE");

    // Relational temporal logic
    std::vector<std::string> d1 = {"15-05-2024"};
    std::vector<std::string> r1 = {"A1"};
    std::vector<std::string> d2 = {"10-05-2024"}; // Earlier date
    std::vector<std::string> r2 = {"B1"};
    auto anomalies = PatternIntelligence::RelationalPattern::checkTemporalLogic(d1, r1, d2, r2);
    assert(anomalies.size() == 1);
}

void TestRunner::testPipelineValidator() {
    // 1. Invalid JSON
    auto res1 = PipelineValidator::validate("invalid json");
    assert(res1.status == ExecutionStatus::FATAL_ERROR);
    
    // 2. Missing steps array
    auto res2 = PipelineValidator::validate(R"({"name": "test"})");
    assert(res2.status == ExecutionStatus::FATAL_ERROR);
    
    // 3. Step missing type
    auto res3 = PipelineValidator::validate(R"({"steps": [{}]})");
    assert(res3.status == ExecutionStatus::FATAL_ERROR);
    
    // 4. Unregistered step
    auto res4 = PipelineValidator::validate(R"({"steps": [{"type": "NonExistent"}]})");
    assert(res4.status == ExecutionStatus::FATAL_ERROR);
}

void TestRunner::testTransactionRollback() {
    PipelineContext ctx;
    ctx.totalRows = 10;
    ctx.rowVisibility.assign(10, 1);
    
    std::unordered_map<std::string, std::string> mockGrid;
    mockGrid["0,0"] = "OldValue";
    
    ctx.setCellVal = [&mockGrid](int r, int c, const std::string& v) {
        mockGrid[std::to_string(r) + "," + std::to_string(c)] = v;
    };
    ctx.getCellVal = [&mockGrid](int r, int c) {
        return mockGrid[std::to_string(r) + "," + std::to_string(c)];
    };
    
    auto& tx = TransactionEngine::getInstance();
    
    // Start TX
    tx.beginTransaction(ctx);
    
    // Track change
    tx.trackCellChange(0, 0, mockGrid["0,0"]);
    
    // Apply change
    ctx.setCellVal(0, 0, "NewValue");
    assert(mockGrid["0,0"] == "NewValue");
    
    // Rollback
    tx.rollback(ctx);
    
    // Verify rollback
    assert(mockGrid["0,0"] == "OldValue");
}

void TestRunner::testExtremeDataCleaningBenchmark() {
    std::cout << "--- Running 10 Extreme Messy Real-World Benchmark Tests ---\n";

    // 1. Extreme Mojibake & Corrupted Encoding
    std::string dirtyEncoding = "\xEF\xBB\xBF\xE2\x80\x8B\xC2\xA0Â₹ 1.250,50/- \t";
    std::string cleanMojibake = Filters::MojibakeCleaner::getInstance().clean(dirtyEncoding);
    std::string cleanNumeric = Filters::ExtremeCleaningEngine::cleanNumericString(cleanMojibake);
    assert(cleanNumeric == "1250.5");

    // 2. Chaotic Mixed Cell Entity Extraction
    std::string chaoticMixed = "Zoë Müller CEO <zoe.muller+promo@company.com> +91 (98765) 43210 Flat 402, Sunrise Towers, Mumbai - 400001";
    Filters::ExtractedEntity entity = Filters::ExtremeCleaningEngine::extractMixedCellData(chaoticMixed);
    assert(entity.isValid);
    assert(entity.cleanEmail == "zoe.muller+promo@company.com");
    assert(!entity.cleanPhone.empty());

    // 3. Date Column Consensus under Mixed Formats
    auto& dc = Filters::DateCleaner::getInstance();
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
    assert(cleanedDates[2] == "2024-05-06"); // Accurately resolved as May 6th due to column anchor!
    assert(cleanedDates[3] == "2024-01-15");
    assert(cleanedDates[4] == "2024-05-12");

    // 4. Financial Currencies & Accounting
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("($1,234.56 USD)") == "-1234.56");
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("Rs. 50,000/- DR") == "-50000");
    assert(Filters::ExtremeCleaningEngine::cleanNumericString("10 Crore") == "100000000");

    // 5. Unit Normalization Across 4 Domains
    auto& uc = Filters::UnitCleaner::getInstance();
    auto parsedMass = uc.parse("1.5 Tonnes");
    assert(parsedMass.isValid && parsedMass.baseMagnitude == 1500.0); // 1500 kg
    auto parsedVol = uc.parse("500 ml");
    assert(parsedVol.isValid && parsedVol.baseMagnitude == 0.5); // 0.5 L
    auto parsedLen = uc.parse("100 cm");
    assert(parsedLen.isValid && parsedLen.baseMagnitude == 1.0); // 1 m
    auto parsedCount = uc.parse("10 Boxes");
    assert(parsedCount.isValid && parsedCount.baseUnit == "pcs");

    // 6. Smart Linear Interpolation Imputation
    auto& ie = Filters::ImputationEngine::getInstance();
    std::vector<std::string> gapData = {"100", "NULL", "120", "n/a", "140"};
    auto impReport = ie.impute(gapData, Filters::ImputationMethod::LINEAR_INTERPOLATE);
    assert(impReport.filledCount == 2);
    assert(impReport.resultValues[1] == "110");
    assert(impReport.resultValues[3] == "130");

    // 7. Full Address Tokenization
    auto& ac = Filters::AddressCleaner::getInstance();
    auto addr = ac.parse("Flat 502, B-Wing, Lodha Bellissimo, NM Joshi Marg, Lower Parel, Mumbai, Maharashtra - 400013");
    assert(addr.isValid);
    assert(addr.pincode == "400013");
    assert(addr.city == "Mumbai");
    assert(addr.state == "Maharashtra");
    assert(addr.country == "India");

    // 8. Number-word parsing in dirty text
    assert(PatternIntelligence::RepairSuggester::suggestRepairs({"one thousand two hundred fifty"}, {"A1"})[0].suggestedValue == "1250");
    assert(PatternIntelligence::RepairSuggester::suggestRepairs({"ninety-nine"}, {"A2"})[0].suggestedValue == "99");

    // 9. Boolean Variations
    Filters::DataCleaner& cleaner = Filters::DataCleaner::getInstance();
    assert(cleaner.clean("CHECKED", Filters::DataType::BOOLEAN) == "TRUE");
    assert(cleaner.clean("PASS", Filters::DataType::BOOLEAN) == "TRUE");
    assert(cleaner.clean("DISABLED", Filters::DataType::BOOLEAN) == "FALSE");
    assert(cleaner.clean("UNCHECKED", Filters::DataType::BOOLEAN) == "FALSE");

    // 10. Multi-Line Record Stitcher (PDF/Bank Statement unrolling)
    std::vector<std::vector<std::string>> multiLineGrid = {
        {"Date", "TxnID", "Description", "Amount"},
        {"01/05/2024", "TXN98421", "Payment to Vendor", ""},
        {"", "", "NEFT Ref: HDFC000124", ""},
        {"", "", "", "45000.00"}
    };
    auto stitchRes = Filters::RecordStitcher::getInstance().stitchGrid(multiLineGrid, true, 0);
    assert(stitchRes.cleanGrid.size() == 2); // 1 Header + 1 Stitched Record
    assert(stitchRes.cleanGrid[1][0] == "01/05/2024");
    assert(stitchRes.cleanGrid[1][1] == "TXN98421");
    assert(stitchRes.cleanGrid[1][2] == "Payment to Vendor - NEFT Ref: HDFC000124");
    assert(stitchRes.cleanGrid[1][3] == "45000.00");
    assert(stitchRes.report.eliminatedChildRows == 2);

    // 11. Universal Multi-Entity Cell De-Mixer
    std::string mixedCell = "Ramesh Sharma | 9876543210 | ramesh@gmail.com | 27AABCT3518Q1Z | ₹15,000 | Flat 402, Mumbai";
    auto demixRes = Filters::MixedCellDeMixer::getInstance().demixCell(mixedCell);
    assert(demixRes.isValid);
    assert(demixRes.name == "Ramesh Sharma");
    assert(demixRes.email == "ramesh@gmail.com");
    assert(demixRes.gstin == "27AABCT3518Q1Z");
    assert(demixRes.amount == "15000");

    // 12. Subtotal & Page Noise Isolator
    std::vector<std::vector<std::string>> noiseGrid = {
        {"Category", "Sales"},
        {"Electronics", "50000"},
        {"Sub Total", "50000"},
        {"-------------------", ""},
        {"Furniture", "30000"},
        {"Page 1 of 4", ""},
        {"Grand Total", "80000"}
    };
    auto isoRes = Filters::SubtotalIsolator::getInstance().isolateSubtotals(noiseGrid, true);
    assert(isoRes.cleanGrid.size() == 3); // Header + Electronics + Furniture
    assert(isoRes.cleanGrid[1][0] == "Electronics");
    assert(isoRes.cleanGrid[2][0] == "Furniture");
    assert(isoRes.removedNoiseRowsCount == 4);

    std::cout << "  ✅ All AI Agent Super-Tools & Extreme Benchmark Scenarios Passed with 100% Accuracy!\n";
}

void TestRunner::testJsEngineAndBundledLibraries() {
    auto& js = JsEngine::getInstance();
    assert(js.init());

    // 1. Test Day.js
    std::string dayRes = js.evalScript("dayjs('2026-09-04').format('YYYY/MM/DD');");
    assert(dayRes.find("2026/09/04") != std::string::npos);

    // 2. Test FormulaJS (VLOOKUP & SUM)
    std::string vlookRes = js.evalScript("formulajs.VLOOKUP('B', [['A', 10], ['B', 20], ['C', 30]], 2, false);");
    assert(vlookRes.find("20") != std::string::npos);

    std::string sumRes = js.evalScript("formulajs.SUM(10, 20, 30, [40, 50]);");
    assert(sumRes.find("150") != std::string::npos);

    // 3. Test Fuse.js (Fuzzy Match)
    std::string fuseRes = js.evalScript("var f = new Fuse(['Abuzar Shaikh', 'Rahul Sharma', 'John Doe']); var r = f.search('Abuzer'); r[0].item;");
    assert(fuseRes.find("Abuzar Shaikh") != std::string::npos);

    // 4. Test Currency.js
    std::string currRes = js.evalScript("currency(19.99).add(0.01).format();");
    assert(currRes.find("$20.00") != std::string::npos);

    // 5. Test Regression.js
    std::string regRes = js.evalScript("var mod = regression.linear([[1, 2], [2, 4], [3, 6]]); mod.predict(4)[1];");
    assert(regRes.find("8") != std::string::npos);

    // 6. Test PapaParse
    std::string papaRes = js.evalScript("var p = Papa.parse('Name,Age\\nAlice,25\\nBob,30', { header: true }); p.data[0].Name;");
    assert(papaRes.find("Alice") != std::string::npos);

    // 7. Test CountryData (Phone-Country Bidirectional Mapping)
    std::string c1 = js.evalScript("CountryData.extractCountryFromPhone('+919876543210');");
    assert(c1.find("India") != std::string::npos);

    std::string c2 = js.evalScript("CountryData.extractCountryFromPhone('+14155552671');");
    assert(c2.find("United States") != std::string::npos);

    std::string c3 = js.evalScript("CountryData.extractCountryFromPhone('+447911123456');");
    assert(c3.find("United Kingdom") != std::string::npos);

    std::string code1 = js.evalScript("CountryData.getCallingCode('India');");
    assert(code1.find("+91") != std::string::npos);

    std::string fmt1 = js.evalScript("CountryData.formatPhoneWithCountry('9876543210', 'India');");
    assert(fmt1.find("+919876543210") != std::string::npos);

    // 8. Test Timeout Watchdog with Infinite Loop (set short timeout for test)
    js.setTimeoutMs(100);
    std::string timeoutRes = js.evalScript("while(true) {}");
    assert(timeoutRes.find("timed out") != std::string::npos);
    js.setTimeoutMs(5000); // restore default

    std::cout << "  ✅ QuickJS Sandboxing, Timeout Watchdog & Bundled Libraries (Day.js, FormulaJS, Fuse, Currency, Regression, PapaParse, CountryData) Passed 100%!\n";
}

} // namespace DataPipeline

