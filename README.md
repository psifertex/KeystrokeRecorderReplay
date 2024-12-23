# Keystroke Recorder & Replay

Keystroke Recorder & Replay is a macOS application that allows you to record and replay keystrokes and mouse events. This can be useful for automating repetitive tasks or creating macros.

## Features

- Record keystrokes and mouse events
- Replay recorded events with customizable delay
- Set the number of times to replay the macro
- Visual indicators for recording and replaying states
- Change app icon based on the current state (recording, replaying, idle)
- Global hotkeys for starting/stopping recording and replaying

## Hotkeys

- **F12**: Start/Stop Recording
- **F11**: Start/Cancel Replay

## Installation

1. Clone the repository:
    ```sh
    git clone https://github.com/psifertex/KeystrokeRecorderReplay.git
    ```
2. Open the project in Xcode:
    ```sh
    cd KeystrokeRecorderReplay
    open KeystrokeRecorderReplay.xcodeproj
    ```
3. Build and run the project in Xcode.

## Usage

1. Launch the application.
2. Grant Accessibility permissions when prompted. If the app does not appear in the list, open System Preferences manually and add the app to the Accessibility list.
3. Use the F12 key to start and stop recording keystrokes and mouse events.
4. Use the F11 key to start and cancel replaying the recorded events.
5. Customize the macro run count and delay between runs in the app's UI.

## Customization

### App Icons

The app uses different icons to indicate its current state:
- `AppIcon`: Default app icon
- `AppIconRecording`: Icon displayed when recording
- `AppIconReplaying`: Icon displayed when replaying

To customize these icons, replace the corresponding images in the `Assets.xcassets` folder.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
