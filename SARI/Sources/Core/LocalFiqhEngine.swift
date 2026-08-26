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
        let sources=try LocalFiqhSearch(dbURL:dbURL).search(question,limit:4)
        guard !sources.isEmpty else {
            return .init(answer:insufficient(language),sources:[],reason:"لم أجد نصًا قريبًا بما يكفي في المصادر المحلية.",confidence:0)
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
        return .init(answer:cleaned.isEmpty ? insufficient(language):cleaned,sources:sources,reason:"الخلاصة صيغت محليًا من المقاطع المسترجعة من المصادر المثبتة على الجهاز.",confidence:confidence)
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
