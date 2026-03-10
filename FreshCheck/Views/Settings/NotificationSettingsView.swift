import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [FoodItem]

    @AppStorage(NotificationService.reminderHourKey)
    private var reminderHour: Int = NotificationService.defaultReminderHour
    @AppStorage(NotificationService.reminderMinuteKey)
    private var reminderMinute: Int = NotificationService.defaultReminderMinute

    private let quickSetTimes: [(hour: Int, minute: Int, label: String)] = [
        (8, 0, "8:00"),
        (12, 0, "12:00"),
        (18, 0, "18:00")
    ]

    private var reminderDate: Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = reminderHour
        comps.minute = reminderMinute
        return Calendar.current.date(from: comps) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("notif.quickSet.title")) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(quickSetTimes, id: \.label) { preset in
                            quickSetChip(hour: preset.hour, minute: preset.minute, label: preset.label)
                        }
                    }
                }

                Section(L10n.tr("notif.timePicker.title")) {
                    DatePicker(
                        L10n.tr("notif.timePicker.label"),
                        selection: Binding(
                            get: { reminderDate },
                            set: { newDate in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                let newHour = comps.hour ?? NotificationService.defaultReminderHour
                                let newMinute = comps.minute ?? NotificationService.defaultReminderMinute
                                updateReminder(hour: newHour, minute: newMinute)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                }
            }
            .navigationTitle(L10n.tr("notif.settings.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { dismiss() }
                }
            }
        }
    }

    private func quickSetChip(hour: Int, minute: Int, label: String) -> some View {
        let isSelected = reminderHour == hour && reminderMinute == minute
        return Button {
            updateReminder(hour: hour, minute: minute)
        } label: {
            Text(label)
                .font(AppTheme.Typography.captionBold)
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func updateReminder(hour: Int, minute: Int) {
        reminderHour = hour
        reminderMinute = minute
        NotificationService.saveReminderTime(hour: hour, minute: minute)
        Task {
            let granted = await NotificationService.requestPermission()
            if granted {
                NotificationService.scheduleSmartDigest(items: items)
            }
        }
    }
}
