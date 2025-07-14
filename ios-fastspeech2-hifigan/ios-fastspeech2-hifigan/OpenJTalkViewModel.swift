//
//  OpenJTalkViewModel.swift
//  ios-fastspeech2-hifigan
//
//  Created by Yasuo Hasegawa on 2025/07/14.
//

import Foundation
import AVFoundation
import AVFAudio

class OpenJTalkViewModel: NSObject, ObservableObject {
    private let openJTalk = OpenJTalk()
    private var audioPlayer: AVAudioPlayer?

    override init(){
        super.init()
        
        do {
            try saveEmptyWavFile(filename: "speech.wav")
        } catch {
            print("Error saving WAV file: \(error)")
        }
    }
    
    func speakWithOpenJTalk(text: String){
        let tempURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("speech.wav")
        
        print(">>>>> speakWithOpenJTalk called")
        openJTalk.synthesize(text, pitch:1.0, to: tempURL!) { [weak self] error in
            guard let self = self else { return }
            print(">>>>> speakWithOpenJTalk synthesize completed")
            // Always update UI on the main thread
            DispatchQueue.main.async {

                if let error = error {
                    print("Synthesis failed with error: \(error.localizedDescription)")
                    // Optionally, show an alert to the user
                    return
                }

                Task{
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    print("Synthesis successful. Playing audio from: \(tempURL!.path)")
                    DispatchQueue.main.async {
                        self.playAudio(from: tempURL!)
                    }
                }
            }
        }
    }
    
    func extractPhoneme(text: String) -> String{
        print(">>>>> extractPhoneme called")
        let phonemes = openJTalk.extractPhonemes(fromText: text)
        print(">>>>> extractPhoneme completed: \(phonemes)")
        return phonemes.joined(separator: ",")
    }
    
    private func playAudio(from url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            self.audioPlayer = try AVAudioPlayer(contentsOf: url)
            self.audioPlayer?.play()

        } catch {
            print("AVAudioPlayer failed with error: \(error.localizedDescription)")
        }
    }
    
    func saveEmptyWavFile(filename: String, sampleRate: Int = 44100, channels: Int = 1, bitsPerSample: Int = 16) throws {
        let fileManager = FileManager.default
        let url = try fileManager
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(filename)

        // No audio data, just the header
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataChunkSize = 0
        let fmtChunkSize = 16
        let audioFormat: UInt16 = 1 // PCM

        var wavHeader = Data()

        // RIFF header
        wavHeader.append("RIFF".data(using: .ascii)!)                     // ChunkID
        wavHeader.append(UInt32(36 + dataChunkSize).littleEndianData)     // ChunkSize = 36 + data size
        wavHeader.append("WAVE".data(using: .ascii)!)                     // Format

        // fmt subchunk
        wavHeader.append("fmt ".data(using: .ascii)!)                     // Subchunk1ID
        wavHeader.append(UInt32(fmtChunkSize).littleEndianData)           // Subchunk1Size
        wavHeader.append(UInt16(audioFormat).littleEndianData)            // AudioFormat (1 = PCM)
        wavHeader.append(UInt16(channels).littleEndianData)               // NumChannels
        wavHeader.append(UInt32(sampleRate).littleEndianData)             // SampleRate
        wavHeader.append(UInt32(byteRate).littleEndianData)               // ByteRate
        wavHeader.append(UInt16(blockAlign).littleEndianData)             // BlockAlign
        wavHeader.append(UInt16(bitsPerSample).littleEndianData)          // BitsPerSample

        // data subchunk
        wavHeader.append("data".data(using: .ascii)!)                     // Subchunk2ID
        wavHeader.append(UInt32(dataChunkSize).littleEndianData)          // Subchunk2Size

        try wavHeader.write(to: url)
        print("Empty WAV saved to: \(url.path)")
    }

}
