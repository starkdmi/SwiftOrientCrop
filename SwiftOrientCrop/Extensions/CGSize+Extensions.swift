//
//  CGSize+Extensions.swift
//  SwiftOrientCrop
//
//  Created by Dmitry Starkov on 24/08/2023.
//

import CoreImage

public extension CGSize {
    /// Oriented size
    func oriented(_ orientation: CGImagePropertyOrientation?) -> CGSize {
        let width = self.width
        let height = self.height

        switch orientation {
        case .up, .upMirrored, .down, .downMirrored:
            return CGSize(width: width, height: height)
        case .leftMirrored, .right, .rightMirrored, .left:
            return CGSize(width: height, height: width)
        default:
            return CGSize(width: width, height: height)
        }
    }
}
