import SwiftUI

private struct SariFiqhTurn:Identifiable {
    let id=UUID(); let question:String; let answer:FiqhServerAnswer
}

struct FiqhAssistantView:View {
    @Environment(\.openURL) private var openURL
    @State private var question=""
    @State private var turns:[SariFiqhTurn]=[]
    @State private var loading=false
    @State private var errorMessage:String?
    @StateObject private var pack=LocalFiqhPack.shared
    private var language:SariLanguage { SariLanguage.selected }

    var body:some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors:[Color(.systemBackground),Color.accentColor.opacity(0.055),Color(.systemBackground)],startPoint:.top,endPoint:.bottom).ignoresSafeArea()
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators:false) {
                        LazyVStack(spacing:16) {
                            introCard
                            if !pack.installed { FiqhPackSetupView() }
                            
                            ForEach(turns) { turn in
                                questionBubble(turn.question)
                                answerCard(turn.answer)
                            }
                            if loading { loadingCard.id("loading") }
                            if let errorMessage { errorCard(errorMessage) }
                            Color.clear.frame(minHeight:24).id("bottom")
                        }.padding(18)
                    }
                    .onChange(of:turns.count){_,_ in withAnimation{proxy.scrollTo("bottom",anchor:.bottom)}}
                    .onChange(of:loading){_,v in if v{withAnimation{proxy.scrollTo("loading",anchor:.bottom)}}}
                }
            }
            .safeAreaInset(edge:.bottom){ composer }
            .navigationTitle(SariStrings.t("ask")).navigationBarTitleDisplayMode(.inline)
        }.sariLanguageEnvironment(language)
    }

    private var introCard:some View {
        HStack(alignment:.top,spacing:12) {
            Image(systemName:"checkmark.shield.fill").font(.title2).foregroundStyle(Color.accentColor)
            VStack(alignment:language.isArabic ? .trailing:.leading,spacing:5) {
                Text(SariUIStrings.text("fiqh_source_based", language)).font(.headline)
                Text(SariUIStrings.text("fiqh_method_desc",language))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }.sariAskCard()
    }

    private var runtimeCard:some View {
        Label(SariUIStrings.text("fiqh_gguf_pending",language),systemImage:"iphone.gen3")
            .font(.subheadline).foregroundStyle(.orange).sariAskCard()
    }

    private func questionBubble(_ text:String)->some View {
        HStack { Spacer(minLength:50); Text(text).textSelection(.enabled).padding(14)
            .background(Color.accentColor,in:RoundedRectangle(cornerRadius:18,style:.continuous)).foregroundStyle(.white)
        }.frame(maxWidth:.infinity)
    }

    private var composer:some View {
        VStack(spacing:8) {
            Divider()
            HStack(alignment:.bottom,spacing:10) {
                TextField(SariUIStrings.text("question_details",language),text:$question,axis:.vertical)
                    .lineLimit(1...5).padding(12)
                    .background(Color(.secondarySystemBackground),in:RoundedRectangle(cornerRadius:18))
                Button { Task{await ask()} } label:{
                    Image(systemName:"arrow.up").font(.headline).frame(width:42,height:42)
                }.buttonStyle(.borderedProminent).clipShape(Circle())
                    .disabled(question.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || loading || !pack.installed)
            }
            Text(SariUIStrings.text("fiqh_not_fatwa", language)).font(.caption2).foregroundStyle(.secondary)
        }.padding(.horizontal,14).padding(.top,8).padding(.bottom,5).background(.ultraThinMaterial)
    }

    private var loadingCard:some View {
        HStack(spacing:12){ProgressView();VStack(alignment:language.isArabic ? .trailing:.leading){Text(SariUIStrings.text("fiqh_searching", language)).fontWeight(.semibold);Text(SariUIStrings.text("fiqh_local_wait", language)).font(.caption).foregroundStyle(.secondary)}}
            .frame(maxWidth:.infinity,alignment:language.isArabic ? .trailing:.leading).sariAskCard()
    }

    private func errorCard(_ text:String)->some View {
        Label(text,systemImage:"wifi.exclamationmark").foregroundStyle(.orange).sariAskCard()
    }

    private func answerCard(_ a:FiqhServerAnswer)->some View {
        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:14) {
            HStack {
                Text(SariUIStrings.format("source_match",language,["value":"\(a.retrieval_confidence)"])).font(.caption.weight(.bold))
                    .padding(.horizontal,10).padding(.vertical,6).background(Color.accentColor.opacity(0.10),in:Capsule())
                Spacer()
                Label(levelLabel(a.level),systemImage:levelIcon(a.level)).font(.subheadline.weight(.bold))
            }
            Text(a.answer).font(.title3.weight(.semibold)).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
            if let r=a.reason,!r.isEmpty {
                Divider()
                DisclosureGroup(SariUIStrings.text("fiqh_why", language)){Text(r).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled).padding(.top,8)}
            }
            if !a.sources.isEmpty {
                Divider(); Text(SariStrings.t("sources")).font(.headline)
                ForEach(a.sources.prefix(4)){source in
                    DisclosureGroup {
                        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:9) {
                            Text(source.text).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
                            if let url=FiqhAPI.shared.absoluteSourceURL(source){
                                Button{openURL(url)}label:{Label(SariUIStrings.text("open_source", language),systemImage:"doc.richtext")}.buttonStyle(.bordered)
                            }
                        }.padding(.top,8)
                    } label:{Text(source.source_label).font(.subheadline.weight(.semibold))}
                    .padding(13).background(Color(.secondarySystemBackground),in:RoundedRectangle(cornerRadius:15))
                }
            }
            if a.contact_scholar_recommended {
                NavigationLink(destination:ScholarsView()){Label(SariUIStrings.text("fiqh_contact_scholar", language),systemImage:"person.2.fill").frame(maxWidth:.infinity)}
                    .buttonStyle(.borderedProminent)
            }
            Text(a.disclaimer).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth:.infinity)
        }.sariAskCard()
    }

    private func levelLabel(_ level: String) -> String {
        let l = language
        if level.contains("explicit") {
            return SariContentText.pick(l,[.ar:"نص صريح",.en:"Explicit source",.tr:"Açık kaynak",.ms:"Sumber jelas",.id:"Sumber eksplisit",.ja:"明示された根拠",.zh:"明确来源",.ru:"Прямой источник",.fr:"Source explicite"])
        }
        if level.contains("inference") {
            return SariContentText.pick(l,[.ar:"استدلال من المصدر",.en:"Source-based inference",.tr:"Kaynağa dayalı çıkarım",.ms:"Rumusan berasaskan sumber",.id:"Kesimpulan berbasis sumber",.ja:"資料に基づく推論",.zh:"基于来源的推断",.ru:"Вывод по источнику",.fr:"Inférence fondée sur la source"])
        }
        return SariContentText.pick(l,[.ar:"المصدر غير كافٍ",.en:"Insufficient source",.tr:"Kaynak yetersiz",.ms:"Sumber tidak mencukupi",.id:"Sumber tidak cukup",.ja:"根拠不足",.zh:"来源不足",.ru:"Недостаточно источников",.fr:"Source insuffisante"])
    }

    private func levelIcon(_ level:String)->String {
        if level.contains("explicit"){return "checkmark.seal.fill"}
        if level.contains("inference"){return "arrow.triangle.branch"}
        return "exclamationmark.triangle.fill"
    }

    @MainActor private func ask() async {
        let q=question.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !q.isEmpty,!loading else{return}
        question="";errorMessage=nil;loading=true
        defer{loading=false}
        do {
            let local=try await LocalFiqhEngine.shared.ask(question:q,language:language)
            let converted=FiqhServerAnswer(
                level: local.sources.isEmpty ? "insufficient" : "inference",
                answer: local.answer,
                reason: local.reason,
                retrieval_confidence: local.confidence,
                confidence_label: "",
                sources: local.sources.map { s in
                    FiqhSource(id:s.id,part:s.part,page:s.page,text:s.text,pdf_file:s.pdfFile,source_label:s.label(language),score:nil,pdf_url:nil)
                },
                contact_scholar_recommended: local.sources.isEmpty,
                ai_enabled: true,
                source_basis: "local",
                disclaimer: SariUIStrings.text("fiqh_local_disclaimer",language)
            )
            turns.append(SariFiqhTurn(question:q,answer:converted))
        } catch {
            question=q
            errorMessage=SariUIStrings.text("fiqh_local_error", language)
        }
    }
}
private extension View {
    func sariAskCard()->some View { self.frame(maxWidth:.infinity).padding(18).background(.regularMaterial,in:RoundedRectangle(cornerRadius:22,style:.continuous)) }
}
