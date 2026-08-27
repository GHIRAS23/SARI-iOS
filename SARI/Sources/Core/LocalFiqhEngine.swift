import Foundation
import SwiftLlama

actor LocalFiqhEngine {
    static let shared=LocalFiqhEngine()
    private var llama:LlamaActor?
    private var loadedPath:String?

    struct Result {
        let answer:String
        let sources:[LocalFiqhSource]
        let reason:String
        let confidence:Int
    }

    func ask(question:String,language:SariLanguage) async throws->Result {
        let pack=await MainActor.run{LocalFiqhPack.shared}
        let installed=await MainActor.run{pack.installed}
        guard installed else{throw URLError(.fileDoesNotExist)}
        let modelURL=await MainActor.run{pack.modelURL}
        let dbURL=await MainActor.run{pack.libraryURL}
        let sources=try LocalFiqhSearch(dbURL:dbURL).search(question,language:language,limit:4)
        guard !sources.isEmpty else {
            return .init(answer:insufficient(language),sources:[],reason:sourceReason(language, found:false),confidence:0)
        }

        let hasModel = await MainActor.run { pack.hasModel }
        guard hasModel else {
            return .init(
                answer: sourceOnlyAnswer(language),
                sources: sources,
                reason: sourceReason(language, found:true),
                confidence: min(78, 52 + sources.count * 6)
            )
        }

        if llama == nil || loadedPath != modelURL.path {
            let model=try LlamaModel(path:modelURL.path,config:.init(contextSize:4096,gpuLayers:.all,threads:max(2,ProcessInfo.processInfo.activeProcessorCount/2)))
            llama=try LlamaActor(model:model,params:.greedy)
            loadedPath=modelURL.path
        }
        let evidence=sources.enumerated().map{"[\($0.offset+1)] \($0.element.text)"}.joined(separator:"\n\n")
        let prompt="""
You are SARI, a source-bound fiqh assistant.
Answer ONLY from the Arabic evidence below.
Never reverse negation. Never add a ruling not supported by the evidence.
If evidence is insufficient, say that clearly.
Answer in \(language.displayName), concise and natural.
Do not expose hidden reasoning. Mention only the conclusion and a short source-based explanation.

EVIDENCE:
\(evidence)

QUESTION:
\(question)
"""
        guard let llama else{throw URLError(.cannotLoadFromNetwork)}
        var output=""
        for try await chunk in await llama.chat(messages:[.user(prompt)],template:.chatML) {
            if case .text(let token)=chunk { output += token }
        }
        let cleaned=output.trimmingCharacters(in:.whitespacesAndNewlines)
        let confidence=min(92,55+min(37,sources.count*8))
        return .init(answer:cleaned.isEmpty ? insufficient(language):cleaned,sources:sources,reason:modelReason(language),confidence:confidence)
    }

    private func sourceOnlyAnswer(_ l:SariLanguage) -> String {
        switch l {
        case .ar: return "وجدت نصوصًا مرتبطة بسؤالك في المصادر الفقهية المحلية. أعرضها لك أدناه كما هي للمراجعة، دون أن أنسب حكمًا للمصدر لم يرد فيه صراحة. إذا احتجت فتوى لحالتك الخاصة فتواصل مع أحد أهل العلم."
        case .en: return "I found passages related to your question in SARI’s local fiqh sources. They are shown below for review. Without the optional local model, SARI will not translate them or formulate a ruling that is not explicit in the source."
        case .tr: return "Yerel fıkıh kaynaklarında sorunuzla ilgili bölümler buldum. Aşağıda incelemeniz için gösteriliyor. İsteğe bağlı yerel model olmadan SARI metni tercüme etmez veya kaynakta açıkça bulunmayan bir hüküm üretmez."
        case .ms: return "Saya menemui petikan berkaitan soalan anda dalam sumber fiqh tempatan SARI. Petikan dipaparkan di bawah. Tanpa model tempatan pilihan, SARI tidak akan menterjemah atau membentuk hukum yang tidak dinyatakan dengan jelas dalam sumber."
        case .id: return "Saya menemukan bagian yang terkait dengan pertanyaan Anda dalam sumber fikih lokal SARI. Bagian tersebut ditampilkan di bawah. Tanpa model lokal opsional, SARI tidak menerjemahkan atau merumuskan hukum yang tidak dinyatakan secara jelas dalam sumber."
        case .ja: return "SARIのローカル・フィクフ資料から関連する箇所を見つけました。下に原文を表示します。任意のローカルモデルがない場合、SARIは原文を翻訳したり、資料に明記されていない判断を作成したりしません。"
        case .zh: return "我在 SARI 的本地教法资料中找到了与问题相关的段落，原文会显示在下方。未安装可选本地模型时，SARI 不会擅自翻译，也不会生成资料中没有明确表述的教法判断。"
        case .ru: return "В локальных источниках SARI найдены фрагменты, связанные с вашим вопросом. Они показаны ниже. Без дополнительной локальной модели SARI не переводит текст и не формулирует постановление, которого нет в источнике явно."
        case .fr: return "J’ai trouvé des passages liés à votre question dans les sources locales de fiqh de SARI. Ils sont affichés ci-dessous. Sans le modèle local optionnel, SARI ne les traduit pas et ne formule pas de jugement qui ne soit pas explicite dans la source."
        }
    }

    private func sourceReason(_ l:SariLanguage, found:Bool) -> String {
        if !found { return insufficient(l) }
        return SariContentText.pick(l,[
            .ar:"تم البحث داخل فهرس «السلسبيل» المحلي المضمّن في التطبيق، ولم يُنشأ حكم آلي دون نموذج محلي موثّق.",
            .en:"SARI searched the bundled local Al-Salsabil index. No automated ruling was generated without the optional local model.",
            .tr:"SARI, uygulamadaki yerel El-Selsebil dizininde arama yaptı. İsteğe bağlı yerel model olmadan otomatik hüküm üretilmedi.",
            .ms:"SARI mencari indeks Al-Salsabil tempatan yang dibundel. Tiada hukum automatik dijana tanpa model tempatan pilihan.",
            .id:"SARI mencari indeks Al-Salsabil lokal yang disertakan. Tidak ada hukum otomatis yang dibuat tanpa model lokal opsional.",
            .ja:"アプリ内のローカル『アル・サルサビール』索引を検索しました。任意のローカルモデルなしでは自動判断を生成しません。",
            .zh:"SARI 已搜索应用内置的本地《السلسبيل》索引。未安装可选本地模型时不会自动生成教法判断。",
            .ru:"Выполнен поиск по локальному индексу «Ас-Сальсабиль». Без дополнительной локальной модели автоматическое постановление не создаётся.",
            .fr:"SARI a recherché dans l’index local d’Al-Salsabil inclus dans l’app. Aucun jugement automatique n’est produit sans le modèle local optionnel."
        ])
    }

    private func modelReason(_ l:SariLanguage) -> String {
        SariContentText.pick(l, [
            .ar: "صيغت الخلاصة محليًا من المقاطع المسترجعة من المصادر المثبتة على الجهاز.",
            .en: "The conclusion was generated locally from passages retrieved from the sources installed on the device.",
            .tr: "Sonuç, cihazdaki kaynaklardan getirilen bölümler kullanılarak yerel olarak oluşturuldu.",
            .ms: "Kesimpulan dibentuk secara tempatan daripada petikan sumber yang disimpan pada peranti.",
            .id: "Kesimpulan dibuat secara lokal dari bagian sumber yang tersimpan di perangkat.",
            .ja: "端末内の資料から取得した箇所を基に、結論をローカルで生成しました。",
            .zh: "结论由设备内已安装来源中检索到的段落在本地生成。",
            .ru: "Вывод сформирован локально на основе фрагментов из источников, установленных на устройстве.",
            .fr: "La conclusion a été formulée localement à partir des passages retrouvés dans les sources installées sur l’appareil."
        ])
    }

    private func insufficient(_ l:SariLanguage)->String {
        switch l {
        case .ar:return "لم أجد في المصادر المحلية نصًا كافيًا للإجابة بثقة."
        case .en:return "I could not find enough support in the local sources to answer confidently."
        case .tr:return "Yerel kaynaklarda güvenle cevap vermek için yeterli dayanak bulamadım."
        case .ms:return "Saya tidak menemui sokongan yang mencukupi dalam sumber tempatan untuk menjawab dengan yakin."
        case .id:return "Saya tidak menemukan dukungan yang cukup dalam sumber lokal untuk menjawab dengan yakin."
        case .ja:return "ローカル資料には、確信をもって回答するための十分な根拠が見つかりませんでした。"
        case .zh:return "本地资料中没有找到足够依据来有把握地回答。"
        case .ru:return "В локальных источниках недостаточно оснований для уверенного ответа."
        case .fr:return "Je n’ai pas trouvé suffisamment d’éléments dans les sources locales pour répondre avec confiance."
        }
    }
}
