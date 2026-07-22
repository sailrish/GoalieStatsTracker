//
//  RecordStatsView.swift
//  GoalieStatsTracker
//
//  Created by Sanya Arora on 9/28/23.
//

import SwiftUI

struct RecordStatsView: View {
    
    var loadPastView: Bool = false
    var disable: Bool = false
    var popToSeasonsView: Binding<Bool>? = nil
    
    @EnvironmentObject var gameStore: GameStore

    @Environment(\.presentationMode) var presentationMode

    @State private var runningScoreColor: Color = Color.black

    @State var showSavePopup: Bool = false

    @State private var showAddSeasonPopup: Bool = false

    @State private var showChangeSeasonPopup: Bool = false

    // shotsData is a class held in @State, so mutating its seasonName alone
    // does not re-render this view; this gets toggled to force the refresh
    @State private var seasonAssignmentRefresh: Bool = false
    
    @State var pointsOn12Meter: [ShotsData.Shot] = []

    @State var isGoal: Bool = false
    @State var is8Meter: Bool = false
            
    @State var shotsData = ShotsData()

    @State var selectedGoalieName: String = ShotsData.defaultGoalieName

    // Which quarters are "lit". While recording this is the set 1...current
    // quarter; when viewing a past game it's the set of quarters whose shots are
    // currently shown (all four by default).
    @State var selectedQuarters: Set<Int> = [1]

    init() {
    }

    init(gameStore: EnvironmentObject<GameStore>, isWomensField: Bool) {
        _gameStore = gameStore
        let ongoingGame = self.gameStore.ongoingGame
        self.shotsData.womensField = isWomensField
        if ongoingGame != nil {
            self._shotsData = State(initialValue: ongoingGame!)
            self._pointsOn12Meter = State(initialValue: ongoingGame!.shots)
            self._selectedGoalieName = State(initialValue: ongoingGame!.goalies.first ?? ShotsData.defaultGoalieName)
            // Resume at the furthest quarter already reached so earlier shots
            // stay visible and recording continues forward from there.
            let maxQuarter = ongoingGame!.shots.map { $0.quarter }.max() ?? 1
            self._selectedQuarters = State(initialValue: Set(1...maxQuarter))
        }
    }
    
    init(gameStore: EnvironmentObject<GameStore>, shotsData: ShotsData, popToSeasonsView: Binding<Bool>? = nil) {
        _gameStore = gameStore
        _shotsData = State(initialValue: shotsData)
        _pointsOn12Meter = State(initialValue: shotsData.shots)
        let goalie = shotsData.goalies.first ?? ShotsData.defaultGoalieName
        _selectedGoalieName = State(initialValue: goalie)
        // A past game opens showing just the quarters this goalie actually
        // played; tapping a bubble filters any quarter in or out from there.
        _selectedQuarters = State(initialValue: Self.defaultQuarters(forGoalie: goalie, in: shotsData))
        loadPastView = true
        disable = true
        self.popToSeasonsView = popToSeasonsView
    }
    
    var body: some View {
        ZStack {
            GeometryReader { proxy in
                ScrollView(.vertical) {
                    VStack {
                        GameTitleView(parent: self, geometry: proxy)
                        GoalieSelectorView(
                            shotsData: shotsData,
                            selectedGoalieName: $selectedGoalieName,
                            disableAddingGoalie: loadPastView,
                            onGoaliesChanged: persistGoalieChange
                        )
                        VStack {
                            Group {
                                ShotSelectorsView(parent: self, geometry: proxy)
                                FieldView(parent: self, geometry: proxy)
                            }
                            .disabled(disable)

                            // The quarter selector stays interactive even when
                            // viewing a past game, where it filters shots.
                            QuarterSelectorView(
                                mode: loadPastView ? .filter : .recording,
                                selectedQuarters: $selectedQuarters
                            )

                            Group {
                                ScoringView(parent: self, geometry: proxy)
                                GameButtonsView(parent: self, geometry: proxy)
                            }
                            .disabled(disable)
                        }

                        if loadPastView == true && shotsData.seasonName.isEmpty {
                            Spacer()
                                .frame(height: proxy.size.height * 0.02)
                            Button {
                                showAddSeasonPopup = true
                            } label: {
                                Text("Add Game to Season")
                                    .foregroundStyle(.teal)
                                    .font(.system(size: proxy.size.height * 0.0225))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: proxy.size.width * 0.02)
                                            .stroke(Color.gray, lineWidth: proxy.size.height * 0.004)
                                            .frame(width: proxy.size.width * 0.45, height: proxy.size.height * 0.045)
                                    )
                            }
                            Spacer()
                                .frame(height: proxy.size.height * 0.02)
                        } else if loadPastView == true && shotsData.seasonName.isEmpty == false && gameStore.seasons.isEmpty == false {
                            Spacer()
                                .frame(height: proxy.size.height * 0.02)
                            Button {
                                showChangeSeasonPopup = true
                            } label: {
                                Text("Change Season")
                                    .foregroundStyle(.teal)
                                    .font(.system(size: proxy.size.height * 0.0225))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: proxy.size.width * 0.02)
                                            .stroke(Color.gray, lineWidth: proxy.size.height * 0.004)
                                            .frame(width: proxy.size.width * 0.45, height: proxy.size.height * 0.045)
                                    )
                            }
                            Spacer()
                                .frame(height: proxy.size.height * 0.02)
                        }
                    }
                    .navigationBarBackButtonHidden(loadPastView == false)
                }
            }
            .onChange(of: selectedGoalieName) { goalie in
                // Selecting a goalie always snaps the filter back to the
                // quarters they played. Widening it is a one-off look at that
                // goalie, not a preference that should follow them around.
                guard loadPastView else { return }
                selectedQuarters = Self.defaultQuarters(forGoalie: goalie, in: shotsData)
            }

            if showSavePopup {
                SaveGamePopupView(seasons: gameStore.seasons) { seasonName in
                    showSavePopup = false
                    shotsData.seasonName = seasonName
                    let game = shotsData
                    Task {
                        do {
                            try await gameStore.save(game: game)
                        }
                        catch {
                            fatalError(error.localizedDescription)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }

            if showAddSeasonPopup {
                SaveGamePopupView(
                    seasons: gameStore.seasons,
                    title: "Add Game to Season",
                    subtitle: "Pick a season for this game",
                    confirmButtonTitle: "Done"
                ) { seasonName in
                    showAddSeasonPopup = false
                    if seasonName.isEmpty == false {
                        addGameToSeason(seasonName)
                    }
                }
            }

            if showChangeSeasonPopup {
                SaveGamePopupView(
                    seasons: gameStore.seasons,
                    title: "Change Season",
                    subtitle: "Pick a season for this game",
                    confirmButtonTitle: "Done"
                ) { seasonName in
                    showChangeSeasonPopup = false
                    if seasonName.isEmpty == false {
                        addGameToSeason(seasonName)
                    }
                }
            }
        }
    }

    func addGameToSeason(_ seasonName: String) {
        shotsData.seasonName = seasonName
        seasonAssignmentRefresh.toggle()
        let game = shotsData
        Task {
            do {
                try await gameStore.update(game: game)
            }
            catch {
                // don't surface errors when assigning a season
            }
            popToSeasonsView?.wrappedValue = true
            presentationMode.wrappedValue.dismiss()
        }
    }

    // Upgrades a legacy (schema v0) game to normalized coordinates once the
    // field width is known, then persists the upgrade. `pointsOn12Meter` is the
    // array actually rendered, so it must be re-synced from the upgraded shots.
    func migrateLegacyCoordinatesIfNeeded() {
        guard shotsData.migrateCoordinatesIfNeeded() else { return }
        pointsOn12Meter = shotsData.shots
        let game = shotsData
        let isPastGame = loadPastView
        Task {
            do {
                if isPastGame {
                    try await gameStore.update(game: game)
                } else {
                    try await gameStore.saveOngoingGame(game: game)
                }
            }
            catch {
                // don't surface errors during a one-time upgrade
            }
        }
    }

    /// The quarters to light up when a goalie is first shown in a past game:
    /// the ones they faced shots in. A goalie with no shots has nothing to
    /// filter by, so they get all four rather than an empty field.
    private static func defaultQuarters(forGoalie goalie: String, in shotsData: ShotsData) -> Set<Int> {
        let played = shotsData.quartersPlayed(forGoalie: goalie)
        return played.isEmpty ? [1, 2, 3, 4] : played
    }

    func persistGoalieChange() {
        pointsOn12Meter = shotsData.shots
        let game = shotsData
        let isPastGame = loadPastView
        Task {
            do {
                if isPastGame {
                    try await gameStore.update(game: game)
                } else {
                    try await gameStore.saveOngoingGame(game: game)
                }
            }
            catch {
                // don't surface errors mid-game
            }
        }
    }
}

struct RecordStatsView_Previews: PreviewProvider {
    static var previews: some View {
        RecordStatsView()
    }
}
