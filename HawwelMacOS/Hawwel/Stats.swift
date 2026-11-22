import Foundation
import Combine

/// إحصائيات التحويل. بتتحفظ على الجهاز بس (Application Support/Hawwel/stats.json)،
/// وما فيهاش الكلام نفسه: عدد مرات وعدد حروف واتجاه واسم البرنامج بس.
final class Stats: ObservableObject {
    struct Data: Codable {
        var total = 0
        var chars = 0
        var toArabic = 0
        var toEnglish = 0
        var days: [String: Int] = [:]   // "2026-11-22": 12
        var dayChars: [String: Int] = [:]
        var apps: [String: Int] = [:]   // "Slack": 46
    }

    @Published private(set) var data = Data()

    /// تقدير الوقت اللي اتوفر: الحروف ÷ 200 حرف في الدقيقة
    static let charsPerMinute = 200.0

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hawwel", isDirectory: true)
        return dir.appendingPathComponent("stats.json")
    }()

    private static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var persist = true

    #if DEBUG
    /// بيانات للمعاينة بس (ما بتتحفظش)
    init(preview: Data) {
        data = preview
        persist = false
    }
    #endif

    init() {
        if let raw = try? Foundation.Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(Data.self, from: raw) {
            data = saved
        }
    }

    func record(chars: Int, toArabic: Bool, app: String?) {
        let day = Self.dayKey.string(from: Date())
        data.total += 1
        data.chars += chars
        if toArabic { data.toArabic += 1 } else { data.toEnglish += 1 }
        data.days[day, default: 0] += 1
        data.dayChars[day, default: 0] += chars
        if let app, !app.isEmpty { data.apps[app, default: 0] += 1 }
        prune()
        save()
    }

    func clear() {
        data = Data()
        save()
    }

    // MARK: - أرقام جاهزة للعرض

    var todayCount: Int { data.days[Self.dayKey.string(from: Date())] ?? 0 }
    var todayChars: Int { data.dayChars[Self.dayKey.string(from: Date())] ?? 0 }

    /// آخر 7 أيام (الأقدم الأول، والنهارده آخر واحد)
    var last7: [(date: Date, count: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { back in
            guard let d = cal.date(byAdding: .day, value: -back, to: today) else { return nil }
            return (d, data.days[Self.dayKey.string(from: d)] ?? 0)
        }
    }

    var weekCount: Int { last7.reduce(0) { $0 + $1.count } }

    /// النسبة اللي اتحوّلت لعربي (0...1)، أو nil لو مفيش تحويلات
    var toArabicShare: Double? {
        let all = data.toArabic + data.toEnglish
        return all == 0 ? nil : Double(data.toArabic) / Double(all)
    }

    /// أكتر 3 برامج ونسبة كل واحد من مجموع التحويلات
    var topApps: [(name: String, share: Double)] {
        let all = data.apps.values.reduce(0, +)
        guard all > 0 else { return [] }
        return data.apps.sorted { $0.value > $1.value }.prefix(3)
            .map { ($0.key, Double($0.value) / Double(all)) }
    }

    static func minutesSaved(chars: Int) -> Double { Double(chars) / charsPerMinute }

    // MARK: - حفظ

    /// بنحتفظ بآخر 400 يوم بس علشان الملف ما يكبرش
    private func prune() {
        guard data.days.count > 400 else { return }
        let keep = Set(data.days.keys.sorted().suffix(400))
        data.days = data.days.filter { keep.contains($0.key) }
        data.dayChars = data.dayChars.filter { keep.contains($0.key) }
    }

    private func save() {
        guard persist else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(data).write(to: url, options: .atomic)
        } catch {
            print("Could not save stats:", error)
        }
    }
}
