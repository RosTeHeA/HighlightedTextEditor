//
//  Pretty-Markdown.swift
//
//
//  Original markdown.swift by Kyle Nazario on 5/26/21.
//  Pretty-Markdown.swift created by RosTeHea on 5/13/23.
//

import SwiftUI

private let inlineCodeRegex = try! NSRegularExpression(pattern: "`[^`]*`", options: [])
private let codeBlockRegex = try! NSRegularExpression(
    pattern: "(`){3}((?!\\1).)+\\1{3}",
    options: [.dotMatchesLineSeparators]
)
private let headingRegex = try! NSRegularExpression(pattern: "^#{1,6}\\s.*$", options: [.anchorsMatchLines])
private let linkOrImageRegex = try! NSRegularExpression(pattern: "!?\\[([^\\[\\]]*)\\]\\((.*?)\\)", options: [])
private let linkOrImageTagRegex = try! NSRegularExpression(pattern: "!?\\[([^\\[\\]]*)\\]\\[(.*?)\\]", options: [])
private let boldRegex = try! NSRegularExpression(pattern: "((\\*|_){2})((?!\\1).)+\\1", options: [])
private let underscoreEmphasisRegex = try! NSRegularExpression(pattern: "(?<!_)_[^_]+_(?!\\*)", options: [])
private let asteriskEmphasisRegex = try! NSRegularExpression(pattern: "(?<!\\*)(\\*)((?!\\1).)+\\1(?!\\*)", options: [])
private let boldEmphasisAsteriskRegex = try! NSRegularExpression(pattern: "(\\*){3}((?!\\1).)+\\1{3}", options: [])
private let blockquoteRegex = try! NSRegularExpression(pattern: "^>.*", options: [.anchorsMatchLines])
private let horizontalRuleRegex = try! NSRegularExpression(pattern: "\n\n(-{3}|\\*{3})\n", options: [])
private let unorderedListRegex = try! NSRegularExpression(pattern: "^(\\-|\\*)\\s", options: [.anchorsMatchLines])
private let orderedListRegex = try! NSRegularExpression(pattern: "^\\d*\\.\\s", options: [.anchorsMatchLines])
private let buttonRegex = try! NSRegularExpression(pattern: "<\\s*button[^>]*>(.*?)<\\s*/\\s*button>", options: [])
private let strikethroughRegex = try! NSRegularExpression(pattern: "(~)((?!\\1).)+\\1", options: [])
private let tagRegex = try! NSRegularExpression(pattern: "^\\[([^\\[\\]]*)\\]:", options: [.anchorsMatchLines])
private let footnoteRegex = try! NSRegularExpression(pattern: "\\[\\^(.*?)\\]", options: [])
// courtesy https://www.regular-expressions.info/examples.html
private let htmlRegex = try! NSRegularExpression(
    pattern: "<([A-Z][A-Z0-9]*)\\b[^>]*>(.*?)</\\1>",
    options: [.dotMatchesLineSeparators, .caseInsensitive]
)

// Code to help style the syntax, as well as highlighting
private let asteriskSyntaxRegex = try! NSRegularExpression(pattern: "\\*", options: [])
private let headingSyntaxRegex = try! NSRegularExpression(pattern: "^#{1,6}", options: [.anchorsMatchLines])
private let italicOpenSyntaxRegex = try! NSRegularExpression(pattern: "(?<=^|[^*])\\*(?=[^*])", options: [])
private let italicCloseSyntaxRegex = try! NSRegularExpression(pattern: "(?<=[^*])\\*(?=[^*]|$)", options: [])
private let highlightedTextRegex = try! NSRegularExpression(pattern: "==[^=]+==", options: [])
private let highlightedSyntaxRegex = try! NSRegularExpression(pattern: "(?<=\\s)==|==(?=\\s)", options: [])



//To help with dark and light modes
extension NSColor {
    static func backgroundColor() -> NSColor {
        let isDarkMode = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDarkMode ? NSColor.darkGray : NSColor.cyan
    }
    
    static func foregroundColor() -> NSColor {
        let isDarkMode = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDarkMode ? NSColor.black : NSColor.labelColor
    }
}


#if os(macOS)
let codeFont = NSFont(name: "Avenir Next", size: NSFont.systemFontSize) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
let headingTraits: NSFontDescriptor.SymbolicTraits = [.bold, .expanded]
let boldTraits: NSFontDescriptor.SymbolicTraits = [.bold]
let emphasisTraits: NSFontDescriptor.SymbolicTraits = [.italic]
let boldEmphasisTraits: NSFontDescriptor.SymbolicTraits = [.bold, .italic]
let secondaryBackground = NSColor.backgroundColor()
let textHighlight = NSColor(calibratedRed: 179/255, green: 239/255, blue: 255/255, alpha: 1)
let lighterColor = NSColor.lightGray
let textColor = NSColor.foregroundColor()
#else
let codeFont = UIFont(name: "Avenir Next", size: UIFont.systemFontSize) ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
let headingTraits: UIFontDescriptor.SymbolicTraits = [.traitBold, .traitExpanded]
let boldTraits: UIFontDescriptor.SymbolicTraits = [.traitBold]
let emphasisTraits: UIFontDescriptor.SymbolicTraits = [.traitItalic]
let boldEmphasisTraits: UIFontDescriptor.SymbolicTraits = [.traitBold, .traitItalic]
let secondaryBackground = UIColor.secondarySystemBackground
let textHighlight = UIColor(red: 179/255, green: 239/255, blue: 255/255, alpha: 1)
let lighterColor = UIColor.lightGray
let textColor = UIColor.label
#endif


private let maxHeadingLevel = 6

public extension Sequence where Iterator.Element == HighlightRule {
    static var prettyMarkdown: [HighlightRule] {
        [
            HighlightRule(pattern: inlineCodeRegex, formattingRule: TextFormattingRule(key: .font, value: codeFont)),
            HighlightRule(pattern: codeBlockRegex, formattingRule: TextFormattingRule(key: .font, value: codeFont)),
            HighlightRule(pattern: headingRegex, formattingRules: [
                TextFormattingRule(fontTraits: headingTraits),
                TextFormattingRule(key: .kern, value: 0.5),
                TextFormattingRule(key: .font, calculateValue: { content, _ in
                    let uncappedLevel = content.prefix(while: { char in char == "#" }).count
                    let level = Swift.min(maxHeadingLevel, uncappedLevel)
                    let fontSize = CGFloat(maxHeadingLevel - level) * 2.5 + defaultEditorFont.pointSize
                    return SystemFontAlias(descriptor: defaultEditorFont.fontDescriptor, size: fontSize) as Any
                })
            ]),
            HighlightRule(
                pattern: linkOrImageRegex,
                formattingRule: TextFormattingRule(key: .underlineStyle, value: NSUnderlineStyle.single.rawValue)
            ),
            HighlightRule(
                pattern: linkOrImageTagRegex,
                formattingRule: TextFormattingRule(key: .underlineStyle, value: NSUnderlineStyle.single.rawValue)
            ),
            HighlightRule(pattern: boldRegex, formattingRule: TextFormattingRule(fontTraits: boldTraits)),
            HighlightRule(
                pattern: asteriskEmphasisRegex,
                formattingRule: TextFormattingRule(fontTraits: emphasisTraits)
            ),
            HighlightRule(
                pattern: underscoreEmphasisRegex,
                formattingRule: TextFormattingRule(fontTraits: emphasisTraits)
            ),
            HighlightRule(
                pattern: boldEmphasisAsteriskRegex,
                formattingRule: TextFormattingRule(fontTraits: boldEmphasisTraits)
            ),
            HighlightRule(
                pattern: blockquoteRegex,
                formattingRule: TextFormattingRule(key: .backgroundColor, value: secondaryBackground)
            ),
            HighlightRule(
                pattern: horizontalRuleRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: lighterColor)
            ),
            HighlightRule(
                pattern: unorderedListRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: lighterColor)
            ),
            HighlightRule(
                pattern: orderedListRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: lighterColor)
            ),
            HighlightRule(
                pattern: buttonRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: lighterColor)
            ),
            HighlightRule(pattern: strikethroughRegex, formattingRules: [
                TextFormattingRule(key: .strikethroughStyle, value: NSUnderlineStyle.single.rawValue),
                TextFormattingRule(key: .strikethroughColor, value: textColor)
            ]),
            HighlightRule(
                pattern: tagRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: lighterColor)
            ),
            HighlightRule(
                pattern: footnoteRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: lighterColor)
            ),
            HighlightRule(pattern: htmlRegex, formattingRules: [
                TextFormattingRule(key: .font, value: codeFont),
                TextFormattingRule(key: .foregroundColor, value: lighterColor)
            ]),
            HighlightRule(pattern: asteriskSyntaxRegex, formattingRule: TextFormattingRule(key: .foregroundColor, value: lighterColor)),
            HighlightRule(pattern: headingSyntaxRegex, formattingRules: [
                TextFormattingRule(key: .foregroundColor, value: lighterColor),
                TextFormattingRule(key: .font, value: SystemFontAlias.systemFont(ofSize: 14))
            ]),
            HighlightRule(pattern: italicOpenSyntaxRegex, formattingRule: TextFormattingRule(key: .foregroundColor, value: lighterColor)),
            HighlightRule(pattern: italicCloseSyntaxRegex, formattingRule: TextFormattingRule(key: .foregroundColor, value: lighterColor)),
            HighlightRule(pattern: highlightedTextRegex, formattingRules: [
                TextFormattingRule(key: .backgroundColor, value: textHighlight),
                TextFormattingRule(key: .foregroundColor, value: textColor)
            ]),
            HighlightRule(pattern: highlightedSyntaxRegex, formattingRule: TextFormattingRule(key: .foregroundColor, value: lighterColor)),
        ]
    }
}
