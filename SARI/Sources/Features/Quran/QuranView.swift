import SwiftUI

struct Ayah: Codable, Identifiable, Hashable {
    let id: Int
    let juz: Int
    let page: Int
    let sura: Int
    let sura_name_ar: String
    let sura_name_en: String
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

    private let bookmarkKey = "sari.quran.bookmarks"
    private let lastReadKey = "sari.quran.lastRead"

    init() {
        loadPreferences()
        load()
    }

    func load() {
        guard let url = Bundle.main.url(forResource: "quran_tafseer", withExtension: "json", subdirectory: "data"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Ayah].self, from: data) else { return }
        ayat = decoded
        surahs = Dictionary(grouping: decoded, by: \.sura)
            .map { key, rows in
                let first = rows.first!
                return SurahSummary(id: key, nameAR: first.sura_name_ar, nameEN: first.sura_name_en, ayahCount: rows.count, firstPage: first.page, juz: first.juz)
            }
            .sorted { $0.id < $1.id }
    }

    func ayat(for surah: Int) -> [Ayah] { ayat.filter { $0.sura == surah } }
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
    @AppStorage("sariLanguage") private var languageRaw=""
    private var language:SariLanguage { SariLanguage(rawValue:languageRaw) ?? .device }
    @StateObject private var store = QuranStore()
    @State private var query = ""
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedSection) {
                    Text(language.isArabic ? SariUIStrings.text("surahs", SariLanguage.selected) : SariStrings.t("quran",language)).tag(0)
                    Text(SariStrings.t("search",language)).tag(1)
                    Text(SariStrings.t("bookmarks",language)).tag(2)
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
            .navigationTitle(SariStrings.t("quran",language))
            .toolbar {
                if let last = store.lastReadID, let ayah = store.ayah(id: last) {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(destination: AyahDetailView(ayah: ayah, store: store)) {
                            Label(SariUIStrings.text("last_read", SariLanguage.selected), systemImage: "bookmark.fill")
                        }
                    }
                }
            }
        }
    }

    private var surahList: some View {
        List {
            if let last = store.lastReadID, let ayah = store.ayah(id: last) {
                Section {
                    NavigationLink(destination: AyahDetailView(ayah: ayah, store: store)) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(SariStrings.t("continueReading",language)).font(.headline)
                                Text(SariUIStrings.format("surah_ayah",SariLanguage.selected,["surah":ayah.sura_name_ar,"ayah":"\(ayah.ayah)"]) + " • " + SariUIStrings.format("page_juz",SariLanguage.selected,["page":"\(ayah.page)","juz":""]))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section(language.isArabic ? SariUIStrings.text("surahs", SariLanguage.selected) : SariStrings.t("quran",language)) {
                ForEach(store.surahs) { surah in
                    NavigationLink(destination: SurahReaderView(surah: surah, store: store)) {
                        HStack(spacing: 14) {
                            Text("\(surah.id)")
                                .font(.caption.bold())
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color.green.opacity(0.12)))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(surah.nameAR).font(.headline)
                                Text("\(surah.nameEN) • " + SariUIStrings.format("ayah_number",SariLanguage.selected,["ayah":"\(surah.ayahCount)"]) + " • Juz \(surah.juz)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            TextField(SariUIStrings.text("search_quran_name",SariLanguage.selected), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding()
                .multilineTextAlignment(.trailing)
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(SariUIStrings.text("quran_search", SariLanguage.selected), systemImage: "magnifyingglass", description: Text(SariUIStrings.text("quran_search_hint", SariLanguage.selected)))
            } else {
                List(store.search(query)) { ayah in
                    NavigationLink(destination: AyahDetailView(ayah: ayah, store: store)) {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(SariUIStrings.format("surah_ayah",SariLanguage.selected,["surah":ayah.sura_name_ar,"ayah":"\(ayah.ayah)"])).font(.headline)
                            Text(ayah.text).lineLimit(3).multilineTextAlignment(.trailing)
                            Text(SariUIStrings.format("page_juz",SariLanguage.selected,["page":"\(ayah.page)","juz":"\(ayah.juz)"])).font(.caption).foregroundStyle(.secondary)
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
                ContentUnavailableView(SariUIStrings.text("no_bookmarks", SariLanguage.selected), systemImage: "bookmark", description: Text(SariUIStrings.text("quran_no_saved_hint", SariLanguage.selected)))
            } else {
                List(saved) { ayah in
                    NavigationLink(destination: AyahDetailView(ayah: ayah, store: store)) {
                        VStack(alignment: .trailing, spacing: 5) {
                            Text(SariUIStrings.format("surah_ayah",SariLanguage.selected,["surah":ayah.sura_name_ar,"ayah":"\(ayah.ayah)"])).font(.headline)
                            Text(ayah.text).lineLimit(2).multilineTextAlignment(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }
}

struct SurahReaderView: View {
    let surah: SurahSummary
    @ObservedObject var store: QuranStore
    @State private var selectedAyah: Ayah?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text(surah.nameAR).font(.largeTitle.bold())
                    Text("\(surah.nameEN) • " + SariUIStrings.format("ayah_number",SariLanguage.selected,["ayah":"\(surah.ayahCount)"]))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)

                ForEach(store.ayat(for: surah.id)) { ayah in
                    Button {
                        store.markRead(ayah.id)
                        selectedAyah = ayah
                    } label: {
                        VStack(alignment: .trailing, spacing: 10) {
                            HStack {
                                Button {
                                    store.toggleBookmark(ayah.id)
                                } label: {
                                    Image(systemName: store.bookmarks.contains(ayah.id) ? "bookmark.fill" : "bookmark")
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Text(SariUIStrings.format("ayah_number",SariLanguage.selected,["ayah":"\(ayah.ayah)"]))
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Capsule().fill(Color.green.opacity(0.10)))
                            }
                            Text(ayah.text)
                                .font(.system(size: 27, weight: .regular, design: .serif))
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundStyle(.primary)
                            Text(SariUIStrings.format("page_juz",SariLanguage.selected,["page":"\(ayah.page)","juz":"\(ayah.juz)"]) + " • " + SariUIStrings.text("tafsir",SariLanguage.selected))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(surah.nameAR)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAyah) { ayah in
            TafsirSheet(ayah: ayah, store: store)
        }
    }
}

struct AyahDetailView: View {
    let ayah: Ayah
    @ObservedObject var store: QuranStore

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 22) {
                HStack {
                    Button {
                        store.toggleBookmark(ayah.id)
                    } label: {
                        Label(store.bookmarks.contains(ayah.id) ? SariUIStrings.text("saved", SariLanguage.selected) : SariUIStrings.text("save", SariLanguage.selected), systemImage: store.bookmarks.contains(ayah.id) ? "bookmark.fill" : "bookmark")
                    }
                    Spacer()
                    Text(SariUIStrings.format("page_juz",SariLanguage.selected,["page":"\(ayah.page)","juz":"\(ayah.juz)"])).font(.caption).foregroundStyle(.secondary)
                }
                Text(ayah.text)
                    .font(.system(size: 30, design: .serif))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Divider()
                Label(SariStrings.t("tafsir", SariLanguage.selected), systemImage: "text.book.closed.fill").font(.title3.bold())
                Text(ayah.tafseer)
                    .font(.body)
                    .lineSpacing(6)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
        }
        .navigationTitle("\(ayah.sura_name_ar) • \(ayah.ayah)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.markRead(ayah.id) }
    }
}

struct TafsirSheet: View {
    let ayah: Ayah
    @ObservedObject var store: QuranStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .trailing, spacing: 18) {
                    Text(ayah.text)
                        .font(.system(size: 27, design: .serif))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Divider()
                    Text(SariStrings.t("tafsir", SariLanguage.selected)).font(.title3.bold())
                    Text(ayah.tafseer)
                        .lineSpacing(6)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding()
            }
            .navigationTitle("\(ayah.sura_name_ar) • \(ayah.ayah)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(store.bookmarks.contains(ayah.id) ? SariUIStrings.text("remove_save", SariLanguage.selected) : SariUIStrings.text("save", SariLanguage.selected)) { store.toggleBookmark(ayah.id) }
                }
                ToolbarItem(placement: .topBarTrailing) { Button(SariUIStrings.text("done", SariLanguage.selected)) { dismiss() } }
            }
        }
    }
}
