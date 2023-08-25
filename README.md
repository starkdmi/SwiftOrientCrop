# SwiftOrientCrop

Project content:
- Oriented image generator
- Load and orient CGImage and CIImage
- Orient CGRect based on image orientation
- Crop CGImage, CIImage and vImage
- Benchmarks

Code located in [Tests](SwiftOrientCropTests/SwiftOrientCropTests.swift).

## Oriented image generator

Those images looks the same when correctly displayed, but under the hood they pretty different.

| <img src='SwiftOrientCropTests/media/iphone_x_1.jpg'/> | <img src='SwiftOrientCropTests/media/iphone_x_2.jpg'/> | <img src='SwiftOrientCropTests/media/iphone_x_3.jpg'/> |
| --- | --- | --- |
| <img src='SwiftOrientCropTests/media/iphone_x_4.jpg'/> | <img src='SwiftOrientCropTests/media/iphone_x_5.jpg'/> | <img src='SwiftOrientCropTests/media/iphone_x_6.jpg'/> |
| <img src='SwiftOrientCropTests/media/iphone_x_7.jpg'/> | <img src='SwiftOrientCropTests/media/iphone_x_8.jpg'/>| |

### Usage
```Swift
try OrientedGenerator.generateFrom(
  source: sourceImageFile,
  destination: destinationDirectory,
  format: .jpeg,
  size: CGSize(width: 1280, height: 1280),
  quality: 0.75
)
```

## Image Crop Benchmarks

One call equals to loading 8 images, crop them and write image data to 
file. Full execution is 10 single calls - 80 images in summary.

| Method | Full Execution Time (seconds) | Average Execution Time per call (seconds) | Average CPU Time (seconds) | Memory Usage (kB) | Memory Peak Physical (MB) | Disk Writes (MB) | CPU Usage (% relative to CGImage) |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| CGImage | 38.719 | 6.372 | 5.365 | 101.6 | __11.6__ | 9.0 | 100% |
| CIImage | __14.432__ | __2.352__ | __1.344__ | 62.3 | 15.0 | 10.9 | 29.3% |
| vImage (CG)\* | 31.458 | 5.186 | 5.162 | __55.7__ | __11.7__ | 9.0 | __23.8%__ |
| vImage (CI)\* | 30.431 | 4.933 | 4.445 | - | 15.4 | 11.0 | 28.8% |

\* vImage doesn't have API to load and save image files, so the CGImage and CIImage was used for it.
