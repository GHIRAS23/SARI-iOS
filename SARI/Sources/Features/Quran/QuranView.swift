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
    @Published private(set) var isLoaded = false
    @Published private(set) var loadError: String?
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
        isLoaded = false
        loadError = nil

        guard let url = Bundle.main.sariResourceURL(
            name: "quran_tafseer",
            extension: "json",
            subdirectory: "data"
        ) else {
            loadError = "Missing bundled quran_tafseer.json"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Ayah].self, from: data)
            let expectedIDs = Set(1...6_236)
            let decodedIDs = Set(decoded.map(\.id))

            guard decoded.count == 6_236,
                  decodedIDs == expectedIDs,
                  Set(decoded.map(\.sura)) == Set(1...114),
                  Set(decoded.map(\.page)) == Set(1...604),
                  decoded.allSatisfy({
                      (1...114).contains($0.sura) &&
                      (1...604).contains($0.page) &&
                      $0.ayah > 0 &&
                      !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                      !$0.tafseer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  }) else {
                loadError = "Quran data failed the 6,236-ayah integrity check"
                return
            }

            let ordered = decoded.sorted { $0.id < $1.id }
            ayat = ordered
            pageIndex = Dictionary(grouping: ordered, by: \.page)
            surahs = Dictionary(grouping: ordered, by: \.sura)
                .map { key, rows in
                    let first = rows[0]
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
            isLoaded = true
        } catch {
            loadError = "Unable to decode bundled Quran data: \(error.localizedDescription)"
        }
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
            Group {
                if store.isLoaded {
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
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text(SariContentText.pick(language, [
                            .ar: "تعذر تحميل بيانات المصحف",
                            .en: "Unable to load Quran data",
                            .tr: "Kur’an verileri yüklenemedi",
                            .ms: "Data al-Quran tidak dapat dimuat",
                            .id: "Data Al-Qur'an tidak dapat dimuat",
                            .ja: "クルアーンのデータを読み込めません",
                            .zh: "无法加载古兰经数据",
                            .ru: "Не удалось загрузить данные Корана",
                            .fr: "Impossible de charger les données du Coran"
                        ]))
                        .font(.headline)
                        Text(SariContentText.pick(language, [
                            .ar: "تحقق من وجود ملف بيانات المصحف وسلامته، ثم أعد المحاولة.",
                            .en: "Check that the bundled Quran data file exists and is valid, then retry.",
                            .tr: "Kur’an veri dosyasının bulunduğunu ve geçerli olduğunu kontrol edip yeniden deneyin.",
                            .ms: "Pastikan fail data al-Quran tersedia dan sah, kemudian cuba lagi.",
                            .id: "Pastikan berkas data Al-Qur'an tersedia dan valid, lalu coba lagi.",
                            .ja: "クルアーンのデータファイルを確認して、もう一度お試しください。",
                            .zh: "请检查古兰经数据文件是否存在且有效，然后重试。",
                            .ru: "Проверьте наличие и целостность файла данных Корана и повторите попытку.",
                            .fr: "Vérifiez que le fichier de données du Coran existe et est valide, puis réessayez."
                        ]))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        Button(SariContentText.pick(language, [
                            .ar: "إعادة المحاولة", .en: "Retry", .tr: "Tekrar dene", .ms: "Cuba lagi",
                            .id: "Coba lagi", .ja: "再試行", .zh: "重试", .ru: "Повторить", .fr: "Réessayer"
                        ])) { store.load() }
                        .buttonStyle(.borderedProminent)
                    }
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @State private var selectionResetToken = 0
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
                        isActive: abs(page - currentPage) <= 1,
                        resetToken: selectionResetToken,
                        onSelectAyah: { ayah in
                            store.markRead(ayah.id)
                            selectedAyah = ayah
                        }
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
                    Label(pageAyatLabel, systemImage: "text.book.closed.fill")
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
        .sheet(item: $selectedAyah, onDismiss: {
            selectionResetToken += 1
        }) { ayah in
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
            .ar: "اختيار آية للتفسير", .en: "Select an ayah for Tafsir", .tr: "Tefsir için ayet seçin",
            .ms: "Pilih ayat untuk tafsir", .id: "Pilih ayat untuk tafsir", .ja: "タフスィールする節を選択",
            .zh: "选择经文查看注释", .ru: "Выбрать аят для тафсира", .fr: "Choisir un verset pour le tafsir"
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
    let resetToken: Int
    let onSelectAyah: (Ayah) -> Void

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
                MushafSVGWebView(data: svgData, resetToken: resetToken) { surahNumber, ayahNumber in
                    guard let tappedAyah = ayat.first(where: {
                        $0.sura == surahNumber && $0.ayah == ayahNumber
                    }) else { return }
                    onSelectAyah(tappedAyah)
                }
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
                        Button {
                            onSelectAyah(ayah)
                        } label: {
                            VStack(alignment: .trailing, spacing: 6) {
                                Text(ayah.text)
                                    .font(.custom("kfgqpchafsuthmanicscript-Reg", size: 23))
                                    .lineSpacing(5)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                Label(tafsirActionLabel, systemImage: "text.book.closed")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .background(Color.green.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
            }

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

    private var tafsirActionLabel: String {
        SariContentText.pick(language, [
            .ar: "عرض التفسير الميسر", .en: "View Tafsir Muyassar", .tr: "Tefsir-i Müyeser'i görüntüle",
            .ms: "Lihat Tafsir Muyassar", .id: "Lihat Tafsir Muyassar", .ja: "タフスィール・ムヤッサルを表示",
            .zh: "查看简明注释", .ru: "Открыть тафсир аль-Муяссар", .fr: "Voir le Tafsir Muyassar"
        ])
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
            .ar: "الصفحة المطابقة لم تُحفظ على الجهاز بعد. يمكنك اختيار الآية لفتح تفسيرها.",
            .en: "The exact page is not cached yet. Select an ayah below to open its Tafsir.",
            .tr: "Tam sayfa henüz önbelleğe alınmadı. Tefsirini açmak için aşağıdan bir ayet seçin.",
            .ms: "Halaman tepat belum dicache. Pilih ayat di bawah untuk melihat tafsirnya.",
            .id: "Halaman presisi belum tersimpan. Pilih ayat di bawah untuk membuka tafsirnya.",
            .ja: "正確なページはまだ保存されていません。下から節を選んで注釈を開いてください。",
            .zh: "精确页面尚未缓存。请从下方选择经文查看注释。",
            .ru: "Точная страница ещё не сохранена. Выберите аят ниже, чтобы открыть тафсир.",
            .fr: "La page exacte n’est pas encore en cache. Choisissez un verset ci-dessous pour ouvrir son tafsir."
        ])
    }

    private var retryLabel: String {
        SariContentText.pick(language, [
            .ar: "إعادة المحاولة", .en: "Retry", .tr: "Tekrar dene", .ms: "Cuba lagi", .id: "Coba lagi",
            .ja: "再試行", .zh: "重试", .ru: "Повторить", .fr: "Réessayer"
        ])
    }
}

/// Displays the original SVG inline so its transparent ayah polygons can receive taps.
/// The SVG's visible glyph paths ignore pointer events, allowing the ayah hit-layer below
/// them to identify the exact surah/ayah pair. A native page-ayah menu remains available
/// as an accessible fallback when an artwork page has no hit-layer.
private struct MushafSVGWebView: UIViewRepresentable {
    let data: Data
    let resetToken: Int
    let onAyahTap: (Int, Int) -> Void

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        var lastData: Data?
        var lastResetToken = 0
        var onAyahTap: ((Int, Int) -> Void)?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "ayahTap",
                  let payload = message.body as? [String: Any],
                  let surahNumber = (payload["surah"] as? NSNumber)?.intValue,
                  let ayahNumber = (payload["ayah"] as? NSNumber)?.intValue,
                  (1...114).contains(surahNumber),
                  (1...286).contains(ayahNumber) else { return }

            onAyahTap?(surahNumber, ayahNumber)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "ayahTap")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.panGestureRecognizer.isEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isUserInteractionEnabled = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onAyahTap = onAyahTap
        if context.coordinator.lastResetToken != resetToken {
            context.coordinator.lastResetToken = resetToken
            webView.evaluateJavaScript("window.sariClearSelection && window.sariClearSelection();", completionHandler: nil)
        }
        guard context.coordinator.lastData != data else { return }
        context.coordinator.lastData = data

        let encoded = data.base64EncodedString()
        let html = """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:;">
          <style>
            html,body,#stage{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:transparent;}
            #stage{display:flex;align-items:center;justify-content:center;}
            #stage svg{display:block;width:100%;height:100%;max-width:100%;max-height:100%;object-fit:contain;}
            .ayahPolygon{fill:#000000;fill-opacity:0.001;pointer-events:all;cursor:pointer;}
            .ayahPolygon.sari-selected{fill:#D5B66A;fill-opacity:0.22;}
          </style>
        </head>
        <body>
          <div id="stage" aria-label="Interactive Quran page"></div>
          <script>
            (() => {
              const svgBase64 = '\(encoded)';
              const bytes = Uint8Array.from(atob(svgBase64), character => character.charCodeAt(0));
              const svgText = new TextDecoder('utf-8').decode(bytes);
              const parsed = new DOMParser().parseFromString(svgText, 'image/svg+xml');
              const parsedRoot = parsed.documentElement;
              const stage = document.getElementById('stage');

              if (!parsedRoot || parsedRoot.localName.toLowerCase() !== 'svg' || parsed.querySelector('parsererror')) {
                stage.textContent = 'Unable to render this Quran page.';
                return;
              }

              // Keep the SVG self-contained and prevent embedded markup from executing.
              parsedRoot.querySelectorAll('script, foreignObject, iframe, object, embed').forEach(node => node.remove());
              [parsedRoot, ...parsedRoot.querySelectorAll('*')].forEach(element => {
                Array.from(element.attributes).forEach(attribute => {
                  const name = attribute.name.toLowerCase();
                  const value = attribute.value.trim();
                  if (name.startsWith('on')) element.removeAttribute(attribute.name);
                  if ((name === 'href' || name.endsWith(':href')) && value && !value.startsWith('#') && !value.startsWith('data:')) {
                    element.removeAttribute(attribute.name);
                  }
                });
              });

              const svgRoot = document.importNode(parsedRoot, true);
              svgRoot.style.width = '100%';
              svgRoot.style.height = '100%';
              svgRoot.setAttribute('preserveAspectRatio', 'xMidYMid meet');

              // The artwork draws glyph paths over the transparent hit polygons.
              // Disable hit testing on glyphs so taps reach the matching ayah polygon.
              svgRoot.querySelectorAll('path:not(.ayahPolygon), text, use, image, line, polyline, polygon, rect, circle, ellipse').forEach(element => {
                element.style.pointerEvents = 'none';
              });

              const hitTargets = Array.from(svgRoot.querySelectorAll('.ayahPolygon'));
              hitTargets.forEach(element => {
                element.style.pointerEvents = 'all';
                element.style.fill = '#000000';
                element.style.fillOpacity = '0.001';
              });

              let selectedPolygon = null;
              const LONG_PRESS_MS = 450;
              const MOVE_CANCEL_PX = 12;
              let pressTimer = null;
              let pressX = 0;
              let pressY = 0;
              const polygonAt = event => {
                const target = event.target instanceof Element ? event.target : null;
                return target && target.closest ? target.closest('.ayahPolygon') : null;
              };
              const clearPress = () => {
                if (pressTimer) { clearTimeout(pressTimer); pressTimer = null; }
              };
              window.sariClearSelection = function () {
                if (selectedPolygon) {
                  selectedPolygon.classList.remove('sari-selected');
                  selectedPolygon.style.fillOpacity = '0.001';
                  selectedPolygon = null;
                }
              };
              svgRoot.addEventListener('pointerdown', event => {
                clearPress();
                const polygon = polygonAt(event);
                if (!polygon) return;
                pressX = event.clientX;
                pressY = event.clientY;
                pressTimer = setTimeout(() => {
                  pressTimer = null;
                  const surah = Number(polygon.getAttribute('surah'));
                  const ayah = Number(polygon.getAttribute('ayah'));
                  if (!Number.isInteger(surah) || !Number.isInteger(ayah)) return;
                  if (surah < 1 || surah > 114 || ayah < 1 || ayah > 286) return;
                  window.sariClearSelection();
                  selectedPolygon = polygon;
                  selectedPolygon.classList.add('sari-selected');
                  selectedPolygon.style.fillOpacity = '0.22';
                  window.webkit.messageHandlers.ayahTap.postMessage({ surah, ayah });
                }, LONG_PRESS_MS);
              }, true);
              svgRoot.addEventListener('pointermove', event => {
                if (Math.hypot(event.clientX - pressX, event.clientY - pressY) > MOVE_CANCEL_PX) clearPress();
              }, true);
              ['pointerup', 'pointercancel'].forEach(name =>
                svgRoot.addEventListener(name, clearPress, true));
              svgRoot.addEventListener('click', event => {
                if (polygonAt(event)) { event.preventDefault(); event.stopPropagation(); }
              }, true);
              document.documentElement.style.webkitTouchCallout = 'none';
              document.documentElement.style.webkitUserSelect = 'none';
              document.documentElement.style.userSelect = 'none';

              stage.replaceChildren(svgRoot);
              document.documentElement.style.touchAction = 'manipulation';
            })();
          </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "ayahTap")
        coordinator.onAyahTap = nil
        webView.stopLoading()
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
    @StateObject private var pack = LocalFiqhPack.shared
    @StateObject private var network = NetworkState.shared

    private var language: SariLanguage { SariLanguage(rawValue: languageRaw) ?? .device }

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

                    if language != .ar {
                        verseMeaningSection
                        Divider()
                        Label(arabicOriginalLabel, systemImage: "text.book.closed.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Text(ayah.tafseer)
                        .font(.body)
                        .lineSpacing(7)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
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
        }
        .task(id: "\(ayah.id)-\(languageRaw)") {
            translated.load(language)
        }
        .sariLanguageEnvironment(language)
    }

    @ViewBuilder
    private var verseMeaningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(verseMeaningTitle, systemImage: "character.book.closed")
                .font(.subheadline.weight(.semibold))

            switch translated.packState(for: "en") {
            case .downloading:
                workingRow(downloadingLabel)
            case .notInstalled, .failed:
                englishDownloadCard
            case .installed:
                installedMeaningContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var installedMeaningContent: some View {
        if language == .en {
            meaningBlock(translated.englishMeaning(for: ayah), note: englishSourceNote)
        } else if let text = translated.languageMeaning(for: ayah) {
            meaningBlock(text, note: languagePackNote)
        } else {
            languagePackOffer
            meaningBlock(translated.englishMeaning(for: ayah), note: englishShownNote)
            aiTranslationControls
        }
    }

    @ViewBuilder
    private func meaningBlock(_ text: String?, note: String) -> some View {
        if let text {
            Text(text)
                .font(.body)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(note)
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text(missingMeaningNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// First-run prompt: shown until the English file is installed, then never again.
    private var englishDownloadCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(englishDownloadNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            if translated.packState(for: "en") == .failed {
                Text(downloadFailedLabel)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if translated.isDownloadConfigured {
                Button {
                    Task { await translated.downloadPack("en") }
                } label: {
                    Label(downloadButtonLabel, systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text(notConfiguredLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var languagePackOffer: some View {
        let code = language.rawValue
        if translated.packState(for: code) == .downloading {
            workingRow(downloadingLabel)
        } else if translated.isDownloadConfigured {
            Button {
                Task { await translated.downloadPack(code) }
            } label: {
                Label(languagePackButton, systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var aiTranslationControls: some View {
        if translated.isTranslatingWithAI {
            workingRow(aiWorkingLabel)
        } else if let ai = translated.aiTranslation {
            Divider()
            Text(ai)
                .font(.body)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(aiNote)
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if pack.readyForInference {
            Button {
                Task { await translated.translateWithLocalModel(for: ayah) }
            } label: {
                Label(aiButtonLabel, systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if translated.aiTranslationFailed {
                Text(aiFailedLabel)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } else {
            Text(aiPackNeededNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func workingRow(_ title: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(title)
                .font(.caption)
        }
    }

    private func localized(_ ar: String, _ en: String) -> String {
        SariContentText.pick(language, [.ar: ar, .en: en])
    }

    private var downloadingLabel: String {
        localized("جارٍ تنزيل الملف…", "Downloading the file…")
    }

    private var englishDownloadNote: String {
        localized(
            "ملف معاني التفسير الإنجليزي غير مثبت. نزّله مرة واحدة، وبعدها يعمل بدون إنترنت. التفسير العربي متاح دائمًا.",
            "The English meaning file is not installed yet. Download it once; after that it works offline. The Arabic tafsir is always available."
        )
    }

    private var downloadButtonLabel: String {
        localized("تنزيل ملف التفسير مرة واحدة", "Download the tafsir file once")
    }

    private var downloadFailedLabel: String {
        localized("تعذر التنزيل. تحقق من الاتصال ثم أعد المحاولة.", "Download failed. Check your connection and try again.")
    }

    private var notConfiguredLabel: String {
        localized(
            "رابط تنزيل ملفات التفسير غير مُعدّ في هذه النسخة.",
            "The tafsir file download address is not configured in this build."
        )
    }

    private var englishShownNote: String {
        localized(
            "المعنى معروض بالإنجليزية لأن ترجمة هذه اللغة غير مثبتة.",
            "The meaning is shown in English because this language's pack is not installed."
        )
    }

    private var languagePackNote: String {
        localized("ترجمة معتمدة من حزمة اللغة المثبتة.", "Translation from the installed language pack.")
    }

    private var languagePackButton: String {
        localized("تنزيل ترجمة هذه اللغة (اختياري)", "Download this language's translation (optional)")
    }

    private var aiButtonLabel: String {
        localized("ترجمة محلية بالذكاء الاصطناعي (احتياطي)", "Translate on-device with AI (fallback)")
    }

    private var aiWorkingLabel: String {
        localized("جارٍ الترجمة محليًا…", "Translating on-device…")
    }

    private var aiNote: String {
        localized(
            "ترجمة آلية محلية من الإنجليزية؛ راجع الأصل عند الحاجة.",
            "On-device machine translation from English; check the source when needed."
        )
    }

    private var aiFailedLabel: String {
        localized("تعذرت الترجمة المحلية.", "On-device translation failed.")
    }

    private var aiPackNeededNote: String {
        localized(
            "للترجمة المحلية بالذكاء الاصطناعي ثبّت حزمة المساعد الفقهي أولًا.",
            "For on-device AI translation, install the fiqh assistant pack first."
        )
    }

    private var missingMeaningNote: String {
        localized("المعنى غير متوفر لهذه الآية في الملف المثبت.", "No meaning for this verse in the installed file.")
    }

    private var verseMeaningTitle: String { SariContentText.pick(language, [
        .ar: "ترجمة معنى الآية", .en: "Translation of the verse's meaning", .tr: "Ayetin anlamının çevirisi",
        .ms: "Terjemahan maksud ayat", .id: "Terjemahan makna ayat", .ja: "節の意味の翻訳",
        .zh: "经文含义的翻译", .ru: "Перевод смысла аята", .fr: "Traduction du sens du verset"
    ]) }

    private var translationPreparingLabel: String { SariContentText.pick(language, [
        .ar: "جارٍ تنزيل المرجع الإنجليزي وإعداد الترجمة…", .en: "Downloading the English source and preparing the translation…",
        .tr: "İngilizce kaynak indiriliyor ve çeviri hazırlanıyor…", .ms: "Memuat turun sumber Inggeris dan menyediakan terjemahan…",
        .id: "Mengunduh sumber bahasa Inggris dan menyiapkan terjemahan…", .ja: "英語の出典をダウンロードし、翻訳を準備中…",
        .zh: "正在下载英文来源并准备翻译…", .ru: "Загрузка английского источника и подготовка перевода…",
        .fr: "Téléchargement de la source anglaise et préparation de la traduction…"
    ]) }

    private var modelSetupButton: String { SariContentText.pick(language, [
        .ar: "تنزيل النموذج المطلوب مرة واحدة", .en: "Download the required model once", .tr: "Gerekli modeli bir kez indir",
        .ms: "Muat turun model yang diperlukan sekali", .id: "Unduh model yang diperlukan sekali", .ja: "必要なモデルを一度ダウンロード",
        .zh: "一次性下载所需模型", .ru: "Скачать необходимую модель один раз", .fr: "Télécharger le modèle requis une fois"
    ]) }

    private var modelRequiredForTranslationNote: String { SariContentText.pick(language, [
        .ar: "تحتاج الترجمة التلقائية إلى تنزيل النموذج مرة واحدة عبر Wi‑Fi أو بيانات الجوال. بعدها تُنشأ الترجمات محليًا.",
        .en: "Automatic translation needs a one-time model download over Wi-Fi or cellular data. Translations are then generated on-device.",
        .tr: "Otomatik çeviri için Wi-Fi veya mobil veriyle modeli bir kez indirin. Sonrasında çeviriler cihazda oluşturulur.",
        .ms: "Terjemahan automatik memerlukan muat turun model sekali melalui Wi-Fi atau data selular. Selepas itu, terjemahan dijana pada peranti.",
        .id: "Terjemahan otomatis memerlukan unduhan model sekali melalui Wi-Fi atau data seluler. Setelah itu, terjemahan dibuat di perangkat.",
        .ja: "自動翻訳にはWi-Fiまたはモバイル通信でのモデルの初回ダウンロードが必要です。その後は端末内で翻訳します。",
        .zh: "自动翻译需要通过 Wi-Fi 或移动数据下载一次模型，之后会在设备本地生成翻译。",
        .ru: "Для автоматического перевода модель нужно один раз загрузить через Wi-Fi или мобильную сеть. Затем перевод создаётся на устройстве.",
        .fr: "La traduction automatique nécessite un téléchargement unique du modèle en Wi-Fi ou sur réseau mobile. Les traductions sont ensuite générées sur l’appareil."
    ]) }

    private var translationSourceNote: String { SariContentText.pick(language, [
        .ar: "ترجمة آلية لمعنى النص الإنجليزي لهلالي وخان؛ راجع الأصل العربي عند الحاجة.",
        .en: "Machine translation of the Hilali–Khan English meaning; consult the Arabic source when needed.",
        .tr: "Hilali–Khan İngilizce anlamının makine çevirisidir; gerektiğinde Arapça kaynağa başvurun.",
        .ms: "Terjemahan mesin bagi makna Inggeris Hilali–Khan; rujuk sumber Arab jika perlu.",
        .id: "Terjemahan mesin dari makna bahasa Inggris Hilali–Khan; periksa sumber Arab bila diperlukan.",
        .ja: "ヒラリー・カーン英訳の機械翻訳です。必要に応じてアラビア語原文を確認してください。",
        .zh: "这是对 Hilali–Khan 英文译义的机器翻译；如有需要，请参阅阿拉伯语原文。",
        .ru: "Машинный перевод английского перевода Хилали и Хана; при необходимости сверяйтесь с арабским оригиналом.",
        .fr: "Traduction automatique du sens anglais de Hilali–Khan ; consultez la source arabe si nécessaire."
    ]) }

    private var englishSourceNote: String { SariContentText.pick(language, [
        .ar: "المصدر الإنجليزي: ترجمة هلالي وخان لمعاني القرآن.",
        .en: "English source: the Hilali–Khan translation of the meanings of the Quran.",
        .tr: "İngilizce kaynak: Hilali–Khan Kur’an meali.",
        .ms: "Sumber bahasa Inggeris: terjemahan makna al-Quran oleh Hilali–Khan.",
        .id: "Sumber bahasa Inggris: terjemahan makna Al-Qur'an oleh Hilali–Khan.",
        .ja: "英語の出典：ヒラリー・カーンによるクルアーンの意味の翻訳。",
        .zh: "英文来源：Hilali–Khan《古兰经含义译本》。",
        .ru: "Английский источник: перевод смыслов Корана Хилали и Хана.",
        .fr: "Source anglaise : traduction du sens du Coran par Hilali et Khan."
    ]) }

    private var translationUnavailableNote: String { SariContentText.pick(language, [
        .ar: "تعذر تحميل النص الإنجليزي أو إعداد الترجمة. تحقق من الاتصال ثم أعد المحاولة.",
        .en: "The English source or translation could not be prepared. Check your connection and retry.",
        .tr: "İngilizce kaynak veya çeviri hazırlanamadı. Bağlantınızı kontrol edip yeniden deneyin.",
        .ms: "Sumber bahasa Inggeris atau terjemahan tidak dapat disediakan. Semak sambungan dan cuba lagi.",
        .id: "Sumber bahasa Inggris atau terjemahan gagal disiapkan. Periksa koneksi lalu coba lagi.",
        .ja: "英語の原文または翻訳を準備できませんでした。接続を確認して再試行してください。",
        .zh: "无法准备英文来源或翻译。请检查网络连接后重试。",
        .ru: "Не удалось подготовить английский источник или перевод. Проверьте подключение и повторите попытку.",
        .fr: "Impossible de préparer la source anglaise ou sa traduction. Vérifiez la connexion et réessayez."
    ]) }

    private var retryTranslationLabel: String { SariContentText.pick(language, [
        .ar: "إعادة المحاولة", .en: "Retry", .tr: "Yeniden dene", .ms: "Cuba lagi", .id: "Coba lagi",
        .ja: "再試行", .zh: "重试", .ru: "Повторить", .fr: "Réessayer"
    ]) }

    private var tafsirTitle: String {
        SariContentText.pick(language, [
            .ar: "التفسير الميسر", .en: "Tafseer Muyassar", .tr: "Tefsir-i Müyeser", .ms: "Tafsir Muyassar",
            .id: "Tafsir Muyassar", .ja: "タフスィール・ムヤッサル", .zh: "简明经注", .ru: "Тафсир аль-Муяссар", .fr: "Tafsir Al-Muyassar"
        ])
    }

    private var translatedMeaningLabel: String {
        SariContentText.pick(language, [
            .ar: "ترجمة معنى التفسير", .en: "Translation of the Tafsir meaning", .tr: "Tefsir anlamının çevirisi",
            .ms: "Terjemahan maksud tafsir", .id: "Terjemahan makna tafsir", .ja: "注釈の意味の翻訳",
            .zh: "注释含义的翻译", .ru: "Перевод смысла тафсира", .fr: "Traduction du sens du tafsir"
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
