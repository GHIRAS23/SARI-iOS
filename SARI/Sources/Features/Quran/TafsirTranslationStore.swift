import Foundation
import CryptoKit

struct TafsirTranslationEntry:Codable { let id:Int;let text:String }
struct TafsirPackDescriptor:Codable { let language:String;let version:String;let sha256:String;let entries:Int }

@MainActor final class TafsirTranslationStore:ObservableObject {
    @Published private(set) var language:String?
    @Published private(set) var translations:[Int:String]=[:]
    @Published private(set) var errorMessage:String?
    private let fm=FileManager.default
    private var dir:URL { fm.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("SARI/TafsirPacks",isDirectory:true) }
    func load(_ lang:String){
        guard lang != "ar" else {language=nil;translations=[:];return}
        let u=dir.appendingPathComponent("\(lang).json")
        guard let d=try? Data(contentsOf:u),let rows=try? JSONDecoder().decode([TafsirTranslationEntry].self,from:d) else {language=nil;translations=[:];return}
        translations=Dictionary(uniqueKeysWithValues:rows.map{($0.id,$0.text)});language=lang
    }
    func translatedTafsir(for ayah:Ayah)->String? { translations[ayah.id] }
    func install(data:Data,descriptor:TafsirPackDescriptor)throws {
        guard descriptor.language != "ar",descriptor.entries==6236 else{throw CocoaError(.fileReadCorruptFile)}
        let digest=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
        guard digest.lowercased()==descriptor.sha256.lowercased() else{throw CocoaError(.fileReadCorruptFile)}
        let rows=try JSONDecoder().decode([TafsirTranslationEntry].self,from:data)
        guard rows.count==6236,Set(rows.map(\.id)).count==6236,rows.allSatisfy({!$0.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty}) else{throw CocoaError(.fileReadCorruptFile)}
        try fm.createDirectory(at:dir,withIntermediateDirectories:true)
        let dest=dir.appendingPathComponent("\(descriptor.language).json")
        try data.write(to:dest,options:.atomic)
        try? fm.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:dest.path)
        load(descriptor.language)
    }
}
