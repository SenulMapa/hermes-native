import SwiftUI

/// Renders assistant/user message text as a sequence of blocks: fenced code
/// blocks get a monospace glass card with copy; everything else is rendered as
/// inline Markdown (bold/italic/links/inline-code). A pragmatic GFM baseline —
/// tables/mermaid/KaTeX come in later polish (PRD §3.2).
public struct MarkdownMessage: View {
    private let blocks: [Block]

    public init(_ content: String) {
        self.blocks = MarkdownMessage.parse(content)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            ForEach(blocks) { block in
                switch block.kind {
                case .text:
                    Text(MarkdownMessage.attributed(block.content))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                case .code(let language):
                    CodeBlockView(code: block.content, language: language)
                }
            }
        }
    }

    // MARK: - Parsing

    struct Block: Identifiable {
        enum Kind: Equatable { case text; case code(language: String?) }
        let id = UUID()
        let kind: Kind
        let content: String
    }

    static func parse(_ content: String) -> [Block] {
        var blocks: [Block] = []
        var lines = content.components(separatedBy: "\n")
        var textBuffer: [String] = []

        func flushText() {
            let joined = textBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { blocks.append(Block(kind: .text, content: joined)) }
            textBuffer.removeAll()
        }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                flushText()
                let fence = line.trimmingCharacters(in: .whitespaces)
                let lang = String(fence.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i]); i += 1
                }
                blocks.append(Block(kind: .code(language: lang.isEmpty ? nil : lang),
                                    content: codeLines.joined(separator: "\n")))
            } else {
                textBuffer.append(line)
            }
            i += 1
        }
        flushText()
        return blocks
    }

    static func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

/// Monospace, syntax-neutral code block with a language chip and copy button.
public struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var copied = false

    public init(code: String, language: String?) {
        self.code = code
        self.language = language
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language?.uppercased() ?? "CODE")
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }
                } label: {
                    Label(copied ? "Copied" : "Copy",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .tint(.secondary)
            }
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(Tokens.Space.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: Tokens.Radius.control))
    }
}
