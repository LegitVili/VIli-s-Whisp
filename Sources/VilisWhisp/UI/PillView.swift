import SwiftUI

struct PillView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var recorder: AudioRecorder
    @State private var levels: [Float] = Array(repeating: 0.05, count: 14)

    var body: some View {
        HStack(spacing: 10) {
            leading
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 300, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.86))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
        .foregroundStyle(.white)
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(recorder.$level) { l in
            levels.removeFirst()
            levels.append(max(0.06, l))
        }
        .animation(.easeOut(duration: 0.08), value: levels)
        .animation(.easeInOut(duration: 0.15), value: controller.state)
    }

    @ViewBuilder
    private var leading: some View {
        switch controller.state {
        case .listening:
            waveform
        case .transcribing, .formatting, .inserting:
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(.white)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 15, weight: .semibold))
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 14, weight: .semibold))
        case .hidden:
            EmptyView()
        }
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(Color(red: 0.45, green: 0.75, blue: 1.0))
                    .frame(width: 3, height: 4 + CGFloat(levels[i]) * 18)
            }
        }
        .frame(height: 22)
    }

    private var label: String {
        switch controller.state {
        case .hidden: return ""
        case .listening(let handsFree): return handsFree ? "Mani libere · tocca per terminare" : "In ascolto…"
        case .transcribing: return "Trascrivo…"
        case .formatting: return "Formatto…"
        case .inserting: return "Inserisco…"
        case .done: return "Fatto"
        case .error(let msg): return msg
        }
    }
}
