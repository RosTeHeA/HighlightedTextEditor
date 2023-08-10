#if os(macOS)
/**
 *  MacEditorTextView
 *  Copyright (c) Thiago Holanda 2020
 *  https://twitter.com/tholanda
 *
 *  Modified by Kyle Nazario 2020
 *
 *  MIT license
 */

import AppKit
import Combine
import SwiftUI

// Adding to enable formatting keyboard shortcuts
public class CustomNSTextView: NSTextView {
    override public var typingAttributes: [NSAttributedString.Key : Any] {
        didSet {
            let defaultEditorFont = NSFont(name: "Lato-Regular", size: NSFont.systemFontSize + 2) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize + 2)
            super.typingAttributes = [NSAttributedString.Key.font: defaultEditorFont]
        }
    }
    override public func keyDown(with event: NSEvent) {
        guard let selectedRange = selectedRanges.first as? NSRange, selectedRange.length > 0 else {
            super.keyDown(with: event)
            return
        }

        let selectedText = (string as NSString).substring(with: selectedRange)
        var newText: String? = nil
        
        if event.modifierFlags.contains(.command) {
            switch event.characters {
            case "b":
                newText = toggleSurrounding(for: selectedText, with: "**")
            case "i":
                newText = toggleSurrounding(for: selectedText, with: "*")
            case "h":
                if event.modifierFlags.contains(.shift) {
                    newText = toggleSurrounding(for: selectedText, with: "==")
                }
            case "s":
                if event.modifierFlags.contains(.shift) {
                    newText = toggleSurrounding(for: selectedText, with: "~~")
                }
            default:
                break
            }
        }

        if let newText = newText {
            insertText(newText, replacementRange: selectedRange)
        } else {
            super.keyDown(with: event)
        }
    }

    private func toggleSurrounding(for text: String, with characters: String) -> String {
        if text.hasPrefix(characters) && text.hasSuffix(characters) {
            return String(text.dropFirst(characters.count).dropLast(characters.count))
        } else {
            return characters + text + characters
        }
    }
}




public struct HighlightedTextEditor: NSViewRepresentable, HighlightingTextEditor {
    public struct Internals {
        public let textView: SystemTextView
        public let scrollView: SystemScrollView?
    }

    @Binding var text: String {
        didSet {
            onTextChange?(text)
        }
    }

    let highlightRules: [HighlightRule]

    private(set) var onEditingChanged: OnEditingChangedCallback?
    private(set) var onCommit: OnCommitCallback?
    private(set) var onTextChange: OnTextChangeCallback?
    private(set) var onSelectionChange: OnSelectionChangeCallback?
    private(set) var introspect: IntrospectCallback?

    public init(
        text: Binding<String>,
        highlightRules: [HighlightRule]
    ) {
        _text = text
        self.highlightRules = highlightRules
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> ScrollableTextView {
        let textView = ScrollableTextView()
        textView.delegate = context.coordinator

        // Set the background color based on device light or dark mode - COMMENTED OUT - SHOULD USE .INTROSPECT IN MAIN APP
//        if NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
//                textView.textView.backgroundColor = NSColor(red: 48/255, green: 39/255, blue: 53/255, alpha: 1)
//            } else {
//                textView.textView.backgroundColor = NSColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)
//            }

        return textView
    }

    // Updated to help stop my "idle timer" refreshing this every 5 seconds and moving the cursor placement to the end. This was only happening in my "private" notes
    
    /* The issue seems to lie in how the text is replaced and how the cursor position is maintained during the update. Since the entire attributed text is being replaced, it might reset the cursor to the end of the content.
     
     The following modification might help to preserve the cursor position:

     Preserve the cursor position and selection before updating the attributed text.
     Set the attributed text.
     Restore the cursor position and selection.
     The code to achieve this could look something like the following modification to the updateNSView method:*/
              
                public func updateNSView(_ view: ScrollableTextView, context: Context) {
                context.coordinator.updatingNSView = true
                let typingAttributes = view.textView.typingAttributes
                
                // Preserve the current selected range
                let currentSelectedRanges = view.textView.selectedRanges

                let highlightedText = HighlightedTextEditor.getHighlightedText(
                    text: text,
                    highlightRules: highlightRules
                )
                
                view.attributedText = highlightedText
                runIntrospect(view)
                
                // Restore the selected range
                view.textView.selectedRanges = currentSelectedRanges
                view.textView.typingAttributes = typingAttributes
                
                context.coordinator.updatingNSView = false
                }
    
    
/* This code snippet saves the current selection before updating the attributed text and restores it afterward. It might prevent the cursor from jumping to the end of the text.
 
 It's worth noting that working with text views and maintaining the cursor position can be delicate, depending on the specific behavior of the underlying text view and the text processing being performed. The above modification is a logical approach based on the code provided, but it might require further refinement and testing to ensure that it works correctly in all scenarios.

 I recommend testing this change in your application and observing how it affects the cursor behavior in different situations, including typing, selection, and highlighting. If further issues arise, you may need to dive deeper into the interaction between the attributed text, selection, and underlying text view behavior.*/

    
    
    private func runIntrospect(_ view: ScrollableTextView) {
        guard let introspect = introspect else { return }
        let internals = Internals(textView: view.textView, scrollView: view.scrollView)
        introspect(internals)
    }
}

public extension HighlightedTextEditor {
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedTextEditor
        var selectedRanges: [NSValue] = []
        var updatingNSView = false

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

//        public func textView(
//            _ textView: NSTextView,
//            shouldChangeTextIn affectedCharRange: NSRange,
//            replacementString: String?
//        ) -> Bool {
//            return true
//        }
        
// Commented out the original (above) and replaced with following to help with auto-continuing ordered and unordered lists
        public func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            if let replacementString = replacementString, replacementString == "\n" {
                let currentLine = textView.string as NSString
                let currentLineRange = currentLine.lineRange(for: affectedCharRange)
                let currentLineContent = currentLine.substring(with: currentLineRange)

                // Unordered list logic
                let indentationPrefixes = ["- ", "* "]
                for prefix in indentationPrefixes {
                    if currentLineContent.hasPrefix(prefix) {
                        // Check if the current line consists only of the prefix and possible whitespace
                        let contentWithoutPrefix = currentLineContent.dropFirst(prefix.count)
                        if contentWithoutPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // If so, replace the entire line with a newline
                            textView.replaceCharacters(in: currentLineRange, with: "\n")
                        } else {
                            // Otherwise, add the prefix to the next line
                            textView.insertText("\n" + prefix, replacementRange: affectedCharRange)
                        }
                        return false // Returning false to indicate that we've handled the change
                    }
                }

                // Ordered list logic
                if let orderedListNumber = currentLineContent.split(separator: " ").first,
                   let number = Int(orderedListNumber.dropLast()),
                   currentLineContent.hasPrefix("\(number). ") {
                    let contentWithoutPrefix = currentLineContent.dropFirst("\(number). ".count)
                    if contentWithoutPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Replace the entire line with a newline if it's only the ordered list prefix
                        textView.replaceCharacters(in: currentLineRange, with: "\n")
                    } else {
                        // Add the next number to the next line
                        let nextNumber = number + 1
                        textView.insertText("\n\(nextNumber). ", replacementRange: affectedCharRange)
                    }
                    return false
                }
            }
            return true // Returning true to allow normal text editing behavior
        }

















        public func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            parent.text = textView.string
            parent.onEditingChanged?()
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let content = String(textView.textStorage?.string ?? "")

            parent.text = content
            selectedRanges = textView.selectedRanges
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let onSelectionChange = parent.onSelectionChange,
                  !updatingNSView,
                  let ranges = textView.selectedRanges as? [NSRange]
            else { return }
            selectedRanges = textView.selectedRanges
            DispatchQueue.main.async {
                onSelectionChange(ranges)
            }
        }

        public func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            parent.text = textView.string
            parent.onCommit?()
        }
    }
}

public extension HighlightedTextEditor {
    final class ScrollableTextView: NSView {
        weak var delegate: NSTextViewDelegate?

        var attributedText: NSAttributedString {
            didSet {
                textView.textStorage?.setAttributedString(attributedText)
            }
        }

        var selectedRanges: [NSValue] = [] {
            didSet {
                guard selectedRanges.count > 0 else {
                    return
                }

                textView.selectedRanges = selectedRanges
            }
        }

        public lazy var scrollView: NSScrollView = {
            let scrollView = NSScrollView()
            scrollView.drawsBackground = true
            scrollView.borderType = .noBorder
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalRuler = false
            scrollView.autoresizingMask = [.width, .height]
            scrollView.translatesAutoresizingMaskIntoConstraints = false

            return scrollView
        }()

        // Commented out original reference, to point this to the new custom view to enable formatting shortcuts
       //  public lazy var textView: NSTextView = {
        public lazy var textView: CustomNSTextView = {
            let contentSize = scrollView.contentSize
            let textStorage = NSTextStorage()

            let layoutManager = NSLayoutManager()
            textStorage.addLayoutManager(layoutManager)

            let textContainer = NSTextContainer(containerSize: scrollView.frame.size)
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(
                width: contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )

            layoutManager.addTextContainer(textContainer)

            let customTextView = CustomNSTextView(frame: .zero, textContainer: textContainer)
            customTextView.autoresizingMask = .width
            customTextView.backgroundColor = NSColor.textBackgroundColor
            customTextView.delegate = self.delegate
            customTextView.drawsBackground = true
            customTextView.isHorizontallyResizable = false
            customTextView.isVerticallyResizable = true
            customTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            customTextView.minSize = NSSize(width: 0, height: contentSize.height)
            
            // Set the text color based on device light or dark mode. Revert this to one line of textView.textColor - NSColor.labelColor for default
            if NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                customTextView.textColor = NSColor.white
            } else {
                customTextView.textColor = NSColor.labelColor
            }

            return customTextView
        }()


        // MARK: - Init

        init() {
            self.attributedText = NSMutableAttributedString()

            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Life cycle

        override public func viewWillDraw() {
            super.viewWillDraw()

            setupScrollViewConstraints()
            setupTextView()
        }

        func setupScrollViewConstraints() {
            scrollView.translatesAutoresizingMaskIntoConstraints = false

            addSubview(scrollView)

            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor)
            ])
        }

        func setupTextView() {
            scrollView.documentView = textView
        }
    }
}

public extension HighlightedTextEditor {
    func introspect(callback: @escaping IntrospectCallback) -> Self {
        var editor = self
        editor.introspect = callback
        return editor
    }

    func onCommit(_ callback: @escaping OnCommitCallback) -> Self {
        var editor = self
        editor.onCommit = callback
        return editor
    }

    func onEditingChanged(_ callback: @escaping OnEditingChangedCallback) -> Self {
        var editor = self
        editor.onEditingChanged = callback
        return editor
    }

    func onTextChange(_ callback: @escaping OnTextChangeCallback) -> Self {
        var editor = self
        editor.onTextChange = callback
        return editor
    }

    func onSelectionChange(_ callback: @escaping OnSelectionChangeCallback) -> Self {
        var editor = self
        editor.onSelectionChange = callback
        return editor
    }

    func onSelectionChange(_ callback: @escaping (_ selectedRange: NSRange) -> Void) -> Self {
        var editor = self
        editor.onSelectionChange = { ranges in
            guard let range = ranges.first else { return }
            callback(range)
        }
        return editor
    }
}
#endif
