import SwiftUI

private struct SariFiqhTurn: Identifiable {
    let id = UUID()
    let question: String
    let answer: FiqhServerAnswer
}

struct FiqhAssistantView: View {
    @Environment(\.openURL) private var openURL
    @State private var question = ""
    @State private var turns: [SariFiqhTurn] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @StateObject private var pack = LocalFiqhPack.shared
    @AppStorage("sariLanguage") private var languageRaw = ""
    @FocusState private var composerFocused: Bool

    private var language: SariLanguage { SariLanguage(rawValue: languageRaw) ?? .device }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color.accentColor.opacity(0.055), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            introCard

                            if !pack.readyForInference {
                                FiqhPackSetupView()
                                    .sariAskCard()
                            } else {
                                runtimeReadyCard
                            }

                            ForEach(turns) { turn in
                                questionBubble(turn.question)
                                answerCard(turn.answer)
                            }

                            if loading { loadingCard.id("loading") }
                            if let errorMessage { errorCard(errorMessage) }
                            Color.clear.frame(height: 28).id("bottom")
                        }
                        .padding(18)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(
                        TapGesture().onEnded { composerFocused = false }
                    )
                    .onChange(of: turns.count) { _, _ in
                        composerFocused = false
                        withAnimation(.easeOut(duration: 0.22)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: loading) { _, value in
                        if value {
                            composerFocused = false
                            withAnimation(.easeOut(duration: 0.22)) {
                                proxy.scrollTo("loading", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .navigationTitle(SariStrings.t("ask", language))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sariLanguageEnvironment(language)
    }

    private var introCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 5) {
                Text(SariUIStrings.text("fiqh_source_based", language))
                    .font(.headline)
                Text(SariUIStrings.text("fiqh_method_desc", language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .sariAskCard()
    }

    private var runtimeReadyCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "iphone.and.arrow.forward")
                .foregroundStyle(.green)
            VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 2) {
                Text(offlineReadyTitle).font(.subheadline.weight(.semibold))
                Text(LocalFiqhPack.recommendedModelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .sariAskCard()
    }

    private func questionBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 50)
            Text(text)
                .textSelection(.enabled)
                .padding(14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    SariUIStrings.text("question_details", language),
                    text: $question,
                    axis: .vertical
                )
                .focused($composerFocused)
                .lineLimit(1...5)
                .submitLabel(.send)
                .onSubmit {
                    guard pack.readyForInference else { return }
                    Task { await ask() }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))

                Button {
                    composerFocused = false
                    Task { await ask() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .disabled(
                    question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || loading
                    || !pack.readyForInference
                )
            }

            Text(pack.readyForInference ? SariUIStrings.text("fiqh_not_fatwa", language) : modelRequiredNote)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .background(.ultraThinMaterial)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: language.isArabic ? .trailing : .leading) {
                Text(SariUIStrings.text("fiqh_searching", language)).fontWeight(.semibold)
                Text(SariUIStrings.text("fiqh_local_wait", language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
        .sariAskCard()
    }

    private func errorCard(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
            .sariAskCard()
    }

    private func answerCard(_ answer: FiqhServerAnswer) -> some View {
        VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 14) {
            HStack {
                Text(
                    SariUIStrings.format(
                        "source_match",
                        language,
                        ["value": "\(answer.retrieval_confidence)"]
                    )
                )
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.10), in: Capsule())

                Spacer()
                Label(levelLabel(answer.level), systemImage: levelIcon(answer.level))
                    .font(.subheadline.weight(.bold))
            }

            Text(answer.answer)
                .font(.title3.weight(.semibold))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if let reason = answer.reason, !reason.isEmpty {
                Divider()
                DisclosureGroup(SariUIStrings.text("fiqh_why", language)) {
                    Text(reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 8)
                }
            }

            if !answer.sources.isEmpty {
                Divider()
                Text(SariStrings.t("sources", language)).font(.headline)

                ForEach(answer.sources.prefix(5)) { source in
                    let sourceIndex = answer.sources.firstIndex(where: { $0.id == source.id }) ?? 0
                    DisclosureGroup {
                        VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 9) {
                            Text(source.text)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            if let url = FiqhAPI.shared.absoluteSourceURL(source) {
                                Button { openURL(url) } label: {
                                    Label(SariUIStrings.text("open_source", language), systemImage: "doc.richtext")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("[S\(sourceIndex + 1)] \(source.source_label)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(13)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15))
                }
            }

            if answer.contact_scholar_recommended {
                NavigationLink(destination: ScholarsView()) {
                    Label(SariUIStrings.text("fiqh_contact_scholar", language), systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Text(answer.disclaimer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .sariAskCard()
    }

    private func levelLabel(_ level: String) -> String {
        if level.contains("explicit") {
            return SariContentText.pick(language, [
                .ar: "نص صريح", .en: "Explicit source", .tr: "Açık kaynak", .ms: "Sumber jelas", .id: "Sumber eksplisit",
                .ja: "明示された根拠", .zh: "明确来源", .ru: "Прямой источник", .fr: "Source explicite"
            ])
        }
        if level.contains("inference") {
            return SariContentText.pick(language, [
                .ar: "استدلال من المصدر", .en: "Source-based inference", .tr: "Kaynağa dayalı çıkarım", .ms: "Rumusan berasaskan sumber",
                .id: "Kesimpulan berbasis sumber", .ja: "資料に基づく推論", .zh: "基于来源的推断", .ru: "Вывод по источнику", .fr: "Inférence fondée sur la source"
            ])
        }
        return SariContentText.pick(language, [
            .ar: "المصدر غير كافٍ", .en: "Insufficient source", .tr: "Kaynak yetersiz", .ms: "Sumber tidak mencukupi",
            .id: "Sumber tidak cukup", .ja: "根拠不足", .zh: "来源不足", .ru: "Недостаточно источников", .fr: "Source insuffisante"
        ])
    }

    private func levelIcon(_ level: String) -> String {
        if level.contains("explicit") { return "checkmark.seal.fill" }
        if level.contains("inference") { return "arrow.triangle.branch" }
        return "exclamationmark.triangle.fill"
    }

    @MainActor
    private func ask() async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !loading, pack.readyForInference else { return }

        composerFocused = false
        question = ""
        errorMessage = nil
        loading = true
        defer { loading = false }

        do {
            let local = try await LocalFiqhEngine.shared.ask(question: q, language: language)
            let converted = FiqhServerAnswer(
                level: local.level,
                answer: local.answer,
                reason: local.reason,
                retrieval_confidence: local.confidence,
                confidence_label: "",
                sources: local.sources.map { source in
                    FiqhSource(
                        id: source.id,
                        part: source.part,
                        page: source.page,
                        text: source.text,
                        pdf_file: source.pdfFile,
                        source_label: source.label(language),
                        score: nil,
                        pdf_url: nil
                    )
                },
                contact_scholar_recommended: local.level == "insufficient",
                ai_enabled: true,
                source_basis: "local",
                disclaimer: SariUIStrings.text("fiqh_local_disclaimer", language)
            )
            turns.append(SariFiqhTurn(question: q, answer: converted))
        } catch {
            question = q
            errorMessage = SariUIStrings.text("fiqh_local_error", language)
        }
    }

    private var offlineReadyTitle: String {
        SariContentText.pick(language, [
            .ar: "الاستدلال المحلي جاهز — بدون إنترنت", .en: "Offline reasoning is ready", .tr: "Çevrimdışı çıkarım hazır",
            .ms: "Penaakulan luar talian sedia", .id: "Penalaran offline siap", .ja: "オフライン推論の準備完了",
            .zh: "离线推理已就绪", .ru: "Офлайн-рассуждение готово", .fr: "Le raisonnement hors ligne est prêt"
        ])
    }

    private var modelRequiredNote: String {
        SariContentText.pick(language, [
            .ar: "نزّل النموذج المحلي مرة واحدة من البطاقة أعلاه لتفعيل الاستنتاج.",
            .en: "Download the local model once from the card above to enable reasoning.",
            .tr: "Çıkarımı etkinleştirmek için yukarıdaki karttan yerel modeli bir kez indirin.",
            .ms: "Muat turun model tempatan sekali daripada kad di atas untuk mengaktifkan penaakulan.",
            .id: "Unduh model lokal sekali dari kartu di atas untuk mengaktifkan penalaran.",
            .ja: "推論を有効にするには、上のカードからローカルモデルを一度ダウンロードしてください。",
            .zh: "请从上方卡片一次性下载本地模型以启用推理。",
            .ru: "Один раз скачайте локальную модель из карточки выше, чтобы включить рассуждение.",
            .fr: "Téléchargez une fois le modèle local depuis la carte ci-dessus pour activer le raisonnement."
        ])
    }
}

private extension View {
    func sariAskCard() -> some View {
        frame(maxWidth: .infinity)
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
