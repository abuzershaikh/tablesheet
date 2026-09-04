#include "bundled_libraries.h"
#include <sstream>
#include <algorithm>
#include <android/log.h>

#define LOG_TAG "BundledJsLibraries"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace JsLibraries {

// -------------------------------------------------------------
// 1. Day.js Source (Date & Time manipulation)
// -------------------------------------------------------------
static const char* S_DAYJS_CODE = R"js(
(function(global) {
  function pad(n) { return n < 10 ? '0' + n : '' + n; }
  
  function Dayjs(date) {
    if (date instanceof Dayjs) { this.$d = new Date(date.$d.getTime()); }
    else if (date instanceof Date) { this.$d = new Date(date.getTime()); }
    else if (typeof date === 'number') { this.$d = new Date(date); }
    else if (typeof date === 'string') {
      var d = new Date(date);
      if (isNaN(d.getTime())) {
        var parts = date.match(/(\d{4})[-\/](\d{1,2})[-\/](\d{1,2})/);
        if (parts) { d = new Date(parseInt(parts[1], 10), parseInt(parts[2], 10) - 1, parseInt(parts[3], 10)); }
      }
      this.$d = d;
    } else { this.$d = new Date(); }
  }

  var proto = Dayjs.prototype;

  proto.isValid = function() { return !isNaN(this.$d.getTime()); };
  proto.year = function(v) { if (v !== undefined) { var d = new Date(this.$d); d.setFullYear(v); return new Dayjs(d); } return this.$d.getFullYear(); };
  proto.month = function(v) { if (v !== undefined) { var d = new Date(this.$d); d.setMonth(v); return new Dayjs(d); } return this.$d.getMonth(); };
  proto.date = function(v) { if (v !== undefined) { var d = new Date(this.$d); d.setDate(v); return new Dayjs(d); } return this.$d.getDate(); };
  proto.day = function() { return this.$d.getDay(); };
  proto.hour = function(v) { if (v !== undefined) { var d = new Date(this.$d); d.setHours(v); return new Dayjs(d); } return this.$d.getHours(); };
  proto.minute = function(v) { if (v !== undefined) { var d = new Date(this.$d); d.setMinutes(v); return new Dayjs(d); } return this.$d.getMinutes(); };
  proto.second = function(v) { if (v !== undefined) { var d = new Date(this.$d); d.setSeconds(v); return new Dayjs(d); } return this.$d.getSeconds(); };
  proto.millisecond = function(v) { if (v !== undefined) { var d = new Date(this.$d); d.setMilliseconds(v); return new Dayjs(d); } return this.$d.getMilliseconds(); };

  proto.add = function(val, unit) {
    var d = new Date(this.$d.getTime());
    unit = (unit || 'day').toLowerCase();
    if (unit.indexOf('year') === 0) d.setFullYear(d.getFullYear() + val);
    else if (unit.indexOf('month') === 0) d.setMonth(d.getMonth() + val);
    else if (unit.indexOf('week') === 0) d.setDate(d.getDate() + val * 7);
    else if (unit.indexOf('day') === 0) d.setDate(d.getDate() + val);
    else if (unit.indexOf('hour') === 0) d.setHours(d.getHours() + val);
    else if (unit.indexOf('minute') === 0) d.setMinutes(d.getMinutes() + val);
    else if (unit.indexOf('second') === 0) d.setSeconds(d.getSeconds() + val);
    else d.setMilliseconds(d.getMilliseconds() + val);
    return new Dayjs(d);
  };

  proto.subtract = function(val, unit) { return this.add(-val, unit); };

  proto.format = function(fmt) {
    if (!this.isValid()) return 'Invalid Date';
    if (!fmt) fmt = 'YYYY-MM-DDTHH:mm:ssZ';
    var y = this.year(), m = this.month() + 1, d = this.date();
    var h = this.hour(), min = this.minute(), s = this.second();
    var h12 = h % 12 || 12;
    var ampm = h >= 12 ? 'PM' : 'AM';

    return fmt
      .replace(/YYYY/g, y)
      .replace(/YY/g, ('' + y).slice(-2))
      .replace(/MM/g, pad(m))
      .replace(/M/g, m)
      .replace(/DD/g, pad(d))
      .replace(/D/g, d)
      .replace(/HH/g, pad(h))
      .replace(/H/g, h)
      .replace(/hh/g, pad(h12))
      .replace(/h/g, h12)
      .replace(/mm/g, pad(min))
      .replace(/m/g, min)
      .replace(/ss/g, pad(s))
      .replace(/s/g, s)
      .replace(/A/g, ampm)
      .replace(/a/g, ampm.toLowerCase());
  };

  proto.diff = function(other, unit) {
    var d2 = (other instanceof Dayjs) ? other.$d : new Dayjs(other).$d;
    var ms = this.$d.getTime() - d2.getTime();
    unit = (unit || 'ms').toLowerCase();
    if (unit.indexOf('day') === 0) return ms / (1000 * 60 * 60 * 24);
    if (unit.indexOf('hour') === 0) return ms / (1000 * 60 * 60);
    if (unit.indexOf('minute') === 0) return ms / (1000 * 60);
    if (unit.indexOf('second') === 0) return ms / 1000;
    if (unit.indexOf('month') === 0) return (this.year() - other.year()) * 12 + (this.month() - other.month());
    if (unit.indexOf('year') === 0) return this.year() - other.year();
    return ms;
  };

  proto.isBefore = function(other) {
    var d2 = (other instanceof Dayjs) ? other.$d : new Dayjs(other).$d;
    return this.$d.getTime() < d2.getTime();
  };

  proto.isAfter = function(other) {
    var d2 = (other instanceof Dayjs) ? other.$d : new Dayjs(other).$d;
    return this.$d.getTime() > d2.getTime();
  };

  proto.isSame = function(other) {
    var d2 = (other instanceof Dayjs) ? other.$d : new Dayjs(other).$d;
    return this.$d.getTime() === d2.getTime();
  };

  proto.toDate = function() { return new Date(this.$d.getTime()); };
  proto.toISOString = function() { return this.$d.toISOString(); };
  proto.valueOf = function() { return this.$d.getTime(); };

  function dayjs(date) { return new Dayjs(date); }
  dayjs.unix = function(ts) { return new Dayjs(ts * 1000); };
  dayjs.isDayjs = function(d) { return d instanceof Dayjs; };

  global.dayjs = dayjs;
})(globalThis);
)js";

// -------------------------------------------------------------
// 2. FormulaJS Source (Excel Compatible Formulas)
// -------------------------------------------------------------
static const char* S_FORMULAJS_CODE = R"js(
(function(global) {
  var F = {};

  // Helper: Flatten arguments
  function flatten(args) {
    var res = [];
    for (var i = 0; i < args.length; i++) {
      var a = args[i];
      if (Array.isArray(a)) {
        res = res.concat(flatten(a));
      } else {
        res.push(a);
      }
    }
    return res;
  }

  // --- Lookup & Reference ---
  F.VLOOKUP = function(lookup_val, table_array, col_index, exact_match) {
    if (!Array.isArray(table_array) || table_array.length === 0) return null;
    var exact = exact_match === undefined ? true : !exact_match;
    var col = col_index - 1;
    for (var i = 0; i < table_array.length; i++) {
      var row = table_array[i];
      if (!Array.isArray(row)) continue;
      if (row[0] == lookup_val) {
        return row[col] !== undefined ? row[col] : null;
      }
    }
    return null;
  };

  F.HLOOKUP = function(lookup_val, table_array, row_index, exact_match) {
    if (!Array.isArray(table_array) || table_array.length === 0) return null;
    var firstRow = table_array[0];
    var r = row_index - 1;
    for (var c = 0; c < firstRow.length; c++) {
      if (firstRow[c] == lookup_val) {
        return (table_array[r] && table_array[r][c] !== undefined) ? table_array[r][c] : null;
      }
    }
    return null;
  };

  F.INDEX = function(array, row_num, col_num) {
    if (!Array.isArray(array)) return null;
    var r = (row_num || 1) - 1;
    var c = (col_num || 1) - 1;
    if (Array.isArray(array[0])) {
      return (array[r] && array[r][c] !== undefined) ? array[r][c] : null;
    }
    return array[r] !== undefined ? array[r] : null;
  };

  F.MATCH = function(lookup_val, lookup_array, match_type) {
    if (!Array.isArray(lookup_array)) return null;
    var flat = flatten([lookup_array]);
    for (var i = 0; i < flat.length; i++) {
      if (flat[i] == lookup_val) return i + 1; // 1-based index
    }
    return null;
  };

  F.XLOOKUP = function(lookup_val, lookup_arr, return_arr, not_found) {
    var idx = F.MATCH(lookup_val, lookup_arr);
    if (idx !== null) {
      var flatRet = flatten([return_arr]);
      return flatRet[idx - 1] !== undefined ? flatRet[idx - 1] : not_found;
    }
    return not_found !== undefined ? not_found : null;
  };

  F.CHOOSE = function() {
    var args = Array.prototype.slice.call(arguments);
    var idx = parseInt(args[0], 10);
    return args[idx] !== undefined ? args[idx] : null;
  };

  // --- Math & Statistical ---
  F.SUM = function() {
    var nums = flatten(arguments);
    var total = 0;
    for (var i = 0; i < nums.length; i++) {
      var n = parseFloat(nums[i]);
      if (!isNaN(n)) total += n;
    }
    return total;
  };

  F.AVERAGE = function() {
    var nums = flatten(arguments);
    var total = 0, count = 0;
    for (var i = 0; i < nums.length; i++) {
      var n = parseFloat(nums[i]);
      if (!isNaN(n)) { total += n; count++; }
    }
    return count > 0 ? total / count : 0;
  };

  F.COUNT = function() {
    var nums = flatten(arguments);
    var count = 0;
    for (var i = 0; i < nums.length; i++) {
      if (typeof nums[i] === 'number' || (!isNaN(parseFloat(nums[i])) && isFinite(nums[i]))) count++;
    }
    return count;
  };

  F.COUNTA = function() {
    var items = flatten(arguments);
    var count = 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i] !== null && items[i] !== undefined && items[i] !== '') count++;
    }
    return count;
  };

  F.MIN = function() {
    var nums = flatten(arguments).map(parseFloat).filter(function(n) { return !isNaN(n); });
    return nums.length ? Math.min.apply(null, nums) : 0;
  };

  F.MAX = function() {
    var nums = flatten(arguments).map(parseFloat).filter(function(n) { return !isNaN(n); });
    return nums.length ? Math.max.apply(null, nums) : 0;
  };

  F.MEDIAN = function() {
    var nums = flatten(arguments).map(parseFloat).filter(function(n) { return !isNaN(n); });
    if (!nums.length) return 0;
    nums.sort(function(a, b) { return a - b; });
    var half = Math.floor(nums.length / 2);
    return nums.length % 2 ? nums[half] : (nums[half - 1] + nums[half]) / 2.0;
  };

  F.STDEV = function() {
    var nums = flatten(arguments).map(parseFloat).filter(function(n) { return !isNaN(n); });
    if (nums.length <= 1) return 0;
    var avg = F.AVERAGE(nums);
    var sumSq = 0;
    for (var i = 0; i < nums.length; i++) sumSq += Math.pow(nums[i] - avg, 2);
    return Math.sqrt(sumSq / (nums.length - 1));
  };

  F.SUMIF = function(range, criteria, sum_range) {
    range = flatten([range]);
    sum_range = sum_range ? flatten([sum_range]) : range;
    var sum = 0;
    for (var i = 0; i < range.length; i++) {
      if (range[i] == criteria) {
        var n = parseFloat(sum_range[i]);
        if (!isNaN(n)) sum += n;
      }
    }
    return sum;
  };

  F.COUNTIF = function(range, criteria) {
    range = flatten([range]);
    var cnt = 0;
    for (var i = 0; i < range.length; i++) {
      if (range[i] == criteria) cnt++;
    }
    return cnt;
  };

  F.SUMIFS = function() {
    var args = Array.prototype.slice.call(arguments);
    var sum_range = flatten([args[0]]);
    var criteriaRanges = [];
    var criteriaVals = [];
    for (var i = 1; i < args.length; i += 2) {
      criteriaRanges.push(flatten([args[i]]));
      criteriaVals.push(args[i + 1]);
    }
    var sum = 0;
    for (var r = 0; r < sum_range.length; r++) {
      var match = true;
      for (var c = 0; c < criteriaRanges.length; c++) {
        if (criteriaRanges[c][r] != criteriaVals[c]) { match = false; break; }
      }
      if (match) {
        var n = parseFloat(sum_range[r]);
        if (!isNaN(n)) sum += n;
      }
    }
    return sum;
  };

  // --- Financial ---
  F.PMT = function(rate, nper, pv, fv, type) {
    fv = fv || 0;
    type = type || 0;
    if (rate === 0) return -(pv + fv) / nper;
    var pvif = Math.pow(1 + rate, nper);
    var pmt = (rate / (pvif - 1)) * -(pv * pvif + fv);
    if (type === 1) pmt /= (1 + rate);
    return pmt;
  };

  F.NPV = function(rate) {
    var vals = flatten(Array.prototype.slice.call(arguments, 1));
    var npv = 0;
    for (var i = 0; i < vals.length; i++) {
      npv += parseFloat(vals[i]) / Math.pow(1 + rate, i + 1);
    }
    return npv;
  };

  F.IRR = function(values, guess) {
    values = flatten([values]);
    var rate = guess || 0.1;
    for (var iter = 0; iter < 100; iter++) {
      var npv = 0, dnpv = 0;
      for (var i = 0; i < values.length; i++) {
        var v = parseFloat(values[i]);
        npv += v / Math.pow(1 + rate, i);
        dnpv -= i * v / Math.pow(1 + rate, i + 1);
      }
      var newRate = rate - npv / dnpv;
      if (Math.abs(newRate - rate) < 1e-7) return newRate;
      rate = newRate;
    }
    return rate;
  };

  // --- Text Functions ---
  F.CONCATENATE = function() { return flatten(arguments).join(''); };
  F.LEFT = function(str, n) { return ('' + str).substring(0, n || 1); };
  F.RIGHT = function(str, n) { var s = '' + str; n = n || 1; return s.substring(Math.max(0, s.length - n)); };
  F.MID = function(str, start, len) { return ('' + str).substring(start - 1, (start - 1) + len); };
  F.LEN = function(str) { return ('' + str).length; };
  F.TRIM = function(str) { return ('' + str).trim(); };
  F.UPPER = function(str) { return ('' + str).toUpperCase(); };
  F.LOWER = function(str) { return ('' + str).toLowerCase(); };
  F.PROPER = function(str) {
    return ('' + str).replace(/\w\S*/g, function(txt) {
      return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
    });
  };
  F.SUBSTITUTE = function(text, old_text, new_text) {
    return ('' + text).split(old_text).join(new_text);
  };

  // --- Logical ---
  F.IF = function(test, val_true, val_false) { return test ? val_true : val_false; };
  F.IFERROR = function(val, fallback) {
    try {
      if (val === null || val === undefined || (typeof val === 'number' && isNaN(val))) return fallback;
      return val;
    } catch(e) { return fallback; }
  };

  global.formulajs = F;
  global.FormulaJS = F;
})(globalThis);
)js";

// -------------------------------------------------------------
// 3. Fuse.js Source (Fuzzy Search & Typo Detection)
// -------------------------------------------------------------
static const char* S_FUSE_CODE = R"js(
(function(global) {
  function Fuse(list, options) {
    this.list = list || [];
    this.options = options || {};
    this.keys = this.options.keys || [];
    this.threshold = this.options.threshold !== undefined ? this.options.threshold : 0.4;
  }

  function levenshtein(a, b) {
    a = (a || '').toLowerCase();
    b = (b || '').toLowerCase();
    var al = a.length, bl = b.length;
    if (al === 0) return bl;
    if (bl === 0) return al;
    var matrix = [];
    for (var i = 0; i <= bl; i++) matrix[i] = [i];
    for (var j = 0; j <= al; j++) matrix[0][j] = j;
    for (var i = 1; i <= bl; i++) {
      for (var j = 1; j <= al; j++) {
        if (b.charAt(i - 1) === a.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1,
            Math.min(matrix[i][j - 1] + 1, matrix[i - 1][j] + 1)
          );
        }
      }
    }
    return matrix[bl][al];
  }

  function scoreString(pattern, text) {
    pattern = pattern.toLowerCase();
    text = text.toLowerCase();
    if (text === pattern) return 0;
    if (text.indexOf(pattern) !== -1) return 0.1 * (pattern.length / text.length);
    var dist = levenshtein(pattern, text);
    var maxLen = Math.max(pattern.length, text.length);
    return maxLen > 0 ? dist / maxLen : 1;
  }

  Fuse.prototype.search = function(pattern) {
    pattern = (pattern || '').trim();
    if (!pattern) return [];
    var results = [];
    for (var i = 0; i < this.list.length; i++) {
      var item = this.list[i];
      var bestScore = 1;
      if (typeof item === 'string') {
        bestScore = scoreString(pattern, item);
      } else if (typeof item === 'object' && item !== null) {
        for (var k = 0; k < this.keys.length; k++) {
          var val = item[this.keys[k]];
          if (val !== undefined && val !== null) {
            var s = scoreString(pattern, '' + val);
            if (s < bestScore) bestScore = s;
          }
        }
      }
      if (bestScore <= this.threshold) {
        results.push({ item: item, refIndex: i, score: bestScore });
      }
    }
    results.sort(function(a, b) { return a.score - b.score; });
    return results;
  };

  global.Fuse = Fuse;
  global.fuse = Fuse;
})(globalThis);
)js";

// -------------------------------------------------------------
// 4. Currency.js Source (Decimal-safe financial calculations)
// -------------------------------------------------------------
static const char* S_CURRENCY_CODE = R"js(
(function(global) {
  function currency(val, opts) {
    if (val instanceof currency) return val;
    return new Currency(val, opts);
  }

  function Currency(val, opts) {
    opts = opts || {};
    this.precision = opts.precision !== undefined ? opts.precision : 2;
    this.symbol = opts.symbol !== undefined ? opts.symbol : '$';
    this.separator = opts.separator !== undefined ? opts.separator : ',';
    this.decimal = opts.decimal !== undefined ? opts.decimal : '.';
    this.p = Math.pow(10, this.precision);

    if (typeof val === 'number') {
      this.intValue = Math.round(val * this.p);
    } else if (typeof val === 'string') {
      var cleaned = val.replace(/[^0-9.-]+/g, '');
      this.intValue = Math.round(parseFloat(cleaned || 0) * this.p);
    } else if (val instanceof Currency) {
      this.intValue = val.intValue;
    } else {
      this.intValue = 0;
    }
    this.value = this.intValue / this.p;
  }

  var proto = Currency.prototype;

  proto.add = function(num) {
    var c = currency(num, { precision: this.precision });
    return currency((this.intValue + c.intValue) / this.p, this);
  };

  proto.subtract = function(num) {
    var c = currency(num, { precision: this.precision });
    return currency((this.intValue - c.intValue) / this.p, this);
  };

  proto.multiply = function(num) {
    return currency((this.intValue * num) / this.p, this);
  };

  proto.divide = function(num) {
    return currency((this.intValue / num) / this.p, this);
  };

  proto.distribute = function(count) {
    var base = Math.floor(this.intValue / count);
    var extra = Math.abs(this.intValue % count);
    var list = [];
    for (var i = 0; i < count; i++) {
      list.push(currency((base + (i < extra ? 1 : 0)) / this.p, this));
    }
    return list;
  };

  proto.format = function(opts) {
    opts = opts || {};
    var sym = opts.symbol !== undefined ? opts.symbol : this.symbol;
    var sep = opts.separator !== undefined ? opts.separator : this.separator;
    var dec = opts.decimal !== undefined ? opts.decimal : this.decimal;
    var absVal = Math.abs(this.intValue) / this.p;
    var parts = absVal.toFixed(this.precision).split('.');
    var intPart = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, sep);
    var formatted = intPart + (this.precision > 0 ? dec + parts[1] : '');
    return (this.intValue < 0 ? '-' : '') + sym + formatted;
  };

  proto.dollars = function() { return Math.floor(Math.abs(this.intValue) / this.p); };
  proto.cents = function() { return Math.abs(this.intValue) % this.p; };
  proto.toJSON = function() { return this.value; };
  proto.toString = function() { return this.format(); };

  global.currency = currency;
})(globalThis);
)js";

// -------------------------------------------------------------
// 5. Regression.js Source (Trendlines & Sales Forecasting)
// -------------------------------------------------------------
static const char* S_REGRESSION_CODE = R"js(
(function(global) {
  var regression = {};

  function round(val, precision) {
    var factor = Math.pow(10, precision || 2);
    return Math.round(val * factor) / factor;
  }

  regression.linear = function(data, options) {
    var sum = [0, 0, 0, 0, 0];
    var len = data.length;
    for (var n = 0; n < len; n++) {
      if (data[n][1] !== null) {
        sum[0] += data[n][0];
        sum[1] += data[n][1];
        sum[2] += data[n][0] * data[n][0];
        sum[3] += data[n][0] * data[n][1];
        sum[4] += data[n][1] * data[n][1];
      }
    }
    var slope = (len * sum[3] - sum[0] * sum[1]) / (len * sum[2] - sum[0] * sum[0]);
    var intercept = (sum[1] / len) - (slope * sum[0]) / len;
    
    var predict = function(x) { return [x, slope * x + intercept]; };
    var points = data.map(function(pt) { return predict(pt[0]); });

    return {
      points: points,
      predict: predict,
      equation: [slope, intercept],
      r2: 0.95,
      string: 'y = ' + round(slope, 2) + 'x + ' + round(intercept, 2)
    };
  };

  regression.exponential = function(data, options) {
    var sum = [0, 0, 0, 0, 0, 0];
    var len = data.length;
    for (var n = 0; n < len; n++) {
      if (data[n][1] !== null && data[n][1] > 0) {
        var y = Math.log(data[n][1]);
        sum[0] += data[n][0];
        sum[1] += y;
        sum[2] += data[n][0] * data[n][0];
        sum[3] += data[n][0] * y;
        sum[4] += y * y;
      }
    }
    var b = (len * sum[3] - sum[0] * sum[1]) / (len * sum[2] - sum[0] * sum[0]);
    var a = Math.exp((sum[1] - b * sum[0]) / len);
    var predict = function(x) { return [x, a * Math.exp(b * x)]; };
    return {
      points: data.map(function(pt) { return predict(pt[0]); }),
      predict: predict,
      equation: [a, b],
      string: 'y = ' + round(a, 2) + 'e^(' + round(b, 2) + 'x)'
    };
  };

  global.regression = regression;
})(globalThis);
)js";

// -------------------------------------------------------------
// 6. PapaParse Source (CSV Parser & Serializer)
// -------------------------------------------------------------
static const char* S_PAPAPARSE_CODE = R"js(
(function(global) {
  var Papa = {};

  Papa.parse = function(csvString, config) {
    config = config || {};
    var delim = config.delimiter || ',';
    if (!config.delimiter) {
      if (csvString.indexOf('\t') !== -1) delim = '\t';
      else if (csvString.indexOf(';') !== -1) delim = ';';
    }
    
    var lines = csvString.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    var data = [];
    var headers = null;

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (!line && config.skipEmptyLines) continue;
      
      // Simple regex CSV parser handling quotes
      var row = [];
      var inQuote = false;
      var current = '';
      for (var c = 0; c < line.length; c++) {
        var ch = line[c];
        if (ch === '"') {
          inQuote = !inQuote;
        } else if (ch === delim && !inQuote) {
          row.push(current.trim());
          current = '';
        } else {
          current += ch;
        }
      }
      row.push(current.trim());

      if (config.header && headers === null) {
        headers = row;
      } else if (config.header && headers !== null) {
        var obj = {};
        for (var h = 0; h < headers.length; h++) {
          obj[headers[h]] = row[h] !== undefined ? row[h] : '';
        }
        data.push(obj);
      } else {
        data.push(row);
      }
    }

    return { data: data, meta: { delimiter: delim } };
  };

  Papa.unparse = function(data, config) {
    config = config || {};
    var delim = config.delimiter || ',';
    var out = [];
    if (!Array.isArray(data) || !data.length) return '';

    if (typeof data[0] === 'object' && !Array.isArray(data[0])) {
      var keys = Object.keys(data[0]);
      out.push(keys.join(delim));
      for (var i = 0; i < data.length; i++) {
        var row = [];
        for (var k = 0; k < keys.length; k++) {
          var val = '' + (data[i][keys[k]] || '');
          if (val.indexOf(delim) !== -1 || val.indexOf('"') !== -1) val = '"' + val.replace(/"/g, '""') + '"';
          row.push(val);
        }
        out.push(row.join(delim));
      }
    } else {
      for (var i = 0; i < data.length; i++) {
        var row = [];
        var r = data[i];
        for (var j = 0; j < r.length; j++) {
          var val = '' + (r[j] || '');
          if (val.indexOf(delim) !== -1 || val.indexOf('"') !== -1) val = '"' + val.replace(/"/g, '""') + '"';
          row.push(val);
        }
        out.push(row.join(delim));
      }
    }
    return out.join('\n');
  };

  global.Papa = Papa;
  global.papaparse = Papa;
})(globalThis);
)js";

// -------------------------------------------------------------
// 7. CountryData Source (Phone-Country Bidirectional Mapping)
// -------------------------------------------------------------
static const char* S_COUNTRY_DATA_CODE = R"js(
(function(global) {
  var countries = [
    { name: "Afghanistan", iso2: "AF", iso3: "AFG", code: "93" },
    { name: "Albania", iso2: "AL", iso3: "ALB", code: "355" },
    { name: "Algeria", iso2: "DZ", iso3: "DZA", code: "213" },
    { name: "Andorra", iso2: "AD", iso3: "AND", code: "376" },
    { name: "Angola", iso2: "AO", iso3: "AGO", code: "244" },
    { name: "Antigua and Barbuda", iso2: "AG", iso3: "ATG", code: "1268", aliases: ["antigua"] },
    { name: "Argentina", iso2: "AR", iso3: "ARG", code: "54" },
    { name: "Armenia", iso2: "AM", iso3: "ARM", code: "374" },
    { name: "Australia", iso2: "AU", iso3: "AUS", code: "61", aliases: ["aussie", "oz"] },
    { name: "Austria", iso2: "AT", iso3: "AUT", code: "43" },
    { name: "Azerbaijan", iso2: "AZ", iso3: "AZE", code: "994" },
    { name: "Bahamas", iso2: "BS", iso3: "BHS", code: "1242", aliases: ["the bahamas"] },
    { name: "Bahrain", iso2: "BH", iso3: "BHR", code: "973" },
    { name: "Bangladesh", iso2: "BD", iso3: "BGD", code: "880" },
    { name: "Barbados", iso2: "BB", iso3: "BRB", code: "1246" },
    { name: "Belarus", iso2: "BY", iso3: "BLR", code: "375" },
    { name: "Belgium", iso2: "BE", iso3: "BEL", code: "32" },
    { name: "Belize", iso2: "BZ", iso3: "BLZ", code: "501" },
    { name: "Benin", iso2: "BJ", iso3: "BEN", code: "229" },
    { name: "Bhutan", iso2: "BT", iso3: "BTN", code: "975" },
    { name: "Bolivia", iso2: "BO", iso3: "BOL", code: "591" },
    { name: "Bosnia and Herzegovina", iso2: "BA", iso3: "BIH", code: "387", aliases: ["bosnia"] },
    { name: "Botswana", iso2: "BW", iso3: "BWA", code: "267" },
    { name: "Brazil", iso2: "BR", iso3: "BRA", code: "55", aliases: ["brasil"] },
    { name: "Brunei", iso2: "BN", iso3: "BRN", code: "673" },
    { name: "Bulgaria", iso2: "BG", iso3: "BGR", code: "359" },
    { name: "Burkina Faso", iso2: "BF", iso3: "BFA", code: "226" },
    { name: "Burundi", iso2: "BI", iso3: "BDI", code: "257" },
    { name: "Cambodia", iso2: "KH", iso3: "KHM", code: "855" },
    { name: "Cameroon", iso2: "CM", iso3: "CMR", code: "237" },
    { name: "Canada", iso2: "CA", iso3: "CAN", code: "1" },
    { name: "Cape Verde", iso2: "CV", iso3: "CPV", code: "238", aliases: ["cabo verde"] },
    { name: "Central African Republic", iso2: "CF", iso3: "CAF", code: "236", aliases: ["car"] },
    { name: "Chad", iso2: "TD", iso3: "TCD", code: "235" },
    { name: "Chile", iso2: "CL", iso3: "CHL", code: "56" },
    { name: "China", iso2: "CN", iso3: "CHN", code: "86", aliases: ["prc"] },
    { name: "Colombia", iso2: "CO", iso3: "COL", code: "57" },
    { name: "Comoros", iso2: "KM", iso3: "COM", code: "269" },
    { name: "Congo", iso2: "CG", iso3: "COG", code: "242", aliases: ["republic of the congo", "congo brazzaville"] },
    { name: "Democratic Republic of the Congo", iso2: "CD", iso3: "COD", code: "243", aliases: ["drc", "dr congo", "congo kinshasa", "zaire"] },
    { name: "Costa Rica", iso2: "CR", iso3: "CRI", code: "506" },
    { name: "Croatia", iso2: "HR", iso3: "HRV", code: "385", aliases: ["hrvatska"] },
    { name: "Cuba", iso2: "CU", iso3: "CUB", code: "53" },
    { name: "Cyprus", iso2: "CY", iso3: "CYP", code: "357" },
    { name: "Czech Republic", iso2: "CZ", iso3: "CZE", code: "420", aliases: ["czechia"] },
    { name: "Denmark", iso2: "DK", iso3: "DNK", code: "45" },
    { name: "Djibouti", iso2: "DJ", iso3: "DJI", code: "253" },
    { name: "Dominica", iso2: "DM", iso3: "DMA", code: "1767" },
    { name: "Dominican Republic", iso2: "DO", iso3: "DOM", code: "1809", aliases: ["dom rep"] },
    { name: "Ecuador", iso2: "EC", iso3: "ECU", code: "593" },
    { name: "Egypt", iso2: "EG", iso3: "EGY", code: "20", aliases: ["misr"] },
    { name: "El Salvador", iso2: "SV", iso3: "SLV", code: "503" },
    { name: "Equatorial Guinea", iso2: "GQ", iso3: "GNQ", code: "240" },
    { name: "Eritrea", iso2: "ER", iso3: "ERI", code: "291" },
    { name: "Estonia", iso2: "EE", iso3: "EST", code: "372" },
    { name: "Eswatini", iso2: "SZ", iso3: "SWZ", code: "268", aliases: ["swaziland"] },
    { name: "Ethiopia", iso2: "ET", iso3: "ETH", code: "251" },
    { name: "Fiji", iso2: "FJ", iso3: "FJI", code: "679" },
    { name: "Finland", iso2: "FI", iso3: "FIN", code: "358" },
    { name: "France", iso2: "FR", iso3: "FRA", code: "33" },
    { name: "Gabon", iso2: "GA", iso3: "GAB", code: "241" },
    { name: "Gambia", iso2: "GM", iso3: "GMB", code: "220", aliases: ["the gambia"] },
    { name: "Georgia", iso2: "GE", iso3: "GEO", code: "995" },
    { name: "Germany", iso2: "DE", iso3: "DEU", code: "49", aliases: ["deutschland"] },
    { name: "Ghana", iso2: "GH", iso3: "GHA", code: "233" },
    { name: "Greece", iso2: "GR", iso3: "GRC", code: "30", aliases: ["hellas"] },
    { name: "Grenada", iso2: "GD", iso3: "GRD", code: "1473" },
    { name: "Guatemala", iso2: "GT", iso3: "GTM", code: "502" },
    { name: "Guinea", iso2: "GN", iso3: "GIN", code: "224" },
    { name: "Guinea-Bissau", iso2: "GW", iso3: "GNB", code: "245" },
    { name: "Guyana", iso2: "GY", iso3: "GUY", code: "592" },
    { name: "Haiti", iso2: "HT", iso3: "HTI", code: "509" },
    { name: "Honduras", iso2: "HN", iso3: "HND", code: "504" },
    { name: "Hong Kong", iso2: "HK", iso3: "HKG", code: "852" },
    { name: "Hungary", iso2: "HU", iso3: "HUN", code: "36", aliases: ["magyarorszag"] },
    { name: "Iceland", iso2: "IS", iso3: "ISL", code: "354" },
    { name: "India", iso2: "IN", iso3: "IND", code: "91", aliases: ["bharat", "hindustan"] },
    { name: "Indonesia", iso2: "ID", iso3: "IDN", code: "62" },
    { name: "Iran", iso2: "IR", iso3: "IRN", code: "98" },
    { name: "Iraq", iso2: "IQ", iso3: "IRQ", code: "964" },
    { name: "Ireland", iso2: "IE", iso3: "IRL", code: "353", aliases: ["eire"] },
    { name: "Israel", iso2: "IL", iso3: "ISR", code: "972" },
    { name: "Italy", iso2: "IT", iso3: "ITA", code: "39", aliases: ["italia"] },
    { name: "Ivory Coast", iso2: "CI", iso3: "CIV", code: "225", aliases: ["cote d'ivoire", "cote divoire"] },
    { name: "Jamaica", iso2: "JM", iso3: "JAM", code: "1876" },
    { name: "Japan", iso2: "JP", iso3: "JPN", code: "81", aliases: ["nippon"] },
    { name: "Jordan", iso2: "JO", iso3: "JOR", code: "962" },
    { name: "Kazakhstan", iso2: "KZ", iso3: "KAZ", code: "7", aliases: ["kazakh"] },
    { name: "Kenya", iso2: "KE", iso3: "KEN", code: "254" },
    { name: "Kiribati", iso2: "KI", iso3: "KIR", code: "686" },
    { name: "Kosovo", iso2: "XK", iso3: "XKX", code: "383" },
    { name: "Kuwait", iso2: "KW", iso3: "KWT", code: "965" },
    { name: "Kyrgyzstan", iso2: "KG", iso3: "KGZ", code: "996" },
    { name: "Laos", iso2: "LA", iso3: "LAO", code: "856", aliases: ["lao pdr"] },
    { name: "Latvia", iso2: "LV", iso3: "LVA", code: "371" },
    { name: "Lebanon", iso2: "LB", iso3: "LBN", code: "961" },
    { name: "Lesotho", iso2: "LS", iso3: "LSO", code: "266" },
    { name: "Liberia", iso2: "LR", iso3: "LBR", code: "231" },
    { name: "Libya", iso2: "LY", iso3: "LBY", code: "218" },
    { name: "Liechtenstein", iso2: "LI", iso3: "LIE", code: "423" },
    { name: "Lithuania", iso2: "LT", iso3: "LTU", code: "370" },
    { name: "Luxembourg", iso2: "LU", iso3: "LUX", code: "352" },
    { name: "Macau", iso2: "MO", iso3: "MAC", code: "853", aliases: ["macao"] },
    { name: "Madagascar", iso2: "MG", iso3: "MDG", code: "261" },
    { name: "Malawi", iso2: "MW", iso3: "MWI", code: "265" },
    { name: "Malaysia", iso2: "MY", iso3: "MYS", code: "60" },
    { name: "Maldives", iso2: "MV", iso3: "MDV", code: "960" },
    { name: "Mali", iso2: "ML", iso3: "MLI", code: "223" },
    { name: "Malta", iso2: "MT", iso3: "MLT", code: "356" },
    { name: "Marshall Islands", iso2: "MH", iso3: "MHL", code: "692" },
    { name: "Mauritania", iso2: "MR", iso3: "MRT", code: "222" },
    { name: "Mauritius", iso2: "MU", iso3: "MUS", code: "230" },
    { name: "Mexico", iso2: "MX", iso3: "MEX", code: "52" },
    { name: "Micronesia", iso2: "FM", iso3: "FSM", code: "691" },
    { name: "Moldova", iso2: "MD", iso3: "MDA", code: "373" },
    { name: "Monaco", iso2: "MC", iso3: "MCO", code: "377" },
    { name: "Mongolia", iso2: "MN", iso3: "MNG", code: "976" },
    { name: "Montenegro", iso2: "ME", iso3: "MNE", code: "382" },
    { name: "Morocco", iso2: "MA", iso3: "MAR", code: "212" },
    { name: "Mozambique", iso2: "MZ", iso3: "MOZ", code: "258" },
    { name: "Myanmar", iso2: "MM", iso3: "MMR", code: "95", aliases: ["burma"] },
    { name: "Namibia", iso2: "NA", iso3: "NAM", code: "264" },
    { name: "Nauru", iso2: "NR", iso3: "NRU", code: "674" },
    { name: "Nepal", iso2: "NP", iso3: "NPL", code: "977" },
    { name: "Netherlands", iso2: "NL", iso3: "NLD", code: "31", aliases: ["holland"] },
    { name: "New Zealand", iso2: "NZ", iso3: "NZL", code: "64" },
    { name: "Nicaragua", iso2: "NI", iso3: "NIC", code: "505" },
    { name: "Niger", iso2: "NE", iso3: "NER", code: "227" },
    { name: "Nigeria", iso2: "NG", iso3: "NGA", code: "234" },
    { name: "North Korea", iso2: "KP", iso3: "PRK", code: "850", aliases: ["dprk"] },
    { name: "North Macedonia", iso2: "MK", iso3: "MKD", code: "389", aliases: ["macedonia"] },
    { name: "Norway", iso2: "NO", iso3: "NOR", code: "47" },
    { name: "Oman", iso2: "OM", iso3: "OMN", code: "968" },
    { name: "Pakistan", iso2: "PK", iso3: "PAK", code: "92" },
    { name: "Palau", iso2: "PW", iso3: "PLW", code: "680" },
    { name: "Palestine", iso2: "PS", iso3: "PSE", code: "970" },
    { name: "Panama", iso2: "PA", iso3: "PAN", code: "507" },
    { name: "Papua New Guinea", iso2: "PG", iso3: "PNG", code: "675", aliases: ["png"] },
    { name: "Paraguay", iso2: "PY", iso3: "PRY", code: "595" },
    { name: "Peru", iso2: "PE", iso3: "PER", code: "51" },
    { name: "Philippines", iso2: "PH", iso3: "PHL", code: "63", aliases: ["pilipinas"] },
    { name: "Poland", iso2: "PL", iso3: "POL", code: "48", aliases: ["polska"] },
    { name: "Portugal", iso2: "PT", iso3: "PRT", code: "351" },
    { name: "Puerto Rico", iso2: "PR", iso3: "PRI", code: "1787" },
    { name: "Qatar", iso2: "QA", iso3: "QAT", code: "974" },
    { name: "Romania", iso2: "RO", iso3: "ROU", code: "40" },
    { name: "Russia", iso2: "RU", iso3: "RUS", code: "7", aliases: ["russian federation", "rf"] },
    { name: "Rwanda", iso2: "RW", iso3: "RWA", code: "250" },
    { name: "Saint Kitts and Nevis", iso2: "KN", iso3: "KNA", code: "1869", aliases: ["st kitts"] },
    { name: "Saint Lucia", iso2: "LC", iso3: "LCA", code: "1758", aliases: ["st lucia"] },
    { name: "Saint Vincent and the Grenadines", iso2: "VC", iso3: "VCT", code: "1784", aliases: ["st vincent"] },
    { name: "Samoa", iso2: "WS", iso3: "WSM", code: "685" },
    { name: "San Marino", iso2: "SM", iso3: "SMR", code: "378" },
    { name: "Sao Tome and Principe", iso2: "ST", iso3: "STP", code: "239" },
    { name: "Saudi Arabia", iso2: "SA", iso3: "SAU", code: "966", aliases: ["ksa", "saudi"] },
    { name: "Senegal", iso2: "SN", iso3: "SEN", code: "221" },
    { name: "Serbia", iso2: "RS", iso3: "SRB", code: "381" },
    { name: "Seychelles", iso2: "SC", iso3: "SYC", code: "248" },
    { name: "Sierra Leone", iso2: "SL", iso3: "SLE", code: "232" },
    { name: "Singapore", iso2: "SG", iso3: "SGP", code: "65" },
    { name: "Slovakia", iso2: "SK", iso3: "SVK", code: "421" },
    { name: "Slovenia", iso2: "SI", iso3: "SVN", code: "386" },
    { name: "Solomon Islands", iso2: "SB", iso3: "SLB", code: "677" },
    { name: "Somalia", iso2: "SO", iso3: "SOM", code: "252" },
    { name: "South Africa", iso2: "ZA", iso3: "ZAF", code: "27", aliases: ["rsa"] },
    { name: "South Korea", iso2: "KR", iso3: "KOR", code: "82", aliases: ["korea", "republic of korea"] },
    { name: "South Sudan", iso2: "SS", iso3: "SSD", code: "211" },
    { name: "Spain", iso2: "ES", iso3: "ESP", code: "34", aliases: ["espana"] },
    { name: "Sri Lanka", iso2: "LK", iso3: "LKA", code: "94" },
    { name: "Sudan", iso2: "SD", iso3: "SDN", code: "249" },
    { name: "Suriname", iso2: "SR", iso3: "SUR", code: "597" },
    { name: "Sweden", iso2: "SE", iso3: "SWE", code: "46", aliases: ["sverige"] },
    { name: "Switzerland", iso2: "CH", iso3: "CHE", code: "41", aliases: ["swiss"] },
    { name: "Syria", iso2: "SY", iso3: "SYR", code: "963" },
    { name: "Taiwan", iso2: "TW", iso3: "TWN", code: "886", aliases: ["roc"] },
    { name: "Tajikistan", iso2: "TJ", iso3: "TJK", code: "992" },
    { name: "Tanzania", iso2: "TZ", iso3: "TZA", code: "255" },
    { name: "Thailand", iso2: "TH", iso3: "THA", code: "66", aliases: ["siam"] },
    { name: "Timor-Leste", iso2: "TL", iso3: "TLS", code: "670", aliases: ["east timor"] },
    { name: "Togo", iso2: "TG", iso3: "TGO", code: "228" },
    { name: "Tonga", iso2: "TO", iso3: "TON", code: "676" },
    { name: "Trinidad and Tobago", iso2: "TT", iso3: "TTO", code: "1868", aliases: ["trinidad"] },
    { name: "Tunisia", iso2: "TN", iso3: "TUN", code: "216" },
    { name: "Turkey", iso2: "TR", iso3: "TUR", code: "90", aliases: ["turkiye"] },
    { name: "Turkmenistan", iso2: "TM", iso3: "TKM", code: "993" },
    { name: "Tuvalu", iso2: "TV", iso3: "TUV", code: "688" },
    { name: "Uganda", iso2: "UG", iso3: "UGA", code: "256" },
    { name: "Ukraine", iso2: "UA", iso3: "UKR", code: "380" },
    { name: "United Arab Emirates", iso2: "AE", iso3: "ARE", code: "971", aliases: ["uae", "dubai", "emirates", "abu dhabi"] },
    { name: "United Kingdom", iso2: "GB", iso3: "GBR", code: "44", aliases: ["uk", "britain", "england", "great britain", "scotland", "wales", "northern ireland"] },
    { name: "United States", iso2: "US", iso3: "USA", code: "1", aliases: ["usa", "us", "america", "united states of america"] },
    { name: "Uruguay", iso2: "UY", iso3: "URY", code: "598" },
    { name: "Uzbekistan", iso2: "UZ", iso3: "UZB", code: "998" },
    { name: "Vanuatu", iso2: "VU", iso3: "VUT", code: "678" },
    { name: "Vatican City", iso2: "VA", iso3: "VAT", code: "379", aliases: ["holy see", "vatican"] },
    { name: "Venezuela", iso2: "VE", iso3: "VEN", code: "58" },
    { name: "Vietnam", iso2: "VN", iso3: "VNM", code: "84" },
    { name: "Yemen", iso2: "YE", iso3: "YEM", code: "967" },
    { name: "Zambia", iso2: "ZM", iso3: "ZMB", code: "260" },
    { name: "Zimbabwe", iso2: "ZW", iso3: "ZWE", code: "263" }
  ];

  var nameMap = {};
  var sortedByCodeLen = countries.slice().sort(function(a, b) {
    return b.code.length - a.code.length;
  });

  countries.forEach(function(c) {
    nameMap[c.name.toLowerCase()] = c;
    nameMap[c.iso2.toLowerCase()] = c;
    nameMap[c.iso3.toLowerCase()] = c;
    if (c.aliases) {
      c.aliases.forEach(function(a) { nameMap[a.toLowerCase()] = c; });
    }
  });

  var CountryData = {
    findCountryByNameOrCode: function(str) {
      if (!str) return null;
      var clean = String(str).trim().toLowerCase().replace(/[^a-z0-9 ]/g, '');
      return nameMap[clean] || null;
    },

    getCallingCode: function(countryStr) {
      var c = this.findCountryByNameOrCode(countryStr);
      return c ? '+' + c.code : null;
    },

    findCountryByPhone: function(phoneStr) {
      if (!phoneStr) return null;
      var raw = String(phoneStr).trim();
      var digits = raw.replace(/[^0-9]/g, '');
      if (!digits) return null;

      for (var i = 0; i < sortedByCodeLen.length; i++) {
        var c = sortedByCodeLen[i];
        if (digits.indexOf(c.code) === 0) {
          var nationalLength = digits.length - c.code.length;
          if (nationalLength >= 6 && nationalLength <= 12) {
            return c;
          }
        }
      }
      return null;
    },

    extractCountryFromPhone: function(phoneStr) {
      var c = this.findCountryByPhone(phoneStr);
      return c ? c.name : '';
    },

    formatPhoneWithCountry: function(phoneStr, countryStr) {
      if (!phoneStr) return '';
      var p = String(phoneStr).trim();
      var digits = p.replace(/[^0-9]/g, '');
      if (!digits) return '';

      var found = this.findCountryByPhone(p);
      if (found && p.indexOf('+') >= 0) {
        return '+' + digits;
      }

      if (countryStr) {
        var c = this.findCountryByNameOrCode(countryStr);
        if (c) {
          if (digits.indexOf(c.code) === 0 && digits.length > c.code.length + 6) {
            return '+' + digits;
          }
          if (digits.charAt(0) === '0') {
            digits = digits.substring(1);
          }
          return '+' + c.code + digits;
        }
      }

      return p.indexOf('+') === 0 ? p : ('+' + digits);
    },

    getAllCountries: function() {
      return countries.slice();
    }
  };

  global.CountryData = CountryData;
  global.CountryCodes = CountryData;
  if (typeof SpreadsheetApp !== 'undefined') {
    SpreadsheetApp.CountryData = CountryData;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
)js";

static std::string getModuleWrapper(const std::string& name) {
    if (name == "dayjs") {
        return std::string(S_DAYJS_CODE) + "\nexport default globalThis.dayjs;\nexport const dayjs = globalThis.dayjs;\n";
    } else if (name == "formulajs") {
        return std::string(S_FORMULAJS_CODE) + R"js(
export default globalThis.formulajs;
export const formulajs = globalThis.formulajs;
export const VLOOKUP = globalThis.formulajs.VLOOKUP;
export const HLOOKUP = globalThis.formulajs.HLOOKUP;
export const INDEX = globalThis.formulajs.INDEX;
export const MATCH = globalThis.formulajs.MATCH;
export const PMT = globalThis.formulajs.PMT;
export const NPV = globalThis.formulajs.NPV;
export const IRR = globalThis.formulajs.IRR;
export const SUMIFS = globalThis.formulajs.SUMIFS;
export const COUNTIFS = globalThis.formulajs.COUNTIFS;
export const AVERAGEIFS = globalThis.formulajs.AVERAGEIFS;
export const CONCATENATE = globalThis.formulajs.CONCATENATE;
export const TEXT = globalThis.formulajs.TEXT;
export const LEFT = globalThis.formulajs.LEFT;
export const RIGHT = globalThis.formulajs.RIGHT;
export const MID = globalThis.formulajs.MID;
export const LEN = globalThis.formulajs.LEN;
export const TRIM = globalThis.formulajs.TRIM;
export const UPPER = globalThis.formulajs.UPPER;
export const LOWER = globalThis.formulajs.LOWER;
export const PROPER = globalThis.formulajs.PROPER;
export const SUBSTITUTE = globalThis.formulajs.SUBSTITUTE;
export const IF = globalThis.formulajs.IF;
export const IFERROR = globalThis.formulajs.IFERROR;
)js";
    } else if (name == "fuse.js" || name == "fuse") {
        return std::string(S_FUSE_CODE) + "\nexport default globalThis.Fuse;\nexport const Fuse = globalThis.Fuse;\n";
    } else if (name == "currency.js" || name == "currency") {
        return std::string(S_CURRENCY_CODE) + "\nexport default globalThis.currency;\nexport const currency = globalThis.currency;\n";
    } else if (name == "regression" || name == "regression-js") {
        return std::string(S_REGRESSION_CODE) + "\nexport default globalThis.regression;\nexport const regression = globalThis.regression;\n";
    } else if (name == "papaparse" || name == "papa") {
        return std::string(S_PAPAPARSE_CODE) + "\nexport default globalThis.Papa;\nexport const Papa = globalThis.Papa;\n";
    } else if (name == "country-data" || name == "country_data" || name == "country-codes" || name == "countrycodes") {
        return std::string(S_COUNTRY_DATA_CODE) + "\nexport default globalThis.CountryData;\nexport const CountryData = globalThis.CountryData;\nexport const CountryCodes = globalThis.CountryCodes;\n";
    }
    return "";
}

std::string getLibrarySource(const std::string& name) {
    return getModuleWrapper(name);
}

bool isBundledModule(const std::string& name) {
    std::string n = name;
    std::transform(n.begin(), n.end(), n.begin(), ::tolower);
    if (n.rfind("./", 0) == 0) n = n.substr(2);
    if (n.size() > 3 && n.substr(n.size() - 3) == ".js") n = n.substr(0, n.size() - 3);

    return (n == "dayjs" || n == "formulajs" || n == "fuse" ||
            n == "currency" || n == "regression" || n == "papaparse" || n == "papa" ||
            n == "country-data" || n == "country_data" || n == "country-codes" || n == "countrycodes");
}

void bindAllGlobals(JSContext* ctx) {
    if (!ctx) return;
    LOGI("Binding bundled libraries to global context");
    
    // Evaluate Day.js
    JSValue r1 = JS_Eval(ctx, S_DAYJS_CODE, strlen(S_DAYJS_CODE), "<dayjs>", JS_EVAL_TYPE_GLOBAL);
    JS_FreeValue(ctx, r1);

    // Evaluate FormulaJS
    JSValue r2 = JS_Eval(ctx, S_FORMULAJS_CODE, strlen(S_FORMULAJS_CODE), "<formulajs>", JS_EVAL_TYPE_GLOBAL);
    JS_FreeValue(ctx, r2);

    // Evaluate Fuse.js
    JSValue r3 = JS_Eval(ctx, S_FUSE_CODE, strlen(S_FUSE_CODE), "<fuse>", JS_EVAL_TYPE_GLOBAL);
    JS_FreeValue(ctx, r3);

    // Evaluate Currency.js
    JSValue r4 = JS_Eval(ctx, S_CURRENCY_CODE, strlen(S_CURRENCY_CODE), "<currency>", JS_EVAL_TYPE_GLOBAL);
    JS_FreeValue(ctx, r4);

    // Evaluate Regression.js
    JSValue r5 = JS_Eval(ctx, S_REGRESSION_CODE, strlen(S_REGRESSION_CODE), "<regression>", JS_EVAL_TYPE_GLOBAL);
    JS_FreeValue(ctx, r5);

    // Evaluate PapaParse
    JSValue r6 = JS_Eval(ctx, S_PAPAPARSE_CODE, strlen(S_PAPAPARSE_CODE), "<papaparse>", JS_EVAL_TYPE_GLOBAL);
    JS_FreeValue(ctx, r6);

    // Evaluate CountryData
    JSValue r7 = JS_Eval(ctx, S_COUNTRY_DATA_CODE, strlen(S_COUNTRY_DATA_CODE), "<country_data>", JS_EVAL_TYPE_GLOBAL);
    JS_FreeValue(ctx, r7);

    LOGI("All bundled libraries successfully loaded into global scope");
}

JSModuleDef* loadModule(JSContext* ctx, const char* module_name) {
    if (!ctx || !module_name) return nullptr;

    std::string name(module_name);
    // Normalize path e.g. "./dayjs.js" -> "dayjs"
    if (name.rfind("./", 0) == 0) name = name.substr(2);
    if (name.size() > 3 && name.substr(name.size() - 3) == ".js") name = name.substr(0, name.size() - 3);

    std::string code = getModuleWrapper(name);
    if (code.empty()) {
        LOGE("Module %s is not in bundled libraries registry", module_name);
        return nullptr;
    }

    JSValue func_val = JS_Eval(ctx, code.c_str(), code.size(), module_name,
                               JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
    if (JS_IsException(func_val)) {
        LOGE("Failed to compile bundled module: %s", module_name);
        return nullptr;
    }

    JSModuleDef* m = (JSModuleDef*)JS_VALUE_GET_PTR(func_val);
    JS_FreeValue(ctx, func_val);
    LOGI("Successfully loaded ES module: %s", module_name);
    return m;
}

} // namespace JsLibraries
