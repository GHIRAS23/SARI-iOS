import SwiftUI

struct FiqhPackSetupView:View {
    @StateObject private var pack=LocalFiqhPack.shared
    @State private var error:String?
    private var manifestURL:URL? {
        guard let raw=Bundle.main.object(forInfoDictionaryKey:"SARI_FIQH_PACK_MANIFEST_URL") as? String else{return nil}
        return URL(string:raw)
    }
    var body:some View {
        VStack(spacing:18) {
            Image(systemName:"brain.head.profile").font(.system(size:52)).foregroundStyle(Color.accentColor)
            Text(SariUIStrings.text("fiqh_activate", SariLanguage.selected)).font(.title2.bold())
            Text(SariUIStrings.text("pack_install_desc",SariLanguage.selected))
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            VStack(alignment:.trailing,spacing:8) {
                Label(SariUIStrings.text("offline_after_download", SariLanguage.selected),systemImage:"wifi.slash")
                Label(SariUIStrings.text("pack_private", SariLanguage.selected),systemImage:"lock.shield.fill")
                Label(SariUIStrings.text("pack_no_per_question_cost", SariLanguage.selected),systemImage:"creditcard")
            }.frame(maxWidth:.infinity,alignment:.trailing).padding(16)
                .background(Color(.secondarySystemBackground),in:RoundedRectangle(cornerRadius:18))
            if pack.downloading {
                ProgressView(value:pack.progress)
                Text(pack.status).font(.subheadline).foregroundStyle(.secondary)
            } else if pack.installed {
                Label(SariUIStrings.text("pack_ready", SariLanguage.selected),systemImage:"checkmark.seal.fill").foregroundStyle(.green)
            } else {
                Button {
                    guard let u=manifestURL else{error=SariUIStrings.text("pack_url_missing",SariLanguage.selected);return}
                    Task{do{try await pack.install(from:u)}catch{self.error=SariUIStrings.text("pack_verify_failed_not_activated",SariLanguage.selected)}}
                } label:{Label(SariUIStrings.text("download_activate", SariLanguage.selected),systemImage:"arrow.down.circle.fill").frame(maxWidth:.infinity)}
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            if let error{Text(error).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)}
            Text(SariUIStrings.text("pack_sha_note",SariLanguage.selected))
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(22).environment(\.layoutDirection,SariLanguage.selected.isArabic ? .rightToLeft : .leftToRight)
    }
}
