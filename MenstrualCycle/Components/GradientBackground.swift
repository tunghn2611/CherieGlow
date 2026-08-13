//
//  GradientBackground.swift
//  MenstrualCycle
//
//  Component: Nền gradient mềm mại dùng chung.
//  Tương thích iOS 15+.
//

import SwiftUI

/// Nền gradient pastel toàn màn hình
struct GradientBackground: View {
    var colors: [Color] = Color.gradientSoft

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Badge tròn nhỏ hiển thị số
struct NotificationBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.coralRed)
                .clipShape(Circle())
        }
    }
}

/// Divider mềm mại hơn mặc định
struct SoftDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.softGray.opacity(0.5))
            .frame(height: 1)
    }
}

/// Shimmer / Skeleton loading placeholder (iOS 15 compatible)
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.softGray.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase)
            )
            .clipped()
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 300
                }
            }
    }
}

struct GradientBackground_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            GradientBackground()
            VStack(spacing: 16) {
                NotificationBadge(count: 3)
                SoftDivider()
                ShimmerView()
                    .frame(height: 40)
                    .padding(.horizontal, 40)
            }
        }
    }
}
