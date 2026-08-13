//
//  CycleViewModel.swift
//  MenstrualCycle
//
//  ViewModel quản lý đa đối tượng và logic chu kỳ.
//  Kết nối SQLite qua CycleRepository.
//  Tương thích iOS 15+.
//

import SwiftUI
import Combine

class CycleViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var profiles: [CycleProfile] = []
    @Published var selectedProfileIndex: Int = 0
    @Published var prediction: CyclePrediction?
    @Published var aiMessage: String = ""
    @Published var comparisonStatus: PeriodComparisonStatus = .notSet
    @Published var actualPeriodDate: Date = Date()
    @Published var showAddProfile: Bool = false
    @Published var showActualDatePicker: Bool = false
    @Published var userName: String = "Bạn"
    @Published var isLoadingAI: Bool = false
    @Published var cycleDates: [CycleDateEntry] = []

    // MARK: - Repository
    private let cycleRepo = CycleRepository()
    private var userId: String = ""

    // MARK: - Computed Properties

    var currentProfile: CycleProfile? {
        guard !profiles.isEmpty, selectedProfileIndex < profiles.count else { return nil }
        return profiles[selectedProfileIndex]
    }

    // MARK: - Init (không load data, chờ setUserId)

    init() {}

    // MARK: - Set User & Load Data

    func setUserId(_ id: String, userName: String = "Bạn") {
        self.userId = id
        self.userName = userName
        loadProfiles()
    }

    func loadProfiles() {
        guard !userId.isEmpty else { return }

        // Bước 1: Load ngay từ SQLite local (hiển thị dữ liệu offline trước)
        loadProfilesFromLocal()

        // Bước 2: Đồng bộ từ backend (nếu có kết nối)
        APIService.shared.getDashboard { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    if response.success, let data = response.data {
                        // 1. Đồng bộ danh sách profiles từ server xuống local
                        if let serverProfiles = data.profiles {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            
                            // Xoá các profile mặc định rỗng ở local để tránh rác giao diện
                            let localProfiles = self.cycleRepo.fetchProfiles(for: self.userId)
                            for localProfile in localProfiles {
                                if localProfile.name.isEmpty && localProfile.lastPeriodStart == nil {
                                    let _ = self.cycleRepo.deleteProfile(id: localProfile.id.uuidString)
                                }
                            }
                            
                            for sProfile in serverProfiles {
                                let lastStart = sProfile.last_period_start != nil ? formatter.date(from: sProfile.last_period_start!) : nil
                                let relationship = ProfileRelationship.fromServerAndName(serverVal: sProfile.relationship ?? "self", name: sProfile.profile_name)
                                
                                let serverProfile = CycleProfile(
                                    id: UUID(uuidString: sProfile.id) ?? UUID(),
                                    name: sProfile.profile_name,
                                    relationship: relationship,
                                    lastPeriodStart: lastStart,
                                    periodDuration: sProfile.avg_period_duration,
                                    cycleLength: sProfile.avg_cycle_length
                                )
                                
                                // Kiểm tra xem server profile đã có trong local chưa
                                let localExists = self.profiles.contains { $0.id == serverProfile.id }
                                if !localExists {
                                    let _ = self.cycleRepo.insertProfile(profile: serverProfile, userId: self.userId)
                                } else {
                                    let _ = self.cycleRepo.updateProfile(serverProfile)
                                }
                                
                                // Tải lịch sử logs của profile này từ server
                                self.syncLogsFromServer(profileId: sProfile.id)
                            }
                            
                            // Re-load list from local to refresh UI
                            self.profiles = self.cycleRepo.fetchProfiles(for: self.userId)
                        }
                        
                        // 2. Đồng bộ các profiles cục bộ chưa được đưa lên server lên
                        self.syncLocalProfilesToServer()

                        // Parse dự đoán từ server cho profile hiện tại
                        if let currentDay = data.currentDayOfCycle {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            let nextPeriod = data.nextPeriodDate != nil ? formatter.date(from: data.nextPeriodDate!) : Date()
                            let nextOvulation = data.nextOvulationDate != nil ? formatter.date(from: data.nextOvulationDate!) : Date()

                            var phase: CyclePhase = .unknown
                            if let sPhase = data.currentPhase {
                                switch sPhase {
                                case "Menstruation", "Kỳ kinh":   phase = .menstruation
                                case "Follicular", "Nang trứng":  phase = .follicular
                                case "Ovulation", "Rụng trứng":   phase = .ovulation
                                case "Luteal", "Hoàng thể":      phase = .luteal
                                case "Pre-menstrual", "Tiền kinh": phase = .preMenstrual
                                default:                          phase = .unknown
                                }
                            }

                            let probPercent = Int((data.conceptionProbability ?? 0.0) * 100)

                            self.prediction = CyclePrediction(
                                currentDay: currentDay,
                                currentPhase: phase,
                                nextPeriodDate: nextPeriod ?? Date(),
                                ovulationDate: nextOvulation ?? Date(),
                                daysUntilNextPeriod: data.daysUntilNextPeriod ?? 0,
                                daysUntilOvulation: max(0, Calendar.current.dateComponents([.day], from: Date(), to: nextOvulation ?? Date()).day ?? 0),
                                fertilityPercent: probPercent,
                                ovulationPercent: phase == .ovulation ? 90 : 10,
                                safePercent: max(0, 100 - probPercent),
                                cycleProgress: Double(currentDay) / Double(data.profile?.avg_cycle_length ?? 28)
                            )

                            self.generateAIMessage()
                        } else {
                            // Server không có prediction → tính toán local
                            self.recalculate()
                        }
                    }
                case .failure(let error):
                    print("⚠️ [CYCLE-SYNC] Không thể tải dữ liệu từ server: \(error.localizedDescription)")
                    // Đã load từ local ở bước 1 rồi, không cần làm gì thêm
                }
            }
        }
    }

    private func loadProfilesFromLocal() {
        let uId = userId
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fetched = self.cycleRepo.fetchProfiles(for: uId)
            
            DispatchQueue.main.async {
                self.profiles = fetched
                if self.profiles.isEmpty {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let defaultProfile = CycleProfile(
                            name: "",
                            relationship: .myself,
                            lastPeriodStart: nil,
                            periodDuration: 5,
                            cycleLength: 28
                        )
                        if self.cycleRepo.insertProfile(profile: defaultProfile, userId: uId) {
                            let refetched = self.cycleRepo.fetchProfiles(for: uId)
                            DispatchQueue.main.async {
                                self.profiles = refetched
                                self.selectedProfileIndex = 0
                                self.loadCycleDates()
                                self.recalculate()
                            }
                        }
                    }
                } else {
                    self.selectedProfileIndex = 0
                    self.loadCycleDates()
                    self.recalculate()
                }
            }
        }
    }

    func loadCycleDates() {
        guard let profile = currentProfile else {
            cycleDates = []
            return
        }
        let profileId = profile.id.uuidString
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fetched = self.cycleRepo.fetchCycleDates(profileId: profileId)
            DispatchQueue.main.async {
                self.cycleDates = fetched
            }
        }
    }

    // MARK: - Actions

    func recalculate() {
        guard let profile = currentProfile,
              let lastStart = profile.lastPeriodStart else {
            prediction = nil
            aiMessage = "Hãy nhập ngày bắt đầu kỳ kinh gần nhất để bắt đầu theo dõi 🌸"
            return
        }

        let result = CycleCalculator.predict(
            lastPeriodStart: lastStart,
            periodDuration: profile.periodDuration,
            cycleLength: profile.cycleLength
        )
        prediction = result
        generateAIMessage()
    }

    func selectProfile(at index: Int) {
        guard index < profiles.count else { return }
        selectedProfileIndex = index
        comparisonStatus = .notSet
        loadCycleDates()
        recalculate()
    }

    func updateLastPeriodStart(_ date: Date) {
        guard selectedProfileIndex < profiles.count else { return }
        profiles[selectedProfileIndex].lastPeriodStart = date
        let _ = cycleRepo.updateProfile(profiles[selectedProfileIndex])
        recalculate()
        syncProfileToServer(profiles[selectedProfileIndex])
    }

    func updatePeriodDuration(_ days: Int) {
        guard selectedProfileIndex < profiles.count else { return }
        let clamped = max(2, min(7, days))
        profiles[selectedProfileIndex].periodDuration = clamped
        let _ = cycleRepo.updateProfile(profiles[selectedProfileIndex])
        recalculate()
        syncProfileToServer(profiles[selectedProfileIndex])
    }

    func updateCycleLength(_ days: Int) {
        guard selectedProfileIndex < profiles.count else { return }
        let clamped = max(21, min(40, days))
        profiles[selectedProfileIndex].cycleLength = clamped
        let _ = cycleRepo.updateProfile(profiles[selectedProfileIndex])
        recalculate()
        syncProfileToServer(profiles[selectedProfileIndex])
    }

    func addProfile(_ profile: CycleProfile) {
        guard !userId.isEmpty else { return }
        if cycleRepo.insertProfile(profile: profile, userId: userId) {
            profiles = cycleRepo.fetchProfiles(for: userId)
            // Chọn profile vừa thêm (profile mới nhất ở đầu danh sách vì ORDER BY created_at DESC)
            selectedProfileIndex = 0
            loadCycleDates()
            recalculate()
            
            // Đồng bộ lên server
            syncNewProfileToServer(profile)
        }
    }

    func deleteProfile(at index: Int) {
        guard profiles.count > 1, index < profiles.count else { return }
        let profileId = profiles[index].id.uuidString
        if cycleRepo.deleteProfile(id: profileId) {
            profiles = cycleRepo.fetchProfiles(for: userId)
            if selectedProfileIndex >= profiles.count {
                selectedProfileIndex = profiles.count - 1
            }
            loadCycleDates()
            recalculate()
        }
    }

    // MARK: - Cycle Dates (Lưu ngày chu kỳ)

    func saveCycleDate(startDate: Date, endDate: Date? = nil, notes: String = "") {
        guard let profile = currentProfile, !userId.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startStr = formatter.string(from: startDate)
        let endStr = endDate != nil ? formatter.string(from: endDate!) : nil

        // 1. Lưu offline cục bộ
        let entry = CycleDateEntry(
            profileId: profile.id.uuidString,
            startDate: startDate,
            endDate: endDate,
            notes: notes
        )
        if cycleRepo.insertCycleDate(entry: entry, userId: userId) {
            loadCycleDates()
        }

        // 2. Gửi đồng bộ lên backend
        APIService.shared.logPeriod(
            id: entry.id.uuidString,
            profileId: profile.id.uuidString,
            startDate: startStr,
            endDate: endStr,
            intensity: "medium"
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    if response.success {
                        print("✅ [CYCLE-LOG] Logged period to backend successfully")
                        self.loadProfiles()
                    }
                case .failure(let error):
                    print("⚠️ [CYCLE-LOG] Failed to sync log to server: \(error.localizedDescription)")
                }
            }
        }
    }

    func deleteCycleDate(at index: Int) {
        guard index < cycleDates.count else { return }
        let id = cycleDates[index].id.uuidString
        if cycleRepo.deleteCycleDate(id: id) {
            loadCycleDates()
        }
    }

    func compareActualDate() {
        // Nếu chưa có prediction từ server, tính toán local trước
        if prediction == nil {
            recalculate()
        }
        
        guard let pred = prediction else {
            comparisonStatus = .notSet
            return
        }
        comparisonStatus = CycleCalculator.comparePeriod(
            actualDate: actualPeriodDate,
            predictedDate: pred.nextPeriodDate
        )
    }

    // MARK: - AI Message

    func generateAIMessage() {
        guard let profile = currentProfile,
              let pred = prediction else {
            aiMessage = ""
            return
        }
        isLoadingAI = true
        AINotificationService.shared.generateAINotification(
            userName: userName,
            profileName: profile.name,
            relationship: profile.relationship,
            phase: pred.currentPhase,
            daysUntilNextPeriod: pred.daysUntilNextPeriod
        ) { [weak self] message in
            self?.aiMessage = message
            self?.isLoadingAI = false
        }
    }

    // MARK: - Server Sync Helpers
    
    private func syncLogsFromServer(profileId: String) {
        APIService.shared.getCycleHistory(profileId: profileId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    if response.success, let data = response.data {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        
                        let localLogs = self.cycleRepo.fetchCycleDates(profileId: profileId)
                        
                        for sLog in data.logs {
                            guard let startDate = formatter.date(from: sLog.period_start_date) else { continue }
                            let endDate = sLog.period_end_date != nil ? formatter.date(from: sLog.period_end_date!) : nil
                            
                            let serverEntry = CycleDateEntry(
                                id: UUID(uuidString: sLog.id) ?? UUID(),
                                profileId: sLog.profile_id,
                                startDate: startDate,
                                endDate: endDate,
                                notes: sLog.notes ?? ""
                            )
                            
                            // Nếu chưa tồn tại cục bộ, lưu vào SQLite
                            let localExists = localLogs.contains { $0.id == serverEntry.id }
                            if !localExists {
                                let _ = self.cycleRepo.insertCycleDate(entry: serverEntry, userId: self.userId)
                            }
                        }
                        
                        // Cập nhật lại UI sau khi đồng bộ xong các date logs
                        if let current = self.currentProfile, current.id.uuidString == profileId {
                            self.loadCycleDates()
                            self.recalculate()
                        }
                    }
                case .failure(let error):
                    print("⚠️ [CYCLE-SYNC] Failed to fetch history logs from server: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func syncLocalProfilesToServer() {
        // Lấy danh sách profile local hiện tại
        let localProfiles = cycleRepo.fetchProfiles(for: userId)
        
        // Gọi getDashboard để lấy danh sách mới nhất từ server
        APIService.shared.getDashboard { result in
            switch result {
            case .success(let response):
                if response.success, let data = response.data, let serverProfiles = data.profiles {
                    let serverIds = Set(serverProfiles.map { $0.id.lowercased() })
                    
                    for lProfile in localProfiles {
                        let localIdStr = lProfile.id.uuidString.lowercased()
                        // Nếu profile cục bộ chưa có trên server, gửi đồng bộ lên
                        if !serverIds.contains(localIdStr) {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            let lastStartStr = lProfile.lastPeriodStart != nil ? formatter.string(from: lProfile.lastPeriodStart!) : ""
                            
                            APIService.shared.createCycleProfile(
                                id: lProfile.id.uuidString,
                                name: lProfile.name.isEmpty ? lProfile.relationship.rawValue : lProfile.name,
                                relationship: lProfile.relationship.serverValue,
                                length: lProfile.cycleLength,
                                duration: lProfile.periodDuration,
                                lastStart: lastStartStr
                            ) { syncResult in
                                switch syncResult {
                                case .success(let res):
                                    if res.success {
                                        print("✅ [CYCLE-SYNC] Offline profile synced successfully: \(lProfile.name)")
                                        // Sau khi đồng bộ profile, đồng bộ cả các date log thuộc về profile này lên
                                        self.syncLocalLogsToServer(profileId: lProfile.id.uuidString)
                                    }
                                case .failure(let err):
                                    print("⚠️ [CYCLE-SYNC] Failed to sync offline profile: \(err.localizedDescription)")
                                }
                            }
                        } else {
                            // Nếu đã có, đồng bộ các logs cục bộ chưa có trên server
                            self.syncLocalLogsToServer(profileId: lProfile.id.uuidString)
                        }
                    }
                }
            case .failure(_):
                break
            }
        }
    }
    
    private func syncLocalLogsToServer(profileId: String) {
        let localLogs = cycleRepo.fetchCycleDates(profileId: profileId)
        
        APIService.shared.getCycleHistory(profileId: profileId) { result in
            switch result {
            case .success(let response):
                if response.success, let data = response.data {
                    let serverLogIds = Set(data.logs.map { $0.id.lowercased() })
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    
                    for lLog in localLogs {
                        let logIdStr = lLog.id.uuidString.lowercased()
                        // Nếu log cục bộ chưa được đẩy lên server
                        if !serverLogIds.contains(logIdStr) {
                            let startStr = formatter.string(from: lLog.startDate)
                            let endStr = lLog.endDate != nil ? formatter.string(from: lLog.endDate!) : nil
                            
                            APIService.shared.logPeriod(
                                id: lLog.id.uuidString,
                                profileId: profileId,
                                startDate: startStr,
                                endDate: endStr,
                                intensity: "medium"
                            ) { syncRes in
                                if case .success(let res) = syncRes, res.success {
                                    print("✅ [CYCLE-SYNC] Local log \(lLog.id.uuidString) synced to server")
                                }
                            }
                        }
                    }
                }
            case .failure(_):
                break
            }
        }
    }

    private func syncProfileToServer(_ profile: CycleProfile) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let lastStartStr = profile.lastPeriodStart != nil ? formatter.string(from: profile.lastPeriodStart!) : ""

        APIService.shared.updateCycleProfile(
            id: profile.id.uuidString,
            name: profile.name.isEmpty ? profile.relationship.rawValue : profile.name,
            relationship: profile.relationship.serverValue,
            length: profile.cycleLength,
            duration: profile.periodDuration,
            lastStart: lastStartStr
        ) { result in
            switch result {
            case .success(let response):
                if response.success {
                    print("✅ [CYCLE-SYNC] Profile settings updated on server")
                }
            case .failure(let error):
                print("⚠️ [CYCLE-SYNC] Failed to update profile settings: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncNewProfileToServer(_ profile: CycleProfile) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let lastStartStr = profile.lastPeriodStart != nil ? formatter.string(from: profile.lastPeriodStart!) : ""

        APIService.shared.createCycleProfile(
            id: profile.id.uuidString,
            name: profile.name.isEmpty ? profile.relationship.rawValue : profile.name,
            relationship: profile.relationship.serverValue,
            length: profile.cycleLength,
            duration: profile.periodDuration,
            lastStart: lastStartStr
        ) { result in
            switch result {
            case .success(let response):
                if response.success {
                    print("✅ [CYCLE-SYNC] New profile synced to server")
                }
            case .failure(let error):
                print("⚠️ [CYCLE-SYNC] Failed to sync new profile: \(error.localizedDescription)")
            }
        }
    }

    func deleteCurrentProfile() {
        guard profiles.count > 1 else { return }
        let index = selectedProfileIndex
        let profileId = profiles[index].id.uuidString
        
        // Gửi lệnh xoá lên server
        APIService.shared.deleteCycleProfile(id: profileId) { _ in }
        
        // Xoá cục bộ trong SQLite
        if cycleRepo.deleteProfile(id: profileId) {
            profiles = cycleRepo.fetchProfiles(for: userId)
            selectedProfileIndex = 0
            loadCycleDates()
            recalculate()
        }
    }

    // MARK: - Helpers

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
}

// MARK: - ProfileRelationship Server Mapping
extension ProfileRelationship {
    var serverValue: String {
        switch self {
        case .myself:   return "self"
        case .lover, .wife: return "partner"
        case .daughter: return "daughter"
        default:        return "other"
        }
    }
    
    static func fromServerValue(_ val: String) -> ProfileRelationship {
        switch val {
        case "self":    return .myself
        case "partner": return .lover
        case "daughter": return .daughter
        default:        return .friend
        }
    }
    
    static func fromServerAndName(serverVal: String, name: String) -> ProfileRelationship {
        if let matched = ProfileRelationship.allCases.first(where: { $0.rawValue == name }) {
            return matched
        }
        return fromServerValue(serverVal)
    }
}
