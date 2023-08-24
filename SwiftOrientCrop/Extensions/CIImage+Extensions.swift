//
//  CIImage+Extensions.swift
//  SwiftOrientCrop
//
//  Created by Dmitry Starkov on 24/08/2023.
//

import CoreImage

public extension CIImage {
    /// Orient `CIImage` to bottom-left coordinate system based on orientation
    func oriented(orientation: CGImagePropertyOrientation?) -> CIImage {
        guard let orientation = orientation, orientation != .up else {
            return self
        }

        let size = self.extent.size

        let transform = orientation.transform(in: size, origin: .bottomLeft) // self.orientationTransform(for: orientation)
        guard transform != .identity else {
            return self
        }

        return self.transformed(by: transform)
    }
}
