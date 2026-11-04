import SwiftUI

/// A note whose lines are split by tabs or pipes is a table. Markdown tables
/// pasted from a chat ("| a | b |" plus a "|---|---|" rule) are accepted too.
struct NoteTable {
    var header: [String]
    var rows: [[String]]
    var columns: Int { header.count }

    static func parse(_ text: String) -> NoteTable? {
        let lines = text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { !$0.allSatisfy { "|-: ".contains($0) } }   // markdown rule line
        guard lines.count >= 2 else { return nil }
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
        return NoteTable(header: cells[0], rows: Array(cells.dropFirst()))
    }

    /// Short label for the Dynamic Island pill: first data row, first two cells.
    var compactLabel: String {
        (rows.first ?? header).prefix(2).joined(separator: " ")
    }
}

/// Renders a NoteTable as an aligned grid that fits a Lock Screen card.
struct NoteTableView: View {
    let table: NoteTable
    var maxRows = 8
    var tint: Color = .primary

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 1) {
            GridRow {
                ForEach(Array(table.header.enumerated()), id: \.offset) { _, h in
                    Text(h).font(.caption2.weight(.bold)).foregroundStyle(tint.opacity(0.7)).lineLimit(1)
                }
            }
            ForEach(Array(table.rows.prefix(maxRows).enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, c in
                        Text(c).font(.caption.monospacedDigit()).foregroundStyle(tint).lineLimit(1)
                    }
                }
            }
            if table.rows.count > maxRows {
                GridRow {
                    Text("+\(table.rows.count - maxRows) more").font(.caption2).foregroundStyle(tint.opacity(0.6))
                        .gridCellColumns(table.columns)
                }
            }
        }
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
