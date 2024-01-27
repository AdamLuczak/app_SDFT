//
//  al_audio_manager.swift
//  xaoc_sdft_macos
//
//  Created by Adam Łuczak on 18/08/2023.
//

import Foundation

import CoreAudio
import SwiftUI
import Combine

class AudioDeviceManager: ObservableObject {
    
    @Published var inputDevices: [String] = []
    @Published var outputDevices: [String] = []
    
    init() 
    {
        fetchAudioDevices()
    }
    
    func fetchAudioDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster)
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        guard status == kAudioHardwareNoError else {
            print("Error retrieving the size of the devices list.")
            return
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs: [AudioObjectID] = Array(repeating: 0, count: deviceCount)
        
        let status2 = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        
        guard status2 == kAudioHardwareNoError else {
            print("Error retrieving the devices list.")
            return
        }
        
        for id in deviceIDs {
               var propertySize: UInt32 = 256
               var name: CFString = "" as CFString
               var property = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceNameCFString, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
               AudioObjectGetPropertyData(id, &property, 0, nil, &propertySize, &name)
               
               // Check if it's an input or output device
               var streamCount: UInt32 = 0
               var dataSourceCount: UInt32 = 0
               property.mScope = kAudioDevicePropertyScopeInput
               AudioObjectGetPropertyDataSize(id, &property, 0, nil, &streamCount)
               property.mSelector = kAudioDevicePropertyDataSources
               AudioObjectGetPropertyDataSize(id, &property, 0, nil, &dataSourceCount)
               if streamCount > 0 && dataSourceCount > 0 {
                   inputDevices.append(name as String)
               }
               
               streamCount = 0
               dataSourceCount = 0
               property.mScope = kAudioDevicePropertyScopeOutput
               AudioObjectGetPropertyDataSize(id, &property, 0, nil, &streamCount)
               property.mSelector = kAudioDevicePropertyDataSources
               AudioObjectGetPropertyDataSize(id, &property, 0, nil, &dataSourceCount)
               if streamCount > 0 && dataSourceCount > 0 {
                   outputDevices.append(name as String)
               }
           }
    }
}

struct audioIOView: View
{
    @ObservedObject var deviceManager = AudioDeviceManager()
    
    var body: some View {
        VStack {
            List(deviceManager.inputDevices, id: \.self) { device in
                Text(device).padding().background(Color.red).cornerRadius(10)
            }.frame(height: 200)
            
            List(deviceManager.outputDevices, id: \.self) { device in
                Text(device).padding().background(Color.blue).cornerRadius(10)
            }.frame(height: 200)
        }
    }
}
