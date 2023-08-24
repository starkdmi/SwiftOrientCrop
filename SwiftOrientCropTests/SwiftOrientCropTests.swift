//
//  SwiftOrientCropTests.swift
//  SwiftOrientCropTests
//
//  Created by Dmitry Starkov on 24/08/2023.
//

import XCTest
import SwiftOrientCrop
import UniformTypeIdentifiers
import Accelerate.vImage

final class SwiftOrientCropTests: XCTestCase {

    static let testsDirectory = URL(fileURLWithPath: #file).deletingLastPathComponent()
    static let mediaDirectory = testsDirectory.appendingPathComponent("media")

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: Oriented image generator

    func testGenerator() throws {
        let sourceImageFile = Self.mediaDirectory.appendingPathComponent("iphone_x.jpg")
        let destinationDirectory = URL(fileURLWithPath: NSTemporaryDirectory()) // Self.tempDirectory
        try OrientedGenerator.generateFrom(source: sourceImageFile, destination: destinationDirectory, format: .jpeg)
        print("Generated images saved at \(destinationDirectory.path)")
    }

    // MARK: Load & Orient

    func testLoadCGImageAndOrient() throws {
        let source = Self.mediaDirectory.appendingPathComponent("iphone_x.jpg")
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else { return }

        // Read image properties
        let primaryIndex = CGImageSourceGetPrimaryImageIndex(imageSource)
        var properties = CGImageSourceCopyPropertiesAtIndex(imageSource, primaryIndex, nil) as? [CFString: Any]

        // Load image
        guard var cgImage = CGImageSourceCreateImageAtIndex(imageSource, primaryIndex, [
            kCGImageSourceShouldCacheImmediately: true
        ] as [CFString: Any] as CFDictionary) else { return }
        // Or the thumbnailed version
        /*let thumbnailsize = CGSize(width: 1280, height: 1280)
        guard var cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, primaryIndex, [
            kCGImageSourceCreateThumbnailWithTransform: false, // required for thumbnail to have same orientation as original
            kCGImageSourceCreateThumbnailFromImageAlways: true, // required to prevent from loading existing thumbnail image which may have different size
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(thumbnailsize.width, thumbnailsize.height)
        ] as [CFString: Any] as CFDictionary) else { return }*/

        // Apply current image orientation
        if let orientationProperty = properties?[kCGImagePropertyOrientation] as? UInt32,
            let orientation = CGImagePropertyOrientation(rawValue: orientationProperty),
            orientation != .up {
            cgImage = cgImage.oriented(orientation: orientation)
            properties?[kCGImagePropertyOrientation] = 1 // override orientation to .up
        }

        // Save CGImage
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("oriented_cgImage.jpg")
        if let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
            // Modify image quality and other settings
            properties?[kCGImageDestinationLossyCompressionQuality] = 0.75

            // Set image properties
            if let properties = properties {
                CGImageDestinationSetProperties(destination, properties as CFDictionary)
            }

            // Add image frame
            CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary?)

            // Write image file
            if CGImageDestinationFinalize(destination) == true {
                print("Image saved at \(url.path)")
            }
        }
    }

    func testLoadOrientedCIImage() throws {
        let source = Self.mediaDirectory.appendingPathComponent("iphone_x.jpg")

        // Load image
        guard let ciImage = CIImage(contentsOf: source, options: [.applyOrientationProperty: true]) else { return }

        // Save image
        let context = CIContext()
        let colorSpace = ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("oriented_ciImage_auto.jpg")
        try context.writeJPEGRepresentation(of: ciImage, to: url, colorSpace: colorSpace)
        print("Image saved at \(url.path)")
    }

    func testLoadCIImageAndOrient() throws {
        let source = Self.mediaDirectory.appendingPathComponent("iphone_x.jpg")

        // Load image
        guard var ciImage = CIImage(contentsOf: source, options: [.applyOrientationProperty: false]) else { return }

        // Read image properties
        var properties = ciImage.properties
        var orientation: CGImagePropertyOrientation?
        if let orientationProperty = properties[kCGImagePropertyOrientation as String] as? UInt32 {
            orientation = CGImagePropertyOrientation(rawValue: orientationProperty)
        }

        // Orient manually
        if let orientation = orientation {
            // Using built-in `CIImage` function
            ciImage = ciImage.oriented(orientation)
            // Or ported `CGImage` custom implementation
            // ciImage = ciImage.oriented(orientation: orientation)

            // Override orientation in metadata
            properties[kCGImagePropertyOrientation as String] = 1 // .up
            ciImage = ciImage.settingProperties(properties)
        }

        // Save image
        let context = CIContext()
        let colorSpace = ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("oriented_ciImage_manual.jpg")
        try context.writeJPEGRepresentation(of: ciImage, to: url, colorSpace: colorSpace)
        print("Image saved at \(url.path)")
    }

    // MARK: Orient Cropping Rectangle

    func testOrientCGRect() throws {
        let rect = CGRect(x: 512, y: 0, width: 1024, height: 1024)

        for (orientation, size) in [
            CGImagePropertyOrientation.up: CGSize(width: 1200, height: 1800),
            .upMirrored: CGSize(width: 1200, height: 1800),
            .down: CGSize(width: 1200, height: 1800),
            .downMirrored: CGSize(width: 1200, height: 1800),
            .leftMirrored: CGSize(width: 1800, height: 1200),
            .right: CGSize(width: 1800, height: 1200),
            .rightMirrored: CGSize(width: 1800, height: 1200),
            .left: CGSize(width: 1800, height: 1200)
        ].sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            print("______\(orientation.description)_______")

            let rect = rect.intersection(CGRect(origin: .zero, size: size.oriented(orientation)))

            // MARK: Using custom CGImage extension

            let orientedRect = rect.oriented(orientation, in: size)
            print("Oriented CGRect \(orientedRect)")

            // MARK: The same could be done using CIImage

            // Create tranform which may be applied to CIImage to orient it
            let size = size.oriented(orientation)
            let ciTransform = CIImage(color: .clear)
                .clamped(to: CGRect(origin: .zero, size: size))
                .cropped(to: CGRect(origin: .zero, size: size))
                .orientationTransform(for: orientation)
            var transformed = rect.applying(ciTransform)

            // Fix .leftMirrored and .rightMirrored cases
            if orientation == .leftMirrored {
                transformed = CGRect(
                    x: rect.origin.y,
                    y: rect.origin.x,
                    width: rect.size.height,
                    height: rect.size.width
                )
            }
            if orientation == .rightMirrored {
                transformed = CGRect(
                    x: size.height - rect.size.height - rect.origin.y,
                    y: size.width - rect.size.width - rect.origin.x,
                    width: rect.size.height,
                    height: rect.size.width
                )
            }
            print("CIImage-based Oriented CGRect \(transformed)")

            print("_________________")
        }
    }

    // MARK: Crop CGImage, CIImage and vImage

    func testCropCGImage() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let rect = CGRect(x: 0, y: 0, width: 2048, height: 2048)

        for index in 1...8 {
            print("______\(CGImagePropertyOrientation(rawValue: UInt32(index))!.description)_______")

            let source = Self.mediaDirectory.appendingPathComponent("iphone_x_\(index).jpg")
            guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else { return }

            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, [
                kCGImageSourceShouldCacheImmediately: true
            ] as [CFString: Any] as CFDictionary) else { return }

            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
            var orientation: CGImagePropertyOrientation?
            if let orientationProperty = properties?[kCGImagePropertyOrientation] as? UInt32 {
                orientation = CGImagePropertyOrientation(rawValue: orientationProperty)
            }

            // Cropping rectangle
            let orientedRect = rect
                // Intersect cropping area with original image size
                .intersection(CGRect(origin: .zero, size: cgImage.size(orientation: orientation)))
                // Orient
                .oriented(orientation, in: cgImage.size)

            // Crop
            guard let croppedImage = cgImage.cropping(to: orientedRect) else { return }

            // Save CGImage
            let url = tempDirectory.appendingPathComponent("cropped_cgImage_\(index).jpg")
            if let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
                // Add image frame
                CGImageDestinationAddImage(destination, croppedImage, [
                    // Preserve original orientation value
                    kCGImagePropertyOrientation: orientation?.rawValue ?? 0
                ] as CFDictionary)

                // Write image file
                if CGImageDestinationFinalize(destination) == true {
                    print("Cropped image saved at \(url.path)")
                }
            }

            print("_________________")
        }
    }

    func testCropCIImage() throws {
        let rect = CGRect(x: 0, y: 0, width: 2048, height: 2048)

        for index in 1...8 {
            print("______\(CGImagePropertyOrientation(rawValue: UInt32(index))!.description)_______")

            // Load image
            let source = Self.mediaDirectory.appendingPathComponent("iphone_x_\(index).jpg")
            guard let ciImage = CIImage(contentsOf: source, options: [.applyOrientationProperty: false]) else { return }

            // Read image properties
            let properties = ciImage.properties
            var orientation: CGImagePropertyOrientation?
            if let orientationProperty = properties[kCGImagePropertyOrientation as String] as? UInt32 {
                orientation = CGImagePropertyOrientation(rawValue: orientationProperty)
            }

            // Cropping rectangle
            let orientedRect = rect
                // Intersect cropping area with original image size
                .intersection(CGRect(origin: .zero, size: ciImage.extent.size.oriented(orientation)))
                // Orient
                .oriented(orientation, in: ciImage.extent.size)

            let ciRect = CGRect(
                x: orientedRect.origin.x,
                y: ciImage.extent.height - orientedRect.size.height - orientedRect.origin.y,
                width: orientedRect.size.width, height: orientedRect.size.height
            )

            // Crop
            let croppedImage = ciImage.cropped(to: ciRect)
                .transformed(by: CGAffineTransform(translationX: -ciRect.origin.x, y: -ciRect.origin.y))

            // Save CIImage
            let context = CIContext()
            let colorSpace = ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cropped_ciImage_\(index).jpg")
            try context.writeJPEGRepresentation(of: croppedImage, to: url, colorSpace: colorSpace)
            print("Cropped image saved at \(url.path)")

            print("_________________")
        }
    }

    func testCropVImageCG() throws {
        // The code for image loading and saving is the same as in `testCropCGImage()`, only processing done via vImage
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let rect = CGRect(x: 0, y: 0, width: 2048, height: 2048)

        for index in 1...8 {
            print("______\(CGImagePropertyOrientation(rawValue: UInt32(index))!.description)_______")

            let source = Self.mediaDirectory.appendingPathComponent("iphone_x_\(index).jpg")
            guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else { return }

            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, [
                kCGImageSourceShouldCacheImmediately: true
            ] as [CFString: Any] as CFDictionary) else { return }

            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
            var orientation: CGImagePropertyOrientation?
            if let orientationProperty = properties?[kCGImagePropertyOrientation] as? UInt32 {
                orientation = CGImagePropertyOrientation(rawValue: orientationProperty)
            }

            // Cropping rectangle
            let orientedRect = rect
                // Intersect cropping area with original image size
                .intersection(CGRect(origin: .zero, size: cgImage.size(orientation: orientation)))
                // Orient
                .oriented(orientation, in: cgImage.size)

            // MARK: vImage Processing

            guard let format = vImage_CGImageFormat(cgImage: cgImage) else { return }

            // Convert CGImage to Image Buffer
            let imageBuffer = try vImage_Buffer(cgImage: cgImage, format: format, flags: [.noFlags])

            // Crop
            let croppedData = imageBuffer.data.assumingMemoryBound(to: UInt8.self)
                .advanced(by: Int(orientedRect.origin.y) * imageBuffer.rowBytes + Int(orientedRect.origin.x) * (cgImage.bitsPerPixel / 8))

            let croppedBuffer = vImage_Buffer(data: croppedData,
                                 height: vImagePixelCount(orientedRect.size.height),
                                 width: vImagePixelCount(orientedRect.size.width),
                                 rowBytes: imageBuffer.rowBytes)

            // Convert vImage_Buffer to CGImage
            let croppedImage = try croppedBuffer.createCGImage(format: format, flags: [.highQualityResampling])
            imageBuffer.free() // croppedBuffer point to the same memory and shouldn't be cleared after

            // Save CGImage
            let url = tempDirectory.appendingPathComponent("cropped_vImageCG_\(index).jpg")
            if let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
                // Add image frame
                CGImageDestinationAddImage(destination, croppedImage, [
                    // Preserve original orientation value
                    kCGImagePropertyOrientation: orientation?.rawValue ?? 0
                ] as CFDictionary)

                // Write image file
                if CGImageDestinationFinalize(destination) == true {
                    print("Cropped image saved at \(url.path)")
                }
            }

            print("_________________")
        }
    }

    func testCropVImageCI() throws {
        // The code for image loading and saving is the same as in `testCropCIImage()`, only processing done via vImage
        let rect = CGRect(x: 0, y: 0, width: 2048, height: 2048)

        for index in 1...8 {
            print("______\(CGImagePropertyOrientation(rawValue: UInt32(index))!.description)_______")

            // Load image
            let source = Self.mediaDirectory.appendingPathComponent("iphone_x_\(index).jpg")
            guard let ciImage = CIImage(contentsOf: source, options: [.applyOrientationProperty: false]) else { return }

            // Read image properties
            let properties = ciImage.properties
            var orientation: CGImagePropertyOrientation?
            if let orientationProperty = properties[kCGImagePropertyOrientation as String] as? UInt32 {
                orientation = CGImagePropertyOrientation(rawValue: orientationProperty)
            }

            // Cropping rectangle
            let orientedRect = rect
                // Intersect cropping area with original image size
                .intersection(CGRect(origin: .zero, size: ciImage.extent.size.oriented(orientation)))
                // Orient
                .oriented(orientation, in: ciImage.extent.size)

            // Convert CIImage to CGImage
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

            // MARK: vImage Processing

            guard let format = vImage_CGImageFormat(cgImage: cgImage) else { return }

            // Convert CGImage to Image Buffer
            let imageBuffer = try vImage_Buffer(cgImage: cgImage, format: format, flags: [.noFlags])

            // Crop
            let croppedData = imageBuffer.data.assumingMemoryBound(to: UInt8.self)
                .advanced(by: Int(orientedRect.origin.y) * imageBuffer.rowBytes + Int(orientedRect.origin.x) * (cgImage.bitsPerPixel / 8))

            let croppedBuffer = vImage_Buffer(data: croppedData,
                                 height: vImagePixelCount(orientedRect.size.height),
                                 width: vImagePixelCount(orientedRect.size.width),
                                 rowBytes: imageBuffer.rowBytes)

            // Convert vImage_Buffer to CGImage
            let croppedCGImage = try croppedBuffer.createCGImage(format: format, flags: [.highQualityResampling])
            imageBuffer.free() // croppedBuffer point to the same memory and shouldn't be cleared after

            // Convert CGImage to CIImage
            var croppedImage = CIImage(cgImage: croppedCGImage, options: [.applyOrientationProperty: false])
            croppedImage = croppedImage.settingProperties(properties)

            // Save CIImage
            let colorSpace = ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cropped_vImageCI_\(index).jpg")
            try context.writeJPEGRepresentation(of: croppedImage, to: url, colorSpace: colorSpace)
            print("Cropped image saved at \(url.path)")

            print("_________________")
        }
    }

    // MARK: Benchmarks

    func testPerformanceCGCrop() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTStorageMetric(), XCTCPUMetric()]) {
            // Test all 10X (38.719 seconds)
            // [CPU Cycles, kC]:
            // - average: 17183934.826
            // - relative standard deviation: 0.931%
            // [Clock Monotonic Time, s]:
            // - average: 6.372
            // - relative standard deviation: 0.873%
            // [CPU Time, s]:
            // - average: 5.365
            // - relative standard deviation: 0.890%
            // [Memory Physical, kB]:
            // - average: 101.594
            // - relative standard deviation: 139.277%
            // [CPU Instructions Retired, kI]:
            // - average: 36206013.045
            // - relative standard deviation: 0.096%
            // [Memory Peak Physical, kB]:
            // - average: 118737.203
            // - relative standard deviation: 0.145%
            // [Disk Logical Writes, kB]:
            // - average: 92453.274
            // - relative standard deviation: 0.629%
            for _ in 0 ..< 10 {
                try? testCropCGImage()
            }
        }
    }

    func testPerformanceCICrop() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTStorageMetric(), XCTCPUMetric()]) {
            // Test all 10X (14.432 seconds)
            // [CPU Cycles, kC]
            // - average: 4192019.178
            // - relative standard deviation: 2.613%
            // [Clock Monotonic Time, s]
            // - average: 2.352
            // - relative standard deviation: 15.741%
            // [CPU Time, s]
            // - average: 1.344
            // - relative standard deviation: 3.871%
            // [Memory Physical, kB]
            // - average: 62.298
            // - relative standard deviation: 326.941%
            // [CPU Instructions Retired, kI]
            // - average: 8606001.467
            // - relative standard deviation: 0.251%
            // [Memory Peak Physical, kB]
            // - average: 1526522.752
            // - relative standard deviation: 0.388%
            // [Disk Logical Writes, kB]
            // - average: 111464.448
            // - relative standard deviation: 0.544%
            for _ in 0 ..< 10 {
                try? testCropCIImage()
            }
        }
    }

    func testPerformanceVCGCrop() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTStorageMetric(), XCTCPUMetric()]) {
            // Test all 10X (31.458 seconds)
            // [CPU Cycles, kC]
            // - average: 16111197.274
            // - relative standard deviation: 0.294%,
            // [Clock Monotonic Time, s]
            // - average: 5.186
            // - relative standard deviation: 7.177%
            // [CPU Time, s]
            // - average: 5.162
            // - relative standard deviation: 0.458%
            // [Memory Physical, kB]
            // - average: 55.706
            // - relative standard deviation: 73.471%
            // [CPU Instructions Retired, kI]
            // - average: 25070455.486
            // - relative standard deviation: 0.089%
            // [Memory Peak Physical, kB]
            // - average: 119035.469
            // - relative standard deviation: 0.064%,
            // [Disk Logical Writes, kB]
            // - average: 92903.014
            // - relative standard deviation: 0.505%
            for _ in 0 ..< 10 {
                try? testCropVImageCG()
            }
        }
    }

    func testPerformanceVCICrop() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTStorageMetric(), XCTCPUMetric()]) {
            // Test all 10X (30.431 seconds)
            // [CPU Cycles, kC]
            // - average: 13929832.124
            // - relative standard deviation: 0.864%
            // [Clock Monotonic Time, s]
            // - average: 4.933
            // - relative standard deviation: 5.760%
            // [CPU Time, s]
            // - average: 4.445
            // - relative standard deviation: 0.971%
            // [Memory Physical, kB]
            // - average: -609.434
            // - relative standard deviation: -214.095%
            // - values: [-3211.008000, 0.000000, 196.608000, -114.688000, 81.920000]
            // [CPU Instructions Retired, kI]
            // - average: 23772650.985
            // - relative standard deviation: 0.135%
            // [Memory Peak Physical, kB]
            // - average: 1574029.363
            // - relative standard deviation: 1.780%
            // [Disk Logical Writes, kB]
            // - average: 111719.219
            // - relative standard deviation: 0.727%
            for _ in 0 ..< 10 {
                try? testCropVImageCI()
            }
        }
    }
}
