#if false
import SwiftUI

struct LivingPoemScene: View {
    let lineIndex: Int
    let isSpeaking: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 30)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                drawBackground(in: &context, size: size)
                drawMoon(in: &context, size: size, time: time)
                drawStudy(in: &context, size: size)
                drawPaperGrain(in: &context, size: size, time: time)
                drawWind(in: &context, size: size, time: time)
                drawPearls(in: &context, size: size, time: time)
                drawVines(in: &context, size: size, time: time)
            }
            .overlay {
                RadialGradient(
                    colors: [
                        PoemeryTheme.paper.opacity(0.08 + Double(lineIndex) * 0.01),
                        .clear,
                        .black.opacity(0.28)
                    ],
                    center: .topTrailing,
                    startRadius: 40,
                    endRadius: 620
                )
                .blendMode(.screen)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.24), .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 320)
                .allowsHitTesting(false)
            }
        }
        .background(PoemeryTheme.deepInk)
    }

    private func drawBackground(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        let moods: [[Color]] = [
            [
                Color(red: 0.10, green: 0.11, blue: 0.12),
                Color(red: 0.25, green: 0.23, blue: 0.21),
                Color(red: 0.09, green: 0.10, blue: 0.10)
            ],
            [
                Color(red: 0.09, green: 0.11, blue: 0.12),
                Color(red: 0.20, green: 0.25, blue: 0.25),
                Color(red: 0.08, green: 0.09, blue: 0.10)
            ],
            [
                Color(red: 0.10, green: 0.10, blue: 0.11),
                Color(red: 0.24, green: 0.22, blue: 0.17),
                Color(red: 0.08, green: 0.08, blue: 0.09)
            ],
            [
                Color(red: 0.08, green: 0.10, blue: 0.09),
                Color(red: 0.16, green: 0.22, blue: 0.17),
                Color(red: 0.06, green: 0.07, blue: 0.07)
            ]
        ]

        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: moods[safe: lineIndex] ?? moods[0]),
                startPoint: CGPoint(x: size.width * 0.15, y: 0),
                endPoint: CGPoint(x: size.width * 0.78, y: size.height)
            )
        )
    }

    private func drawMoon(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let pulse = CGFloat((sin(time * 0.42) + 1) / 2)
        let radius = size.width * (0.19 + CGFloat(lineIndex) * 0.008)
        let center = CGPoint(x: size.width * 0.78, y: size.height * 0.18)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.addFilter(.blur(radius: 18 + pulse * 5))
        context.fill(
            Path(ellipseIn: rect.insetBy(dx: -14, dy: -14)),
            with: .color(PoemeryTheme.moon.opacity(0.10 + Double(lineIndex) * 0.025))
        )
        context.addFilter(.blur(radius: 0))
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    PoemeryTheme.paper.opacity(0.28),
                    PoemeryTheme.moon.opacity(0.12),
                    .clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private func drawStudy(in context: inout GraphicsContext, size: CGSize) {
        let deskY = size.height * 0.72
        var desk = Path()
        desk.move(to: CGPoint(x: -20, y: deskY))
        desk.addLine(to: CGPoint(x: size.width + 20, y: deskY + 24))
        desk.addLine(to: CGPoint(x: size.width + 20, y: size.height + 40))
        desk.addLine(to: CGPoint(x: -20, y: size.height + 40))
        desk.closeSubpath()
        context.fill(desk, with: .color(Color.black.opacity(0.26)))

        let window = CGRect(x: size.width * 0.12, y: size.height * 0.15, width: size.width * 0.38, height: size.height * 0.29)
        var frame = Path(roundedRect: window, cornerRadius: 4)
        context.stroke(frame, with: .color(PoemeryTheme.paper.opacity(0.12)), lineWidth: 1)
        frame = Path()
        frame.move(to: CGPoint(x: window.midX, y: window.minY))
        frame.addLine(to: CGPoint(x: window.midX, y: window.maxY))
        frame.move(to: CGPoint(x: window.minX, y: window.midY))
        frame.addLine(to: CGPoint(x: window.maxX, y: window.midY))
        context.stroke(frame, with: .color(PoemeryTheme.paper.opacity(0.08)), lineWidth: 1)

        let paperRect = CGRect(x: size.width * 0.30, y: deskY - 58, width: size.width * 0.40, height: 88)
        context.fill(
            Path(roundedRect: paperRect, cornerRadius: 10),
            with: .color(PoemeryTheme.paper.opacity(0.11))
        )
        context.stroke(
            Path(roundedRect: paperRect, cornerRadius: 10),
            with: .color(PoemeryTheme.paper.opacity(0.14)),
            lineWidth: 0.7
        )
    }

    private func drawPaperGrain(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let grainCount = 80
        for index in 0..<grainCount {
            let seed = CGFloat(index)
            let x = ((seed * 47).truncatingRemainder(dividingBy: size.width + 80)) - 40
            let y = ((seed * 83).truncatingRemainder(dividingBy: size.height + 80)) - 40
            let drift = reduceMotion ? 0 : CGFloat(sin(time * 0.2 + Double(index))) * 1.4
            let rect = CGRect(x: x + drift, y: y, width: 1.2, height: 1.2)
            context.fill(Path(ellipseIn: rect), with: .color(PoemeryTheme.paper.opacity(0.035)))
        }
    }

    private func drawWind(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let intensity = lineIndex == 1 ? 1.0 : (lineIndex > 1 ? 0.68 : 0.34)
        let lines = 9
        for index in 0..<lines {
            var path = Path()
            let baseY = size.height * (0.21 + CGFloat(index) * 0.055)
            let phase = reduceMotion ? 0 : CGFloat(time * (0.16 + Double(index) * 0.01))
            let offset = CGFloat(sin(phase + Double(index))) * size.width * 0.035
            path.move(to: CGPoint(x: -40 + offset, y: baseY))
            path.addCurve(
                to: CGPoint(x: size.width + 30, y: baseY + CGFloat(index % 3 - 1) * 18),
                control1: CGPoint(x: size.width * 0.28, y: baseY - 42 + offset * 0.2),
                control2: CGPoint(x: size.width * 0.66, y: baseY + 34 - offset * 0.2)
            )
            context.stroke(
                path,
                with: .color(PoemeryTheme.paper.opacity(0.025 + 0.05 * intensity)),
                style: StrokeStyle(lineWidth: CGFloat(0.7 + intensity), lineCap: .round)
            )
        }
    }

    private func drawPearls(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard lineIndex >= 2 else { return }

        let count = lineIndex == 2 ? 9 : 5
        for index in 0..<count {
            let phase = reduceMotion ? 0 : CGFloat(sin(time * 0.55 + Double(index) * 1.7))
            let x = size.width * (0.34 + CGFloat(index % 3) * 0.13) + phase * 5
            let y = size.height * (0.64 + CGFloat(index / 3) * 0.035) - phase * 6
            let radius = CGFloat(3 + index % 3)
            context.addFilter(.blur(radius: 4))
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                with: .color(PoemeryTheme.pearl.opacity(lineIndex == 2 ? 0.30 : 0.16))
            )
            context.addFilter(.blur(radius: 0))
        }
    }

    private func drawVines(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let intensity = lineIndex == 3 ? 1.0 : 0.28
        for index in 0..<7 {
            var path = Path()
            let startX = size.width * (0.08 + CGFloat(index) * 0.14)
            let baseY = size.height + 24
            let sway = reduceMotion ? 0 : CGFloat(sin(time * 0.28 + Double(index))) * 10
            path.move(to: CGPoint(x: startX, y: baseY))
            path.addCurve(
                to: CGPoint(x: startX + sway + CGFloat(index % 2 == 0 ? 28 : -24), y: size.height * (0.70 - CGFloat(index % 3) * 0.025)),
                control1: CGPoint(x: startX - 18, y: size.height * 0.91),
                control2: CGPoint(x: startX + 44 + sway, y: size.height * 0.82)
            )
            context.stroke(
                path,
                with: .color(PoemeryTheme.vine.opacity(0.10 + 0.22 * intensity)),
                style: StrokeStyle(lineWidth: 1.2 + intensity * 1.4, lineCap: .round)
            )
        }
    }
}
#endif

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
