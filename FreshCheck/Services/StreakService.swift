// FreshCheck/Services/StreakService.swift
import Foundation

enum StreakService {
    static let currentStreakKey = "streak.currentStreak"
    private static let lastActivityKey = "streak.lastActivityDate"

    static var currentStreak: Int {
        UserDefaults.standard.integer(forKey: currentStreakKey)
    }

    static func recordActivity() {
        let today = Calendar.current.startOfDay(for: Date())
        let defaults = UserDefaults.standard

        if let stored = defaults.object(forKey: lastActivityKey) as? Date {
            let lastDay = Calendar.current.startOfDay(for: stored)

            if lastDay == today {
                return
            }

            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            if lastDay == yesterday {
                defaults.set(defaults.integer(forKey: currentStreakKey) + 1, forKey: currentStreakKey)
            } else {
                defaults.set(1, forKey: currentStreakKey)
            }
        } else {
            defaults.set(1, forKey: currentStreakKey)
        }

        defaults.set(today, forKey: lastActivityKey)
    }

    /// For testing and debug reset only
    static func reset() {
        UserDefaults.standard.removeObject(forKey: lastActivityKey)
        UserDefaults.standard.removeObject(forKey: currentStreakKey)
    }
}
