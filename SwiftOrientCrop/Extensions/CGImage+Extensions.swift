//
//  CGImage+Extensions.swift
//  SwiftOrientCrop
//
//  Created by Dmitry Starkov on 24/08/2023.
//

import CoreGraphics
import CoreImage

public extension CGImage {
    /// `CGImage` size property
    var size: CGSize {
        return CGSize(width: self.width, height: self.height)
    }

    /// Oriented image size
    func size(orientation: CGImagePropertyOrientation?) -> CGSize {
        return self.size.oriented(orientation)
    }

    /// Orient `CGImage` to top-left coordinate system based on orientation
    func oriented(orientation: CGImagePropertyOrientation?) -> CGImage {
        guard let orientation = orientation, orientation != .up else {
            return self
        }

        // Swap width and height if needed
        let size = self.size(orientation: orientation)

        let transform = orientation.transform(in: size, origin: .topLeft)
        guard transform != .identity else {
            return self
        }

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: self.bitsPerComponent,
            bytesPerRow: Int(size.width) * Int(self.bitsPerPixel / 8),
            space: self.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: self.bitmapInfo.rawValue | self.alphaInfo.rawValue).rawValue
        ) else {
            return self
        }

        context.concatenate(transform)

        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(self, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(self, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }

        return context.makeImage() ?? self
    }
}
