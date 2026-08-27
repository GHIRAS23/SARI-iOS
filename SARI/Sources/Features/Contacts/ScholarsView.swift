import SwiftUI
import UIKit

private struct ScholarsFile: Codable {
    let source: String
    let purpose: String
    let items: [Scholar]
}

struct Scholar: Codable, Identifiable {
    var id: String { phone }
    let name: String
    let role: String
    let phone: String
    let note: String?
    let contact_mode: String
}

struct ScholarsView: View {
    private let file: ScholarsFile? = {
        guard let url = Bundle.main.sariResourceURL(name: "scholars", extension: "json", subdirectory: "data"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ScholarsFile.self, from: data)
    }()
    @State private var copiedPhone: String?
    private var language: SariLanguage { SariLanguage.selected }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                if let file {
                    VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 8) {
                        Label(file.purpose, systemImage: "person.2.badge.gearshape")
                            .font(.headline)
                        Text(file.source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SariContentText.pick(language,[
                            .ar:"هذه القائمة مخصصة للحاجة الشرعية والإفتاء. راعِ أوقات التواصل والملاحظات الموضحة لكل شيخ.",
                            .en:"These contacts are for religious questions when needed. Please respect the listed contact times and notes.",
                            .tr:"Bu kişiler gerektiğinde dini sorular içindir. İletişim saatleri ve notlara uyun.",
                            .ms:"Senarai ini untuk pertanyaan agama apabila diperlukan. Hormati waktu dan nota hubungan.",
                            .id:"Daftar ini untuk pertanyaan agama bila diperlukan. Hormati waktu dan catatan kontak.",
                            .ja:"必要な宗教上の質問のための連絡先です。連絡時間と注意事項を守ってください。",
                            .zh:"此列表用于有需要时的宗教咨询，请遵守联系时间和备注。",
                            .ru:"Эти контакты предназначены для религиозных вопросов при необходимости. Учитывайте время и примечания.",
                            .fr:"Ces contacts sont destinés aux questions religieuses en cas de besoin. Respectez les horaires et remarques indiqués."
                        ]))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
                    .padding(18)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    ForEach(file.items) { scholar in
                        scholarCard(scholar)
                    }
                } else {
                    ContentUnavailableView(
                        SariUIStrings.text("scholars_title",language),
                        systemImage: "person.2.slash",
                        description: Text(SariContentText.pick(language,[.ar:"تعذر تحميل قائمة المشايخ.",.en:"The scholar contact list could not be loaded."]))
                    )
                }
            }
            .padding(18)
        }
        .navigationTitle(SariUIStrings.text("scholars_title",language))
        .navigationBarTitleDisplayMode(.inline)
        .sariLanguageEnvironment(language)
    }

    private func scholarCard(_ scholar: Scholar) -> some View {
        VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 4) {
                    Text(scholar.name).font(.headline)
                    Text(scholar.role).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
            }

            HStack(spacing: 10) {
                Image(systemName: "phone.fill").foregroundStyle(SariDesign.emerald)
                Text(scholar.phone)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)
                Spacer()
                Button {
                    UIPasteboard.general.string = scholar.phone
                    copiedPhone = scholar.phone
                } label: {
                    Label(
                        copiedPhone == scholar.phone ? copyDone : copyLabel,
                        systemImage: copiedPhone == scholar.phone ? "checkmark" : "doc.on.doc"
                    )
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            if let note = scholar.note, !note.isEmpty {
                Label(note, systemImage: scholar.contact_mode == "whatsapp" ? "message.fill" : scholar.contact_mode == "sms" ? "text.bubble.fill" : "clock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if scholar.contact_mode == "whatsapp", let url = whatsappURL(scholar.phone) {
                    Link(destination: url) {
                        Label("WhatsApp", systemImage: "message.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent)
                } else if scholar.contact_mode == "sms", let url = URL(string: "sms:\(scholar.phone)") {
                    Link(destination: url) {
                        Label(smsLabel, systemImage: "text.bubble.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent)
                }
                if let url = URL(string: "tel:\(scholar.phone)") {
                    Link(destination: url) {
                        Label(SariUIStrings.text("call",language), systemImage: "phone.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
        .padding(17)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var copyLabel:String { SariContentText.pick(language,[.ar:"نسخ الرقم",.en:"Copy number",.tr:"Numarayı kopyala",.ms:"Salin nombor",.id:"Salin nomor",.ja:"番号をコピー",.zh:"复制号码",.ru:"Копировать номер",.fr:"Copier le numéro"]) }
    private var copyDone:String { SariContentText.pick(language,[.ar:"تم النسخ",.en:"Copied",.tr:"Kopyalandı",.ms:"Disalin",.id:"Disalin",.ja:"コピー済み",.zh:"已复制",.ru:"Скопировано",.fr:"Copié"]) }
    private var smsLabel:String { SariContentText.pick(language,[.ar:"رسالة نصية",.en:"Text message",.tr:"SMS",.ms:"Mesej teks",.id:"Pesan teks",.ja:"SMS",.zh:"短信",.ru:"SMS",.fr:"SMS"]) }

    private func whatsappURL(_ phone: String) -> URL? {
        let digits = phone.filter(\.isNumber)
        let international = digits.hasPrefix("0") ? "966" + digits.dropFirst() : digits
        return URL(string: "https://wa.me/\(international)")
    }
}
