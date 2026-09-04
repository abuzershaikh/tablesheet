#ifndef TEST_RUNNER_H
#define TEST_RUNNER_H

namespace DataPipeline {

class TestRunner {
public:
    static void runAllTests();
    
private:
    static void testPipelineValidator();
    static void testTransactionRollback();
    static void testLocaleNumberCleaning();
    static void testColumnDateConsensus();
    static void testInvertedIndexClustering();
    static void testRowAligner();
    static void testPatternIntelligence();
    static void testExtremeDataCleaningBenchmark();
    static void testJsEngineAndBundledLibraries();
};

} // namespace DataPipeline

#endif // TEST_RUNNER_H
