/*
 * email_plugin.cpp  —  Enterprise Layered Email Detector Plugin Implementation
 */
#include "email_plugin.h"
#include "../../cleaning/email_cleaner.h"

namespace Filters {

float EmailPlugin::detect(const std::string& val) const {
    if (val.empty()) return 0.0f;
    EmailMetadata meta = EmailCleaner::analyzeAndNormalize(val);
    if (!meta.isValid) return 0.0f;
    return (float)meta.confidenceScore / 100.0f;
}

} // namespace Filters
