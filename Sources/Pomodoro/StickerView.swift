import AppKit
import PomodoroCore
import SwiftUI

/// Text colour for the transparent sticker; each has a shadow that keeps it readable on photos.
enum StickerStyle: CaseIterable, Identifiable {
    case white, black, red

    var id: Self { self }

    var title: String {
        switch self {
        case .white: "White"
        case .black: "Black"
        case .red: "Ripe Red"
        }
    }

    var color: Color {
        switch self {
        case .white: .white
        case .black: .black
        case .red: Color(red: 0.90, green: 0.25, blue: 0.22)
        }
    }

    var shadow: Color {
        switch self {
        case .white, .red: .black.opacity(0.35)
        case .black: .white.opacity(0.5)
        }
    }
}

/// Compact week stats on a transparent background, to paste over a photo in an Instagram Story.
struct StickerView: View {
    let data: ShareCardData
    let style: StickerStyle

    var body: some View {
        VStack(spacing: 36) {
            HStack(spacing: 16) {
                Image(nsImage: TomatoImage.image(for: .idle)).resizable().frame(width: 64, height: 64)
                Text("Ripe").font(.system(size: 60, weight: .bold, design: .rounded))
            }
            VStack(spacing: 0) {
                Text(TimeFormat.duration(data.weekSeconds))
                    .font(.system(size: 150, weight: .bold, design: .rounded))
                Text("focused this week").font(.system(size: 44, weight: .medium, design: .rounded))
            }
            bars
            Text(summaryLine).font(.system(size: 44, weight: .semibold, design: .rounded))
            if !data.apps.isEmpty {
                VStack(spacing: 10) {
                    ForEach(data.apps) { app in
                        HStack {
                            Text(app.name).lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 32)
                            Text(TimeFormat.duration(app.seconds)).monospacedDigit()
                        }
                    }
                }
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .frame(width: 640)
            }
        }
        .foregroundStyle(style.color)
        .shadow(color: style.shadow, radius: 10)
        .padding(40) // room for the shadow so it isn't clipped
        .frame(width: 900)
    }

    private var summaryLine: String {
        let sessions = "\(data.weekSessions) \(data.weekSessions == 1 ? "session" : "sessions")"
        guard let start = data.bestHoursStart else { return sessions }
        return "\(sessions) · Best \(TimeFormat.hourRange(start: start))"
    }

    private var bars: some View {
        let maxSeconds = max(data.days.map(\.seconds).max() ?? 0, 1)
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return HStack(alignment: .bottom, spacing: 28) {
            ForEach(data.days) { day in
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(style.color.opacity(day.seconds > 0 ? 1 : 0.35))
                        .frame(width: 60, height: max(12, 180 * CGFloat(day.seconds) / CGFloat(maxSeconds)))
                    Text(symbols[Calendar.current.component(.weekday, from: day.day) - 1])
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                }
            }
        }
        .frame(height: 240, alignment: .bottom)
    }
}

extension ShareCard {
    /// Puts the sticker on the clipboard as a transparent PNG (TIFF too, for Mac apps); false if rendering fails.
    /// With Universal Clipboard it can be pasted straight into an Instagram Story on an iPhone.
    static func copySticker(for data: ShareCardData, style: StickerStyle) -> Bool {
        let renderer = ImageRenderer(content: StickerView(data: data, style: style))
        renderer.scale = 1
        guard let cgImage = renderer.cgImage else { return false }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let png = rep.representation(using: .png, properties: [:]), let tiff = rep.tiffRepresentation else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        return pasteboard.setData(png, forType: .png) && pasteboard.setData(tiff, forType: .tiff)
    }
}
