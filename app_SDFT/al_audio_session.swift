//
//  al_audio_session.swift
//  xaoc_sdft_macos
//
//  Created by Adam Łuczak on 17/08/2023.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

func fetchAudioDevices() -> [AVCaptureDevice] 
{
    return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .externalUnknown], mediaType: .audio, position: .unspecified).devices
}


class AudioSession: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate
{
    @Published  var samplesArray:[Float] = []
    @Published  var test_ena = false

    var freq:  Double = 1.0
    var phase: Double = 0.0
    
    var captureSession: AVCaptureSession?
    
    var audioOutput = AVCaptureAudioDataOutput()

    var buffer:[Float] = []
    
    override init()
    {
        super.init()
//        let url = Bundle.main.url(forResource: "background_angry-robot", withExtension: "wav")!
//        self.ap      = AudioProcessor(filePath: url)

    }
    
    var selectedDevice: AVCaptureDevice?
    {
        didSet {
                    setupSession()
                    startSession() // <- Tu uruchamiamy sesję po ustawieniu urządzenia
                }
    }
        
    func setupSession()
    {
        captureSession?.stopRunning()
        captureSession = AVCaptureSession()

        guard let device = selectedDevice else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession!.canAddInput(input)
            {
                captureSession!.addInput(input)
            }

            if captureSession!.canAddOutput(audioOutput)
            {
                captureSession!.addOutput(audioOutput)
                let queue = DispatchQueue(label: "audioOutputQueue")
                audioOutput.setSampleBufferDelegate(self, queue: queue)
            }
        }
        catch
        {
            print("Błąd podczas dodawania wejścia: \(error)")
        }
    }

    func startSession()
    {
        captureSession?.startRunning()
    }

    func stopSession()
    {
        captureSession?.stopRunning()
    }

    func getdata(from sampleBuffer: CMSampleBuffer) -> Data
    {
        var abl = AudioBufferList()
        var blockBuffer: CMBlockBuffer?

        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                bufferListSizeNeededOut: nil,
                                                                bufferListOut: &abl,
                                                                bufferListSize: MemoryLayout<AudioBufferList>.size,
                                                                blockBufferAllocator: nil,
                                                                blockBufferMemoryAllocator: nil,
                                                                flags: 0,
                                                                blockBufferOut: &blockBuffer)

        let buffers = UnsafeMutableAudioBufferListPointer(&abl)

        var data = Data()
        for audioBuffer in buffers {
            if let frame = audioBuffer.mData?.assumingMemoryBound(to: UInt8.self) {
                data.append(frame, count: Int(audioBuffer.mDataByteSize))
            }
        }
        return data
    }
    
    func convertToFloats(from sampleBuffer: CMSampleBuffer) -> [Float] {
        // 1. Pobierz ASBD
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else {
            return []
        }
        
        // 2. Sprawdź, czy format jest zgodny z oczekiwaniami
        guard asbd.mFormatID == kAudioFormatLinearPCM, asbd.mBitsPerChannel == 32, asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 else {
            print("Niewłaściwy format audio")
            return []
        }
        
        // 3. Pobierz dane
        let data = self.getdata(from: sampleBuffer)
        
        // 4. Konwersja na tablicę Float
        let count = data.count / 4
        var floatArray = [Float](repeating: 0, count: count)
        _ = floatArray.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        
        return floatArray
    }
    
    func generateSinWave(periods: Int, samples: Int) -> [Float]
    {
        var table = [Float](repeating: Float(0.0), count: samples)
        
        for x in 0..<samples
        {
            self.phase      = self.phase + self.freq
            self.freq      += 0.00001;

            table[x] = Float( sin(self.phase) * sin(2 * Double.pi * 8*Double(x)/Double(samples)))
        }
        return table
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        //print(sampleBuffer)
        
        let smpArray = self.convertToFloats(from: sampleBuffer)
        
        let floatArray = test_ena ? generateSinWave(periods: 128, samples: smpArray.count) : smpArray

        if !test_ena
        {
            freq = 0
        }
        
        if buffer.count == 0
        {
            self.buffer = floatArray
        }
        else
        {
            self.buffer = self.buffer + floatArray
        }
        
        if self.buffer.count < 2048
        {
            return;
        }
        else if self.buffer.count == 2048
        {
            let outBuff = self.buffer;
            self.buffer = []
            
            AL_Metal_SDFT.shared.compute(dataContainer: outBuff)
        }
        else if self.buffer.count >= 2048
        {
            let outBuff = Array(self.buffer.prefix(2048)) // pobranie pierwszych 2048 próbek
            self.buffer = Array(self.buffer.dropFirst(2048)) // usuń pierwsze 2048 próbek, zostaw resztę

            AL_Metal_SDFT.shared.compute(dataContainer: outBuff)
        }
    }
}

struct AudioDeviceView: View
{
    var device: AVCaptureDevice

    var body: some View {
        Text(device.localizedName)
    }
}

struct AudioDevicesListView: View
{
    @ObservedObject var audioSession = AudioSession()

    var devices: [AVCaptureDevice] = fetchAudioDevices()

    var body: some View
    {
        List(devices, id: \.uniqueID)
        { device in
            Button(action: {
                
                AVCaptureDevice.requestAccess(for: .audio)
                { response in
                    if response {
                        // Użytkownik przyznał dostęp
                    } else {
                        // Użytkownik odmówił dostępu
                    }
                }
                
                audioSession.selectedDevice = device
                print("selected",device)
            }) {
                AudioDeviceView(device: device)
            }
        }
        .onAppear {
            audioSession.startSession()
        }
        .onDisappear {
            audioSession.stopSession()
        }
    }
}

