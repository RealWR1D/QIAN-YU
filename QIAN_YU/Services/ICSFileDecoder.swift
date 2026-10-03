import Foundation
import CoreFoundation

/// Internal stage of the ICS import pipeline.
enum ICSFileDecoder {
    static func decodeDataToString(_ data: Data) -> String? {
        if let str = String(data: data, encoding: .utf8) { return str }

        let gb18030Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let str = String(data: data, encoding: gb18030Encoding) { return str }

        let gb2312Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)))
        if let str = String(data: data, encoding: gb2312Encoding) { return str }

        if let str = String(data: data, encoding: .utf16) { return str }
        return String(data: data, encoding: .isoLatin1)
    }

    static func unfoldICS(_ text: String) -> String {
        var res = text.replacingOccurrences(of: "\r\n ", with: "")
        res = res.replacingOccurrences(of: "\r\n\t", with: "")
        res = res.replacingOccurrences(of: "\n ", with: "")
        res = res.replacingOccurrences(of: "\n\t", with: "")
        return res
    }

    static func unescapeICSText(_ text: String) -> String {
        var str = text
        str = str.replacingOccurrences(of: "\\\\", with: "\\")
        str = str.replacingOccurrences(of: "\\;", with: ";")
        str = str.replacingOccurrences(of: "\\,", with: ",")
        str = str.replacingOccurrences(of: "\\n", with: "\n")
        str = str.replacingOccurrences(of: "\\N", with: "\n")
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseDate(_ dateStr: String, tzid: String?) -> Date? {
        let trimmed = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)

        var tz = TimeZone.current
        if trimmed.hasSuffix("Z") {
            tz = TimeZone(secondsFromGMT: 0) ?? .current
        } else if let tzid = tzid, let resolved = TimeZone(identifier: tzid) {
            tz = resolved
        }

        let formats = [
            "yyyyMMdd'T'HHmmss'Z'",
            "yyyyMMdd'T'HHmmss",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyyMMdd'T'HHmm'Z'",
            "yyyyMMdd'T'HHmm"
        ]

        for fmt in formats {
            let df = DateFormatter()
            df.dateFormat = fmt
            df.timeZone = tz
            df.locale = Locale(identifier: "en_US_POSIX")
            if let date = df.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    static func parseDurationMinutes(_ durationStr: String) -> Int? {
        let str = durationStr.uppercased()
        guard str.hasPrefix("PT") else { return nil }
        var total = 0
        let body = String(str.dropFirst(2))

        if let hRange = body.range(of: #"(\d+)H"#, options: .regularExpression) {
            let hStr = body[hRange].dropLast()
            if let h = Int(hStr) { total += h * 60 }
        }
        if let mRange = body.range(of: #"(\d+)M"#, options: .regularExpression) {
            let mStr = body[mRange].dropLast()
            if let m = Int(mStr) { total += m }
        }

        return total > 0 ? total : nil
    }
}
