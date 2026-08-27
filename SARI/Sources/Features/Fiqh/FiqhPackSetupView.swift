import SwiftUI

struct FiqhPackSetupView: View {
    @StateObject private var pack = LocalFiqhPack.shared
    @State private var error: String?
    private var language: SariLanguage { SariLanguage.selected }

    private var manifestURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SARI_FIQH_PACK_MANIFEST_URL") as? String,
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.title2.bold())

            Text(description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 10) {
                Label(localSourcesLabel, systemImage: "books.vertical.fill")
                Label(privacyLabel, systemImage: "lock.shield.fill")
                Label(costLabel, systemImage: "creditcard")
            }
            .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))

            if pack.downloading {
                ProgressView(value: pack.progress)
                Text(downloadStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if pack.installed {
                Label(readyLabel, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.headline)

                if let manifestURL, !pack.hasModel {
                    Button {
                        Task {
                            do {
                                error = nil
                                try await pack.install(from: manifestURL)
                            } catch {
                                self.error = failedLabel
                            }
                        }
                    } label: {
                        Label(optionalModelButton, systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            } else {
                Button {
                    error = nil
                    pack.refresh()
                    if !pack.installed { error = bundledSourceError }
                } label: {
                    Label(retryLabel, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text(verificationNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(22)
        .sariLanguageEnvironment(language)
    }

    private var title: String { SariContentText.pick(language, [
        .ar: "المساعد الفقهي المحلي", .en: "Local fiqh assistant", .tr: "Yerel fıkıh asistanı", .ms: "Pembantu fiqh tempatan",
        .id: "Asisten fikih lokal", .ja: "ローカル・フィクフ助手", .zh: "本地教法助手", .ru: "Локальный фикх-помощник", .fr: "Assistant fiqh local"
    ]) }

    private var description: String { SariContentText.pick(language, [
        .ar: "مكتبة المصادر الفقهية الأساسية مضمّنة داخل SARI وتُجهّز تلقائيًا. لا تحتاج رابط تنزيل لبدء البحث في المصادر.",
        .en: "SARI includes its core fiqh source library and prepares it automatically. No download link is required to start source search.",
        .tr: "SARI temel fıkıh kaynak kütüphanesini içerir ve otomatik hazırlar. Kaynak araması için indirme bağlantısı gerekmez.",
        .ms: "SARI menyertakan pustaka sumber fiqh asas dan menyediakannya secara automatik. Tiada pautan muat turun diperlukan untuk carian sumber.",
        .id: "SARI menyertakan pustaka sumber fikih inti dan menyiapkannya otomatis. Tidak diperlukan tautan unduhan untuk mencari sumber.",
        .ja: "SARIには基本のフィクフ資料ライブラリが内蔵され、自動で準備されます。資料検索を始めるためのダウンロードURLは不要です。",
        .zh: "SARI 已内置基础教法资料库并自动准备，无需下载链接即可开始检索来源。",
        .ru: "Основная библиотека источников фикха встроена в SARI и подготавливается автоматически. Для поиска по источникам ссылка на загрузку не нужна.",
        .fr: "La bibliothèque principale de sources de fiqh est incluse dans SARI et préparée automatiquement. Aucun lien de téléchargement n’est requis pour lancer la recherche."
    ]) }

    private var localSourcesLabel: String { SariContentText.pick(language, [
        .ar: "المصادر الأساسية تعمل محليًا", .en: "Core sources work locally", .tr: "Temel kaynaklar yerel çalışır", .ms: "Sumber asas berfungsi secara tempatan",
        .id: "Sumber inti bekerja secara lokal", .ja: "基本資料は端末内で動作", .zh: "基础来源在本地运行", .ru: "Основные источники работают локально", .fr: "Les sources principales fonctionnent localement"
    ]) }
    private var privacyLabel: String { SariUIStrings.text("pack_private", language) }
    private var costLabel: String { SariUIStrings.text("pack_no_per_question_cost", language) }
    private var readyLabel: String { SariContentText.pick(language, [
        .ar: pack.hasModel ? "المصادر والنموذج المحلي جاهزان" : "المصادر الفقهية المحلية جاهزة", .en: pack.hasModel ? "Local sources and model are ready" : "Local fiqh sources are ready",
        .tr: "Yerel fıkıh kaynakları hazır", .ms: "Sumber fiqh tempatan sedia", .id: "Sumber fikih lokal siap", .ja: "ローカル資料の準備ができました", .zh: "本地教法来源已就绪", .ru: "Локальные источники фикха готовы", .fr: "Les sources locales de fiqh sont prêtes"
    ]) }
    private var optionalModelButton: String { SariContentText.pick(language, [
        .ar: "تنزيل النموذج المحلي الاختياري", .en: "Download optional local model", .tr: "İsteğe bağlı yerel modeli indir", .ms: "Muat turun model tempatan pilihan",
        .id: "Unduh model lokal opsional", .ja: "任意のローカルモデルをダウンロード", .zh: "下载可选本地模型", .ru: "Скачать дополнительную локальную модель", .fr: "Télécharger le modèle local optionnel"
    ]) }
    private var retryLabel: String { SariContentText.pick(language, [
        .ar: "إعادة تجهيز المصادر", .en: "Prepare sources again", .tr: "Kaynakları yeniden hazırla", .ms: "Sediakan semula sumber", .id: "Siapkan ulang sumber", .ja: "資料を再準備", .zh: "重新准备来源", .ru: "Подготовить источники снова", .fr: "Préparer à nouveau les sources"
    ]) }
    private var bundledSourceError: String { SariContentText.pick(language, [
        .ar: "تعذر تجهيز مكتبة المصادر المضمّنة. أعد تشغيل التطبيق أو أعد تثبيت النسخة.", .en: "The bundled source library could not be prepared. Restart or reinstall this build.",
        .tr: "Dahili kaynak kütüphanesi hazırlanamadı. Uygulamayı yeniden başlatın veya bu sürümü yeniden yükleyin.", .ms: "Pustaka sumber terbina tidak dapat disediakan. Mulakan semula atau pasang semula binaan ini.",
        .id: "Pustaka sumber bawaan tidak dapat disiapkan. Mulai ulang atau instal ulang build ini.", .ja: "内蔵資料ライブラリを準備できませんでした。アプリを再起動または再インストールしてください。",
        .zh: "无法准备内置来源库。请重启应用或重新安装此版本。", .ru: "Не удалось подготовить встроенную библиотеку. Перезапустите или переустановите сборку.", .fr: "Impossible de préparer la bibliothèque intégrée. Redémarrez ou réinstallez cette version."
    ]) }
    private var failedLabel: String { SariUIStrings.text("pack_verify_failed_not_activated", language) }
    private var downloadStatus: String { SariContentText.pick(language, [
        .ar: "جاري تنزيل النموذج الاختياري والتحقق منه…", .en: "Downloading and verifying the optional model…", .tr: "İsteğe bağlı model indiriliyor ve doğrulanıyor…",
        .ms: "Memuat turun dan mengesahkan model pilihan…", .id: "Mengunduh dan memverifikasi model opsional…", .ja: "任意モデルをダウンロード・検証中…", .zh: "正在下载并验证可选模型…", .ru: "Загрузка и проверка дополнительной модели…", .fr: "Téléchargement et vérification du modèle optionnel…"
    ]) }
    private var verificationNote: String { SariContentText.pick(language, [
        .ar: "إذا أضفت نموذجًا محليًا لاحقًا فلن يُفعّل إلا بعد التحقق من الحجم وبصمة SHA‑256.", .en: "If an optional local model is added later, SARI activates it only after size and SHA‑256 verification.",
        .tr: "İsteğe bağlı model daha sonra eklenirse yalnızca boyut ve SHA‑256 doğrulamasından sonra etkinleştirilir.", .ms: "Jika model pilihan ditambah kemudian, ia hanya diaktifkan selepas semakan saiz dan SHA‑256.",
        .id: "Jika model opsional ditambahkan nanti, model hanya diaktifkan setelah verifikasi ukuran dan SHA‑256.", .ja: "後で任意モデルを追加する場合、サイズとSHA‑256検証後にのみ有効化されます。", .zh: "如日后添加可选本地模型，只有通过大小和 SHA‑256 校验后才会启用。", .ru: "Если позже добавить модель, она активируется только после проверки размера и SHA‑256.", .fr: "Si un modèle local est ajouté plus tard, il ne sera activé qu’après vérification de sa taille et de son SHA‑256."
    ]) }
}
