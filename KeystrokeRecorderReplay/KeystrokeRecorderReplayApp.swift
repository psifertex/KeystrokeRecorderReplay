// KeystrokeRecorderReplayApp.swift

import SwiftUI
import Carbon

@main
struct KeystrokeRecorderReplayApp: App {
    @StateObject private var viewModel = RecorderViewModel()
    
    // Integrate AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    // Assign the ViewModel to the AppDelegate
                    appDelegate.viewModel = viewModel
                    viewModel.checkAccessibilityPermissions()
                }
        }
    }
}

// Define AppDelegate to handle application lifecycle events and global hotkeys
class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel: RecorderViewModel?
    var hotKeyRefF11: EventHotKeyRef? = nil
    var hotKeyRefF12: EventHotKeyRef? = nil
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register global hotkeys
        registerGlobalHotKeys()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Terminate the app when the last window is closed
        return true
    }
    
    // Register global hotkeys using Carbon APIs
    func registerGlobalHotKeys() {
        // Check for Accessibility permissions
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        if !accessEnabled {
            // Permissions not granted, prompt the user and terminate
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permissions Required"
                alert.informativeText = "Accessibility permissions are required for this app to function properly. Please enable them in System Preferences."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "Quit")
                alert.runModal()
                NSApp.terminate(nil)
            }
            return
        }
        
        // Define signatures for hotkeys
        let signatureF12 = "RCRR".fourCharCode
        let signatureF11 = "RCRP".fourCharCode
        
        var hotKeyID1 = EventHotKeyID(signature: signatureF12, id: 1)
        var hotKeyID2 = EventHotKeyID(signature: signatureF11, id: 2)
        
        // Register F12 as Hotkey ID 1
        var hotKeyRefF12: EventHotKeyRef? = nil
        let statusF12 = RegisterEventHotKey(UInt32(kVK_F12), 0, hotKeyID1, GetApplicationEventTarget(), 0, &hotKeyRefF12)
        if statusF12 != noErr {
            print("Failed to register hotkey F12")
        }
        
        // Register F11 as Hotkey ID 2
        var hotKeyRefF11: EventHotKeyRef? = nil
        let statusF11 = RegisterEventHotKey(UInt32(kVK_F11), 0, hotKeyID2, GetApplicationEventTarget(), 0, &hotKeyRefF11)
        if statusF11 != noErr {
            print("Failed to register hotkey F11")
        }
        
        // Install an event handler to handle hotkey events
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), HotKeyHandler, 1, &eventSpec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), nil)
    }
}

// Extension to convert a 4-character string to UInt32
extension String {
    var fourCharCode: UInt32 {
        var result: UInt32 = 0
        let utf8 = self.utf8
        for char in utf8 {
            result = (result << 8) | UInt32(char)
        }
        return result
    }
}

// Global function to handle hotkey events
func HotKeyHandler(nextHandler: EventHandlerCallRef?, theEvent: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let theEvent = theEvent, let userData = userData else { return noErr }
    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    
    if status != noErr {
        return status
    }
    
    // Check which hotkey was pressed based on signature and ID
    if hotKeyID.signature == "RCRR".fourCharCode && hotKeyID.id == 1 {
        // F12 pressed - Toggle Recording
        appDelegate.viewModel?.toggleRecording()
    } else if hotKeyID.signature == "RCRP".fourCharCode && hotKeyID.id == 2 {
        // F11 pressed - Toggle Replay
        appDelegate.viewModel?.toggleReplay()
    }
    
    return noErr
}

class RecorderViewModel: ObservableObject {
    // Published properties to update the UI
    @Published var isRecording: Bool = false
    @Published var isReplaying: Bool = false
    @Published var recordedEvents: [RecordedEvent] = []
    @Published var replayDelay: Double = 0.0 // Additional delay multiplier
    @Published var countdown: Int = 0
    @Published var errorMessage: String?
    
    // New Published properties for macro runs
    @Published var macroRunCount: Int = 1
    @Published var macroRunDelay: Double = 1.0 // Delay between macro runs in seconds
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var startTime: CFAbsoluteTime?
    private var timer: Timer?
    
    private var replayTask: DispatchWorkItem?
    
    // Struct to store recorded events with their relative timestamps
    struct RecordedEvent {
        let event: CGEvent
        let timestamp: CFAbsoluteTime
    }
    
    // Check and request Accessibility permissions
    func checkAccessibilityPermissions() {
        let options = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let accessEnabled = AXIsProcessTrustedWithOptions([options: true] as CFDictionary)
        if !accessEnabled {
            // Permissions not granted, prompt the user
            DispatchQueue.main.async {
                self.errorMessage = "Accessibility permissions are required. Please enable them in System Preferences."
            }
        }
    }
    
    // Toggle Recording with F12 hotkey
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecordingWithCountdown()
        }
    }
    
    // Toggle Replay with F11 hotkey
    func toggleReplay() {
        if isReplaying {
            cancelReplay()
        } else {
            startReplayWithCountdown()
        }
    }
    
    // Start recording events with a countdown
    func startRecordingWithCountdown() {
        guard !isRecording else { return }
        countdown = 2
        errorMessage = nil
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { return }
            if self.countdown > 0 {
                self.countdown -= 1
            }
            if self.countdown <= 0 {
                t.invalidate()
                self.startRecording()
            }
        }
    }
    
    // Start recording events
    func startRecording() {
        guard !isRecording else { return }
        
        // Clear previous recordings
        recordedEvents.removeAll()
        startTime = CFAbsoluteTimeGetCurrent()
        
        // Create event tap
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask( (1 << CGEventType.keyDown.rawValue) |
                                          (1 << CGEventType.leftMouseDown.rawValue) |
                                          (1 << CGEventType.rightMouseDown.rawValue)),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .keyDown || type == .leftMouseDown || type == .rightMouseDown {
                    let viewModel = Unmanaged<RecorderViewModel>.fromOpaque(refcon!).takeUnretainedValue()
                    if let start = viewModel.startTime {
                        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                        if keyCode != kVK_F11 && keyCode != kVK_F12 {
                            let timestamp = CFAbsoluteTimeGetCurrent() - start
                            let recordedEvent = RecorderViewModel.RecordedEvent(event: event.copy()!, timestamp: timestamp)
                            DispatchQueue.main.async {
                                viewModel.recordedEvents.append(recordedEvent)
                            }
                        }
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            isRecording = true
            errorMessage = nil
        } else {
            errorMessage = "Failed to create event tap. Please ensure the app has Accessibility permissions."
        }
    }
    
    // Stop recording events
    func stopRecording() {
        guard isRecording else { return }
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
            self.runLoopSource = nil
        }
        isRecording = false
    }
    
    // Start replay events with a countdown
    func startReplayWithCountdown() {
        guard !isReplaying, !recordedEvents.isEmpty else { return }
        countdown = 2
        errorMessage = nil
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { return }
            if self.countdown > 0 {
                self.countdown -= 1
            }
            if self.countdown <= 0 {
                t.invalidate()
                self.startReplay()
            }
        }
    }
    
    // Start replaying events
    func startReplay() {
        guard !isReplaying, !recordedEvents.isEmpty else { return }
        isReplaying = true
        replayTask = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            for run in 1...self.macroRunCount {
                if self.replayTask?.isCancelled ?? false {
                    break
                }
                var previousTimestamp: CFAbsoluteTime = 0
                for recordedEvent in self.recordedEvents {
                    if self.replayTask?.isCancelled ?? false {
                        break
                    }
                    let delay = (recordedEvent.timestamp - previousTimestamp + self.replayDelay)
                    if delay > 0 {
                        Thread.sleep(forTimeInterval: delay)
                    }
                    let event = recordedEvent.event
                    event.post(tap: .cghidEventTap)
                    previousTimestamp = recordedEvent.timestamp
                }
                if run < self.macroRunCount {
                    Thread.sleep(forTimeInterval: self.macroRunDelay)
                }
            }
            DispatchQueue.main.async {
                self.isReplaying = false
            }
        }
        DispatchQueue.global(qos: .userInitiated).async(execute: replayTask!)
    }
    
    // Cancel replaying events
    func cancelReplay() {
        guard isReplaying else { return }
        replayTask?.cancel()
        isReplaying = false
    }
}

