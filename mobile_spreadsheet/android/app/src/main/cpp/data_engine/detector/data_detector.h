#ifndef DATA_DETECTOR_H
#define DATA_DETECTOR_H

#include "../cache/column_metadata.h"
#include <string>
#include <vector>
#include <memory>

namespace Filters {

class IDataDetectorPlugin {
public:
    virtual ~IDataDetectorPlugin() = default;
    
    // Returns confidence score from 0.0 to 1.0. Returns 0 if not a match.
    virtual float detect(const std::string& val) const = 0;
    
    virtual DataType getDataType() const = 0;
    virtual std::string getName() const = 0;
};

class DataDetector {
public:
    static DataDetector& getInstance() {
        static DataDetector instance;
        return instance;
    }

    void registerPlugin(std::shared_ptr<IDataDetectorPlugin> plugin);
    
    // Returns the type with the highest confidence
    DataType detect(const std::string& cellValue);
    
private:
    DataDetector(); // Initialize with default plugins
    std::vector<std::shared_ptr<IDataDetectorPlugin>> plugins;
};

} // namespace Filters

#endif // DATA_DETECTOR_H
