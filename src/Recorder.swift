import AVFoundation
import Combine

func plog(_ msg: String) {   // -> app.log via launchd's StandardErrorPath
    FileHandle.standardError.write("\(Date().formatted(.iso8601)) \(msg)\n".data(using: .utf8)!)
}

// Captures one input device to numbered 16 kHz mono wav segments and publishes a
// level history for the waveform. Built on AVCaptureSession rather than
// AVAudioEngine: the engine binds the *system default* input before you can
// choose another, and with a Bluetooth headset mid-call that bind can block in
// coreaudiod for minutes. A capture session opens exactly the device we name.
//
// Everything that touches the session runs on `q`, never on main, and start/stop
// carry a 15 s timeout so a blocked device freezes a background thread, not the app.
final class Recorder: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    @Published var levels: [Float] = Array(repeating: 0, count: 20)
    @Published var elapsed: TimeInterval = 0
    @Published private(set) var isRecording = false
    private(set) var dir: URL?            // main-thread view of the active session
    var deviceUID = ""                    // "" = system default input
    private(set) var deviceName = ""

    static let hungCode = 2
    static var builtInMicUID: String? { AudioDevices.builtInMicUID }

    private let q = DispatchQueue(label: "piroba.audio")
    private let cbq = DispatchQueue(label: "piroba.audio.buffers")
    private var session: AVCaptureSession?   // q only
    private var writer: AVAssetWriter?       // cbq only
    private var input: AVAssetWriterInput?   // cbq only
    private var sessionStarted = false       // cbq only
    private var device: AVCaptureDevice?     // q only
    private var qDir: URL?                   // q only; non-nil while a session is active
    private var segment = 0                  // q only
    private var startedAt = Date()
    private var lastBuffer = Date()          // heuristic; written on cbq/q, read on main
    private var timer: Timer?
    private var bufferCount = 0
    private var peak: Float = 0                  // since the current device was opened
    private var switchedToBuiltIn = false
    private var gen = 0                      // main only; bumps on every start/stop outcome or timeout

    // MARK: main-thread API

    func start(into dir: URL, completion: @escaping (Error?) -> Void) {
        gen += 1
        let my = gen
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, my == gen else { return }
            gen += 1
            plog("start hung for 15s on \(deviceName.isEmpty ? "default input" : deviceName) — abandoning")
            completion(NSError(domain: "Piroba", code: Recorder.hungCode,
                               userInfo: [NSLocalizedDescriptionKey: "audio device did not respond"]))
        }
        q.async {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                self.device = Recorder.captureDevice(uid: self.deviceUID) ?? AVCaptureDevice.default(for: .audio)
                guard let dev = self.device else { throw NSError(domain: "Piroba", code: 3, userInfo: [NSLocalizedDescriptionKey: "no input device"]) }
                self.deviceName = dev.localizedName
                self.qDir = dir
                self.segment = 0
                self.peak = 0; self.bufferCount = 0; self.switchedToBuiltIn = false
                try self.openSegment(in: dir)
            } catch {
                self.qDir = nil
                DispatchQueue.main.async {
                    guard my == self.gen else { return }
                    self.gen += 1
                    completion(error)
                }
                return
            }
            DispatchQueue.main.async {
                guard my == self.gen else {            // timed out meanwhile: tear down quietly
                    self.q.async { self.closeSegment(); self.qDir = nil }
                    return
                }
                self.gen += 1
                self.dir = dir
                self.startedAt = Date()
                self.isRecording = true
                for name in [AVCaptureDevice.wasDisconnectedNotification, AVCaptureDevice.wasConnectedNotification,
                             .AVCaptureSessionRuntimeError, .AVCaptureSessionWasInterrupted] {
                    NotificationCenter.default.addObserver(self, selector: #selector(self.deviceChanged), name: name, object: nil)
                }
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
                completion(nil)
            }
        }
    }

    // Completion fires once the file is closed, so the caller can hand it to ffmpeg.
    func stop(completion: @escaping (URL?) -> Void) {
        timer?.invalidate(); timer = nil
        NotificationCenter.default.removeObserver(self)
        isRecording = false
        levels = Array(repeating: 0, count: levels.count)
        elapsed = 0
        let done = dir
        dir = nil
        gen += 1
        let my = gen
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, my == gen else { return }
            gen += 1
            plog("stop hung for 15s — handing over whatever was written")
            completion(done)
        }
        q.async {
            self.closeSegment()
            self.qDir = nil
            DispatchQueue.main.async {
                guard my == self.gen else { return }
                self.gen += 1
                completion(done)
            }
        }
    }

    static func captureDevice(uid: String) -> AVCaptureDevice? {
        guard !uid.isEmpty else { return nil }
        if let d = AVCaptureDevice(uniqueID: uid) { return d }
        let name = AudioDevices.inputs().first { $0.uid == uid }?.name
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified)
            .devices.first { $0.localizedName == name }
    }

    // A Bluetooth headset that another app already holds hands us zeros, not audio.
    private func switchToBuiltIn() {
        guard let uid = AudioDevices.builtInMicUID, let dev = Recorder.captureDevice(uid: uid), dev != device else { return }
        plog("silent on \(deviceName) — switching to \(dev.localizedName)")
        device = dev
        deviceName = dev.localizedName
        peak = 0
        restartSegment()
    }

    // MARK: audio queue

    private func openSegment(in dir: URL) throws {
        guard let dev = device else { return }
        segment += 1
        let s = AVCaptureSession()
        let inp = try AVCaptureDeviceInput(device: dev)
        let out = AVCaptureAudioDataOutput()
        out.setSampleBufferDelegate(self, queue: cbq)
        guard s.canAddInput(inp), s.canAddOutput(out) else {
            throw NSError(domain: "Piroba", code: 4, userInfo: [NSLocalizedDescriptionKey: "cannot capture from \(dev.localizedName)"])
        }
        s.addInput(inp); s.addOutput(out)

        let url = dir.appendingPathComponent(String(format: "audio-%02d.wav", segment))
        let w = try AVAssetWriter(outputURL: url, fileType: .wav)
        let wi = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false,
        ])
        wi.expectsMediaDataInRealTime = true
        w.add(wi)
        guard w.startWriting() else { throw w.error ?? NSError(domain: "Piroba", code: 5) }
        cbq.sync { writer = w; input = wi; sessionStarted = false }

        s.startRunning()
        session = s
        lastBuffer = Date()
        plog("segment \(segment) open on \(dev.localizedName)")
    }

    private func closeSegment() {
        session?.stopRunning()
        session = nil
        cbq.sync {
            guard let w = writer else { return }
            input?.markAsFinished()
            if w.status == .writing {
                let sem = DispatchSemaphore(value: 0)
                w.finishWriting { sem.signal() }
                _ = sem.wait(timeout: .now() + 5)
            } else {
                w.cancelWriting()
            }
            writer = nil; input = nil
        }
    }

    private func restartSegment() {
        guard let dir = qDir else { return }
        closeSegment()
        do { try openSegment(in: dir) } catch {
            plog("segment restart failed, retrying in 5s: \(error.localizedDescription)")
            lastBuffer = Date()   // back off: tick() tries again after the 5 s window, not every 0.5 s
        }
    }

    // MARK: callbacks

    func captureOutput(_ output: AVCaptureOutput, didOutput sb: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let w = writer, let wi = input, w.status == .writing else { return }
        if !sessionStarted { w.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sb)); sessionStarted = true }
        if wi.isReadyForMoreMediaData { wi.append(sb) }
        lastBuffer = Date()
        bufferCount += 1
        let level = min(1, Recorder.rms(sb) * 6)
        if level > peak { peak = level }   // ponytail: gain knob — raise if bars sit flat for quiet talkers
        DispatchQueue.main.async {
            self.levels.removeFirst()
            self.levels.append(level)
        }
    }

    // RMS of one buffer in the device's native format (float32 or int16), 0…1.
    private static func rms(_ sb: CMSampleBuffer) -> Float {
        guard let fd = CMSampleBufferGetFormatDescription(sb),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee else { return 0 }
        var abl = AudioBufferList()
        var block: CMBlockBuffer?
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sb, bufferListSizeNeededOut: nil, bufferListOut: &abl, bufferListSize: MemoryLayout<AudioBufferList>.size,
                blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: &block) == noErr,
              let data = abl.mBuffers.mData else { return 0 }
        let bytes = Int(abl.mBuffers.mDataByteSize)
        var sum: Float = 0
        var n = 0
        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            let p = data.assumingMemoryBound(to: Float.self); n = bytes / 4
            for i in 0..<n { sum += p[i] * p[i] }
        } else if asbd.mBitsPerChannel == 16 {
            let p = data.assumingMemoryBound(to: Int16.self); n = bytes / 2
            for i in 0..<n { let v = Float(p[i]) / 32768; sum += v * v }
        }
        return n > 0 ? (sum / Float(n)).squareRoot() : 0
    }

    @objc private func deviceChanged(_ n: Notification) {
        plog("audio change: \(n.name.rawValue)")
        q.async { self.restartSegment() }
    }

    private func tick() {
        elapsed = Date().timeIntervalSince(startedAt)
        if Int(elapsed * 2) == 10 { plog("level check at 5s: peak \(peak), buffers \(bufferCount)") }   // one line, for "waveform is flat" reports
        if elapsed >= 10, !switchedToBuiltIn, bufferCount > 50, peak < 0.002 {
            switchedToBuiltIn = true
            q.async { self.switchToBuiltIn() }
        }
        if Date().timeIntervalSince(lastBuffer) > 5 {
            lastBuffer = Date()   // one restart per 5 s window even if q is slow
            q.async { self.restartSegment() }
        }
    }
}
