//
//  URL.swift
//  Regex courtesy of https://urlregex.com
//
//  Created by Kyle Nazario on 10/25/20.
//

import Foundation
import SwiftUI

private let urlRegexPattern =
    "((https?://)?((www\\.)?\\w+\\.)+(com|org|net|edu|gov|mil|biz|info|io|mobi|name|ly|tv|co|uk|ca|de|jp|fr|au|us|ru|ch|it|nl|se|no|es|in|ae|ar|at|be|bg|br|bz|cl|cn|cz|dk|fi|gr|hk|hu|id|ie|il|in|ir|is|kr|kz|lt|lu|lv|ma|mx|my|nz|ph|pk|pl|pt|ro|sa|sg|si|sk|th|tr|ua|vn|za)(\\b|/)(/\\w+\\.\\w+)*(\\?\\w+(&\\w+)*)?)"


private let _urlRegex = try! NSRegularExpression(pattern: urlRegexPattern, options: [])

public extension Sequence where Iterator.Element == HighlightRule {
    static var url: [HighlightRule] {
        [
            HighlightRule(pattern: _urlRegex, formattingRules: [
                TextFormattingRule(key: .underlineStyle, value: NSUnderlineStyle.single.rawValue),
                TextFormattingRule(key: .link) { urlString, _ in
                    URL(string: urlString) as Any
                }
            ])
        ]
    }
}

public extension HighlightRule {
    static var urlRegex: NSRegularExpression {
        _urlRegex
    }
}
