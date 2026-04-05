---
title: "std.image"
description: "Image decoding, encoding, resizing, cropping, and pixel manipulation."
---

**Status: Implemented** -- C runtime backing.

The `std.image` module provides functions for decoding, encoding, and transforming raster images. Supports PNG, JPEG, WebP, and BMP formats.

## Types

### $imgbuf

| Field | Type | Meaning |
|-------|------|---------|
| width | u32 | Image width in pixels |
| height | u32 | Image height in pixels |
| channels | u8 | Number of color channels (3=RGB, 4=RGBA) |
| data | @($byte) | Raw pixel data |

### $imgfmt (sum type)

| Variant | Meaning |
|---------|---------|
| Png | PNG format |
| Jpeg | JPEG format |
| Webp | WebP format |
| Bmp | BMP format |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `image.decode` | `data: @($byte)` | `$imgbuf!$str` | Decode an image from bytes (auto-detects format) |
| `image.encode` | `img: $imgbuf; fmt: $imgfmt; quality: u8` | `@($byte)!$str` | Encode an image to bytes in the given format |
| `image.resize` | `img: $imgbuf; w: u32; h: u32` | `$imgbuf` | Resize an image to the given dimensions |
| `image.crop` | `img: $imgbuf; x: u32; y: u32; w: u32; h: u32` | `$imgbuf!$str` | Crop a rectangular region |
| `image.to_grayscale` | `img: $imgbuf` | `$imgbuf` | Convert to grayscale |
| `image.flip_h` | `img: $imgbuf` | `$imgbuf` | Flip horizontally |
| `image.flip_v` | `img: $imgbuf` | `$imgbuf` | Flip vertically |
| `image.pixel_at` | `img: $imgbuf; x: u32; y: u32` | `@($byte)!$str` | Get pixel channel values at (x, y) |
| `image.from_raw` | `data: @($byte); w: u32; h: u32; channels: u8` | `$imgbuf` | Construct an image buffer from raw pixel data |

## Usage

```toke
use std.image
use std.file

f=main():i64{
  let raw = file.read("photo.jpg")|{Ok:d d;Err:e <1}
  let img = image.decode(raw)|{Ok:i i;Err:e <1}
  let thumb = image.resize(img; 128; 128)
  let out = image.encode(thumb; image.$imgfmt.Png; 90)|{Ok:b b;Err:e <1}
  file.write("thumb.png"; out)
  <0
}
```

## Dependencies

None.
