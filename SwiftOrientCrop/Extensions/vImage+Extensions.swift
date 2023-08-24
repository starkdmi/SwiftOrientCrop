//
//  vImage+Extensions.swift
//  SwiftOrientCrop
//
//  Created by Dmitry Starkov on 24/08/2023.
//

import Foundation
import Accelerate.vImage

public extension vImage_Buffer {
    /// Crop image buffer
    /// Warning: free the source buffer when done, but NOT the one returned by this call (as it points just to a small part of original memory)
    func crop(_ rect: CGRect, bitsPerPixel: Int) -> vImage_Buffer? {
        guard rect.origin.x >= 0, rect.origin.y >= 0,
              rect.size.width <= CGFloat(self.width), rect.size.height <= CGFloat(self.height)
        else {
            return nil
        }

        let data = self.data.assumingMemoryBound(to: UInt8.self)
            .advanced(by: Int(rect.origin.y) * self.rowBytes + Int(rect.origin.x) * (bitsPerPixel / 8))

        return vImage_Buffer(
            data: data,
            height: vImagePixelCount(rect.size.height),
            width: vImagePixelCount(rect.size.width),
            rowBytes: self.rowBytes
        )
    }
}
