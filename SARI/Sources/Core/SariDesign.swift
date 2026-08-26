import SwiftUI

enum SariDesign {
    static let emerald=Color(red:0.035,green:0.40,blue:0.32)
    static let deep=Color(red:0.025,green:0.20,blue:0.20)
    static let midnight=Color(red:0.025,green:0.11,blue:0.14)
    static let gold=Color(red:0.82,green:0.67,blue:0.34)
    static let sand=Color(red:0.96,green:0.93,blue:0.85)
    static let mint=Color(red:0.90,green:0.96,blue:0.94)
    static let hero=LinearGradient(colors:[emerald,deep,midnight],startPoint:.topTrailing,endPoint:.bottomLeading)
}
struct SariCard<Content:View>:View {
    let content:Content
    init(@ViewBuilder content:()->Content){self.content=content()}
    var body:some View {
        content.padding(18).background(.regularMaterial,in:RoundedRectangle(cornerRadius:26,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:26).stroke(.white.opacity(0.10),lineWidth:1))
            .shadow(color:.black.opacity(0.06),radius:16,y:8)
    }
}
struct SariSectionTitle:View {
    let title:String,icon:String
    var body:some View {HStack{Image(systemName:icon).foregroundStyle(SariDesign.gold);Text(title).font(.title3.bold());Spacer()}}
}
