#ifndef COLUMN_METADATA_H
#define COLUMN_METADATA_H

#include <string>

namespace Filters {

enum class DataType {
    UNKNOWN,
    TEXT,
    NUMBER,
    DATE,
    TIME,
    DATETIME,
    PHONE,
    EMAIL,
    CURRENCY,
    BOOLEAN,
    FORMULA,
    URL,
    IP_ADDRESS,
    MAC_ADDRESS,
    UUID,
    JSON,
    XML,
    BARCODE,
    QR,
    PAN,
    GST,
    AADHAAR,
    MIXED,
    BLANK
};

struct ColumnMetadata {
    std::string name;
    DataType type = DataType::UNKNOWN;
    float confidence = 0.0f; // 0.0 to 1.0
    bool nullable = true;
    bool unique = false;
    bool indexed = false;
    bool dirty = true;
};

} // namespace Filters

#endif // COLUMN_METADATA_H
