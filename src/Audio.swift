import CoreAudio
import Foundation

private func addr(_ s: AudioObjectPropertySelector,
                  _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: s, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

private func objects(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> [AudioObjectID] {
    var a = addr(sel)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(obj, &a, 0, nil, &size) == noErr else { return [] }
    var out = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(obj, &a, 0, nil, &size, &out) == noErr else { return [] }
    return out
}

private func string(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String? {
    var a = addr(sel)
    var ref: Unmanaged<CFString>? = nil
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let err = withUnsafeMutablePointer(to: &ref) { AudioObjectGetPropertyData(obj, &a, 0, nil, &size, $0) }
    return err == noErr ? ref?.takeRetainedValue() as String? : nil
}

// Who is capturing from an audio input right now, minus us.
// ponytail: one CoreAudio call covers Teams, Zoom, Meet, FaceTime — no per-app guessing.
enum MicWatch {
    static var someoneElseIsRecording: Bool {
        let me = getpid()
        for p in objects(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList) {
            var running: UInt32 = 0
            var a = addr(kAudioProcessPropertyIsRunningInput)
            var s = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(p, &a, 0, nil, &s, &running) == noErr, running != 0 else { continue }
            var pid: pid_t = -1
            var pa = addr(kAudioProcessPropertyPID)
            var ps = UInt32(MemoryLayout<pid_t>.size)
            guard AudioObjectGetPropertyData(p, &pa, 0, nil, &ps, &pid) == noErr else { continue }
            if pid != me { return true }
        }
        return false
    }
}

enum AudioDevices {
    struct Device: Identifiable, Hashable { let id: AudioDeviceID; let uid: String; let name: String }

    static func inputs() -> [Device] {
        objects(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices).compactMap { id in
            var a = addr(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput)
            var size: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size) == noErr, size > 0,
                  let uid = string(id, kAudioDevicePropertyDeviceUID),
                  let name = string(id, kAudioObjectPropertyName) else { return nil }
            return Device(id: id, uid: uid, name: name)
        }
    }

    static func id(forUID uid: String) -> AudioDeviceID? { inputs().first { $0.uid == uid }?.id }
}
