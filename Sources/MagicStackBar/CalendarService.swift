import EventKit
import Foundation

/// カレンダー.app（に同期された Outlook / Google 含む）から空き日を計算する。
/// 「平日で、9:00〜18:00 に予定が 1 件もない日」を終日空きとみなす。
struct CalendarService {
  let store = EKEventStore()

  func requestAccess() async throws {
    let granted = try await store.requestFullAccessToEvents()
    if !granted {
      throw AppError.calendarDenied
    }
  }

  func freeDates(daysAhead: Int = 60) -> [String] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current

    var result: [String] = []
    let today = calendar.startOfDay(for: Date())

    for offset in 1...daysAhead {
      guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
      let weekday = calendar.component(.weekday, from: day)
      // 1 = 日曜, 7 = 土曜
      if weekday == 1 || weekday == 7 { continue }

      guard
        let workStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
        let workEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)
      else { continue }

      let predicate = store.predicateForEvents(
        withStart: workStart, end: workEnd, calendars: nil
      )
      let events = store.events(matching: predicate)
        .filter { $0.availability != .free }

      if events.isEmpty {
        result.append(formatter.string(from: day))
      }
    }
    return result
  }
}
