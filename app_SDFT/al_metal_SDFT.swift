//
//  Al_Metal_DepthToImage.swift
//  vScanner3
//
//  Created by Adam Łuczak on 29/04/2022.
//

import Foundation
import Combine
import Foundation
import CoreMedia
import Metal
import MetalKit
import AVFoundation
import SwiftUI

class AL_Metal_SDFT: ObservableObject
{
    @Published  var outputDFT:[Float]                               = []
    @Published  var outputSig:[Float]                               = []
    @Published  var outputBuf:[Float]                               = []
    @Published  var outputSpec:[NSImage]                            = []

                let sdft_len                                        = 2048
                let hist_len                                        = 2048
                let hist_margin                                     = 128
                let spectrogram_dx                                  = 2048
                let spectrogram_dy                                  = 64

                var device:MTLDevice?                               = MTLCreateSystemDefaultDevice()

                var computePipelineState:MTLComputePipelineState?   = nil
                var commandQueue: MTLCommandQueue?                  = nil
                var commandBuffer:MTLCommandBuffer?                 = nil
                var computeCommandEncoder:MTLComputeCommandEncoder? = nil
                var shaderTransformFunction:MTLFunction?            = nil
                
                var outSpectrogramTextureCache:CVMetalTextureCache? = nil;
                var outSpectrogramTexture:MTLTexture?               = nil;

                var magInBuffer:MTLBuffer?                          = nil
                var magINDataCache:[Float]                          = Array(repeating: Float(0.0),count: 2048)

                var magOutBuffer:MTLBuffer?                         = nil
                var magOutDataCache:[Float]                         = Array(repeating: Float(0.0),count: 3*2048)

                var sdftRealBuffer:MTLBuffer?                       = nil
                var sdftRealDataCache:[Float]                       = Array(repeating: Float(0.0),count: 2048)

                var sdftImagBuffer:MTLBuffer?                       = nil
                var sdftImagDataCache:[Float]                       = Array(repeating: Float(0.0),count: 2048)

                var channelBuffer1:MTLBuffer?                       = nil
                var channelDataCache1:[Float]                       = Array(repeating: Float(0.0),count: 2048)

                var channelBuffer2:MTLBuffer?                       = nil
                var channelDataCache2:[Float]                       = Array(repeating: Float(0.0),count: 2048)
    
                var colorTableBuffer:MTLBuffer?                     = nil
                let colorTable                                      = AL_Metal_SDFT.fillLookupTable()
    

    static      var shared                                          = AL_Metal_SDFT()
    
    init()
    {
        if let device = device
        {
            commandQueue                = device.makeCommandQueue()

            let library                 = device.makeDefaultLibrary()
            shaderTransformFunction     = library!.makeFunction(name: "al_shader_sdft_func")!
        
            outSpectrogramTextureCache  = makeTextureCache();
            outSpectrogramTexture       = makeEmptyTexture(format: .bgra8Unorm,   width:  1024, height:  32)

            magInBuffer                 = device.makeBuffer(    bytes: magINDataCache,
                                                                length: 2048*MemoryLayout<Float>.size,
                                                                options: .storageModeShared)!
            
            magOutBuffer                = device.makeBuffer(    bytes: magOutDataCache,
                                                                length: 3*2048*MemoryLayout<Float>.size,
                                                                options: .storageModeShared)!

            sdftRealBuffer              = device.makeBuffer(    bytes: sdftRealDataCache,
                                                                length: 2048*MemoryLayout<Float>.size,
                                                                options: .storageModeShared)!

            sdftImagBuffer              = device.makeBuffer(    bytes: sdftImagDataCache,
                                                                length: 2048*MemoryLayout<Float>.size,
                                                                options: .storageModeShared)!
            
            channelBuffer1              = device.makeBuffer(    bytes: channelDataCache1,
                                                                length: 2048*MemoryLayout<Float>.size,
                                                                options: .storageModeShared)!
            
            channelBuffer2              = device.makeBuffer(    bytes: channelDataCache2,
                                                                length: 2048*MemoryLayout<Float>.size,
                                                                options: .storageModeShared)!

            colorTableBuffer            = device.makeBuffer(    bytes: colorTable,
                                                                length: 1024*MemoryLayout<simd_float3>.size,
                                                                options: .storageModeShared)!

            let zeroData                = [Float](repeating: 0.0, count: 2*2048)

            magInBuffer?.contents().copyMemory(from: zeroData, byteCount: 2048 * MemoryLayout<Float>.size)
            magOutBuffer?.contents().copyMemory(from: zeroData, byteCount: 3 * 2048 * MemoryLayout<Float>.size)
            sdftRealBuffer?.contents().copyMemory(from: zeroData, byteCount: 2048 * MemoryLayout<Float>.size)
            sdftImagBuffer?.contents().copyMemory(from: zeroData, byteCount: 2048 * MemoryLayout<Float>.size)
            channelBuffer1?.contents().copyMemory(from: zeroData, byteCount: 2048 * MemoryLayout<Float>.size)
            channelBuffer2?.contents().copyMemory(from: zeroData, byteCount: 2048 * MemoryLayout<Float>.size)
        }
        else
        {
            print("error loading device")
        }
    }
    
    //-----------------------------------------------------------------------
    // create texture cache
    //-----------------------------------------------------------------------

    func makeTextureCache()->CVMetalTextureCache?
    {
        var newTextureCache: CVMetalTextureCache? = nil
        
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device!, nil, &newTextureCache) != kCVReturnSuccess
        {
            assertionFailure("Unable to allocate texture cache")
        }
        
        return(newTextureCache)
    }

    //-----------------------------------------------------------------------
    // create empty texture
    //-----------------------------------------------------------------------

    func makeEmptyTexture(format: MTLPixelFormat, width:Int, height:Int)->MTLTexture?
    {
        let matchingDescriptor              = MTLTextureDescriptor()
            matchingDescriptor.width        = width
            matchingDescriptor.height       = height
            matchingDescriptor.usage        = .shaderWrite
            matchingDescriptor.pixelFormat  = format//.bgra8Unorm
            matchingDescriptor.storageMode  = .shared
    
            return( device?.makeTexture(descriptor: matchingDescriptor))
    }
    
    //-----------------------------------------------------------------------
    // run shader for depthmap
    //-----------------------------------------------------------------------

    func compute(dataContainer:[Float]) -> [Float]
    {
        let size = channelBuffer1!.length

        memcpy(channelBuffer2!.contents(), channelBuffer1!.contents(), size)
        memcpy(channelBuffer1!.contents(), dataContainer, dataContainer.count*4)

        do
        {
            computePipelineState        = try device!.makeComputePipelineState(function: shaderTransformFunction!)
        }
        catch
        {
            print("error !")
            return []
        }

        //...........................
        // prepare command encoder
        //...........................

        let startTime = Date()

        commandBuffer                   = commandQueue?.makeCommandBuffer()!
        computeCommandEncoder           = commandBuffer?.makeComputeCommandEncoder()!
        
        guard (computeCommandEncoder)  != nil else {print("cannot init computeCommandEncoder"); return [] }
        
        computeCommandEncoder!.setComputePipelineState(computePipelineState!)
        
        computeCommandEncoder!.setTexture(outSpectrogramTexture,    index: 0)
        
        computeCommandEncoder!.setBuffer (sdftRealBuffer,   offset: 0,   index: 0)
        computeCommandEncoder!.setBuffer (sdftImagBuffer,   offset: 0,   index: 1)
        computeCommandEncoder!.setBuffer (magInBuffer,      offset: 0,   index: 2)
        computeCommandEncoder!.setBuffer (magOutBuffer,     offset: 0,   index: 3)
        computeCommandEncoder!.setBuffer (channelBuffer1,   offset: 0,   index: 4)
        computeCommandEncoder!.setBuffer (channelBuffer2,   offset: 0,   index: 5)
        computeCommandEncoder!.setBuffer (colorTableBuffer, offset: 0,   index: 6)

        computeCommandEncoder!.dispatchThreadgroups(MTLSize(width:1, height:1, depth:1), threadsPerThreadgroup: MTLSize(width: 512, height: 1, depth: 1))
        computeCommandEncoder!.endEncoding()
        
        commandBuffer!.commit()
        commandBuffer!.waitUntilCompleted()
    
        let elapsedTime = Date().timeIntervalSince(startTime)
        //print("Czas wykonania: \(elapsedTime) sekund.")

        let dataSize    = 2048*MemoryLayout<Float>.stride
        let data        = NSData(bytesNoCopy: (magInBuffer?.contents())!, length: dataSize, freeWhenDone: false)
            data.getBytes(&magINDataCache, length: dataSize)

        let dataSize1    = 2048*MemoryLayout<Float>.stride
        let data1        = NSData(bytesNoCopy: (channelBuffer1?.contents())!, length: dataSize1, freeWhenDone: false)
            data1.getBytes(&channelDataCache1, length: dataSize1)

        let dataSize2    = 2048*MemoryLayout<Float>.stride
        let data2        = NSData(bytesNoCopy: (channelBuffer2?.contents())!, length: dataSize2, freeWhenDone: false)
            data2.getBytes(&channelDataCache2, length: dataSize2)

        let out_specBar  = outSpectrogramTexture?.convertRGBAToCGImage()
        let image        = NSImage(cgImage: out_specBar!, size: CGSize(width: 1024, height: 32))

        
        DispatchQueue.main.async
        {
            self.outputDFT      = self.magINDataCache
            self.outputSig      = self.channelDataCache1
            self.outputBuf      = self.channelDataCache2

            if self.outputSpec.count > 8
            {
                self.outputSpec.remove(at: 0)
            }
            self.outputSpec.append(image);
        }
        return magINDataCache
    }
    
    // lookup table for spectrogram
    
    static func fillLookupTable() -> [simd_float3]
    {
        let numberOfEntries = 1024

        // Definiujemy tablicę dla kolorów w formacie RGB w zakresie [0, 1].
        var colors = [simd_float3](repeating: simd_float3(0, 0, 0), count: numberOfEntries)

        for value in (0..<numberOfEntries) {
            let normalizedValue = CGFloat(value) / CGFloat(numberOfEntries - 1)
          
            // Definiowanie `hue` - od niebieskiego przy `0.0` do czerwonego przy `1.0`.
            let hue = 0.6666 - (0.6666 * normalizedValue)
            let brightness = sqrt(normalizedValue)
            
            let color = NSColor(hue: hue,
                                saturation: 1,
                                brightness: brightness,
                                alpha: 1)
            
            var red = CGFloat()
            var green = CGFloat()
            var blue = CGFloat()
            
            color.getRed(&red, green: &green, blue: &blue, alpha: nil)
         
            // Zapisywanie kolorów w formacie RGB.
            colors[value] = simd_float3(Float(green), Float(red), Float(blue))
        }
        
        return colors
    }
}


