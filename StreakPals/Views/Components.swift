import SwiftUI

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.background.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View {
        modifier(ScreenBackground())
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(filled ? Color.white : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                filled ? AnyShapeStyle(Theme.ember) : AnyShapeStyle(Theme.card),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(filled ? Color.clear : Theme.line, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct FlameView: View {
    var streak: Int
    var lit: Bool = true
    var size: CGFloat = 64

    private var glowing: Bool { lit && streak > 0 }

    var body: some View {
        ZStack {
            Image(systemName: "flame.fill")
                .font(.system(size: size))
                .foregroundStyle(Theme.ember.opacity(glowing ? 0.38 : 0.08))
                .blur(radius: glowing ? size * 0.14 : 0)
            Image(systemName: "flame.fill")
                .font(.system(size: size))
                .foregroundStyle(
                    LinearGradient(
                        colors: glowing
                            ? [Theme.gold, Theme.ember]
                            : [Theme.muted.opacity(0.45), Theme.muted.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .symbolEffect(.pulse, options: .repeating, isActive: glowing)
            Image(systemName: "flame.fill")
                .font(.system(size: size * 0.46))
                .foregroundStyle(Color.white.opacity(glowing ? 0.92 : 0.2))
                .offset(y: size * 0.16)
        }
        .frame(width: size * 1.15, height: size * 1.3)
        .accessibilityHidden(true)
    }
}

struct SymbolBadge: View {
    var symbol: String
    var hex: String
    var size: CGFloat = 48

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(Theme.color(hex).opacity(0.16))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Theme.color(hex))
            }
            .accessibilityHidden(true)
    }
}

struct MemberAvatars: View {
    var members: [MemberState]

    var body: some View {
        HStack(spacing: -6) {
            ForEach(members.prefix(6)) { member in
                ZStack(alignment: .bottomTrailing) {
                    Text(member.pal.initial)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.color(member.pal.colorHex))
                        .frame(width: 30, height: 30)
                        .background(Theme.color(member.pal.colorHex).opacity(0.16), in: Circle())
                        .overlay(Circle().stroke(Theme.card, lineWidth: 2))
                    if member.checkedIn {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.good)
                            .background(Theme.card, in: Circle())
                            .offset(x: 2, y: 2)
                    }
                }
                .accessibilityLabel("\(member.pal.displayName), \(member.checkedIn ? "checked in" : "not yet")")
            }
            if members.count > 6 {
                Text("+\(members.count - 6)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.leading, 10)
            }
        }
    }
}

struct DayStrip: View {
    var days: [DayDot]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(day.isToday ? Theme.ink : Theme.muted)
                    Circle()
                        .fill(fill(for: day))
                        .frame(width: 14, height: 14)
                        .overlay {
                            if day.isToday {
                                Circle().stroke(Theme.ember, lineWidth: 1.5).frame(width: 20, height: 20)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let done = days.filter(\.complete).count
        return "\(done) of \(days.filter(\.started).count) recent days secured"
    }

    private func fill(for day: DayDot) -> Color {
        if !day.started { return Theme.line }
        return day.complete ? Theme.ember : Theme.ember.opacity(0.16)
    }
}

struct CelebrationCover: View {
    var habitTitle: String

    var body: some View {
        VStack(spacing: 10) {
            FlameView(streak: 3, lit: true, size: 78)
            Text("Today counts")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text(habitTitle)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
        .accessibilityElement(children: .combine)
    }
}

enum AppRoute: Hashable {
    case habit(UUID)
    case circle(UUID)
}
