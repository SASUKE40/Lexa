import SwiftUI

struct DiffView: View {
    let segments: [DiffSegment]

    var body: some View {
        Text(attributed)
            .lineSpacing(3)
    }

    private var attributed: AttributedString {
        var text = AttributedString()
        for segment in segments {
            var part = AttributedString(segment.text)
            switch segment.kind {
            case .same:
                break
            case .added:
                part.foregroundColor = .green
                part.backgroundColor = .green.opacity(0.15)
            case .removed:
                part.foregroundColor = .red.opacity(0.85)
                part.backgroundColor = .red.opacity(0.1)
                part.strikethroughStyle = .single
            }
            text += part
        }
        return text
    }
}

#Preview {
    DiffView(segments: TextDiff.diff("Their going to the libary tomorow.", "They're going to the library tomorrow."))
        .padding()
        .frame(width: 400)
}
