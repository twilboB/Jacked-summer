import SwiftUI

// Reusable surfaces and small components built on Apple's real glass materials.
// Everything degrades to solid warm surfaces when Reduce Transparency is on.
//
// VERIFY against the iOS 27 SDK: `.glassEffect(in:)`, `GlassEffectContainer`,
// `.glassEffectID(_:in:)`, and the `.glass` / `.glassProminent` button styles.
// API shapes have shifted across betas.

let kCardRadius: CGFloat = 20

/// A content card. Glass by default; a solid warm surface under Reduce Transparency.
struct GlassCard<Content: View>: View {
    @Environment(\.prefersSolidSurfaces) private var solid
    var cornerRadius: CGFloat = kCardRadius
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(GlassSurface(cornerRadius: cornerRadius, solid: solid))
    }
}

/// Applies glass or a solid fallback to any surface.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = kCardRadius
    var solid: Bool

    func body(content: Content) -> some View {
        if solid {
            content.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(hex: 0x241F18))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                    )
            )
        } else {
            content.glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

/// A small section title above a group of cards.
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A compact stat: big condensed number over a caption.
struct StatChip: View {
    let value: String
    let caption: String
    var tint: Color? = nil
    var systemImage: String? = nil

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(tint ?? .secondary)
                }
                Text(value)
                    .font(.stat(26))
                    .foregroundStyle(tint ?? .primary)
                    .contentTransition(.numericText())
            }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A molten-filled progress bar, optionally marking a threshold (e.g. the cut line).
struct MoltenProgressBar: View {
    /// 0...1 fill fraction.
    var fraction: Double
    /// Optional 0...1 position of a reference marker.
    var markerFraction: Double? = nil
    var height: CGFloat = 10
    var beat: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.10))
                Capsule()
                    .fill(Palette.moltenGradient)
                    .frame(width: max(0, min(1, fraction)) * w)
                    .shadow(color: beat ? Palette.molten.opacity(0.6) : .clear, radius: 6)
                if let markerFraction {
                    Rectangle()
                        .fill(.white.opacity(0.7))
                        .frame(width: 2)
                        .offset(x: max(0, min(1, markerFraction)) * w - 1)
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

/// Streak flame: molten and glowing when alive, cold grey at zero.
struct FlameView: View {
    var alive: Bool
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: size))
            .foregroundStyle(alive ? AnyShapeStyle(Palette.moltenGradient) : AnyShapeStyle(Color.secondary))
            .shadow(color: alive ? Palette.molten.opacity(0.7) : .clear, radius: 12)
            .symbolEffect(.pulse, options: alive ? .repeating : .nonRepeating, value: alive)
            .accessibilityLabel(alive ? "Streak alive" : "Streak cold")
    }
}

/// A rolling seven-day dot strip; filled dots mark logged days.
struct DotStrip: View {
    /// Oldest-to-newest booleans, length 7.
    let filled: [Bool]
    /// Weekday initials aligned to `filled`.
    var labels: [String] = []

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(filled.enumerated()), id: \.offset) { idx, on in
                VStack(spacing: 4) {
                    Circle()
                        .fill(on ? AnyShapeStyle(Palette.moltenGradient) : AnyShapeStyle(Color.white.opacity(0.12)))
                        .frame(width: 14, height: 14)
                    if idx < labels.count {
                        Text(labels[idx])
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// A small confidence tag for AI-sourced entries.
struct ConfidenceTag: View {
    let confidence: String
    var body: some View {
        let c = Confidence(rawValue: confidence)
        let color: Color = {
            switch c {
            case .high: return Palette.green
            case .med: return Palette.gold
            case .low: return Palette.red
            case .none: return .secondary
            }
        }()
        Text((c?.label ?? confidence).uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel("Confidence \(c?.label ?? confidence)")
    }
}

/// Small icon marking the source of a food entry.
struct SourceMarker: View {
    let source: FoodSource
    var body: some View {
        Image(systemName: source.symbolName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Source \(source.rawValue)")
    }
}

/// A delta with an up/down arrow so colour is never the only signal.
struct DeltaLabel: View {
    /// Positive = improvement (green up), negative = regression (faint down).
    let value: Double
    var unit: String = ""
    var goodWhenPositive: Bool = true

    var body: some View {
        let positive = value >= 0
        let good = positive == goodWhenPositive
        let magnitude = abs(value)
        let text = magnitude >= 100
            ? String(format: "%.0f", magnitude)
            : String(format: "%.1f", magnitude)
        HStack(spacing: 2) {
            Image(systemName: positive ? "arrow.up" : "arrow.down")
                .font(.caption2.weight(.bold))
            Text("\(text)\(unit)")
                .font(.statSmall(15))
        }
        .foregroundStyle(value == 0 ? AnyShapeStyle(Color.secondary)
                         : good ? AnyShapeStyle(Palette.green) : AnyShapeStyle(Color.secondary))
        .accessibilityLabel("\(positive ? "up" : "down") \(text)\(unit)")
    }
}
