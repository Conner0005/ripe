import AppKit
import PomodoroCore
import SwiftUI

/// 1080×1920 Instagram Story card for the past week.
struct ShareCardView: View {
    let data: ShareCardData
    private let cream = Color(red: 1, green: 0.96, blue: 0.92)

    /// With apps on the card, the ring, bars and gaps shrink so everything fits in 1920pt.
    private var compact: Bool { !data.apps.isEmpty }

    var body: some View {
        VStack(spacing: compact ? 48 : 70) {
            HStack(spacing: 24) {
                Image(nsImage: TomatoImage.image(for: .idle)).resizable().frame(width: 96, height: 96)
                Text("Ripe").font(.system(size: 88, weight: .bold, design: .rounded))
            }
            ZStack {
                Circle().stroke(cream.opacity(0.25), lineWidth: 36)
                Circle().trim(from: 0, to: 0.75)
                    .stroke(cream, style: StrokeStyle(lineWidth: 36, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 8) {
                    Text(TimeFormat.duration(data.weekSeconds))
                        .font(.system(size: compact ? 104 : 130, weight: .bold, design: .rounded))
                    Text("focused this week").font(.system(size: 44, weight: .medium, design: .rounded))
                }
            }
            .frame(width: compact ? 460 : 620, height: compact ? 460 : 620)
            bars
            VStack(spacing: 18) {
                Text("\(data.weekSessions) \(data.weekSessions == 1 ? "session" : "sessions") this week")
                if let start = data.bestHoursStart {
                    Text("Best: \(TimeFormat.hourRange(start: start))")
                }
            }
            .font(.system(size: 52, weight: .semibold, design: .rounded))
            if compact { apps }
        }
        .foregroundStyle(cream)
        .frame(width: 1080, height: 1920)
        .background(LinearGradient(colors: [Color(red: 1, green: 0.45, blue: 0.36), Color(red: 0.80, green: 0.20, blue: 0.19)],
                                   startPoint: .top, endPoint: .bottom))
    }

    private var bars: some View {
        let maxSeconds = max(data.days.map(\.seconds).max() ?? 0, 1)
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return HStack(alignment: .bottom, spacing: 36) {
            ForEach(data.days) { day in
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(cream.opacity(day.seconds > 0 ? 1 : 0.3))
                        .frame(width: 80, height: max(16, (compact ? 220 : 300) * CGFloat(day.seconds) / CGFloat(maxSeconds)))
                    Text(symbols[Calendar.current.component(.weekday, from: day.day) - 1])
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                }
            }
        }
        .frame(height: compact ? 290 : 380, alignment: .bottom)
    }

    private var apps: some View {
        VStack(spacing: 14) {
            Text("Top apps").font(.system(size: 40, weight: .bold, design: .rounded)).opacity(0.85)
            ForEach(data.apps) { app in
                HStack {
                    Text(app.name).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 32)
                    Text(TimeFormat.duration(app.seconds)).monospacedDigit()
                }
                .font(.system(size: 44, weight: .semibold, design: .rounded))
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 32)
        .frame(width: 820)
        .background(cream.opacity(0.15), in: RoundedRectangle(cornerRadius: 36))
    }
}

@MainActor
enum ShareCard {
    /// Renders the card to a PNG in a temporary folder; nil if rendering fails.
    static func png(for data: ShareCardData, now: Date) -> URL? {
        let renderer = ImageRenderer(content: ShareCardView(data: data))
        renderer.scale = 1
        guard let cgImage = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Ripe-week-\(formatter.string(from: now)).png")
        do {
            try png.write(to: url)
            return url
        } catch {
            NSLog("Ripe: failed to write share card: \(error)")
            return nil
        }
    }
}
