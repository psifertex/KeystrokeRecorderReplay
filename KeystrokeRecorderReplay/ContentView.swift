// ContentView.swift

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: RecorderViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Keystroke Recorder & Replay")
                .font(.title)
                .padding(.top, 40)
            
            if viewModel.countdown > 0 {
                Text("Starting in \(viewModel.countdown)...")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.toggleRecording()
                }) {
                    Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                        .frame(minWidth: 140, minHeight: 40)
                        .background(viewModel.isRecording ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(viewModel.isReplaying)
            }
            
            Button(action: {
                viewModel.toggleReplay()
            }) {
                Text(viewModel.isReplaying ? "Cancel Replay" : "Replay Events")
                    .frame(minWidth: 140, minHeight: 40)
                    .background(viewModel.isReplaying || viewModel.recordedEvents.isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(viewModel.isReplaying || viewModel.recordedEvents.isEmpty || viewModel.isRecording)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Macro Run Count:")
                    TextField("Run Count", value: $viewModel.macroRunCount, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Delay Between Runs:")
                    TextField("Delay", value: $viewModel.macroRunDelay, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                    Text("s")
                }
            }
            .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Hotkeys:")
                    .font(.headline)
                HStack {
                    Text("F12: Start/Stop Recording")
                    Spacer()
                }
                HStack {
                    Text("F11: Start/Cancel Replay")
                    Spacer()
                }
            }
            .padding(.horizontal, 40)
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(RecorderViewModel())
    }
}
