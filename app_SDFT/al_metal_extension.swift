//
//  al_metal_extension.swift
//  xaoc_sdft
//
//  Created by Adam Łuczak on 17/08/2023.
//

import Foundation
import MetalKit

extension MTLTexture
{
    func convertMonoToCGImage() -> CGImage?
    {
        //assert(texture.pixelFormat == .bgra8Unorm)
        
        let width               = self.width
        let height              = self.height
        let pixelByteCount      = 1 * MemoryLayout<UInt8>.size
        let imageBytesPerRow    = width * pixelByteCount
        let imageByteCount      = imageBytesPerRow * height
        let imageBytes          = UnsafeMutableRawPointer.allocate(byteCount: imageByteCount, alignment: pixelByteCount)
        
        self.getBytes(  imageBytes,
                         bytesPerRow: imageBytesPerRow,
                         from: MTLRegionMake2D(0, 0, width, height),
                         mipmapLevel: 0)
        
        guard let colorSpace    = CGColorSpace(name: CGColorSpace.linearGray) else { return nil }
        
        let bitmapInfo:UInt32   = 0//CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let bitmapContext = CGContext(data: nil,
                                            width: width,
                                            height: height,
                                            bitsPerComponent: 8,
                                            bytesPerRow: imageBytesPerRow,
                                            space: colorSpace,
                                            bitmapInfo: bitmapInfo) else { return nil }
        
        bitmapContext.data?.copyMemory(from: imageBytes, byteCount: imageByteCount)
        
        let image = bitmapContext.makeImage()
        
        defer
        {
            imageBytes.deallocate()
        }
        
        return image
    }
    
    func convertRGBAToCGImage() -> CGImage?
    {
        //assert(texture.pixelFormat == .bgra8Unorm)
        
        let width               = self.width
        let height              = self.height
        let pixelByteCount      = 4 * MemoryLayout<UInt8>.size
        let imageBytesPerRow    = width * pixelByteCount
        let imageByteCount      = imageBytesPerRow * height
        let imageBytes          = UnsafeMutableRawPointer.allocate(byteCount: imageByteCount, alignment: pixelByteCount)
        
        self.getBytes(  imageBytes,
                         bytesPerRow: imageBytesPerRow,
                         from: MTLRegionMake2D(0, 0, width, height),
                         mipmapLevel: 0)
        
        guard let colorSpace    = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        
        let bitmapInfo          = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let bitmapContext = CGContext(data: nil,
                                            width: width,
                                            height: height,
                                            bitsPerComponent: 8,
                                            bytesPerRow: imageBytesPerRow,
                                            space: colorSpace,
                                            bitmapInfo: bitmapInfo) else { return nil }
        
        bitmapContext.data?.copyMemory(from: imageBytes, byteCount: imageByteCount)
        
        let image = bitmapContext.makeImage()
        
        defer
        {
            imageBytes.deallocate()
        }
        
        return image
    }
    
    func convertMonoToOneComponent8() -> CGImage?
    {
        var pxbuffer: CVPixelBuffer? = nil
            
        let imageWidth      = 100;
        let imageHeight     = 100;
        let attributes      = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary

            CVPixelBufferCreate(kCFAllocatorDefault,
                                imageWidth,
                                imageHeight,
                                kCVPixelFormatType_OneComponent8,
                                attributes as CFDictionary?,
                                &pxbuffer)
        
        
        return nil
    }
     
    func convertF16ToCVPixelBuffer() -> CVPixelBuffer?
    {
        assert(self.pixelFormat == .r16Float)

        var pixelBuffer: CVPixelBuffer?

        CVPixelBufferCreate(    kCFAllocatorDefault,
                                self.width,
                                self.height,
                                kCVPixelFormatType_DepthFloat16,
                                nil,
                                &pixelBuffer)
              
        if let pixelBuffer = pixelBuffer
        {
             CVPixelBufferLockBaseAddress( pixelBuffer, [])

             let pixelBufferBytes   = CVPixelBufferGetBaseAddress( pixelBuffer )
             let bytesPerRow        = CVPixelBufferGetBytesPerRow( pixelBuffer )
             let region             = MTLRegionMake2D(0, 0, self.width, self.height)

             self.getBytes( pixelBufferBytes!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
             
             CVPixelBufferUnlockBaseAddress( pixelBuffer, [])
             
             return pixelBuffer
        }

        return nil
    }
    
    func convertF32ToCVPixelBuffer() -> CVPixelBuffer?
     {
         assert(self.pixelFormat == .r32Float)
         
         var pixelBuffer: CVPixelBuffer?

         CVPixelBufferCreate(   kCFAllocatorDefault,
                                self.width,
                                self.height,
                                kCVPixelFormatType_DepthFloat32,
                                nil,
                                &pixelBuffer)
                  
         if let pixelBuffer = pixelBuffer
         {
             CVPixelBufferLockBaseAddress( pixelBuffer, [])
         
             let pixelBufferBytes   = CVPixelBufferGetBaseAddress( pixelBuffer )
             let bytesPerRow        = CVPixelBufferGetBytesPerRow( pixelBuffer )
             let region             = MTLRegionMake2D(0, 0, self.width, self.height)

             self.getBytes( pixelBufferBytes!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
             
             CVPixelBufferUnlockBaseAddress( pixelBuffer, [])
             
             return pixelBuffer
         }
         
         return nil
    }
    
    func convertRGBAToCVPixelBuffer() -> CVPixelBuffer?
    {
         //assert(texture.pixelFormat == .bgra8Unorm)
         
         var pixelBuffer: CVPixelBuffer?

         CVPixelBufferCreate(   kCFAllocatorDefault,
                                self.width,
                                self.height,
                                kCVPixelFormatType_32BGRA,
                                nil,
                                &pixelBuffer)
                  
         if let pixelBuffer = pixelBuffer
         {
             CVPixelBufferLockBaseAddress( pixelBuffer, [])
         
             let pixelBufferBytes   = CVPixelBufferGetBaseAddress( pixelBuffer )
             let bytesPerRow        = CVPixelBufferGetBytesPerRow( pixelBuffer )
             let region             = MTLRegionMake2D(0, 0, self.width, self.height)

             self.getBytes( pixelBufferBytes!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
             
             CVPixelBufferUnlockBaseAddress( pixelBuffer, [])
                          
             return pixelBuffer
         }
         
         return nil
    }
}
