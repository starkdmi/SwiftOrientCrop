# SwiftOrientCrop

Project content:
- Oriented image generator
- Load and orient CGImage and CIImage
- Orient CGRect based on image orientation
- Crop CGImage, CIImage and vImage
- Speed/Memory/Storage benchmarks

Code located in [Tests](SwiftOrientCropTests/SwiftOrientCropTests.swift).

## Oriented image generator

Those images looks the same when correctly displayed, but under the hood they pretty different.

| <img src='SwiftOrientCropTests/media/iphone_x_1.jpg'/> | <img src='SwiftOrientCropTests/media/iphone_x_2.jpg'/> | <img src='SwiftOrientCropTests/media/iphone_x_3.jpg'/> |
| --- | --- | --- |
| <img src='SwiftOrientCropTests/media/iphone_x_4.jpg'/> | <img src='SwiftOrientCropTests/media/iphone_x_5.jpg'/> | <img src='SwiftOrientCropTests/media/iphone_x_6.jpg'/> |
| <img src='SwiftOrientCropTests/media/iphone_x_7.jpg'/> | <img src='SwiftOrientCropTests/media/iphone_x_8.jpg'/>| |
