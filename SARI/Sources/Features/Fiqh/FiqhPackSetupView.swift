import SwiftUI

struct FiqhPackSetupView: View {
    @StateObject private var pack = LocalFiqhPack.shared
    @AppStorage("sariLanguage") private var languageRaw = ""
    @State private var error: String?
    private var language: SariLanguage { SariLanguage(rawValue: languageRaw) ?? .device }

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
                Label(modelLabel, systemImage: "cpu.fill")
                Label(privacyLabel, systemImage: "lock.shield.fill")
                Label(costLabel, systemImage: "creditcard")
            }
            .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))

            if pack.downloading {
                VStack(spacing: 9) {
                    ProgressView(value: pack.progress)
                    Text(downloadStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if pack.downloadedBytes > 0 {
                        Text(progressDetails)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(downloadKeepOpen)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if pack.readyForInference {
                Label(readyLabel, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else if pack.installed {
                VStack(spacing: 10) {
                    Label(sourcesReadyModelMissing, systemImage: "books.vertical.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline.weight(.semibold))

                    Button {
                        Task {
                            do {
                                error = nil
                                try await pack.installRecommendedModel()
                            } catch {
                                self.error = failureMessage(error)
                            }
                        }
                    } label: {
                        Label(modelActionButton, systemImage: pack.hasModel ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text(modelSizeNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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
        .task { await pack.resumeBackgroundWorkIfNeeded() }
        .sariLanguageEnvironment(language)
    }

    private var title: String { SariContentText.pick(language, [
        .ar: "المساعد الفقهي المحلي", .en: "Local fiqh assistant", .tr: "Yerel fıkıh asistanı", .ms: "Pembantu fiqh tempatan",
        .id: "Asisten fikih lokal", .ja: "ローカル・フィクフ助手", .zh: "本地教法助手", .ru: "Локальный фикх-помощник", .fr: "Assistant fiqh local"
    ]) }

    private var description: String { SariContentText.pick(language, [
        .ar: "مصادر «السلسبيل» مضمّنة داخل SARI. نزّل نموذج الذكاء الاصطناعي مرة واحدة، وبعدها يفهم السؤال ويستدل من المصادر ويجيب محليًا بدون إنترنت.",
        .en: "Al-Salsabil sources are bundled with SARI. Download the AI model once; afterward SARI can understand the question, reason from the sources, and answer fully offline.",
        .tr: "Es-Selsebil kaynakları SARI'ye dahildir. Yapay zekâ modelini bir kez indirin; ardından SARI soruyu anlayıp kaynaklardan çıkarım yaparak çevrimdışı yanıt verir.",
        .ms: "Sumber Al-Salsabil disertakan dalam SARI. Muat turun model AI sekali; selepas itu SARI memahami soalan, membuat rumusan daripada sumber dan menjawab sepenuhnya di luar talian.",
        .id: "Sumber Al-Salsabil disertakan dalam SARI. Unduh model AI sekali; setelah itu SARI memahami pertanyaan, menyimpulkan dari sumber, dan menjawab sepenuhnya offline.",
        .ja: "『アル・サルサビール』資料はSARIに内蔵されています。AIモデルを一度ダウンロードすれば、その後は質問を理解し、資料に基づいて端末内だけで回答できます。",
        .zh: "《السلسبيل》资料已内置在 SARI 中。只需下载一次 AI 模型，之后即可在本地理解问题、依据资料推断并离线回答。",
        .ru: "Источники «Ас-Сальсабиль» встроены в SARI. Скачайте модель ИИ один раз — после этого SARI сможет понимать вопрос, делать вывод по источникам и отвечать полностью офлайн.",
        .fr: "Les sources d’Al-Salsabil sont intégrées à SARI. Téléchargez le modèle IA une fois ; ensuite SARI comprend la question, raisonne à partir des sources et répond entièrement hors ligne."
    ]) }

    private var localSourcesLabel: String { SariContentText.pick(language, [
        .ar: "المصادر الفقهية تعمل محليًا", .en: "Fiqh sources work locally", .tr: "Fıkıh kaynakları yerel çalışır", .ms: "Sumber fiqh berfungsi secara tempatan",
        .id: "Sumber fikih bekerja secara lokal", .ja: "フィクフ資料は端末内で動作", .zh: "教法资料在本地运行", .ru: "Источники фикха работают локально", .fr: "Les sources de fiqh fonctionnent localement"
    ]) }

    private var modelLabel: String { SariContentText.pick(language, [
        .ar: "نموذج متعدد اللغات: \(LocalFiqhPack.recommendedModelName)", .en: "Multilingual model: \(LocalFiqhPack.recommendedModelName)",
        .tr: "Çok dilli model: \(LocalFiqhPack.recommendedModelName)", .ms: "Model berbilang bahasa: \(LocalFiqhPack.recommendedModelName)",
        .id: "Model multibahasa: \(LocalFiqhPack.recommendedModelName)", .ja: "多言語モデル: \(LocalFiqhPack.recommendedModelName)",
        .zh: "多语言模型：\(LocalFiqhPack.recommendedModelName)", .ru: "Многоязычная модель: \(LocalFiqhPack.recommendedModelName)",
        .fr: "Modèle multilingue : \(LocalFiqhPack.recommendedModelName)"
    ]) }

    private var privacyLabel: String { SariUIStrings.text("pack_private", language) }
    private var costLabel: String { SariUIStrings.text("pack_no_per_question_cost", language) }

    private var readyLabel: String { SariContentText.pick(language, [
        .ar: "المصادر والنموذج المحلي جاهزان — يعمل بدون إنترنت", .en: "Local sources and model are ready — works offline",
        .tr: "Yerel kaynaklar ve model hazır — çevrimdışı çalışır", .ms: "Sumber dan model tempatan sedia — berfungsi di luar talian",
        .id: "Sumber dan model lokal siap — bekerja offline", .ja: "ローカル資料とモデルの準備完了 — オフラインで動作",
        .zh: "本地资料和模型已就绪 — 可离线运行", .ru: "Локальные источники и модель готовы — работает офлайн",
        .fr: "Sources et modèle locaux prêts — fonctionne hors ligne"
    ]) }

    private var sourcesReadyModelMissing: String { SariContentText.pick(language, [
        .ar: "المصادر جاهزة؛ بقي تنزيل نموذج الاستدلال", .en: "Sources are ready; the reasoning model still needs to be downloaded",
        .tr: "Kaynaklar hazır; çıkarım modeli henüz indirilmeli", .ms: "Sumber sedia; model penaakulan masih perlu dimuat turun",
        .id: "Sumber siap; model penalaran masih perlu diunduh", .ja: "資料は準備済みです。推論モデルのダウンロードが必要です",
        .zh: "资料已就绪；还需下载推理模型", .ru: "Источники готовы; осталось скачать модель рассуждения",
        .fr: "Les sources sont prêtes ; il reste à télécharger le modèle de raisonnement"
    ]) }

    private var modelActionButton: String {
        if pack.hasModel && pack.installedVersion == LocalFiqhPack.recommendedModelVersion {
            return SariContentText.pick(language, [
                .ar: "فحص النموذج المثبت", .en: "Validate installed model", .tr: "Kurulu modeli doğrula", .ms: "Sahkan model dipasang",
                .id: "Validasi model terpasang", .ja: "インストール済みモデルを検証", .zh: "验证已安装模型", .ru: "Проверить установленную модель", .fr: "Valider le modèle installé"
            ])
        }
        return SariContentText.pick(language, [
            .ar: "تنزيل نموذج الذكاء المحلي", .en: "Download offline AI model", .tr: "Çevrimdışı AI modelini indir", .ms: "Muat turun model AI luar talian",
            .id: "Unduh model AI offline", .ja: "オフラインAIモデルをダウンロード", .zh: "下载离线 AI 模型", .ru: "Скачать офлайн-модель ИИ", .fr: "Télécharger le modèle IA hors ligne"
        ])
    }

    private var modelSizeNote: String { SariContentText.pick(language, [
        .ar: "تنزيل واحد بحجم يقارب 2.1 جيجابايت. بعد التحقق من SHA‑256 لا يحتاج المساعد إلى الإنترنت للإجابة.",
        .en: "One-time download of about 2.1 GB. After SHA-256 verification, answering does not require internet.",
        .tr: "Yaklaşık 2,1 GB tek seferlik indirme. SHA-256 doğrulamasından sonra yanıt için internet gerekmez.",
        .ms: "Muat turun sekali kira-kira 2.1 GB. Selepas pengesahan SHA-256, jawapan tidak memerlukan internet.",
        .id: "Unduhan sekali sekitar 2,1 GB. Setelah verifikasi SHA-256, jawaban tidak memerlukan internet.",
        .ja: "約2.1GBを一度だけダウンロードします。SHA-256検証後、回答にインターネットは不要です。",
        .zh: "一次下载约 2.1 GB。通过 SHA-256 校验后，回答无需联网。",
        .ru: "Разовая загрузка около 2,1 ГБ. После проверки SHA-256 интернет для ответов не нужен.",
        .fr: "Téléchargement unique d’environ 2,1 Go. Après vérification SHA-256, les réponses ne nécessitent plus Internet."
    ]) }

    private var retryLabel: String { SariContentText.pick(language, [
        .ar: "إعادة تجهيز المصادر", .en: "Prepare sources again", .tr: "Kaynakları yeniden hazırla", .ms: "Sediakan semula sumber", .id: "Siapkan ulang sumber",
        .ja: "資料を再準備", .zh: "重新准备来源", .ru: "Подготовить источники снова", .fr: "Préparer à nouveau les sources"
    ]) }

    private var bundledSourceError: String { SariContentText.pick(language, [
        .ar: "تعذر تجهيز مكتبة المصادر المضمّنة. أعد تشغيل التطبيق أو أعد تثبيت النسخة.", .en: "The bundled source library could not be prepared. Restart or reinstall this build.",
        .tr: "Dahili kaynak kütüphanesi hazırlanamadı. Uygulamayı yeniden başlatın veya bu sürümü yeniden yükleyin.", .ms: "Pustaka sumber terbina tidak dapat disediakan. Mulakan semula atau pasang semula binaan ini.",
        .id: "Pustaka sumber bawaan tidak dapat disiapkan. Mulai ulang atau instal ulang build ini.", .ja: "内蔵資料ライブラリを準備できませんでした。アプリを再起動または再インストールしてください。",
        .zh: "无法准备内置来源库。请重启应用或重新安装此版本。", .ru: "Не удалось подготовить встроенную библиотеку. Перезапустите или переустановите сборку.", .fr: "Impossible de préparer la bibliothèque intégrée. Redémarrez ou réinstallez cette version."
    ]) }

    private var failedLabel: String { SariUIStrings.text("pack_verify_failed_not_activated", language) }

    private var downloadStatus: String { SariContentText.pick(language, [
        .ar: pack.status, .en: "Downloading and verifying the offline model…", .tr: "Çevrimdışı model indiriliyor ve doğrulanıyor…",
        .ms: "Memuat turun dan mengesahkan model luar talian…", .id: "Mengunduh dan memverifikasi model offline…", .ja: "オフラインモデルをダウンロード・検証中…",
        .zh: "正在下载并验证离线模型…", .ru: "Загрузка и проверка офлайн-модели…", .fr: "Téléchargement et vérification du modèle hors ligne…"
    ]) }

    private var downloadKeepOpen: String { SariContentText.pick(language, [
        .ar: "يمكنك الانتقال لأي واجهة أو وضع SARI في الخلفية؛ يستمر التنزيل عبر نظام iOS قدر الإمكان، ويستكمل تلقائيًا عند الانقطاع.", .en: "You can leave this screen or put SARI in the background; iOS continues the transfer when possible and SARI resumes interruptions automatically.", .tr: "Bu ekrandan ayrılabilir veya SARI'yi arka plana alabilirsiniz; iOS mümkün olduğunda indirmeye devam eder ve SARI kesintileri otomatik sürdürür.",
        .ms: "Jika sambungan terputus, SARI mencuba semula secara automatik dan menyimpan data sambungan untuk percubaan seterusnya.", .id: "Jika koneksi terputus, SARI mencoba lagi otomatis dan menyimpan data lanjutan untuk percobaan berikutnya.", .ja: "接続が切れた場合、SARIは自動再試行し、次回のために再開データを保存します。",
        .zh: "如果连接中断，SARI 会自动重试，并保存断点数据供下次继续。", .ru: "При обрыве соединения SARI автоматически повторит попытку и сохранит данные для продолжения.", .fr: "Si la connexion est interrompue, SARI réessaie automatiquement et conserve les données de reprise."
    ]) }


    private var progressDetails: String {
        let written = formatBytes(pack.downloadedBytes)
        let total = pack.totalBytes > 0 ? formatBytes(pack.totalBytes) : "—"
        let speed = pack.bytesPerSecond > 0 ? " · \(formatBytes(Int64(pack.bytesPerSecond)))/s" : ""
        let percent = Int((pack.progress * 100).rounded())
        return "\(written) / \(total) · \(percent)%\(speed)"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter.string(fromByteCount: max(bytes, 0))
    }

    private func failureMessage(_ error: Error) -> String {
        let reason: String
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                reason = SariContentText.pick(language, [
                    .ar: "انقطع الاتصال أثناء التنزيل. بيانات الاستئناف محفوظة؛ أعد المحاولة وسيكمل SARI قدر الإمكان من حيث توقف.",
                    .en: "The connection was interrupted. Resume data was saved; try again and SARI will continue where possible."
                ])
            case .dataLengthExceedsMaximum:
                reason = SariContentText.pick(language, [
                    .ar: "المساحة الحرة غير كافية لتنزيل النموذج والتحقق منه. وفر ما لا يقل عن 3.2 جيجابايت.",
                    .en: "There is not enough free storage to download and verify the model. Free at least 3.2 GB."
                ])
            case .cannotDecodeContentData:
                reason = SariContentText.pick(language, [
                    .ar: "اكتمل ملف غير مطابق للحجم أو بصمة SHA‑256، لذلك رفضه SARI ولن يفعّله.",
                    .en: "The completed file did not match the expected size or SHA-256, so SARI rejected it."
                ])
            default:
                reason = urlError.localizedDescription
            }
        } else {
            reason = error.localizedDescription
        }
        return "\(failedLabel)\n\(reason)"
    }

    private var verificationNote: String { SariContentText.pick(language, [
        .ar: "يُفعّل النموذج فقط بعد مطابقة بصمة SHA‑256 الموثقة؛ وإذا فشل التحقق فلا يُستخدم الملف.",
        .en: "The model is activated only after its verified SHA-256 matches; a failed verification is never used.",
        .tr: "Model yalnızca doğrulanmış SHA-256 eşleşirse etkinleştirilir; doğrulaması başarısız dosya kullanılmaz.",
        .ms: "Model hanya diaktifkan selepas SHA-256 yang disahkan sepadan; fail yang gagal semakan tidak digunakan.",
        .id: "Model hanya diaktifkan setelah SHA-256 terverifikasi cocok; file yang gagal verifikasi tidak digunakan.",
        .ja: "検証済みSHA-256が一致した場合のみモデルを有効化し、検証に失敗したファイルは使用しません。",
        .zh: "仅在已验证的 SHA-256 匹配后启用模型；校验失败的文件不会被使用。",
        .ru: "Модель активируется только при совпадении проверенного SHA-256; файл с ошибкой проверки не используется.",
        .fr: "Le modèle n’est activé qu’après concordance du SHA-256 vérifié ; un fichier invalide n’est jamais utilisé."
    ]) }
}
