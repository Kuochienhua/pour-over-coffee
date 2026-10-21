import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BrewActivityBundle: WidgetBundle {
    var body: some Widget {
        BrewLiveActivity()
    }
}

struct BrewLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BrewActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding()
                .activityBackgroundTint(Color.brown.opacity(0.15))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.methodTitle, systemImage: "cup.and.saucer.fill")
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state)
                        .font(.title3.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StageSummary(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "cup.and.saucer.fill")
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "cup.and.saucer.fill")
            }
        }
    }
}

/// 計時中交給系統自己往上數（不需要 App 每秒更新）；暫停時顯示固定秒數。
private struct ElapsedText: View {
    let state: BrewActivityAttributes.ContentState

    var body: some View {
        if state.isRunning {
            Text(state.timerStart, style: .timer)
        } else {
            Text(String(format: "%d:%02d", state.pausedSeconds / 60, state.pausedSeconds % 60))
        }
    }
}

private struct StageSummary: View {
    let state: BrewActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(state.stageName)・注到 \(state.targetWater) g")
                .font(.headline)
            if let next = state.nextStageName, let date = state.nextStageDate, state.isRunning {
                HStack(spacing: 4) {
                    Text("下一段「\(next)」")
                    Text(date, style: .timer).monospacedDigit()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else if !state.isRunning {
                Text("已暫停").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(context.attributes.methodTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StageSummary(state: context.state)
            }
            Spacer()
            ElapsedText(state: context.state)
                .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }
}
