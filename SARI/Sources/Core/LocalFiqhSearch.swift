import Foundation
import SQLite3

struct LocalFiqhSource:Identifiable {
    let id:Int; let part:Int; let page:Int; let text:String; let pdfFile:String
    var label:String{"السلسبيل — الجزء \(part)، الصفحة \(page)"}
}

enum LocalFiqhSearchError:Error { case openFailed, queryFailed }

final class LocalFiqhSearch {
    private let dbURL:URL
    init(dbURL:URL){self.dbURL=dbURL}

    func search(_ question:String,limit:Int=4)throws->[LocalFiqhSource]{
        var db:OpaquePointer?
        guard sqlite3_open_v2(dbURL.path,&db,SQLITE_OPEN_READONLY,nil)==SQLITE_OK,let db else{throw LocalFiqhSearchError.openFailed}
        defer{sqlite3_close(db)}
        let terms=Self.terms(question)
        guard !terms.isEmpty else{return []}
        // Portable query: does not depend on iOS SQLite having the same FTS5 build as desktop.
        let score=terms.map{"(CASE WHEN normalized LIKE ? THEN 1 ELSE 0 END)"}.joined(separator:"+")
        let whereClause=terms.map{_ in "normalized LIKE ?"}.joined(separator:" OR ")
        let sql="SELECT id,part,page,text,pdf_file,(\(score)) AS score FROM pages WHERE \(whereClause) ORDER BY score DESC,id ASC LIMIT ?"
        var st:OpaquePointer?
        guard sqlite3_prepare_v2(db,sql,-1,&st,nil)==SQLITE_OK,let st else{throw LocalFiqhSearchError.queryFailed}
        defer{sqlite3_finalize(st)}
        var idx:Int32=1
        for t in terms { sqlite3_bind_text(st,idx,"%\(t)%",-1,SQLITE_TRANSIENT);idx += 1 }
        for t in terms { sqlite3_bind_text(st,idx,"%\(t)%",-1,SQLITE_TRANSIENT);idx += 1 }
        sqlite3_bind_int(st,idx,Int32(limit))
        var result:[LocalFiqhSource]=[]
        while sqlite3_step(st)==SQLITE_ROW {
            let id=Int(sqlite3_column_int(st,0)),part=Int(sqlite3_column_int(st,1)),page=Int(sqlite3_column_int(st,2))
            let text=String(cString:sqlite3_column_text(st,3)),pdf=String(cString:sqlite3_column_text(st,4))
            result.append(.init(id:id,part:part,page:page,text:text,pdfFile:pdf))
        }
        return result
    }

    private static func terms(_ q:String)->[String] {
        let normalized=q.lowercased()
            .replacingOccurrences(of:"أ",with:"ا").replacingOccurrences(of:"إ",with:"ا").replacingOccurrences(of:"آ",with:"ا")
            .replacingOccurrences(of:"ة",with:"ه")
        let stop:Set<String>=["من","في","على","الى","إلى","هل","ما","هو","هي","عن","ثم","بعد","قبل","the","a","an","is","are","to","of","in","and","or"]
        return normalized.split{!$0.isLetter && !$0.isNumber}.map(String.init).filter{$0.count>=3 && !stop.contains($0)}.prefix(8).map{$0}
    }
}
