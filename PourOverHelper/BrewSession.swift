import ActivityKit
import AVFoundation
import Foundation
import Observation
import UIKit

/// 沖煮計時引擎：計時、在每段開始前語音／震動提示、保持螢幕常亮、更新動態島，並記錄秤的重量曲線。
@Observable
@MainActor
final class BrewSession {
    struct WeightSample: Identifiable {
        let id = UUID()
        let second: Double
        let grams: Double
    }

    private(set) var elapsed: TimeInterval = 0
    private(set) var isRunning = false
    private(set) var stages: [PourStage] = []
    private(set) var weightSamples: [WeightSample] = []
    private(set) var recipe = BrewRecipe()

    private var startDate: Date?
    private var accumulated: TimeInterval = 0
    private var ticker: Task<Void, Never>?
    private var announcedWarnings = Set<Int>()
    private var announcedStarts = Set<Int>()
    private var announcedStops = Set<Int>()
    private let speech = AVSpeechSynthesizer()
    private let scale: ScaleManager
    private var hasActivity = false
    private var lastActivityStage: Int?

    init(scale: ScaleManager) {
        self.scale = scale
    }

    var seconds: Int { Int(elapsed) }
    var hasStarted: Bool { elapsed > 0 || isRunning }
    var currentStage: PourStage? { stages.last { Double($0.startSecond) <= elapsed } }
    var nextStage: PourStage? { stages.first { Double($0.startSecond) > elapsed } }
    var expectedWater: Double { PourPlanner.expectedWater(at: elapsed, stages: stages) }

    /// 目前是否在建議的注水時段內，以及進度（0...1）。
    var pourProgress: Double? {
        guard let stage = currentStage, stage.pourSeconds > 0 else { return nil }
        let into = elapsed - Double(stage.startSecond)
        return into < Double(stage.pourSeconds) ? into / Double(stage.pourSeconds) : nil
    }

    /// 只在還沒開始時跟著食譜更新，避免沖到一半計畫被改掉。
    func configure(with recipe: BrewRecipe) {
        guard !hasStarted else { return }
        self.recipe = recipe
        stages = PourPlanner.stages(for: recipe)
    }

    func start() {
        guard !isRunning else { return }
        if !hasStarted { prepareAudio() }
        startDate = .now
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        haptic(.start)
        if elapsed == 0, let first = stages.first, first.startSecond == 0 {
            announcedWarnings.insert(first.id)
            announcedStarts.insert(first.id)
            speak("開始，\(first.name)，注到 \(Int(first.targetWater)) 克")
        }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        updateActivity(force: true)
    }

    func pause() {
        guard let startDate else { return }
        accumulated += Date.now.timeIntervalSince(startDate)
        self.startDate = nil
        isRunning = false
        ticker?.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        updateActivity(force: true)
    }

    func reset() {
        pause()
        accumulated = 0
        elapsed = 0
        weightSamples = []
        announcedWarnings = []
        announcedStarts = []
        announcedStops = []
        lastActivityStage = nil
        speech.stopSpeaking(at: .immediate)
        endActivity()
        stages = PourPlanner.stages(for: recipe)
    }

    private func tick() {
        guard let startDate else { return }
        elapsed = accumulated + Date.now.timeIntervalSince(startDate)
        if let grams = scale.weight, scale.isConnected {
            weightSamples.append(WeightSample(second: elapsed, grams: grams))
        }
        cue()
        updateActivity(force: false)
    }

    /// 提示規則：開始前 3 秒語音預告，開始時強震動，建議注完時輕震動。
    /// 每段每種提示只觸發一次；從背景回來跳過多段時只提示最新的一段。
    private func cue() {
        if let next = nextStage, !announcedWarnings.contains(next.id),
           Double(next.startSecond) - elapsed <= 3 {
            announcedWarnings.insert(next.id)
            if next.pourSeconds > 0 {
                speak("準備\(next.name)，注到 \(Int(next.targetWater)) 克")
            } else {
                speak("準備\(next.name)")
            }
            haptic(.warning)
        }
        if let current = currentStage, !announcedStarts.contains(current.id) {
            stages.filter { $0.startSecond <= current.startSecond }.forEach {
                announcedStarts.insert($0.id); announcedWarnings.insert($0.id)
            }
            haptic(.start)
            if current.pourSeconds == 0 { speak(current.name) }
        }
        if let current = currentStage, current.pourSeconds > 0, !announcedStops.contains(current.id),
           elapsed - Double(current.startSecond) >= Double(current.pourSeconds) {
            announcedStops.insert(current.id)
            haptic(.stop)
        }
    }

    // MARK: - 語音與震動

    private enum Haptic { case start, warning, stop }

    private func haptic(_ kind: Haptic) {
        guard UserDefaults.standard.object(forKey: SettingsKey.haptics) as? Bool ?? true else { return }
        switch kind {
        case .start:   UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .stop:    UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func prepareAudio() {
        // 靜音模式下也要聽得到提示，並暫時壓低正在播放的音樂。
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers, .mixWithOthers])
    }

    private func speak(_ text: String) {
        guard UserDefaults.standard.object(forKey: SettingsKey.voice) as? Bool ?? true else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate = 0.52
        speech.speak(utterance)
    }

    // MARK: - 動態島 / 鎖定畫面

    private func activityState() -> BrewActivityAttributes.ContentState {
        let stage = currentStage ?? stages.first
        let effectiveStart = Date.now.addingTimeInterval(-elapsed)
        return .init(stageName: stage?.name ?? "準備",
                     targetWater: Int(stage?.targetWater ?? 0),
                     timerStart: effectiveStart,
                     isRunning: isRunning,
                     pausedSeconds: seconds,
                     nextStageName: nextStage?.name,
                     nextStageDate: nextStage.map { effectiveStart.addingTimeInterval(Double($0.startSecond)) })
    }

    /// 只在換段、開始、暫停時更新，不每 0.1 秒更新（系統對更新頻率有限制）。
    private func updateActivity(force: Bool) {
        guard UserDefaults.standard.object(forKey: SettingsKey.liveActivity) as? Bool ?? true,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let stageID = currentStage?.id
        guard force || stageID != lastActivityStage else { return }
        lastActivityStage = stageID
        let content = ActivityContent(state: activityState(), staleDate: nil)

        // Activity 不是 Sendable，所以不保存實例，每次在 Task 內重新取得。
        if hasActivity {
            Task {
                for activity in Activity<BrewActivityAttributes>.activities { await activity.update(content) }
            }
        } else if isRunning {
            let attributes = BrewActivityAttributes(methodTitle: recipe.method.title,
                                                    totalWater: Int(recipe.totalWater))
            hasActivity = (try? Activity.request(attributes: attributes, content: content)) != nil
        }
    }

    private func endActivity() {
        guard hasActivity else { return }
        hasActivity = false
        Task {
            for activity in Activity<BrewActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
