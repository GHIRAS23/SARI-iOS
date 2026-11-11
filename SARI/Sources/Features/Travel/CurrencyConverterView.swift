import SwiftUI

struct CurrencyConverterView: View {
    @StateObject private var store = CurrencyConverterStore()
    private var language: SariLanguage { SariLanguage.selected }

    var body: some View {
        Form {
                Section(title("المبلغ", "Amount")) {
                    TextField(title("أدخل المبلغ", "Enter amount"), text: $store.amount)
                        .keyboardType(.decimalPad)
                }
                Section(title("من العملة", "From currency")) {
                    Picker(title("العملة الأساسية", "Base currency"), selection: Binding(
                        get: { store.baseCurrency },
                        set: { newValue in Task { await store.changeBaseCurrency(newValue) } }
                    )) {
                        ForEach(CurrencyOption.all) { option in Text(option.display).tag(option.code) }
                    }
                }
                Section(title("إلى العملة", "To currency")) {
                    Picker(title("العملة المستهدفة", "Target currency"), selection: $store.targetCurrency) {
                        ForEach(CurrencyOption.all) { option in Text(option.display).tag(option.code) }
                    }
                    Button { store.swapCurrencies() } label: {
                        Label(title("عكس العملتين", "Swap currencies"), systemImage: "arrow.left.arrow.right")
                    }
                }
                Section(title("نتيجة التحويل", "Conversion result")) {
                    if let value = store.convertedValue {
                        Text(value.formatted(.number.precision(.fractionLength(2...4))) + " \(store.targetCurrency)")
                            .font(.title2.bold())
                    } else {
                        Text(title("أدخل مبلغًا صالحًا وانتظر تحديث الأسعار.", "Enter a valid amount and wait for rates."))
                            .foregroundStyle(.secondary)
                    }
                    if let rate = store.exchangeRate {
                        Text("1 \(store.baseCurrency) = \(rate.formatted(.number.precision(.fractionLength(4...6)))) \(store.targetCurrency)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section(title("تحديث البيانات", "Data freshness")) {
                    HStack {
                        if store.isLoading { ProgressView() }
                        Text(store.isLoading ? title("جاري تحديث الأسعار…", "Updating rates…") : title("آخر تحديث", "Last updated"))
                        Spacer()
                        if let date = store.updatedAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if store.isUsingCachedRates {
                        Label(title("تعمل بالنسخة المحفوظة دون اتصال أو بعد فشل التحديث.", "Using the saved offline snapshot or the last successful update."), systemImage: "wifi.slash")
                            .font(.caption).foregroundStyle(.orange)
                    } else if store.updatedAt != nil {
                        Label(title("الأسعار إرشادية وليست عرضًا ملزمًا من بنك أو شركة صرافة.", "Rates are indicative, not a bank or exchange-house quote."), systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
                    Button { Task { await store.loadRates() } } label: {
                        Label(title("تحديث أسعار الصرف", "Refresh exchange rates"), systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isLoading)
                }
        }
        .navigationTitle(title("تحويل العملات", "Currency converter"))
        .task { if store.updatedAt == nil { await store.loadRates() } }
        .sariLanguageEnvironment(language)
    }

    private func title(_ ar: String, _ en: String) -> String { SariTravelFeatureText.text(arabic: ar, english: en, language: language) }
}
