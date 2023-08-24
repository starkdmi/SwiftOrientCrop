//
//  CGRect+Extensions.swift
//  SwiftOrientCrop
//
//  Created by Dmitry Starkov on 24/08/2023.
//

import CoreGraphics
import CoreImage

public extension CGRect {
    /// Orient `CGRect` to top-left coordinate system based on orientation and size to work in
    func oriented(_ orientation: CGImagePropertyOrientation?, in size: CGSize) -> CGRect {
        switch orientation {
        case .up: // 1
            return self
        case .upMirrored: // 2
            return CGRect(
                x: size.width - self.size.width - self.origin.x,
                y: self.origin.y,
                width: self.size.width,
                height: self.size.height
            )
        case .down: // 3
            return CGRect(
                x: size.width - self.size.width - self.origin.x,
                y: size.height - self.size.height - self.origin.y,
                width: self.size.width,
                height: self.size.height
            )
        case .downMirrored: // 4
            return CGRect(
                x: self.origin.x,
                y: size.height - self.size.height - self.origin.y,
                width: self.size.width,
                height: self.size.height
            )
        case .leftMirrored: // 5
            return CGRect(
                x: self.origin.y,
                y: self.origin.x,
                width: self.size.height,
                height: self.size.width
            )
        case .right: // 6
            return self.applying(
                .identity
                    .translatedBy(x: 0, y: size.height)
                    .rotated(by: .pi / -2.0)
            ).rounded
        case .rightMirrored: // 7
            return CGRect(
                x: size.width - self.size.height - self.origin.y,
                y: size.height - self.size.width - self.origin.x,
                width: self.size.height,
                height: self.size.width
            )
        case .left: // 8
            return self.applying(
                .identity
                    .translatedBy(x: size.width, y: 0)
                    .rotated(by: .pi / 2.0)
            ).rounded
        default:
            return self
        }
    }

    /// Round decimal point
    var rounded: CGRect {
        return CGRect(
            origin: CGPoint(
                x: self.origin.x.rounded(),
                y: self.origin.y.rounded()
            ),
            size: CGSize(
                width: self.size.width.rounded(),
                height: self.size.height.rounded()
            )
        )
    }
}
