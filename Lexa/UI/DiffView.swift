import AppKit
import SwiftUI

struct DiffView: View {
    let segments: [DiffSegment]

    var body: some View {
        Text(attributed)
            .font(.system(size: 13.5))
            .lineSpacing(4)
    }

    private var attributed: AttributedString {
        var text = AttributedString()
        for segment in segments {
            var part = AttributedString(segment.text)
            switch segment.kind {
            case .same:
                break
            case .added:
                part.foregroundColor = Color(nsColor: .systemGreen)
                part.backgroundColor = Color(nsColor: .systemGreen).opacity(0.16)
                part.inlinePresentationIntent = .stronglyEmphasized
            case .removed:
                part.foregroundColor = Color(nsColor: .systemRed).opacity(0.8)
                part.backgroundColor = Color(nsColor: .systemRed).opacity(0.11)
                part.strikethroughStyle = .single
                part.strikethroughColor = NSColor.systemRed.withAlphaComponent(0.75)
            }
            text += part
        }
        return text
    }
}

#Preview {
    DiffView(segments: TextDiff.diff("Their going to the libary tomorow.", "They're going to the library tomorrow."))
        .padding()
        .frame(width: 420)
}
