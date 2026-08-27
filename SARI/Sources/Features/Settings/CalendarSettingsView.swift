import SwiftUI

struct CalendarSettingsView: View {

    @AppStorage(
        "dateDisplayMode",
        store: UserDefaults(
            suiteName: "group.sa.sari.app"
        )
    )
    private var mode = "dual"

    @AppStorage(
        "hijriAdjustment",
        store: UserDefaults(
            suiteName: "group.sa.sari.app"
        )
    )
    private var adjustment = 0

    var body: some View {
        Form {

            Section {
                Picker(
                    SariUIStrings.text(
                        "calendar",
                        SariLanguage.selected
                    ),
                    selection: $mode
                ) {
                    ForEach(
                        SariDateDisplayMode.allCases
                    ) { item in
                        Text(item.title)
                            .tag(item.rawValue)
                    }
                }
            } header: {
                Text(
                    SariUIStrings.text(
                        "calendar_display",
                        SariLanguage.selected
                    )
                )
            }

            Section {
                Stepper(
                    SariUIStrings.format(
                        "days_value",
                        SariLanguage.selected,
                        [
                            "value":
                                "\(adjustment >= 0 ? "+" : "")\(adjustment)"
                        ]
                    ),
                    value: $adjustment,
                    in: -2...2
                )

                Button(
                    SariUIStrings.text(
                        "reset",
                        SariLanguage.selected
                    )
                ) {
                    adjustment = 0
                }
                .disabled(adjustment == 0)

            } header: {
                Text(
                    SariUIStrings.text(
                        "hijri_correction",
                        SariLanguage.selected
                    )
                )
            } footer: {
                Text(
                    SariUIStrings.text(
                        "hijri_correction_note",
                        SariLanguage.selected
                    )
                )
            }

            Section {
                ForEach(
                    SariCalendar.lines(),
                    id: \.self
                ) { line in
                    Text(line)
                }

            } header: {
                Text(
                    SariUIStrings.text(
                        "preview",
                        SariLanguage.selected
                    )
                )
            }
        }
        .navigationTitle(
            SariUIStrings.text(
                "calendar_date",
                SariLanguage.selected
            )
        )
    }
}