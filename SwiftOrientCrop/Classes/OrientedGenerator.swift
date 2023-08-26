//
//  OrientedGenerator.swift
//  SwiftOrientCrop
//
//  Created by Dmitry Starkov on 24/08/2023.
//

import CoreImage
import AVFoundation

#if os(macOS)
import AppKit
typealias Font = NSFont
typealias Color = NSColor
#else
import UIKit
typealias Font = UIFont
typealias Color = UIColor
#endif

/// Image output format
public enum ImageFormat: String {
    case jpeg, png, heif, tiff

    @available(macOS 12.0, *) case heif10
}

/// Struct for all possible orientation configurations
private struct ImageOrientation {
    let orientation: CGImagePropertyOrientation
    let angle: CGFloat
    let isMirrored: Bool

    /// Orientation configurations
    static let orientations: [ImageOrientation] = [
        .init(orientation: .up, angle: 0, isMirrored: false),
        .init(orientation: .upMirrored, angle: 0, isMirrored: true),
        .init(orientation: .down, angle: .pi, isMirrored: false),
        .init(orientation: .downMirrored, angle: .pi, isMirrored: true),
        .init(orientation: .leftMirrored, angle: .pi / 2.0, isMirrored: true),
        .init(orientation: .right, angle: .pi / 2.0, isMirrored: false),
        .init(orientation: .rightMirrored, angle: -.pi / 2.0, isMirrored: true),
        .init(orientation: .left, angle: -.pi / 2.0, isMirrored: false)
    ]
}

public struct OrientedGenerator {
    /// Generate all EXIF oriented images from the source image
    /// - source: Source image file
    /// - destination: Destination directory, should exists
    /// - format: Image format
    /// - size: Size to fit, the source resolution is used for `nil`
    /// - quality: Image compression, from 0.0 to 1.0, used only by compressed image formats
    public static func generateFrom(
        source: URL,
        destination directory: URL,
        format: ImageFormat = .jpeg,
        size: CGSize? = nil,
        quality: Double? = nil
    ) throws {
        /* The equavialent to this code can be achieved using ImageMagick (except the direction labels):
         convert "image.jpg" -auto-orient -set option:exif '1' -orient "TopLeft" "oriented_1.jpg";
         convert "image.jpg" -auto-orient -set option:exif '2' -orient "TopRight" -flop "oriented_2.jpg";
         convert "image.jpg" -auto-orient -set option:exif '3' -orient "BottomRight" -rotate 180 "oriented_3.jpg";
         convert "image.jpg" -auto-orient -set option:exif '4' -orient "BottomLeft" -flop -rotate 180 "oriented_4.jpg";
         convert "image.jpg" -auto-orient -set option:exif '5' -orient "LeftTop" -flop -rotate -90 "oriented_5.jpg";
         convert "image.jpg" -auto-orient -set option:exif '6' -orient "RightTop" -rotate -90 "oriented_6.jpg";
         convert "image.jpg" -auto-orient -set option:exif '7' -orient "RightBottom" -flop -rotate 90 "oriented_7.jpg";
         convert "image.jpg" -auto-orient -set option:exif '8' -orient "LeftBottom" -rotate 90 "oriented_8.jpg"
        */

        let filename = source.lastPathComponent.components(separatedBy: ".").first ?? "oriented_image"

        // MARK: Load image

        let context = CIContext()
        var ciImage = CIImage(contentsOf: source, options: [.applyOrientationProperty: true])!
        // Resize
        if let size = size, ciImage.extent.width > size.width || ciImage.extent.height > size.height {
            // Size to fit in
            let rect = AVMakeRect(aspectRatio: ciImage.extent.size, insideRect: CGRect(origin: CGPoint.zero, size: size))

            ciImage = ciImage.applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: rect.size.width / ciImage.extent.size.width,
                kCIInputAspectRatioKey: 1.0
            ])
            /*ciImage = ciImage.clampedToExtent().applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: rect.size.width / ciImage.extent.size.width,
                kCIInputAspectRatioKey: 1.0
            ]).cropped(to: CGRect(origin: .zero, size: rect.size))*/
        }

        // MARK: Direction Labels

        // Setup
        let imageSize = ciImage.extent.size
        let offset: CGFloat = 16.0 // text offset from image border
        let fontSize = min(imageSize.width, imageSize.height) / 16.0 // relative text size
        let backgroundColor = CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.3) // transparent text background color
        let background = CIImage(color: backgroundColor) // text background image
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Font.systemFont(ofSize: fontSize),
            .foregroundColor: Color.white
        ]

        // Add labels
        let textGenerator = CIFilter(name: "CIAttributedTextImageGenerator")
        if let textGenerator = textGenerator {
            for (string, point) in [
                "Left": CGPoint(x: offset, y: imageSize.height/2),
                "Top": CGPoint(x: imageSize.width / 2, y: imageSize.height),
                "Right": CGPoint(x: imageSize.width, y: imageSize.height / 2),
                "Bottom": CGPoint(x: imageSize.width / 2, y: 0)
            ] {
                let label = NSAttributedString(string: " \(string) ", attributes: attributes)
                textGenerator.setValue(label, forKey: "inputText")
                if var textImage = textGenerator.outputImage {
                    let labelSize = label.size()
                    let backgroundImage = background.cropped(to: CGRect(origin: .zero, size: labelSize))
                    textImage = textImage.composited(over: backgroundImage)

                    var offsetX: CGFloat = 0, offsetY: CGFloat = 0
                    switch string {
                    case "Left":
                        offsetX = -2
                        offsetY = labelSize.height / 2
                    case "Top":
                        offsetX = labelSize.width / 2
                        offsetY = labelSize.height
                    case "Right":
                        offsetX = labelSize.width + 2
                        offsetY = labelSize.height / 2
                    case "Bottom":
                        offsetX = labelSize.width / 2
                    default:
                        break
                    }
                    textImage = textImage.transformed(by: .init(translationX: point.x - offsetX, y: point.y - offsetY))
                    ciImage = textImage.composited(over: ciImage)
                }
            }
        }

        // MARK: Image generation

        let colorSpace = ciImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let pixelFormat = CIFormat.RGBA16

        for orientation in ImageOrientation.orientations {
            var orientedImage = ciImage
            let id = orientation.orientation.rawValue

            // Draw orientation ID at the middle
            if let textGenerator = textGenerator {
                let string = " \(orientation.orientation.description) (\(id)) "
                let label = NSAttributedString(string: string, attributes: attributes)
                textGenerator.setValue(label, forKey: "inputText")
                if var center = textGenerator.outputImage {
                    let labelSize = label.size()
                    let backgroundImage = background.cropped(to: CGRect(origin: .zero, size: labelSize))
                    center = center.composited(over: backgroundImage)
                    center = center.transformed(by: .init(
                        translationX: imageSize.width / 2 - (labelSize.width / 2),
                        y: imageSize.height / 2 - (labelSize.height / 2)
                    ))
                    orientedImage = center.composited(over: orientedImage)
                }
            }

            // Mirror (reflect horizontally)
            if orientation.isMirrored {
                orientedImage = orientedImage
                    .transformed(by: CGAffineTransform(scaleX: -1.0, y: 1.0))
            }

            // Rotate
            orientedImage = orientedImage
                .transformed(by: CGAffineTransform(rotationAngle: orientation.angle))

            // Set orientation
            orientedImage = orientedImage.settingProperties([
                kCGImagePropertyOrientation: orientation.orientation.rawValue
            ])

            // Properties
            var options: [CIImageRepresentationOption: Any] = [:]
            if let quality = quality {
                // PNG and TIFF will not be affected
                options[CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)] = quality
            }

            let destination = directory.appendingPathComponent("\(filename)_\(id)")

            // Save image
            switch format {
            case .jpeg:
                try context.writeJPEGRepresentation(
                    of: orientedImage,
                    to: destination.appendingPathExtension("jpg"),
                    colorSpace: colorSpace,
                    options: options
                )
            case .png:
                try context.writePNGRepresentation(
                    of: orientedImage,
                    to: destination.appendingPathExtension("png"),
                    format: pixelFormat,
                    colorSpace: colorSpace,
                    options: options
                )
            case .heif:
                try context.writeHEIFRepresentation(
                    of: orientedImage,
                    to: destination.appendingPathExtension("heic"),
                    format: pixelFormat,
                    colorSpace: colorSpace,
                    options: options
                )
            case .heif10:
                if #available(macOS 12.0, *) {
                    try context.writeHEIF10Representation(
                        of: orientedImage,
                        to: destination.appendingPathExtension("heic"),
                        colorSpace: colorSpace,
                        options: options
                    )
                }
            case .tiff:
                try context.writeTIFFRepresentation(
                    of: orientedImage,
                    to: destination.appendingPathExtension("tiff"),
                    format: pixelFormat,
                    colorSpace: colorSpace,
                    options: options
                )
            }
        }
    }
}
