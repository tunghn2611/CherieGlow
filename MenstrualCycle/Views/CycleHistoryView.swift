//
//  CycleHistoryView.swift
//  MenstrualCycle
//
//  Lịch sử chu kỳ
//

import SwiftUI

struct CycleHistoryEntry: Identifiable {
    let id = UUID()
    let cycleNumber: Int
    let startDate: String
    let endDate: String
    let duration: Int
    let status: String
    let statusColor: Color
}

struct CycleHistoryView: View {
    @Environment(\.presentationMode) var presentationMode
    let history: [CycleHistoryEntry] = [
        CycleHistoryEntry(cycleNumber: 6, startDate: "10/06", endDate: "14/06", duration: 5, status: "Đúng hạn", statusColor: .mintGreen),
        CycleHistoryEntry(cycleNumber: 5, startDate: "13/05", endDate: "17/05", duration: 5, status: "Sớm 2 ngày", statusColor: .peachYellow),
        CycleHistoryEntry(cycleNumber: 4, startDate: "15/04", endDate: "20/04", duration: 6, status: "Trễ 1 ngày", statusColor: .coralRed),
        CycleHistoryEntry(cycleNumber: 3, startDate: "16/03", endDate: "20/03", duration: 5, status: "Đúng hạn", statusColor: .mintGreen),
        CycleHistoryEntry(cycleNumber: 2, startDate: "16/02", endDate: "21/02", duration: 6, status: "Đúng hạn", statusColor: .mintGreen),
        CycleHistoryEntry(cycleNumber: 1, startDate: "18/01", endDate: "22/01", duration: 5, status: "Sớm 1 ngày", statusColor: .peachYellow)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard
                
                ForEach(history) { entry in
                    historyRow(entry)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color.softPink.ignoresSafeArea())
        .navigationTitle("Lịch sử chu kỳ")
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
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .font(.title)
                    .foregroundColor(.dustyRose)
                Text("Tổng quan chu kỳ")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                miniStat(value: "28 ngày", label: "Trung bình")
                miniStat(value: "5 ngày", label: "Kỳ kinh")
                miniStat(value: "6", label: "Chu kỳ")
            }
        }
        .pastelCard()
    }
    
    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.softPink.opacity(0.5))
        .cornerRadius(12)
    }
    
    private func historyRow(_ entry: CycleHistoryEntry) -> some View {
        HStack(spacing: 16) {
            // Cycle number circle
            ZStack {
                Circle()
                    .fill(Color.softPink)
                    .frame(width: 48, height: 48)
                Text("#\(entry.cycleNumber)")
                    .font(.subheadline.bold())
                    .foregroundColor(.dustyRose)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.startDate) - \(entry.endDate)")
                    .font(.subheadline.bold())
                    .foregroundColor(.textPrimary)
                Text("\(entry.duration) ngày")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Status badge
            Text(entry.status)
                .font(.caption2.bold())
                .foregroundColor(entry.statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(entry.statusColor.opacity(0.15))
                .cornerRadius(12)
        }
        .pastelCard()
    }
}

struct CycleHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CycleHistoryView()
        }
    }
}
