//
//  StatisticsView.swift
//  MenstrualCycle
//
//  Thống kê
//

import SwiftUI

struct StatisticsView: View {
    @Environment(\.presentationMode) var presentationMode
    let monthlyLengths = [28, 27, 30, 26, 29, 28]
    let maxLen = 32.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                periodStatsCard
                barChartCard
                healthScoreCard
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color.softPink.ignoresSafeArea())
        .navigationTitle("Thống kê")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.body.bold())
                        .foregroundColor(.dustyRose)
                }
            }
        }
    }
    
    private var periodStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.dustyRose)
                Text("Chu kỳ kinh nguyệt")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statTile(value: "28 ngày", label: "Chu kỳ TB", color: .dustyRose)
                statTile(value: "5 ngày", label: "Kỳ kinh TB", color: .coralRed)
                statTile(value: "26 ngày", label: "Ngắn nhất", color: .mintGreen)
                statTile(value: "32 ngày", label: "Dài nhất", color: .lavender)
            }
        }
        .pastelCard()
    }
    
    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var barChartCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Biểu đồ 6 tháng gần nhất")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            
            HStack(alignment: .bottom, spacing: 16) {
                ForEach(0..<6, id: \.self) { i in
                    let len = monthlyLengths[i]
                    let heightRatio = Double(len) / maxLen
                    
                    VStack(spacing: 6) {
                        Text("\(len)")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                            
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: Color.gradientPink),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 24, height: CGFloat(heightRatio * 120))
                            
                        Text("T\(i+1)")
                            .font(.caption)
                            .foregroundColor(.textPrimary)
                    }
                }
            }
            .frame(height: 160, alignment: .bottom)
        }
        .pastelCard()
    }
    
    private var healthScoreCard: some View {
        VStack(spacing: 16) {
            Text("Điểm sức khỏe tổng quan")
                .font(.headline)
                .foregroundColor(.textPrimary)
                
            ZStack {
                Circle()
                    .stroke(Color.softGray.opacity(0.3), lineWidth: 16)
                    .frame(width: 140, height: 140)
                    
                Circle()
                    .trim(from: 0, to: 0.85)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.mintGreen, .deepRose]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    
                Text("85/100")
                    .font(.title2.bold())
                    .foregroundColor(.textPrimary)
            }
            .padding(.vertical, 10)
            
            Text("Sức khỏe của bạn rất tốt! 🌟")
                .font(.subheadline)
                .foregroundColor(.dustyRose)
        }
        .pastelCard()
    }
}

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StatisticsView()
        }
    }
}
