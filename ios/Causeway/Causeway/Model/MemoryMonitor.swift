import Foundation
import Combine

/// TESTING ONLY — the on-screen memory HUD (see `MemoryHUD`). Set to `false` before any
/// App Store build; it is intentionally NOT `#if DEBUG`-gated so the HUD is visible in a
/// **Release** build launched **untethered** (no Xcode debugger), which is the only way to
/// read the app's real memory behaviour without View Debugging / Malloc Stack Logging
/// inflating and growing it. See BACKLOG "I6-verify".
enum DebugFlags {
    static let memoryHUD = true
}

/// Reads the process's own memory numbers via mach — no Instruments needed.
enum MemoryFootprint {
    /// Physical footprint in bytes: the SAME metric the OS (jetsam) uses to decide whether to
    /// kill the app. `nil` if the query fails.
    static func footprintBytes() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        return kr == KERN_SUCCESS ? info.phys_footprint : nil
    }

    /// Bytes still available to this process before it gets a memory warning / is killed.
    /// Trends toward zero as the app approaches the jetsam limit. 0 if unavailable.
    static func availableBytes() -> UInt64 { UInt64(os_proc_available_memory()) }

    static func footprintMB() -> Double? { footprintBytes().map { Double($0) / 1_048_576 } }
    static func availableMB() -> Double { Double(availableBytes()) / 1_048_576 }
}

/// Samples memory on its own 1-per-2s timer and publishes it. Deliberately isolated (its own
/// `ObservableObject`, observed only by `MemoryHUD`) so the sampling tick never re-renders the
/// board — exactly the `GameClock` pattern, and the whole point given what we're measuring.
final class MemoryMonitor: ObservableObject {
    @Published private(set) var footprintMB: Double = 0
    @Published private(set) var peakMB: Double = 0
    @Published private(set) var availableMB: Double = 0
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.sample() }
    }
    func stop() { timer?.invalidate(); timer = nil }

    private func sample() {
        if let mb = MemoryFootprint.footprintMB() {
            footprintMB = mb
            if mb > peakMB { peakMB = mb }
        }
        availableMB = MemoryFootprint.availableMB()
    }

    deinit { timer?.invalidate() }
}
