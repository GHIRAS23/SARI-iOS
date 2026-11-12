import SwiftUI
struct SariAdaptiveContainer<Content:View>:View {
    @ViewBuilder let content:(_ width:CGFloat)->Content
    var body:some View {
        GeometryReader { geo in
            ScrollView {
                content(geo.size.width)
                    .frame(maxWidth: geo.size.width >= 700 ? 980 : .infinity)
                    .frame(maxWidth:.infinity)
                    .padding(.horizontal, geo.size.width < 360 ? 12 : 18)
            }
        }
    }
}
enum SariAdaptive {
    static func columns(for width:CGFloat)->Int {
        if width >= 900 { return 4 }
        if width >= 650 { return 3 }
        return 2
    }
}
