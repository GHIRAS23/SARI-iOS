import SwiftUI
import WebKit

struct Ayah: Codable, Identifiable, Hashable {
    let id: Int
    let juz: Int
    let page: Int
    let sura: Int
    let sura_name_ar: String
    let sura_name_en: String
    let line_start: Int
    let line_end: Int
    let ayah: Int
    let text: String
    let search_text: String
    let tafseer: String
}

struct SurahSummary: Identifiable, Hashable {
    let id: Int
    let nameAR: String
    let nameEN: String
    let ayahCount: Int
    let firstPage: Int
    let juz: Int
}

@MainActor
final class QuranStore: ObservableObject {
    @Published private(set) var ayat: [Ayah] = []
    @Published private(set) var surahs: [SurahSummary] = []
    @Published var bookmarks: Set<Int> = []
    @Published var lastReadID: Int?

    private var pageIndex: [Int: [Ayah]] = [:]
    private let bookmarkKey = "sari.quran.bookmarks"
    private let lastReadKey = "sari.quran.lastRead"

    init() {
        loadPreferences()
        load()
    }

    func load() {
        guard let url = Bundle.main.sariResourceURL(name: "quran_tafseer", extension: "json", subdirectory: "data"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Ayah].self, from: data) else { return }
        ayat = decoded
        pageIndex = Dictionary(grouping: decoded, by: \.page)
        surahs = Dictionary(grouping: decoded, by: \.sura)
            .map { key, rows in
                let first = rows.first!
                return SurahSummary(
                    id: key,
                    nameAR: first.sura_name_ar,
                    nameEN: first.sura_name_en,
                    ayahCount: rows.count,
                    firstPage: first.page,
                    juz: first.juz
                )
            }
            .sorted { $0.id < $1.id }
    }

    func ayat(for surah: Int) -> [Ayah] { ayat.filter { $0.sura == surah } }
    func ayat(onPage page: Int) -> [Ayah] { pageIndex[page] ?? [] }
    func ayah(id: Int) -> Ayah? { ayat.first { $0.id == id } }

    func search(_ query: String) -> [Ayah] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return Array(ayat.lazy.filter {
            $0.search_text.localizedCaseInsensitiveContains(q) ||
            $0.sura_name_ar.localizedCaseInsensitiveContains(q) ||
            $0.sura_name_en.localizedCaseInsensitiveContains(q)
        }.prefix(250))
    }

    func toggleBookmark(_ id: Int) {
        if bookmarks.contains(id) { bookmarks.remove(id) } else { bookmarks.insert(id) }
        UserDefaults.standard.set(Array(bookmarks), forKey: bookmarkKey)
    }

    func markRead(_ id: Int) {
        lastReadID = id
        UserDefaults.standard.set(id, forKey: lastReadKey)
    }

    private func loadPreferences() {
        bookmarks = Set(UserDefaults.standard.array(forKey: bookmarkKey) as? [Int] ?? [])
        let saved = UserDefaults.standard.integer(forKey: lastReadKey)
        lastReadID = saved > 0 ? saved : nil
    }
}

struct QuranView: View {
    @AppStorage("sariLanguage") private var languageRaw = ""
    private var language: SariLanguage { SariLanguage(rawValue: languageRaw) ?? .device }
    @StateObject private var store = QuranStore()
    @State private var query = ""
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedSection) {
                    Text(SariContentText.pick(language, [
                        .ar: "السور", .en: "Surahs", .tr: "Sureler", .ms: "Surah", .id: "Surah",
                        .ja: "スーラ", .zh: "章", .ru: "Суры", .fr: "Sourates"
                    ])).tag(0)
                    Text(SariStrings.t("search", language)).tag(1)
                    Text(SariStrings.t("bookmarks", language)).tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if selectedSection == 0 {
                    surahList
                } else if selectedSection == 1 {
                    searchView
                } else {
                    bookmarksView
                }
            }
            .navigationTitle(SariStrings.t("quran", language))
            .toolbar {
                if let last = store.lastReadID, let ayah = store.ayah(id: last) {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(destination: MushafReaderView(startPage: ayah.page, store: store)) {
                            Label(SariUIStrings.text("last_read", language), systemImage: "book.pages.fill")
                        }
                    }
                }
            }
        }
        .sariLanguageEnvironment(language)
    }

    private var surahList: some View {
        List {
            if let last = store.lastReadID, let ayah = store.ayah(id: last) {
                Section {
                    NavigationLink(destination: MushafReaderView(startPage: ayah.page, store: store)) {
                        HStack(spacing: 12) {
                            Image(systemName: "book.pages.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.green.opacity(0.10)))
                            VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 3) {
                                Text(SariStrings.t("continueReading", language)).font(.headline)
                                Text("\(ayah.sura_name_ar) • \(localizedPage(ayah.page))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section(SariContentText.pick(language, [
                .ar: "سور القرآن الكريم", .en: "Quran Surahs", .tr: "Kur'an Sureleri", .ms: "Surah Al-Quran",
                .id: "Surah Al-Qur'an", .ja: "クルアーンの章", .zh: "古兰经章节", .ru: "Суры Корана", .fr: "Sourates du Coran"
            ])) {
                ForEach(store.surahs) { surah in
                    NavigationLink(destination: SurahReaderView(surah: surah, store: store)) {
                        HStack(spacing: 14) {
                            Text("\(surah.id)")
                                .font(.caption.bold())
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.green.opacity(0.11)))
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(surah.nameAR).font(.headline)
                                Text("\(surah.nameEN) • \(surah.ayahCount) • \(localizedPage(surah.firstPage))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            TextField(SariUIStrings.text("search_quran_name", language), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding()
                .multilineTextAlignment(language.isArabic ? .trailing : .leading)
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    SariUIStrings.text("quran_search", language),
                    systemImage: "magnifyingglass",
                    description: Text(SariUIStrings.text("quran_search_hint", language))
                )
            } else {
                List(store.search(query)) { ayah in
                    NavigationLink(destination: MushafReaderView(startPage: ayah.page, initialAyah: ayah, store: store)) {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("\(ayah.sura_name_ar) • \(ayah.ayah)").font(.headline)
                            Text(ayah.text)
                                .font(.custom("kfgqpchafsuthmanicscript-Reg", size: 21))
                                .lineLimit(3)
                                .multilineTextAlignment(.trailing)
                            Text("\(localizedPage(ayah.page)) • Juz \(ayah.juz)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var bookmarksView: some View {
        let saved = store.ayat.filter { store.bookmarks.contains($0.id) }
        return Group {
            if saved.isEmpty {
                ContentUnavailableView(
                    SariUIStrings.text("no_bookmarks", language),
                    systemImage: "bookmark",
                    description: Text(SariUIStrings.text("quran_no_saved_hint", language))
                )
            } else {
                List(saved) { ayah in
                    NavigationLink(destination: MushafReaderView(startPage: ayah.page, initialAyah: ayah, store: store)) {
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("\(ayah.sura_name_ar) • \(ayah.ayah)").font(.headline)
                            Text(ayah.text)
                                .font(.custom("kfgqpchafsuthmanicscript-Reg", size: 20))
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func localizedPage(_ page: Int) -> String {
        SariContentText.pick(language, [
            .ar: "صفحة \(page)", .en: "Page \(page)", .tr: "Sayfa \(page)", .ms: "Halaman \(page)",
            .id: "Halaman \(page)", .ja: "\(page)ページ", .zh: "第\(page)页", .ru: "Страница \(page)", .fr: "Page \(page)"
        ])
    }
}

struct SurahReaderView: View {
    let surah: SurahSummary
    @ObservedObject var store: QuranStore

    var body: some View {
        MushafReaderView(startPage: surah.firstPage, store: store)
            .navigationTitle(surah.nameAR)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct MushafReaderView: View {
    let startPage: Int
    let initialAyah: Ayah?
    @ObservedObject var store: QuranStore

    @AppStorage("sariLanguage") private var languageRaw = ""
    @State private var currentPage: Int
    @State private var selectedAyah: Ayah?
    @State private var showPageJump = false
    @State private var pageInput = ""

    private var language: SariLanguage { SariLanguage(rawValue: languageRaw) ?? .device }

    init(startPage: Int, initialAyah: Ayah? = nil, store: QuranStore) {
        self.startPage = min(max(startPage, 1), 604)
        self.initialAyah = initialAyah
        self.store = store
        _currentPage = State(initialValue: min(max(startPage, 1), 604))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            TabView(selection: $currentPage) {
                ForEach(1...604, id: \.self) { page in
                    MushafPageView(
                        page: page,
                        ayat: store.ayat(onPage: page),
                        isActive: abs(page - currentPage) <= 1
                    )
                    .tag(page)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .bottom) { pageControls }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    let pageAyat = store.ayat(onPage: currentPage)
                    if pageAyat.isEmpty {
                        Text(noAyatLabel)
                    } else {
                        ForEach(pageAyat) { ayah in
                            Button {
                                store.markRead(ayah.id)
                                selectedAyah = ayah
                            } label: {
                                Text("\(ayah.sura_name_ar) • \(ayah.ayah)")
                            }
                        }
                    }
                } label: {
                    Label(pageAyatLabel, systemImage: "text.book.closed")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    pageInput = "\(currentPage)"
                    showPageJump = true
                } label: {
                    Label(pageLabel, systemImage: "number.square")
                }
            }
        }
        .sheet(item: $selectedAyah) { ayah in
            TafsirSheet(ayah: ayah, store: store)
        }
        .alert(pageJumpTitle, isPresented: $showPageJump) {
            TextField("1–604", text: $pageInput)
                .keyboardType(.numberPad)
            Button(SariUIStrings.text("cancel", language), role: .cancel) {}
            Button(goLabel) {
                if let value = Int(pageInput), (1...604).contains(value) {
                    withAnimation { currentPage = value }
                }
            }
        } message: {
            Text(pageJumpMessage)
        }
        .onAppear {
            if let initialAyah {
                selectedAyah = initialAyah
                store.markRead(initialAyah.id)
            } else if let first = store.ayat(onPage: currentPage).first {
                store.markRead(first.id)
            }
        }
        .onChange(of: currentPage) { _, newPage in
            if let first = store.ayat(onPage: newPage).first { store.markRead(first.id) }
            Task {
                let nearby = (max(1, newPage - 2)...min(604, newPage + 2))
                    .filter { $0 != newPage }
                await MushafPageRepository.shared.prefetch(pages: nearby)
            }
        }
        .task {
            let nearby = (max(1, currentPage - 2)...min(604, currentPage + 2))
                .filter { $0 != currentPage }
            await MushafPageRepository.shared.prefetch(pages: nearby)
        }
        .sariLanguageEnvironment(language)
    }

    private var pageControls: some View {
        HStack(spacing: 18) {
            Button {
                guard currentPage > 1 else { return }
                withAnimation { currentPage -= 1 }
            } label: {
                Image(systemName: "chevron.backward")
                    .frame(width: 42, height: 38)
            }
            .disabled(currentPage <= 1)

            Button {
                pageInput = "\(currentPage)"
                showPageJump = true
            } label: {
                VStack(spacing: 1) {
                    Text(pageLabel).font(.subheadline.bold())
                    Text("\(currentPage) / 604").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(minWidth: 110)
            }
            .buttonStyle(.plain)

            Button {
                guard currentPage < 604 else { return }
                withAnimation { currentPage += 1 }
            } label: {
                Image(systemName: "chevron.forward")
                    .frame(width: 42, height: 38)
            }
            .disabled(currentPage >= 604)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
    }

    private var pageLabel: String {
        SariContentText.pick(language, [
            .ar: "صفحة \(currentPage)", .en: "Page \(currentPage)", .tr: "Sayfa \(currentPage)", .ms: "Halaman \(currentPage)",
            .id: "Halaman \(currentPage)", .ja: "\(currentPage)ページ", .zh: "第\(currentPage)页", .ru: "Страница \(currentPage)", .fr: "Page \(currentPage)"
        ])
    }

    private var pageJumpTitle: String {
        SariContentText.pick(language, [
            .ar: "الانتقال إلى صفحة", .en: "Go to page", .tr: "Sayfaya git", .ms: "Pergi ke halaman", .id: "Buka halaman",
            .ja: "ページへ移動", .zh: "前往页面", .ru: "Перейти к странице", .fr: "Aller à la page"
        ])
    }

    private var pageJumpMessage: String {
        SariContentText.pick(language, [
            .ar: "أدخل رقم صفحة من 1 إلى 604", .en: "Enter a page number from 1 to 604", .tr: "1–604 arasında sayfa numarası girin",
            .ms: "Masukkan nombor halaman 1 hingga 604", .id: "Masukkan nomor halaman 1–604", .ja: "1〜604のページ番号を入力してください",
            .zh: "请输入1到604的页码", .ru: "Введите номер страницы от 1 до 604", .fr: "Entrez un numéro de page de 1 à 604"
        ])
    }

    private var goLabel: String {
        SariContentText.pick(language, [
            .ar: "انتقال", .en: "Go", .tr: "Git", .ms: "Pergi", .id: "Buka", .ja: "移動", .zh: "前往", .ru: "Перейти", .fr: "Aller"
        ])
    }

    private var pageAyatLabel: String {
        SariContentText.pick(language, [
            .ar: "آيات الصفحة", .en: "Page verses", .tr: "Sayfa ayetleri", .ms: "Ayat halaman", .id: "Ayat halaman",
            .ja: "このページの節", .zh: "本页经文", .ru: "Аяты страницы", .fr: "Versets de la page"
        ])
    }

    private var noAyatLabel: String {
        SariContentText.pick(language, [
            .ar: "لا توجد بيانات آيات لهذه الصفحة", .en: "No verse data for this page", .tr: "Bu sayfa için ayet verisi yok",
            .ms: "Tiada data ayat untuk halaman ini", .id: "Tidak ada data ayat untuk halaman ini", .ja: "このページの節データがありません",
            .zh: "本页没有经文数据", .ru: "Нет данных аятов для этой страницы", .fr: "Aucune donnée de verset pour cette page"
        ])
    }
}

private struct MushafPageView: View {
    let page: Int
    let ayat: [Ayah]
    let isActive: Bool

    @AppStorage("sariLanguage") private var languageRaw = ""
    @State private var svgData: Data?
    @State private var failed = false
    @State private var retryToken = 0

    private var language: SariLanguage { SariLanguage(rawValue: languageRaw) ?? .device }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

            if let svgData {
                MushafSVGWebView(data: svgData)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(2)
            } else if failed {
                fallbackView
                    .padding(14)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(loadingLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .task(id: "\(page)-\(isActive)-\(retryToken)") {
            guard isActive, svgData == nil else { return }
            failed = false
            do {
                svgData = try await MushafPageRepository.shared.svgData(for: page)
            } catch {
                failed = true
            }
        }
    }

    private var fallbackView: some View {
        VStack(spacing: 12) {
            Label(exactPageUnavailableLabel, systemImage: "wifi.exclamationmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .trailing, spacing: 12) {
                    ForEach(ayat) { ayah in
                        Text(ayah.text)
                            .font(.custom("kfgqpchafsuthmanicscript-Reg", size: 23))
                            .lineSpacing(5)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .environment(\.layoutDirection, .rightToLeft)

            Button {
                svgData = nil
                failed = false
                retryToken += 1
            } label: {
                Label(retryLabel, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var loadingLabel: String {
        SariContentText.pick(language, [
            .ar: "تحميل صفحة المصحف الدقيقة…", .en: "Loading the exact Mushaf page…", .tr: "Tam Mushaf sayfası yükleniyor…",
            .ms: "Memuat halaman Mushaf tepat…", .id: "Memuat halaman Mushaf presisi…", .ja: "正確なムシャフページを読み込み中…",
            .zh: "正在加载精确的穆斯哈夫页面…", .ru: "Загрузка точной страницы мусхафа…", .fr: "Chargement de la page exacte du Moushaf…"
        ])
    }

    private var exactPageUnavailableLabel: String {
        SariContentText.pick(language, [
            .ar: "الصفحة المطابقة لم تُحفظ على الجهاز بعد. يظهر النص المحلي مؤقتًا.",
            .en: "The exact page is not cached on this device yet. Local text is shown temporarily.",
            .tr: "Tam sayfa henüz cihazda önbelleğe alınmadı. Yerel metin geçici olarak gösteriliyor.",
            .ms: "Halaman tepat belum disimpan pada peranti. Teks tempatan dipaparkan sementara.",
            .id: "Halaman presisi belum tersimpan di perangkat. Teks lokal ditampilkan sementara.",
            .ja: "正確なページはまだ端末に保存されていません。一時的にローカル本文を表示します。",
            .zh: "精确页面尚未缓存在设备上，暂时显示本地文本。",
            .ru: "Точная страница ещё не сохранена на устройстве; временно показан локальный текст.",
            .fr: "La page exacte n’est pas encore en cache sur l’appareil ; le texte local est affiché temporairement."
        ])
    }

    private var retryLabel: String {
        SariContentText.pick(language, [
            .ar: "إعادة المحاولة", .en: "Retry", .tr: "Tekrar dene", .ms: "Cuba lagi", .id: "Coba lagi",
            .ja: "再試行", .zh: "重试", .ru: "Повторить", .fr: "Réessayer"
        ])
    }
}

private struct MushafSVGWebView: UIViewRepresentable {
    let data: Data

    final class Coordinator {
        var lastData: Data?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastData != data else { return }
        context.coordinator.lastData = data
        let encoded = data.base64EncodedString()
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
          <style>
            html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:transparent;}
            img{display:block;width:100%;height:100%;object-fit:contain;object-position:center;}
          </style>
        </head>
        <body><img alt="Mushaf page" src="data:image/svg+xml;base64,\(encoded)"></body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

struct AyahDetailView: View {
    let ayah: Ayah
    @ObservedObject var store: QuranStore

    var body: some View {
        MushafReaderView(startPage: ayah.page, initialAyah: ayah, store: store)
    }
}

struct TafsirSheet: View {
    let ayah: Ayah
    @ObservedObject var store: QuranStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sariLanguage") private var languageRaw = ""
    @StateObject private var translated = TafsirTranslationStore()

    private var language: SariLanguage { SariLanguage(rawValue: languageRaw) ?? .device }
    private var translatedText: String? { translated.translatedTafsir(for: ayah) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .trailing, spacing: 18) {
                    Text(ayah.text)
                        .font(.custom("kfgqpchafsuthmanicscript-Reg", size: 27))
                        .lineSpacing(7)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(spacing: 8) {
                        Label("\(ayah.sura_name_ar) • \(ayah.ayah)", systemImage: "book.pages")
                        Spacer()
                        Text("\(ayah.page)").foregroundStyle(.secondary)
                    }
                    .font(.caption)

                    Divider()

                    Label(tafsirTitle, systemImage: "text.book.closed.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)

                    if let translatedText, !translatedText.isEmpty, language != .ar {
                        Text(translatedText)
                            .font(.body)
                            .lineSpacing(6)
                            .multilineTextAlignment(language.isArabic ? .trailing : .leading)
                            .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)

                        DisclosureGroup(arabicOriginalLabel) {
                            Text(ayah.tafseer)
                                .lineSpacing(6)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.top, 8)
                        }
                    } else {
                        Text(ayah.tafseer)
                            .font(.body)
                            .lineSpacing(6)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        if language != .ar {
                            Label(noVerifiedTranslationNote, systemImage: "checkmark.shield")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("\(ayah.sura_name_ar) • \(ayah.ayah)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.toggleBookmark(ayah.id)
                    } label: {
                        Image(systemName: store.bookmarks.contains(ayah.id) ? "bookmark.fill" : "bookmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(SariUIStrings.text("done", language)) { dismiss() }
                }
            }
        }
        .onAppear {
            store.markRead(ayah.id)
            translated.load(language.rawValue)
        }
        .onChange(of: languageRaw) { _, _ in translated.load(language.rawValue) }
        .sariLanguageEnvironment(language)
    }

    private var tafsirTitle: String {
        SariContentText.pick(language, [
            .ar: "التفسير الميسر", .en: "Tafseer Muyassar", .tr: "Tefsir-i Müyeser", .ms: "Tafsir Muyassar",
            .id: "Tafsir Muyassar", .ja: "タフスィール・ムヤッサル", .zh: "简明经注", .ru: "Тафсир аль-Муяссар", .fr: "Tafsir Al-Muyassar"
        ])
    }

    private var arabicOriginalLabel: String {
        SariContentText.pick(language, [
            .ar: "النص العربي الأصلي", .en: "Original Arabic tafsir", .tr: "Arapça asıl tefsir", .ms: "Tafsir Arab asal",
            .id: "Tafsir Arab asli", .ja: "アラビア語原文", .zh: "阿拉伯语原文", .ru: "Оригинал на арабском", .fr: "Tafsir arabe original"
        ])
    }

    private var noVerifiedTranslationNote: String {
        SariContentText.pick(language, [
            .ar: "يعرض النص العربي الموثوق حتى تتوفر حزمة ترجمة موثقة لهذه اللغة.",
            .en: "The verified Arabic source is shown until a verified translation pack is installed for this language.",
            .tr: "Bu dil için doğrulanmış çeviri paketi kurulana kadar güvenilir Arapça kaynak gösterilir.",
            .ms: "Sumber Arab yang disahkan dipaparkan sehingga pek terjemahan yang disahkan dipasang.",
            .id: "Sumber Arab terverifikasi ditampilkan sampai paket terjemahan terverifikasi dipasang.",
            .ja: "この言語の検証済み翻訳パックが導入されるまで、検証済みアラビア語原文を表示します。",
            .zh: "在安装该语言的可靠翻译包之前，先显示经核验的阿拉伯语原文。",
            .ru: "Пока проверенный перевод для этого языка не установлен, показывается проверенный арабский оригинал.",
            .fr: "La source arabe vérifiée est affichée jusqu'à l'installation d'une traduction vérifiée pour cette langue."
        ])
    }
}
