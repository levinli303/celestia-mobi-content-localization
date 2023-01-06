import Foundation

enum ParserError {
    case malformed
    case englishResourceMissing
    case directoryIteration
    case createDirectory
    case writeFile
}

extension ParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformed:
            return "Malformed file"
        case .englishResourceMissing:
            return "English resource missing"
        case .directoryIteration:
            return "Error in iterating contents of a directory"
        case .createDirectory:
            return "Error creating a directory"
        case .writeFile:
            return "Error writing to file"
        }
    }
}

public class Parser {
    public init() {}

    public func parseFile(at path: String) throws -> [String: String] {
        let stringsFilePath = (path as NSString).appendingPathComponent("Localizable.strings")
        guard let dictionary = NSDictionary(contentsOfFile: stringsFilePath) as? [String: String] else {
            throw ParserError.malformed
        }
        return dictionary
    }

    public func parseDirectory(at path: String) throws -> [String: [String: String]] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            throw ParserError.directoryIteration
        }

        var stringsByLocale = [String: [String: String]]()
        for content in contents {
            guard content.hasSuffix(".lproj") else { continue }
            let locale = String(content[content.startIndex..<content.index(content.endIndex, offsetBy: -6)])
            stringsByLocale[locale] = try parseFile(at: (path as NSString).appendingPathComponent(content))
        }

        guard let englishStrings = stringsByLocale["en"] else {
            throw ParserError.englishResourceMissing
        }

        // Remove strings that are not included in en
        var clearedStringsByLocale = [String: [String: String]]()
        for (locale, strings) in stringsByLocale {
            var newStrings = [String: String]()
            for (key, value) in strings {
                if englishStrings[key] == nil { continue }
                newStrings[key] = value
            }
            if !newStrings.isEmpty {
                clearedStringsByLocale[locale] = newStrings
            }
        }

        return clearedStringsByLocale
    }

    public func writeStrings(_ stringsByLocale: [String: [String: String]], to path: String) throws {
        guard let englishStrings = stringsByLocale["en"] else {
            throw ParserError.englishResourceMissing
        }
        for (locale, strings) in stringsByLocale {
            let directory = (path as NSString).appendingPathComponent("\(locale).lproj")
            do {
                if !FileManager.default.fileExists(atPath: directory) {
                    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                }
            } catch {
                throw ParserError.createDirectory
            }

            var singleStrings = [String]()
            let stringsPath = (directory as NSString).appendingPathComponent("Localizable.strings")
            for (key, value) in strings {
                guard let english = englishStrings[key] else {
                    throw ParserError.englishResourceMissing
                }

                let string = "// English: \(english)\n\"\(key.replacingOccurrences(of: "\"", with: "\\\""))\" = \"\(value.replacingOccurrences(of: "\"", with: "\\\""))\";"
                singleStrings.append(string)
            }
            do {
                try singleStrings.joined(separator: "\n\n").write(toFile: stringsPath, atomically: true, encoding: .utf8)
            } catch {
                throw ParserError.writeFile
            }
        }
    }

    public func convertToStringsByKeys(_ stringsByLocale: [String: [String: String]]) throws -> [String: [String: String]] {
        guard let englishStrings = stringsByLocale["en"] else {
            throw ParserError.englishResourceMissing
        }
        var results = [String: [String: String]]()
        for (key, value) in englishStrings {
            var result = ["en": value]
            for (locale, strings) in stringsByLocale {
                if let string = strings[key] {
                    result[locale] = string
                }
            }
            results[key] = result
        }
        return results
    }

    public func convertToStringsByLocales(_ stringsByKeys: [String: [String: String]]) throws -> [String: [String: String]] {
        var results = [String: [String: String]]()
        for (key, strings) in stringsByKeys {
            var hasEnglishResource = false
            for (locale, string) in strings {
                if !hasEnglishResource, locale == "en" {
                    hasEnglishResource = true
                }
                if results[locale] != nil {
                    results[locale]![key] = string
                } else {
                    results[locale] = [key: string]
                }
            }
            if !hasEnglishResource {
                throw ParserError.englishResourceMissing
            }
        }
        return results
    }
}
