import SwiftUI

/// A small non-interactive overlay showing live memory: current physical footprint (what
/// jetsam kills on), the peak (high-water mark — if it never plateaus, that's a real leak),
/// and headroom before the OS kills the app. TESTING ONLY, gated by `DebugFlags.memoryHUD`.
struct MemoryHUD: View {
    @StateObject private var mon = MemoryMonitor()

    var body: some View {
        HStack(spacing: 10) {
            field("MEM", mon.footprintMB, warn: false)
            field("PEAK", mon.peakMB, warn: false)
            // FREE = headroom before jetsam; os_proc_available_memory() reports 0 where no
            // limit is enforced (e.g. the Simulator), so only show it when it's meaningful.
            if mon.availableMB > 0 {
                field("FREE", mon.availableMB, warn: mon.availableMB < 300)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .foregroundStyle(.white)
        .allowsHitTesting(false)
        .onAppear { mon.start() }
    }

    private func field(_ label: String, _ mb: Double, warn: Bool) -> some View {
        HStack(spacing: 3) {
            Text(label).foregroundStyle(.white.opacity(0.55))
            Text(mb >= 1024 ? String(format: "%.2fG", mb / 1024) : "\(Int(mb.rounded()))M")
                .foregroundStyle(warn ? .red : .white)
                .monospacedDigit()
        }
    }
}
