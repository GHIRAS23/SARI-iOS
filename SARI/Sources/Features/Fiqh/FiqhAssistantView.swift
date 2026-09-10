import SwiftUI
import UIKit

struct FiqhAssistantView: View {
    @State private var question = ""
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var showHistory = false
    @StateObject private var pack = LocalFiqhPack.shared
    @StateObject private var history = SariFiqhHistoryStore.shared
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

                            ForEach(history.currentTurns) { turn in
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
                    .onChange(of: history.currentTurns.count) { _, _ in
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
                    .onChange(of: history.currentConversationID) { _, _ in
                        errorMessage = nil
                        composerFocused = false
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .navigationTitle(SariStrings.t("ask", language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel(historyLabel)

                    Button {
                        composerFocused = false
                        history.newConversation()
                        question = ""
                        errorMessage = nil
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(newConversationLabel)
                }
            }
        }
        .sheet(isPresented: $showHistory) { historySheet }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            Task {
                await LocalFiqhEngine.shared.releaseModelIfIdle()
                await SariDiagnostics.shared.log("fiqh.memoryWarning releaseRequested=true")
            }
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
                Label(levelLabel(answer.level), systemImage: levelIcon(answer.level))
                    .font(.subheadline.weight(.bold))
                Spacer()
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
                Text(supportingTextTitle)
                    .font(.headline)

                VStack(spacing: 10) {
                    ForEach(Array(answer.sources.prefix(3))) { item in
                        Text(item.text)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
                            .padding(13)
                            .background(
                                Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                            )
                            .accessibilityLabel(supportingTextTitle)
                    }
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

    private var historySheet: some View {
        NavigationStack {
            List {
                ForEach(history.conversations) { conversation in
                    Button {
                        history.select(conversation.id)
                        showHistory = false
                    } label: {
                        VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 5) {
                            Text(conversation.preview.isEmpty ? newConversationLabel : conversation.preview)
                                .font(.body.weight(.semibold))
                                .lineLimit(2)
                            Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.compactMap { index in
                        history.conversations.indices.contains(index) ? history.conversations[index].id : nil
                    }
                    for id in ids { history.delete(id) }
                }
            }
            .navigationTitle(historyLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(doneLabel) { showHistory = false }
                }
            }
        }
        .sariLanguageEnvironment(language)
    }

    private func levelLabel(_ level: String) -> String {
        if level.contains("explicit") {
            return SariContentText.pick(language, [
                .ar: "نص صريح", .en: "Explicit text", .tr: "Açık metin", .ms: "Teks jelas", .id: "Teks eksplisit",
                .ja: "明示された本文", .zh: "明确文本", .ru: "Прямой текст", .fr: "Texte explicite"
            ])
        }
        if level.contains("inference") {
            return SariContentText.pick(language, [
                .ar: "استدلال", .en: "Text-based inference", .tr: "Metne dayalı çıkarım", .ms: "Rumusan berasaskan teks",
                .id: "Kesimpulan berbasis teks", .ja: "本文に基づく推論", .zh: "基于文本的推断", .ru: "Вывод по тексту", .fr: "Inférence fondée sur le texte"
            ])
        }
        return SariContentText.pick(language, [
            .ar: "النص غير كافٍ", .en: "Insufficient text", .tr: "Metin yetersiz", .ms: "Teks tidak mencukupi",
            .id: "Teks tidak cukup", .ja: "本文不足", .zh: "文本不足", .ru: "Недостаточно текста", .fr: "Texte insuffisant"
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
                    // Metadata remains available inside the saved object for integrity and
                    // future audits. answerCard intentionally renders only source.text.
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
            history.append(question: q, answer: converted)
        } catch {
            question = q
            errorMessage = message(for: error)
            await SariDiagnostics.shared.log(
                "fiqh.ask failed type=\(String(describing: type(of: error))) error=\(String(describing: error))"
            )
        }
    }

    private func message(for error: Error) -> String {
        if let engineError = error as? LocalFiqhEngineError {
            switch engineError {
            case .busy:
                return SariContentText.pick(language, [
                    .ar: "ساري ما زال يعالج السؤال السابق. انتظر اكتمال الإجابة ثم حاول مرة أخرى.",
                    .en: "SARI is still processing the previous question. Wait for it to finish and try again."
                ])
            case .questionTooLong:
                return SariContentText.pick(language, [
                    .ar: "السؤال طويل جدًا للتشغيل المحلي الآمن. اختصره قليلًا ثم أعد الإرسال.",
                    .en: "The question is too long for the safe local context. Shorten it slightly and send it again."
                ])
            case .promptTooLarge:
                return SariContentText.pick(language, [
                    .ar: "تعذر تجهيز النصوص ضمن الحد الآمن. أعد صياغة السؤال بشكل أقصر.",
                    .en: "The supporting text could not fit within the safe limit. Rephrase the question more briefly."
                ])
            case .runtimeValidationFailed:
                return SariContentText.pick(language, [
                    .ar: "النموذج المحلي لم يجتز فحص التشغيل. أعد فحصه من بطاقة الإعداد أعلاه.",
                    .en: "The local model did not pass its runtime check. Run the check again from the setup card above."
                ])
            }
        }
        return SariUIStrings.text("fiqh_local_error", language)
    }

    private var supportingTextTitle: String {
        SariContentText.pick(language, [
            .ar: "النص المستند إليه", .en: "Supporting text", .tr: "Dayanak metin", .ms: "Teks sandaran",
            .id: "Teks yang digunakan", .ja: "根拠となる本文", .zh: "所依据的文本", .ru: "Опорный текст", .fr: "Texte d’appui"
        ])
    }

    private var historyLabel: String {
        SariContentText.pick(language, [
            .ar: "المحادثات", .en: "Conversations", .tr: "Konuşmalar", .ms: "Perbualan", .id: "Percakapan",
            .ja: "会話", .zh: "对话", .ru: "Диалоги", .fr: "Conversations"
        ])
    }

    private var newConversationLabel: String {
        SariContentText.pick(language, [
            .ar: "محادثة جديدة", .en: "New conversation", .tr: "Yeni konuşma", .ms: "Perbualan baharu", .id: "Percakapan baru",
            .ja: "新しい会話", .zh: "新对话", .ru: "Новый диалог", .fr: "Nouvelle conversation"
        ])
    }

    private var doneLabel: String {
        SariContentText.pick(language, [
            .ar: "تم", .en: "Done", .tr: "Bitti", .ms: "Selesai", .id: "Selesai", .ja: "完了", .zh: "完成", .ru: "Готово", .fr: "Terminé"
        ])
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
            .ar: "نزّل النموذج المحلي أو افحص النسخة المثبتة مرة واحدة لتفعيل الاستنتاج.",
            .en: "Download the local model or validate the installed copy once to enable reasoning.",
            .tr: "Çıkarımı etkinleştirmek için yerel modeli indirin veya kurulu kopyayı bir kez doğrulayın.",
            .ms: "Muat turun model tempatan atau sahkan salinan yang dipasang sekali untuk mengaktifkan penaakulan.",
            .id: "Unduh model lokal atau validasi salinan yang terpasang sekali untuk mengaktifkan penalaran.",
            .ja: "推論を有効にするには、ローカルモデルをダウンロードするか、インストール済みモデルを一度検証してください。",
            .zh: "下载本地模型或对已安装模型进行一次验证即可启用推理。",
            .ru: "Скачайте локальную модель или один раз проверьте уже установленную копию, чтобы включить рассуждение.",
            .fr: "Téléchargez le modèle local ou validez une fois la copie installée pour activer le raisonnement."
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
