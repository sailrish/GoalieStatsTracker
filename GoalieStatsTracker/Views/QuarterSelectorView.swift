//
//  QuarterSelectorView.swift
//  GoalieStatsTracker
//

import SwiftUI

struct QuarterSelectorView: View {

    enum Mode {
        // Live game: the quarter only ever moves forward and lights every
        // quarter up to the current one.
        case recording
        // Viewing a past game: each bubble freely toggles that quarter's shots
        // in and out of the display.
        case filter
    }

    let mode: Mode
    @Binding var selectedQuarters: Set<Int>

    private let quarters = [1, 2, 3, 4]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(quarters, id: \.self) { quarter in
                Button(
                    action: { handleTap(quarter) },
                    label: {
                        Text("Quarter \(quarter)")
                            .padding(8)
                            .foregroundColor(.black)
                            .font(.system(size: 14))
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 10,
                                    style: .continuous
                                )
                                .fill(.teal)
                                .opacity(selectedQuarters.contains(quarter) ? 0.75 : 0.1)
                            )
                    }
                )
            }
        }
    }

    private func handleTap(_ quarter: Int) {
        switch mode {
        case .recording:
            // The game can't go back to an earlier quarter, so advancing lights
            // this quarter and every earlier one; tapping the current or an
            // earlier bubble does nothing.
            let current = selectedQuarters.max() ?? 0
            guard quarter > current else { return }
            withAnimation {
                selectedQuarters = Set(1...quarter)
            }
        case .filter:
            withAnimation {
                if selectedQuarters.contains(quarter) {
                    selectedQuarters.remove(quarter)
                } else {
                    selectedQuarters.insert(quarter)
                }
            }
        }
    }
}

#Preview {
    QuarterSelectorView(mode: .recording, selectedQuarters: .constant([1]))
}
