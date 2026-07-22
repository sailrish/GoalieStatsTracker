//
//  SeasonsView.swift
//  GoalieStatsTracker
//

import Foundation
import SwiftUI

struct SeasonsView: View {

    struct GoalieSeasonStat {
        let goalieName: String
        let savePercentage: Int
    }

    @EnvironmentObject var gameStore: GameStore

    @State private var showNewSeasonPopup = false
    @State private var newSeasonName = ""

    var body: some View {
        ZStack {
            GeometryReader { proxy in
            List {
                Button {
                    newSeasonName = ""
                    showNewSeasonPopup = true
                } label: {
                    Label("Create New Season", systemImage: "plus.circle.fill")
                        .font(.system(size: proxy.size.height * 0.02, weight: .semibold))
                        .foregroundStyle(.teal)
                }
                ForEach(Array(gameStore.seasons.enumerated()), id: \.offset) { _, season in
                    SeasonRow(
                        season: season,
                        stats: savePercentages(forSeason: season),
                        nameFontSize: proxy.size.height * 0.02,
                        statFontSize: proxy.size.height * 0.0175,
                        statSpacing: proxy.size.height * 0.0075
                    )
                }
                .onDelete { indexes in
                    Task {
                        await deleteSeason(offsets: indexes)
                    }
                }
                .onMove { source, destination in
                    gameStore.moveSeason(fromOffsets: source, toOffset: destination)
                }
                if gameStore.storage.contains(where: { $0.seasonName.isEmpty }) {
                    NavigationLink {
                        LoadPastView(seasonName: "")
                    } label: {
                        Text("No Season")
                            .font(.system(size: proxy.size.height * 0.02, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Seasons")
            .toolbar {
                EditButton()
            }
            }

            if showNewSeasonPopup {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        VStack(spacing: 8) {
                            Text("Create New Season")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            Text("Enter a name for the new season")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            TextField("Season name", text: $newSeasonName)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(.teal)
                                .padding(.top, 8)
                        }
                        .padding()

                        Divider()

                        HStack(spacing: 0) {
                            Button(role: .cancel) {
                                showNewSeasonPopup = false
                            } label: {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            Divider()
                                .frame(height: 44)
                            Button {
                                let name = newSeasonName.trimmingCharacters(in: .whitespaces)
                                showNewSeasonPopup = false
                                if name.isEmpty == false {
                                    gameStore.addSeason(named: name)
                                }
                            } label: {
                                Text("Create")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    .frame(maxWidth: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(UIColor.systemBackground))
                    )
                    .padding(40)
                }
            }
        }
        .task {
            do {
                let _ = try await gameStore.load()
            }
            catch {}
        }
    }

    func savePercentages(forSeason season: String) -> [GoalieSeasonStat] {
        let seasonGames = gameStore.storage.filter { $0.seasonName == season }

        var goalieNames: [String] = []
        for game in seasonGames {
            for shot in game.shots {
                if goalieNames.contains(shot.goalieName) == false {
                    goalieNames.append(shot.goalieName)
                }
            }
        }

        // The season figure is every save divided by every shot faced, not the
        // mean of the per-game percentages: a 2-shot game shouldn't weigh as
        // much as a 40-shot one.
        return goalieNames.compactMap { goalie in
            let shots = seasonGames.reduce(0) { $0 + $1.totalShots(forGoalie: goalie) }
            guard shots > 0 else { return nil }
            let saves = seasonGames.reduce(0) { $0 + $1.saves(forGoalie: goalie) }
            let percentage = Int((Float(saves) / Float(shots)) * 100)
            return GoalieSeasonStat(goalieName: goalie, savePercentage: percentage)
        }
    }

    func deleteSeason(offsets: IndexSet) async {
        do {
            let seasonsToDelete = offsets.map { gameStore.seasons[$0] }
            for season in seasonsToDelete {
                try await gameStore.removeSeason(named: season)
            }
        }
        catch {
            fatalError(error.localizedDescription)
        }
    }
}

private struct SeasonRow: View {
    let season: String
    let stats: [SeasonsView.GoalieSeasonStat]
    let nameFontSize: CGFloat
    let statFontSize: CGFloat
    let statSpacing: CGFloat

    @EnvironmentObject var gameStore: GameStore
    @Environment(\.editMode) private var editMode
    @State private var draftName = ""
    // The name this season had when editing began, so a rename that ends on a
    // blank or duplicate name can be rolled back to it.
    @State private var originalName = ""
    @State private var showDuplicateAlert = false

    private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

    var body: some View {
        Group {
            if isEditing {
                TextField("Season name", text: $draftName)
                    .font(.system(size: nameFontSize, weight: .semibold))
                    .foregroundColor(.teal)
                    .submitLabel(.done)
            } else {
                NavigationLink {
                    LoadPastView(seasonName: season)
                } label: {
                    VStack(alignment: .leading) {
                        Text(season)
                            .font(.system(size: nameFontSize, weight: .semibold))
                        ForEach(stats, id: \.goalieName) { stat in
                            Spacer()
                                .frame(height: statSpacing)
                            Text("\(stat.goalieName): \(stat.savePercentage)%")
                                .font(.system(size: statFontSize, weight: .light))
                        }
                    }
                }
            }
        }
        .onAppear { beginEditing() }
        .onChange(of: isEditing) { editing in
            if editing {
                beginEditing()
            } else {
                finishEditing()
            }
        }
        // Apply each keystroke immediately (locally) so the new name shows up as
        // it's typed. Blank/duplicate values are ignored here and handled on end.
        .onChange(of: draftName) { newValue in
            gameStore.renameSeasonLocally(from: season, to: newValue)
        }
        .alert("Already a season with that name", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private func beginEditing() {
        originalName = season
        draftName = season
    }

    private func finishEditing() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        if trimmed == season {
            // Last keystroke applied cleanly. Push to iCloud only if it changed.
            if season != originalName {
                gameStore.syncRenamedSeason(named: season)
            }
            return
        }
        // The final name never applied: it's blank or a duplicate. Warn on a
        // duplicate, then roll any partially-applied renaming back to the start.
        if trimmed.isEmpty == false, gameStore.seasonExists(trimmed, excluding: season) {
            showDuplicateAlert = true
        }
        if season != originalName {
            gameStore.renameSeasonLocally(from: season, to: originalName)
        }
        draftName = originalName
    }
}

struct SeasonsView_Previews: PreviewProvider {
    static var previews: some View {
        SeasonsView()
    }
}
