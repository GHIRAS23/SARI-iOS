import SwiftUI

struct SariAdaptiveSurface<Content:View>:View {
 @Environment(\.horizontalSizeClass) private var h
 let content:Content
 init(@ViewBuilder content:()->Content){self.content=content()}
 var body:some View {
  ZStack {
   Color(.systemBackground).ignoresSafeArea()
   LinearGradient(colors:[SariDesign.mint.opacity(0.55),Color.clear,SariDesign.gold.opacity(0.07)],startPoint:.topTrailing,endPoint:.bottomLeading).ignoresSafeArea()
   ScrollView(showsIndicators:false){content.frame(maxWidth:h == .regular ? 920:700).frame(maxWidth:.infinity).padding(.horizontal,h == .regular ? 28:18).padding(.vertical,16)}
  }
 }
}
struct SariFeatureHero:View {
 let title:String,subtitle:String,icon:String
 var body:some View {HStack(spacing:16){VStack(alignment:.trailing,spacing:6){Text(title).font(.title.bold());Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.82))}.frame(maxWidth:.infinity,alignment:.trailing);ZStack{RoundedRectangle(cornerRadius:18).fill(.white.opacity(0.13)).frame(width:62,height:62);Image(systemName:icon).font(.title2).foregroundStyle(SariDesign.gold)}}.foregroundStyle(.white).padding(20).background(SariDesign.hero,in:RoundedRectangle(cornerRadius:28)).overlay(RoundedRectangle(cornerRadius:28).stroke(SariDesign.gold.opacity(0.28)))}
}
