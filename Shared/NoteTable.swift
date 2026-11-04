import SwiftUI

/// A note whose lines are split by tabs or pipes is a table. Markdown tables
/// pasted from a chat ("| a | b |" plus a "|---|---|" rule) are accepted too.
struct NoteTable {
    var title: String?
    var header: [String]
    var rows: [[String]]
    var columns: Int { header.count }

    static func parse(_ text: String) -> NoteTable? {
        let rawLines = text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { !$0.allSatisfy { "|-: ".contains($0) } }   // markdown rule line
        var lines = rawLines
        guard lines.count >= 2 else { return nil }
        func sep(_ l: String) -> Bool { l.contains("\t") || l.contains("|") }
        // a plain first line above the rows is the table's title
        var title: String?
        if !sep(lines[0]), lines.count >= 3, lines.dropFirst().allSatisfy(sep) {
            title = lines.removeFirst().trimmingCharacters(in: CharacterSet(charactersIn: ":：- "))
        }
        let useTabs = lines.allSatisfy { $0.contains("\t") }
        let usePipes = !useTabs && lines.allSatisfy { $0.contains("|") }
        guard useTabs || usePipes else { return nil }
        var cells: [[String]] = lines.map { line in
            var l = line
            if usePipes {
                if l.hasPrefix("|") { l.removeFirst() }
                if l.hasSuffix("|") { l.removeLast() }
            }
            return l.split(separator: useTabs ? "\t" : "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        let width = cells.map(\.count).max() ?? 0
        guard width >= 2 else { return nil }
        cells = cells.map { $0 + Array(repeating: "", count: width - $0.count) }
        return NoteTable(title: title, header: cells[0], rows: Array(cells.dropFirst()))
    }

    /// Short label for the Dynamic Island pill: first data row, first two cells.
    var compactLabel: String {
        (rows.first ?? header).prefix(2).joined(separator: " ")
    }
}

/// Renders a NoteTable like an Apple Notes table: every cell boxed with a
/// hairline, header bold. Sized to fit the 160pt Lock Screen card cap:
/// up to 5 rows at caption size, up to 8 at caption2, then "+N more".
struct NoteTableView: View {
    let table: NoteTable
    var maxRows = 8
    var tint: Color = .primary

    private var shown: [[String]] { Array(table.rows.prefix(maxRows)) }
    private var small: Bool { shown.count > 5 }
    private var line: Color { tint.opacity(0.28) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let t = table.title, !t.isEmpty {
                Text(t).font(.caption.weight(.semibold)).foregroundStyle(tint).lineLimit(1)
            }
            grid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var grid: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(Array(table.header.enumerated()), id: \.offset) { _, h in
                    cell(h, bold: true)
                }
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, c in
                        cell(c, bold: false)
                    }
                }
            }
            if table.rows.count > maxRows {
                GridRow {
                    Text("+\(table.rows.count - maxRows) more in the app")
                        .font(.caption2).foregroundStyle(tint.opacity(0.6))
                        .padding(.horizontal, 6).padding(.top, 3)
                        .gridCellColumns(table.columns)
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(line, lineWidth: 0.6))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func cell(_ text: String, bold: Bool) -> some View {
        Text(text)
            .font(small ? .caption2 : .caption)
            .fontWeight(bold ? .bold : .regular)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(bold ? tint.opacity(0.85) : tint)
            .padding(.horizontal, 6)
            .padding(.vertical, small ? 1.5 : 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bold ? tint.opacity(0.07) : .clear)
            .overlay(Rectangle().stroke(line, lineWidth: 0.6))
    }
}
