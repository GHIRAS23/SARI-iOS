import SwiftUI

@MainActor
final class LocalFoodGuideStore: ObservableObject {
    @Published private(set) var recipes: [LocalFoodRecipe] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private var activeRequestID: UUID?

    func load(countryCode: String) async {
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil
        defer { if activeRequestID == requestID { isLoading = false } }
        do {
            let freshRecipes = try await LocalFoodService.fetchRecipes(countryCode: countryCode)
            guard activeRequestID == requestID else { return }
            recipes = freshRecipes
        } catch let error as LocalFoodServiceError {
            guard activeRequestID == requestID else { return }
            recipes = []
            switch error {
            case .unsupportedCountry:
                errorMessage = SariTravelFeatureText.text(arabic: "مزود البيانات لا يغطي مطبخ هذه الدولة حاليًا. لن نعرض أطباقًا غير موثقة.", english: "The food provider does not cover this country's cuisine yet. Unverified dishes will not be shown.", language: SariLanguage.selected)
            case .noMeals:
                errorMessage = SariTravelFeatureText.text(arabic: "لا توجد أكلات متاحة من مصدر البيانات لهذه الوجهة.", english: "No dishes are currently available from the selected data provider.", language: SariLanguage.selected)
            case .invalidResponse:
                errorMessage = SariTravelFeatureText.text(arabic: "تعذر التحقق من بيانات الأكلات.", english: "The food data could not be verified.", language: SariLanguage.selected)
            }
        } catch {
            guard activeRequestID == requestID else { return }
            recipes = []
            errorMessage = SariTravelFeatureText.text(arabic: "تعذر الاتصال بمصدر الأكلات. تحقق من الإنترنت وحاول مجددًا.", english: "Could not connect to the food provider. Check your connection and try again.", language: SariLanguage.selected)
        }
    }
}

struct LocalFoodGuideView: View {
    let destination: TravelDestination
    @StateObject private var store = LocalFoodGuideStore()
    private var language: SariLanguage { SariLanguage.selected }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(title("أكلات محلية من قاعدة البيانات", "Local dishes from the food database")).font(.title3.bold())
                    Text(title("تعرض هذه الصفحة وصفات متاحة من مزود بيانات خارجي وليست ترتيبًا للأكثر شعبية. تختلف الوصفة بين المطاعم، ولا تعني معلومات الطبق أن كل نسخة منه حلال.", "This page displays recipes available from an external provider, not a popularity ranking. Restaurant recipes vary, and dish information does not mean every version is halal."))
                        .font(.subheadline).foregroundStyle(.secondary)
                }.foodCardStyle()

                if store.isLoading {
                    HStack { ProgressView(); Text(title("جاري تحميل الأكلات…", "Loading local dishes…")) }.foodCardStyle()
                }
                if let error = store.errorMessage {
                    VStack(spacing: 10) {
                        Label(error, systemImage: "info.circle").font(.subheadline).foregroundStyle(.secondary)
                        Button { Task { await store.load(countryCode: destination.code) } } label: {
                            Label(title("إعادة المحاولة", "Try again"), systemImage: "arrow.clockwise")
                        }.buttonStyle(.bordered)
                    }.foodCardStyle()
                }
                ForEach(store.recipes) { recipe in recipeCard(recipe) }
                Text(title("المصدر: TheMealDB. أسماء الأطباق والمكونات تُعرض كما وردت في قاعدة البيانات، وقد لا تتوفر تغطية لكل الدول.", "Source: TheMealDB. Dish names and ingredients are shown as supplied by the database; not every country is covered."))
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(18)
        }
        .navigationTitle(title("أكلات \(destination.name(language))", "Food in \(destination.name(language))"))
        .task(id: destination.code) { await store.load(countryCode: destination.code) }
        .sariLanguageEnvironment(language)
    }

    private func recipeCard(_ recipe: LocalFoodRecipe) -> some View {
        let risk = LocalFoodRiskChecker.assess(recipe.ingredients)
        return VStack(alignment: .leading, spacing: 10) {
            if let imageURL = recipe.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: Image(systemName: "fork.knife").frame(maxWidth: .infinity).frame(height: 120).background(Color.secondary.opacity(0.1))
                    case .empty: ProgressView().frame(maxWidth: .infinity).frame(height: 120)
                    @unknown default: EmptyView()
                    }
                }
                .frame(height: 170).clipped().clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Text(recipe.name).font(.headline)
            if let category = recipe.category, !category.isEmpty { Text(category).font(.caption).foregroundStyle(.secondary) }
            riskView(risk)
            if !recipe.ingredients.isEmpty {
                DisclosureGroup(title("المكونات المتاحة في الوصفة", "Ingredients listed in the recipe")) {
                    Text(recipe.ingredients.joined(separator: "، ")).font(.subheadline).foregroundStyle(.secondary).padding(.top, 6)
                }
            }
            if let instructions = recipe.instructions {
                DisclosureGroup(title("طريقة التحضير في المصدر", "Preparation instructions from source")) {
                    Text(instructions).font(.subheadline).foregroundStyle(.secondary).lineSpacing(3).padding(.top, 6)
                }
            }
            if let source = recipe.sourceURL {
                Link(title("فتح مصدر الوصفة", "Open recipe source"), destination: source).font(.caption.weight(.semibold))
            }
        }.foodCardStyle()
    }

    @ViewBuilder private func riskView(_ risk: FoodIngredientRisk) -> some View {
        switch risk {
        case .noListedConcern:
            Label(title("لم تظهر مكونات تنبيه ضمن البيانات المتاحة؛ لا يُعد ذلك شهادة حلال.", "No flagged ingredient appears in the available data; this is not halal certification."), systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
        case .needsVerification(let ingredients):
            Label(title("يحتاج إلى التحقق من المكونات", "Ingredients require verification"), systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(.orange)
            Text(title("مكونات تتطلب معرفة المصدر أو طريقة التحضير: ", "Ingredients whose source or preparation should be checked: ") + ingredients.joined(separator: ", "))
                .font(.caption).foregroundStyle(.secondary)
        case .possibleNonHalal(let ingredients):
            Label(title("قد يحتوي على مكونات غير حلال", "May contain non-halal ingredients"), systemImage: "exclamationmark.octagon.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(.red)
            Text(title("مكونات مثيرة للاشتباه وردت في الوصفة: ", "Ingredients of concern listed in this recipe: ") + ingredients.joined(separator: ", "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func title(_ arabic: String, _ english: String) -> String { SariTravelFeatureText.text(arabic: arabic, english: english, language: language) }
}

private extension View {
    func foodCardStyle() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.primary.opacity(0.045)))
    }
}
