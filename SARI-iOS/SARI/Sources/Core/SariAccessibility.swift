import SwiftUI
extension View {
    func sariReadableText() -> some View {
        self.fixedSize(horizontal:false,vertical:true)
            .lineLimit(nil)
    }
}
struct SariReadableWidth<Content:View>:View {
    @ViewBuilder let content:()->Content
    var body:some View {
        content()
          .frame(maxWidth:900)
          .frame(maxWidth:.infinity)
          .padding(.horizontal,16)
    }
}
