import CoreAudio
import CoreMediaIO
import Foundation

/// Detects whether the user is currently in a call by asking the system whether
/// any microphone or camera is live. We don't try to recognize specific apps —
/// a browser tab on Google Meet counts just as much as the Zoom app — we only
/// look at whether the input devices are running anywhere on the system.
enum CallDetector {
    /// True if any audio input device (microphone) is running anywhere on the
    /// system. Conferencing apps hold the mic open for the whole call, even
    /// while muted, so this stays true throughout a call.
    static var isMicrophoneInUse: Bool {
        audioInputDevices().contains { audioDeviceIsRunningSomewhere($0) }
    }

    /// True if any camera is running anywhere on the system.
    ///
    /// Note: under the App Sandbox this only returns devices when the bundle
    /// carries `com.apple.security.device.camera`; without it the camera list
    /// comes back empty and we fall back to the microphone signal (which is
    /// active in virtually every video call anyway).
    static var isCameraInUse: Bool {
        cameraDevices().contains { cmioDeviceIsRunningSomewhere($0) }
    }

    /// Combined gate used by AppState before showing the overlay: suppress the
    /// alert whenever audio or video is in use.
    static var shouldSuppressAlert: Bool {
        isMicrophoneInUse || isCameraInUse
    }

    // MARK: - Core Audio (microphone)

    private static func audioInputDevices() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0
        else { return [] }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr
        else { return [] }
        return devices.filter { deviceHasInputChannels($0) }
    }

    private static func deviceHasInputChannels(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0
        else { return false }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, raw) == noErr
        else { return false }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.contains { $0.mNumberChannels > 0 }
    }

    private static func audioDeviceIsRunningSomewhere(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr
        else { return false }
        return running != 0
    }

    // MARK: - CoreMediaIO (camera)

    private static func cameraDevices() -> [CMIOObjectID] {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(0)
        )
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0
        else { return [] }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr
        else { return [] }
        return devices
    }

    private static func cmioDeviceIsRunningSomewhere(_ device: CMIOObjectID) -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(0)
        )
        var running: UInt32 = 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(device, &address, 0, nil, size, &used, &running) == noErr
        else { return false }
        return running != 0
    }
}
