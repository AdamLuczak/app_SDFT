//
//  ContentView.swift
//  xaoc_sdft_macos
//
//  Created by Adam Łuczak on 17/08/2023.
//


import SwiftUI
import AVFoundation
import Foundation
import CoreGraphics
import AppKit

struct ContentView: View
{
    @ObservedObject var sdft            = AL_Metal_SDFT.shared
    @State          var mag:[Float]     = []
    @ObservedObject var audioSession    = AudioSession()
                    var devices: [AVCaptureDevice] = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .externalUnknown], mediaType: .audio, position: .unspecified).devices
    
    @State var isSelected = false;
    
    var body: some View
    {
        NavigationSplitView
        {
            VStack
            {
                VStack()
                {
                    ForEach(devices, id: \.uniqueID)
                    { device in
                        
                        HStack
                        {
                            Button(action:
                                    {
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
                            },
                                   label:
                                    {
                                HStack
                                {
                                    Text(device.localizedName)
                                        .font(.system(size: 12))
                                }
                                .padding(4)
                                .frame(maxWidth:.infinity)
                                .cornerRadius(8)
                            })
                            .padding(4)
                            
                            Spacer()
                        }
                        
                    }
                    .onAppear {
                        audioSession.startSession()
                    }
                    .onDisappear {
                        audioSession.stopSession()
                    }
                }
                .frame(minHeight: 128)
                
                VStack
                {
                    Form
                    {
                        Section(header:Text("Mode"))
                        {
                            Toggle("test signal",isOn: $audioSession.test_ena)
                        }
                    }
                    Spacer()
                }
                .frame(minHeight: 128)
            }
        }
        detail:
        {
            VStack
            {
                GraphView(data: $sdft.outputSig, isLogScale: false)
                    .frame(width: 1024, height: 56)
                    .foregroundColor(.white)
                    .background(Color.indigo.opacity(0.15))
                
                GraphView(data: $sdft.outputDFT, isLogScale: true)
                    .frame(width: 1024, height: 200)
                    .foregroundColor(.white)
                    .background(Color.indigo.opacity(0.25))
                
                
                VStack(spacing:0)
                {
                    if sdft.outputSpec.count > 0
                    {
                        let last = sdft.outputSpec.count - 1
                        
                        ForEach(0..<sdft.outputSpec.count, id: \.self)
                        { ind in
                            
                            Image(nsImage:sdft.outputSpec[last - ind])
                                .frame(width:1024, height:32)
                                .padding(0)
                        }
                    }
                }
                .frame(minHeight: 128)
                
                Spacer()
            }
        }
        .onAppear
        {
        }
    }
}


import SwiftUI

struct GraphView: View
{
    @Binding var data: [Float]
    let isLogScale:Bool
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let verticalScale: CGFloat = size.height
                let horizontalScale: CGFloat = size.width / CGFloat(1024)

                guard data.count > 1 else { return }
                
                var path = Path()
                let numberOfOktaves = 1

                path.move(to: CGPoint(x: 0, y: 100-CGFloat(data[0]/100) * verticalScale))
                
                for index in 0...1023 {
                    let value       = data[index]
                    var xPosition   = CGFloat(index) * horizontalScale
                    
                    if isLogScale
                    {
                        let logScaledIndex              = log10(CGFloat(index + 1))
                        let maxLogScaledValue           = log10(CGFloat(1024))
                        let normalizedLogScaledIndex    = CGFloat(index) / CGFloat(1024)
                        
                        xPosition = normalizedLogScaledIndex * size.width
                        
                        path.addLine(to: CGPoint(x: xPosition, y: 0-CGFloat(value/80) * verticalScale))
                    }
                    else
                    {
                        path.addLine(to: CGPoint(x: xPosition, y: size.height/2-CGFloat(value/2) * verticalScale))
                    }
                }
                
                context.stroke(path, with: .color(.blue), lineWidth: 1)
            }
        }
    }
}
