import AccrueAppSupport
import AccrueCore
import SwiftUI

struct ActivationSetupView: View {
    @EnvironmentObject private var appModel: AccrueAppModel

    @State private var currencyCode = Locale.current.currency?.identifier ?? "USD"
    @State private var payRuleKind = StoredPayRuleKind.hourlyRate
    @State private var payAmountText = "50"

    private var payAmount: Decimal? {
        Decimal(string: payAmountText)
    }

    private var draft: AccrueSetupDraft? {
        guard let payAmount, !currencyCode.isEmpty else {
            return nil
        }

        return AccrueSetupDraft(
            currencyCode: currencyCode.uppercased(),
            payRuleKind: payRuleKind,
            payAmount: payAmount
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Accrue")
                    .font(.largeTitle.weight(.semibold))
                Text("Set the currency and Pay Rule used for your Menu Bar Presence.")
                    .foregroundStyle(.secondary)
            }

            AnimatedMenuBarPreview(draft: draft)

            VStack(alignment: .leading, spacing: 14) {
                TextField("Currency", text: $currencyCode)
                    .textFieldStyle(.roundedBorder)

                Picker("Pay Rule", selection: $payRuleKind) {
                    ForEach(StoredPayRuleKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                TextField(payRuleKind.title, text: $payAmountText)
                    .textFieldStyle(.roundedBorder)
            }

            if let setupError = appModel.setupError {
                Text(setupError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Start Accruing") {
                    if let draft {
                        appModel.saveSetup(draft)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft == nil)
            }
        }
        .padding(28)
        .frame(width: 460, height: 520)
    }
}

private struct AnimatedMenuBarPreview: View {
    let draft: AccrueSetupDraft?

    private let calculator = AccrueSnapshotCalculator()

    var body: some View {
        TimelineView(.animation) { timeline in
            let snapshot = calculator.snapshot(
                for: configuration,
                at: previewDate(for: timeline.date),
                calendar: previewCalendar,
                locale: Locale.current
            )

            HStack(spacing: 8) {
                Image(systemName: "menubar.rectangle")
                    .foregroundStyle(.secondary)

                Text(snapshot.formattedAccruedAmount ?? "Accrue")
                    .font(.system(.body, design: .rounded).monospacedDigit())
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary, in: Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var configuration: AccrueConfiguration {
        guard let draft else {
            return .defaultWorkday
        }

        return AccrueConfiguration(
            currencyCode: draft.currencyCode,
            payRule: draft.payRuleKind.makePayRule(amount: draft.payAmount),
            workStartHour: 9,
            workEndHour: 17,
            workingWeekdays: [3]
        )
    }

    private var previewCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private func previewDate(for date: Date) -> Date {
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10)
        let elapsedHours = cycle / 10 * 8
        let components = DateComponents(
            calendar: previewCalendar,
            timeZone: previewCalendar.timeZone,
            year: 2026,
            month: 5,
            day: 19,
            hour: 9
        )
        let start = components.date ?? date

        return start.addingTimeInterval(elapsedHours * 3_600)
    }
}
