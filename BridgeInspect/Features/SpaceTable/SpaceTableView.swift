import SwiftUI
import SwiftData

/// The core field screen: one row per wall, one column per inspection type.
/// Read-and-tap only — no editable fields live in the grid.
struct SpaceTableView: View {
    @Environment(\.modelContext) private var context
    let space: Space

    @State private var selectedCell: InspectionCellTarget?
    @State private var selectedWall: Wall?
    @State private var showingAddWall = false
    /// Cell currently under a finger, so the press is visible before the sheet opens.
    @State private var pressedCell: String?

    private var walls: [Wall] { space.activeWalls }

    private typealias Metrics = Theme.Metrics

    var body: some View {
        Group {
            if walls.isEmpty {
                ContentUnavailableView {
                    Label("No Walls", systemImage: "rectangle.split.3x1")
                } description: {
                    Text("Add the walls in this space.")
                } actions: {
                    Button("Add Wall") { showingAddWall = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 0) {
                    summaryBar
                    Divider()
                    table
                }
            }
        }
        .navigationTitle(space.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Wall", systemImage: "plus") { showingAddWall = true }
            }
        }
        .sheet(item: $selectedCell) { target in
            InspectionDetailSheet(wall: target.wall, type: target.type)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedWall) { wall in
            WallDetailView(wall: wall)
        }
        .sheet(isPresented: $showingAddWall) {
            WallEditSheet(space: space)
                .presentationDetents([.height(220)])
        }
    }

    // MARK: - Summary

    /// Answers "am I finished here?" without reading the grid.
    private var summaryBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(walls.count) walls")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if space.isComplete {
                    Label("Complete", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Palette.done)
                } else {
                    HStack(spacing: 4) {
                        Text("\(space.outstandingCount)")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                        Text("remaining")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            CompletionBar(fraction: space.completionFraction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCorner)
                .fill(Theme.Palette.card)
                .shadow(color: .black.opacity(0.07), radius: 8, y: 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Table

    private var table: some View {
        ScrollView(.vertical, showsIndicators: true) {
            HStack(alignment: .top, spacing: 0) {
                frozenColumn
                    // Stops the column absorbing leftover width, which would
                    // otherwise push the scrolling columns off-screen.
                    .fixedSize(horizontal: true, vertical: false)

                Rectangle()
                    .fill(Theme.Palette.hairline)
                    .frame(width: 1)

                ScrollView(.horizontal, showsIndicators: false) {
                    scrollingColumns
                }
            }
        }
    }

    private var frozenColumn: some View {
        VStack(spacing: 0) {
            headerCell("WALL", width: Metrics.wallColumnWidth)
            hairline
            ForEach(Array(walls.enumerated()), id: \.element.id) { index, wall in
                Text(wall.name)
                    .font(Theme.Fonts.wallLabel)
                    // A finished wall recedes, so the eye lands on what is left.
                    .foregroundStyle(wall.isComplete ? Theme.Palette.done : .primary)
                    .frame(width: Metrics.wallColumnWidth, height: Metrics.rowHeight)
                    .background(rowBackground(index))
                    .contentShape(.rect)
                    .onTapGesture { selectedWall = wall }
                hairline
            }
        }
    }

    private var scrollingColumns: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                headerCell("NOTE", width: Metrics.noteColumnWidth)
                ForEach(InspectionType.allCases) { type in
                    headerCell(type.shortTitle, width: Metrics.cellWidth)
                }
            }
            hairline
            ForEach(Array(walls.enumerated()), id: \.element.id) { index, wall in
                HStack(spacing: 0) {
                    noteCell(for: wall)
                    ForEach(InspectionType.allCases) { type in
                        inspectionCell(wall: wall, type: type)
                    }
                }
                .background(rowBackground(index))
                hairline
            }
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Theme.Palette.hairline)
            .frame(height: 1)
    }

    /// Alternating tint so a row stays readable across the frozen/scrolling seam.
    private func rowBackground(_ index: Int) -> Color {
        index.isMultiple(of: 2) ? .clear : Theme.Palette.rowStripe
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(Theme.Fonts.columnHeader)
            .kerning(0.2)
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .frame(width: width, height: Metrics.headerHeight)
            .background(Theme.Palette.headerFill)
    }

    // MARK: - Cells

    /// Shows whether the wall carries a note. Opens the wall screen either way.
    private func noteCell(for wall: Wall) -> some View {
        let key = "note-\(wall.id)"
        return Group {
            if wall.hasNote {
                Image(systemName: "text.alignleft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.accent)
            } else {
                Circle()
                    .fill(Theme.Palette.notApplicable.opacity(0.5))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: Metrics.noteColumnWidth, height: Metrics.rowHeight)
        .background(pressHighlight(key))
        .contentShape(.rect)
        .onTapGesture { selectedWall = wall }
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
        } onPressingChanged: { pressing in
            pressedCell = pressing ? key : nil
        }
    }

    /// Tap opens the detail sheet. Long-press marks Completed without a sheet,
    /// because "mark it done" is the most common action in the field.
    private func inspectionCell(wall: Wall, type: InspectionType) -> some View {
        let key = "\(wall.id)-\(type.rawValue)"
        let status = wall.status(for: type)
        return StatusGlyph(status: status)
            .frame(width: Metrics.cellWidth, height: Metrics.rowHeight)
            .background(pressHighlight(key))
            .contentShape(.rect)
            .onTapGesture {
                selectedCell = InspectionCellTarget(wall: wall, type: type)
            }
            .onLongPressGesture(minimumDuration: 0.35) {
                toggleCompleted(wall: wall, type: type)
            } onPressingChanged: { pressing in
                pressedCell = pressing ? key : nil
            }
            .accessibilityLabel("\(wall.name), \(type.title)")
            .accessibilityValue(status.title)
    }

    private func pressHighlight(_ key: String) -> some View {
        RoundedRectangle(cornerRadius: Theme.Metrics.corner)
            .fill(Theme.Palette.pressed.opacity(pressedCell == key ? 1 : 0))
            .padding(4)
    }

    private func toggleCompleted(wall: Wall, type: InspectionType) {
        let inspection = InspectionResolver.resolve(
            wall: wall, type: type, context: context
        )
        withAnimation(.easeOut(duration: 0.15)) {
            inspection.status = (inspection.status == .completed) ? .notStarted : .completed
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

/// Identifies which cell opened the detail sheet.
struct InspectionCellTarget: Identifiable {
    let wall: Wall
    let type: InspectionType
    var id: String { "\(wall.id)-\(type.rawValue)" }
}
