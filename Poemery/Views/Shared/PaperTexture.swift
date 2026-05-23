import SwiftUI

struct PaperTexture: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<90 {
                let seed = CGFloat(index)
                let x = (seed * 37).truncatingRemainder(dividingBy: size.width)
                let y = (seed * 71).truncatingRemainder(dividingBy: size.height)
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: min(size.width, x + 9 + seed.truncatingRemainder(dividingBy: 17)), y: y + 1))
                context.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 0.45)
            }
        }
    }
}
