import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Color {
  let r: UInt8
  let g: UInt8
  let b: UInt8
  let a: UInt8

  init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) {
    self.r = r
    self.g = g
    self.b = b
    self.a = a
  }

  static let clear = Color(0, 0, 0, 0)
}

func mix(_ start: Color, _ end: Color, amount: Double) -> Color {
  let clampedAmount = Swift.max(0, Swift.min(1, amount))
  func channel(_ start: UInt8, _ end: UInt8) -> UInt8 {
    UInt8((Double(start) + (Double(end) - Double(start)) * clampedAmount).rounded())
  }

  return Color(
    channel(start.r, end.r),
    channel(start.g, end.g),
    channel(start.b, end.b),
    channel(start.a, end.a)
  )
}

func hex(_ value: String, alpha: UInt8 = 255) -> Color {
  let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
  guard cleaned.count == 6, let raw = Int(cleaned, radix: 16) else {
    fatalError("Invalid hex color \(value)")
  }

  return Color(
    UInt8((raw >> 16) & 0xff),
    UInt8((raw >> 8) & 0xff),
    UInt8(raw & 0xff),
    alpha
  )
}

struct Canvas {
  let width: Int
  let height: Int
  var pixels: [UInt8]

  init(width: Int, height: Int, background: Color = .clear) {
    self.width = width
    self.height = height
    self.pixels = Array(repeating: 0, count: width * height * 4)

    if background.a > 0 {
      fillRect(0, 0, width, height, background)
    }
  }

  mutating func setPixel(_ x: Int, _ y: Int, _ color: Color) {
    guard x >= 0, y >= 0, x < width, y < height else {
      return
    }

    let index = (y * width + x) * 4
    pixels[index] = color.r
    pixels[index + 1] = color.g
    pixels[index + 2] = color.b
    pixels[index + 3] = color.a
  }

  mutating func fillRect(_ x: Int, _ y: Int, _ rectWidth: Int, _ rectHeight: Int, _ color: Color) {
    guard rectWidth > 0, rectHeight > 0 else {
      return
    }

    for drawY in y..<(y + rectHeight) {
      for drawX in x..<(x + rectWidth) {
        setPixel(drawX, drawY, color)
      }
    }
  }

  mutating func checkerRect(
    _ x: Int,
    _ y: Int,
    _ rectWidth: Int,
    _ rectHeight: Int,
    _ primary: Color,
    _ secondary: Color,
    step: Int = 2
  ) {
    guard rectWidth > 0, rectHeight > 0 else {
      return
    }

    for drawY in y..<(y + rectHeight) {
      for drawX in x..<(x + rectWidth) {
        let useSecondary = ((drawX / step) + (drawY / step)) % 2 == 0
        setPixel(drawX, drawY, useSecondary ? secondary : primary)
      }
    }
  }

  mutating func strokeRect(_ x: Int, _ y: Int, _ rectWidth: Int, _ rectHeight: Int, _ color: Color) {
    guard rectWidth > 0, rectHeight > 0 else {
      return
    }

    for drawX in x..<(x + rectWidth) {
      setPixel(drawX, y, color)
      setPixel(drawX, y + rectHeight - 1, color)
    }

    for drawY in y..<(y + rectHeight) {
      setPixel(x, drawY, color)
      setPixel(x + rectWidth - 1, drawY, color)
    }
  }

  mutating func fillEllipse(
    centerX: Int,
    centerY: Int,
    radiusX: Int,
    radiusY: Int,
    fill: Color,
    outline: Color? = nil
  ) {
    let outerRX = max(radiusX, 1)
    let outerRY = max(radiusY, 1)

    if let outline {
      fillEllipseRaw(centerX: centerX, centerY: centerY, radiusX: outerRX, radiusY: outerRY, color: outline)
      fillEllipseRaw(centerX: centerX, centerY: centerY, radiusX: max(outerRX - 1, 0), radiusY: max(outerRY - 1, 0), color: fill)
    } else {
      fillEllipseRaw(centerX: centerX, centerY: centerY, radiusX: outerRX, radiusY: outerRY, color: fill)
    }
  }

  mutating func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ color: Color) {
    var startX = x0
    var startY = y0
    let deltaX = abs(x1 - startX)
    let stepX = startX < x1 ? 1 : -1
    let deltaY = -abs(y1 - startY)
    let stepY = startY < y1 ? 1 : -1
    var error = deltaX + deltaY

    while true {
      setPixel(startX, startY, color)
      if startX == x1 && startY == y1 {
        break
      }

      let errorTimesTwo = error * 2
      if errorTimesTwo >= deltaY {
        error += deltaY
        startX += stepX
      }
      if errorTimesTwo <= deltaX {
        error += deltaX
        startY += stepY
      }
    }
  }

  mutating func sprinkle(
    inRectX x: Int,
    y: Int,
    width rectWidth: Int,
    height rectHeight: Int,
    colors: [Color],
    spacingX: Int,
    spacingY: Int,
    offset: Int = 0
  ) {
    guard !colors.isEmpty else {
      return
    }

    for drawY in y..<(y + rectHeight) {
      for drawX in x..<(x + rectWidth) {
        let selector = (drawX * 13 + drawY * 7 + offset) % max(spacingX, 1)
        let rowSelector = (drawX * 5 + drawY * 11 + offset) % max(spacingY, 1)
        if selector == 0 && rowSelector == 0 {
          let color = colors[(drawX + drawY + offset) % colors.count]
          setPixel(drawX, drawY, color)
        }
      }
    }
  }

  func writePNG(to url: URL) throws {
    let data = Data(pixels)
    guard let provider = CGDataProvider(data: data as CFData) else {
      throw NSError(domain: "AssetGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create data provider."])
    }

    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let cgImage = CGImage(
      width: width,
      height: height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    ) else {
      throw NSError(domain: "AssetGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create image."])
    }

    guard let destination = CGImageDestinationCreateWithURL(
      url as CFURL,
      UTType.png.identifier as CFString,
      1,
      nil
    ) else {
      throw NSError(domain: "AssetGen", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to create PNG destination."])
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    if !CGImageDestinationFinalize(destination) {
      throw NSError(domain: "AssetGen", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to write PNG."])
    }
  }

  private mutating func fillEllipseRaw(centerX: Int, centerY: Int, radiusX: Int, radiusY: Int, color: Color) {
    guard radiusX > 0, radiusY > 0 else {
      return
    }

    let minX = centerX - radiusX
    let maxX = centerX + radiusX
    let minY = centerY - radiusY
    let maxY = centerY + radiusY
    let rxSquared = Double(radiusX * radiusX)
    let rySquared = Double(radiusY * radiusY)

    for drawY in minY...maxY {
      for drawX in minX...maxX {
        let dx = Double(drawX - centerX)
        let dy = Double(drawY - centerY)
        let normalized = (dx * dx) / rxSquared + (dy * dy) / rySquared
        if normalized <= 1.0 {
          setPixel(drawX, drawY, color)
        }
      }
    }
  }
}

let ink = hex("#2B2925")
let soilDark = hex("#4C3929")
let soil = hex("#6B5137")
let soilLight = hex("#8C6844")
let grassDark = hex("#4D6841")
let grass = hex("#6B8A52")
let grassLight = hex("#91AF66")
let mossLight = hex("#B9D48B")
let stone = hex("#8B836F")
let stoneLight = hex("#B6AD97")
let skyTop = hex("#D6E8EF")
let skyMid = hex("#E4E9D9")
let skyBottom = hex("#DFE7CE")
let farGreen = hex("#859985")
let midGreen = hex("#6B8268")
let nearGreen = hex("#536D4F")
let skyMist = hex("#C7D6CF")
let stormDark = hex("#534D5E")
let storm = hex("#726A7D")
let stormLight = hex("#A29AAF")
let goodDark = hex("#4E7C76")
let goodMid = hex("#78ABA2")
let goodLight = hex("#D7F0E5")
let emberDark = hex("#953C22")
let ember = hex("#D46A2B")
let emberLight = hex("#F4B75E")
let emberCore = hex("#FFF0AA")
let cream = hex("#E9DFC0")
let skin = hex("#D9A76B")
let hair = hex("#5B3B27")
let tealDark = hex("#215852")
let teal = hex("#2F746D")
let tealLight = hex("#58A79C")
let clothDark = hex("#635E55")
let cloth = hex("#8B8578")
let redDark = hex("#7B332F")
let red = hex("#A84B43")
let redLight = hex("#C77A6A")

func clamp(_ value: Int, min lower: Int, max upper: Int) -> Int {
  Swift.max(lower, Swift.min(upper, value))
}

func profile(width: Int, base: Double, waves: [(amplitude: Double, frequency: Double, phase: Double)]) -> [Int] {
  guard width > 1 else {
    return [Int(base.rounded())]
  }

  return (0..<width).map { x in
    let t = Double(x) / Double(width - 1)
    let y = waves.reduce(base) { partial, wave in
      partial + sin(t * .pi * 2 * wave.frequency + wave.phase) * wave.amplitude
    }
    return Int(y.rounded())
  }
}

func fillTerrain(canvas: inout Canvas, topProfile: [Int], fill: Color, shade: Color, highlight: Color) {
  for x in 0..<canvas.width {
    let topY = clamp(topProfile[x], min: 0, max: canvas.height - 1)
    for y in topY..<canvas.height {
      let color: Color
      if ((x + y) % 9) < 2 {
        color = highlight
      } else if ((x * 3 + y * 5) % 11) < 3 {
        color = shade
      } else {
        color = fill
      }
      canvas.setPixel(x, y, color)
    }

    canvas.setPixel(x, topY, ink)
    canvas.setPixel(x, min(topY + 1, canvas.height - 1), highlight)
  }
}

func addGrassTufts(canvas: inout Canvas, topProfile: [Int], color: Color, count: Int, stride: Int) {
  for index in 0..<count {
    let x = (index * stride) % canvas.width
    let topY = clamp(topProfile[x], min: 1, max: canvas.height - 3)
    canvas.setPixel(x, topY - 1, color)
    canvas.setPixel(x, topY - 2, color)
    canvas.setPixel(min(x + 1, canvas.width - 1), topY - 1, color)
  }
}

func drawFloorTopTile() -> Canvas {
  var canvas = Canvas(width: 48, height: 48)
  let turf = profile(
    width: canvas.width,
    base: 10,
    waves: [(1.2, 4, 0.2), (0.7, 8, 1.1)]
  )

  fillTerrain(canvas: &canvas, topProfile: turf.map { $0 + 7 }, fill: soil, shade: soilDark, highlight: soilLight)

  for x in 0..<canvas.width {
    let grassTop = clamp(turf[x], min: 4, max: 14)
    for y in grassTop..<(grassTop + 8) {
      let color: Color = ((x + y) % 7 < 2) ? grassLight : (((x * 2 + y) % 5 == 0) ? grassDark : grass)
      canvas.setPixel(x, y, color)
    }
    canvas.setPixel(x, grassTop, ink)
    canvas.setPixel(x, min(grassTop + 1, canvas.height - 1), mossLight)
  }

  addGrassTufts(canvas: &canvas, topProfile: turf, color: mossLight, count: 18, stride: 7)
  canvas.sprinkle(inRectX: 6, y: 22, width: 36, height: 20, colors: [soilLight, stoneLight], spacingX: 11, spacingY: 6, offset: 3)
  return canvas
}

func drawFloorBaseTile() -> Canvas {
  var canvas = Canvas(width: 48, height: 48, background: soil)
  canvas.checkerRect(0, 0, 48, 48, soil, soilDark, step: 4)
  canvas.sprinkle(inRectX: 3, y: 5, width: 42, height: 38, colors: [soilLight, stone, stoneLight], spacingX: 10, spacingY: 5, offset: 9)

  for x in stride(from: 6, to: 42, by: 11) {
    canvas.line(x, 4, x - 2, 44, shadeColor(for: x))
  }

  return canvas
}

func shadeColor(for seed: Int) -> Color {
  seed % 2 == 0 ? soilDark : clothDark
}

func drawGroundTransition() -> Canvas {
  var canvas = Canvas(width: 96, height: 72)
  let ridge = profile(
    width: canvas.width,
    base: 16,
    waves: [(2.0, 3, 0.35), (1.0, 6, 1.2)]
  )

  fillTerrain(canvas: &canvas, topProfile: ridge.map { $0 + 10 }, fill: soil, shade: soilDark, highlight: soilLight)

  for x in 0..<canvas.width {
    let grassTop = ridge[x]
    for y in grassTop..<(grassTop + 12) {
      let color: Color = ((x + y) % 9 < 3) ? grassLight : (((x * 3 + y) % 7 < 2) ? grassDark : grass)
      canvas.setPixel(x, y, color)
    }
    canvas.setPixel(x, grassTop, ink)
    canvas.setPixel(x, min(grassTop + 1, canvas.height - 1), mossLight)
  }

  addGrassTufts(canvas: &canvas, topProfile: ridge, color: mossLight, count: 24, stride: 9)
  canvas.sprinkle(inRectX: 0, y: 32, width: 96, height: 32, colors: [soilLight, stone], spacingX: 13, spacingY: 5, offset: 7)
  return canvas
}

func drawObstacleTile() -> Canvas {
  var canvas = Canvas(width: 16, height: 16)
  canvas.fillRect(1, 1, 14, 14, soil)
  canvas.strokeRect(1, 1, 14, 14, ink)
  canvas.fillRect(2, 2, 12, 4, soilLight)
  canvas.fillRect(2, 6, 12, 7, soil)
  canvas.line(2, 7, 13, 7, ink)
  canvas.fillRect(4, 4, 8, 2, grassDark)
  canvas.fillRect(3, 9, 10, 3, soilDark)
  canvas.setPixel(3, 3, stoneLight)
  canvas.setPixel(12, 3, stoneLight)
  canvas.setPixel(3, 12, stoneLight)
  canvas.setPixel(12, 12, stoneLight)
  return canvas
}

func drawSkyBackdrop() -> Canvas {
  var canvas = Canvas(width: 320, height: 180)

  for y in 0..<canvas.height {
    let amount = Double(y) / Double(canvas.height - 1)
    let baseColor: Color
    if amount < 0.55 {
      baseColor = mix(skyTop, skyMid, amount: amount / 0.55)
    } else {
      baseColor = mix(skyMid, skyBottom, amount: (amount - 0.55) / 0.45)
    }

    for x in 0..<canvas.width {
      let shimmer = ((x * 5 + y * 3) % 23 == 0) ? skyMist : baseColor
      canvas.setPixel(x, y, shimmer)
    }
  }

  canvas.fillEllipse(centerX: 78, centerY: 42, radiusX: 36, radiusY: 18, fill: hex("#F2F3E3", alpha: 220))
  canvas.fillEllipse(centerX: 260, centerY: 28, radiusX: 48, radiusY: 20, fill: hex("#F6F6EB", alpha: 190))
  canvas.fillEllipse(centerX: 238, centerY: 36, radiusX: 26, radiusY: 11, fill: hex("#F1F3E5", alpha: 170))
  canvas.fillEllipse(centerX: 286, centerY: 31, radiusX: 24, radiusY: 10, fill: hex("#F1F3E5", alpha: 170))

  for x in stride(from: 10, to: 310, by: 34) {
    let hazeY = 118 + (x / 34) % 3
    canvas.fillRect(x, hazeY, 18, 2, hex("#E9E8D3", alpha: 120))
    canvas.fillRect(x + 3, hazeY + 3, 12, 1, hex("#F1EEDC", alpha: 110))
  }

  for x in stride(from: 0, to: canvas.width, by: 13) {
    let cloudBandY = 70 + (x / 13) % 6
    canvas.fillRect(x, cloudBandY, 7, 1, hex("#EDF0E1", alpha: 95))
  }

  return canvas
}

func drawParallaxLayer(fill: Color, shade: Color, highlight: Color, baseHeight: Double, waves: [(Double, Double, Double)], detailStride: Int) -> Canvas {
  var canvas = Canvas(width: 256, height: 96)
  let ridge = profile(width: canvas.width, base: baseHeight, waves: waves.map { ($0.0, $0.1, $0.2) })
  fillTerrain(canvas: &canvas, topProfile: ridge, fill: fill, shade: shade, highlight: highlight)

  for x in stride(from: 0, to: canvas.width, by: detailStride) {
    let topY = clamp(ridge[x] - 2, min: 6, max: canvas.height - 12)
    let columnHeight = 3 + (x / detailStride) % 4
    canvas.fillRect(x, topY, 2, columnHeight, shade)
  }

  canvas.fillRect(0, canvas.height - 4, canvas.width, 4, shade)
  canvas.sprinkle(inRectX: 0, y: canvas.height - 18, width: canvas.width, height: 12, colors: [highlight, shade], spacingX: 19, spacingY: 4, offset: detailStride)
  return canvas
}

func drawStormCloud() -> Canvas {
  var canvas = Canvas(width: 96, height: 48)
  canvas.fillEllipse(centerX: 26, centerY: 24, radiusX: 18, radiusY: 12, fill: storm, outline: ink)
  canvas.fillEllipse(centerX: 47, centerY: 19, radiusX: 20, radiusY: 14, fill: stormLight, outline: ink)
  canvas.fillEllipse(centerX: 68, centerY: 24, radiusX: 18, radiusY: 13, fill: storm, outline: ink)
  canvas.fillRect(18, 24, 58, 13, storm)
  canvas.strokeRect(18, 24, 58, 13, ink)
  canvas.fillRect(24, 26, 10, 3, stormDark)
  canvas.fillRect(62, 26, 10, 3, stormDark)
  canvas.fillRect(31, 30, 5, 2, ink)
  canvas.fillRect(60, 30, 5, 2, ink)
  canvas.line(34, 36, 42, 41, stormDark)
  canvas.line(62, 41, 70, 36, stormDark)
  return canvas
}

func drawGoodCloud() -> Canvas {
  var canvas = Canvas(width: 96, height: 48)
  canvas.fillEllipse(centerX: 27, centerY: 24, radiusX: 18, radiusY: 12, fill: goodMid, outline: ink)
  canvas.fillEllipse(centerX: 48, centerY: 19, radiusX: 20, radiusY: 14, fill: goodLight, outline: ink)
  canvas.fillEllipse(centerX: 69, centerY: 24, radiusX: 18, radiusY: 13, fill: goodMid, outline: ink)
  canvas.fillRect(18, 24, 58, 13, goodMid)
  canvas.strokeRect(18, 24, 58, 13, ink)
  canvas.fillRect(26, 27, 4, 4, tealDark)
  canvas.fillRect(62, 27, 4, 4, tealDark)
  canvas.line(36, 34, 48, 37, tealDark)
  canvas.line(48, 37, 60, 34, tealDark)
  canvas.fillRect(12, 10, 2, 2, mossLight)
  canvas.fillRect(78, 8, 2, 2, mossLight)
  canvas.fillRect(82, 13, 1, 4, mossLight)
  canvas.fillRect(16, 14, 1, 4, mossLight)
  return canvas
}

func drawFireballSprite() -> Canvas {
  var canvas = Canvas(width: 64, height: 24)
  let frameOffsets = [0, 16, 32, 48]
  let flameProfiles: [[(Int, Int, Int, Int)]] = [
    [(5, 2, 6, 18), (4, 6, 8, 12), (6, 8, 4, 6)],
    [(4, 3, 8, 17), (5, 6, 6, 12), (7, 8, 3, 6)],
    [(5, 2, 6, 18), (3, 7, 10, 11), (6, 9, 4, 5)],
    [(4, 3, 8, 17), (5, 5, 6, 13), (6, 9, 4, 5)],
  ]

  for (frameIndex, offsetX) in frameOffsets.enumerated() {
    for block in flameProfiles[frameIndex] {
      canvas.fillRect(offsetX + block.0, block.1, block.2, block.3, ember)
    }
    canvas.fillRect(offsetX + 6, 6, 4, 10, emberLight)
    canvas.fillRect(offsetX + 7, 9, 2, 5, emberCore)
    canvas.line(offsetX + 7, 1, offsetX + 10, 4, ink)
    canvas.line(offsetX + 5, 22, offsetX + 10, 20, ink)
    canvas.strokeRect(offsetX + 4, 3, 8, 17, emberDark)
  }

  return canvas
}

func drawBugWalkerSprite() -> Canvas {
  var canvas = Canvas(width: 96, height: 18)
  let legOffsets = [
    [(2, 13), (6, 14), (15, 13), (19, 14)],
    [(2, 14), (6, 13), (15, 14), (19, 13)],
    [(1, 13), (5, 14), (16, 13), (20, 14)],
    [(1, 14), (5, 13), (16, 14), (20, 13)],
  ]

  for frame in 0..<4 {
    let offsetX = frame * 24
    canvas.fillEllipse(centerX: offsetX + 11, centerY: 8, radiusX: 8, radiusY: 5, fill: red, outline: ink)
    canvas.fillRect(offsetX + 6, 6, 10, 4, redLight)
    canvas.fillRect(offsetX + 17, 7, 4, 4, soilDark)
    canvas.fillRect(offsetX + 4, 8, 3, 3, soilDark)
    canvas.line(offsetX + 5, 4, offsetX + 2, 1, ink)
    canvas.line(offsetX + 18, 4, offsetX + 21, 1, ink)

    for leg in legOffsets[frame] {
      canvas.line(offsetX + leg.0, 11, offsetX + leg.0 - 2, leg.1, ink)
      canvas.line(offsetX + leg.1 - 10, 11, offsetX + leg.1 - 8, leg.1, ink)
    }
  }

  return canvas
}

func drawDeadBug() -> Canvas {
  var canvas = Canvas(width: 24, height: 10)
  canvas.fillEllipse(centerX: 12, centerY: 5, radiusX: 9, radiusY: 3, fill: red, outline: ink)
  canvas.fillRect(7, 4, 10, 2, redLight)
  canvas.line(4, 7, 1, 9, ink)
  canvas.line(20, 7, 23, 9, ink)
  return canvas
}

func drawBugSingle() -> Canvas {
  var canvas = Canvas(width: 24, height: 18)
  canvas.fillEllipse(centerX: 11, centerY: 8, radiusX: 8, radiusY: 5, fill: red, outline: ink)
  canvas.fillRect(6, 6, 10, 4, redLight)
  canvas.fillRect(17, 7, 4, 4, soilDark)
  canvas.line(5, 4, 2, 1, ink)
  canvas.line(18, 4, 21, 1, ink)
  for legX in [3, 6, 15, 18] {
    canvas.line(legX, 11, legX - 2, 15, ink)
  }
  return canvas
}

func thickLine(canvas: inout Canvas, _ startX: Int, _ startY: Int, _ endX: Int, _ endY: Int, _ color: Color, thickness: Int = 2) {
  for offsetX in 0..<thickness {
    for offsetY in 0..<thickness {
      canvas.line(startX + offsetX, startY + offsetY, endX + offsetX, endY + offsetY, color)
    }
  }
}

func drawSideProfileHead(canvas: inout Canvas, originX: Int, originY: Int) {
  canvas.fillRect(originX + 1, originY + 2, 4, 6, skin)
  canvas.fillRect(originX + 5, originY + 3, 2, 3, skin)
  canvas.fillRect(originX + 4, originY + 6, 2, 1, skin)
  canvas.fillRect(originX, originY + 1, 4, 2, hair)
  canvas.fillRect(originX, originY + 3, 1, 4, hair)
  canvas.fillRect(originX + 1, originY, 3, 1, hair)
  canvas.line(originX + 1, originY + 1, originX + 5, originY + 1, ink)
  canvas.line(originX, originY + 2, originX, originY + 6, ink)
  canvas.line(originX + 5, originY + 2, originX + 6, originY + 3, ink)
  canvas.line(originX + 6, originY + 4, originX + 5, originY + 6, ink)
  canvas.line(originX + 4, originY + 7, originX + 2, originY + 8, ink)
  canvas.setPixel(originX + 5, originY + 4, ink)
}

func drawSideProfileTorso(canvas: inout Canvas, originX: Int, originY: Int, leaning: Int = 0) {
  canvas.fillRect(originX, originY + 1, 5, 10, tealDark)
  canvas.fillRect(originX + 1, originY + 1, 4, 9, cream)
  canvas.fillRect(originX + 4, originY + 2, 1, 7, teal)
  canvas.fillRect(originX + 1, originY, 3, 2, skin)
  canvas.line(originX, originY + 1, originX + 3 + leaning, originY, ink)
  canvas.line(originX, originY + 2, originX, originY + 10, ink)
  canvas.line(originX + 5, originY + 2, originX + 5, originY + 9, ink)
  canvas.line(originX + 1, originY + 11, originX + 4, originY + 11, ink)
  canvas.setPixel(originX + 2, originY + 4, tealLight)
  canvas.setPixel(originX + 2, originY + 7, tealLight)
}

func drawArm(canvas: inout Canvas, shoulder: (Int, Int), elbow: (Int, Int), hand: (Int, Int), sleeve: Color, forearm: Color) {
  thickLine(canvas: &canvas, shoulder.0, shoulder.1, elbow.0, elbow.1, sleeve)
  thickLine(canvas: &canvas, elbow.0, elbow.1, hand.0, hand.1, forearm)
}

func drawLeg(canvas: inout Canvas, hip: (Int, Int), knee: (Int, Int), foot: (Int, Int), color: Color, shoe: Color) {
  thickLine(canvas: &canvas, hip.0, hip.1, knee.0, knee.1, color)
  thickLine(canvas: &canvas, knee.0, knee.1, foot.0, foot.1, color)
  canvas.fillRect(foot.0 - 1, foot.1 + 1, 4, 2, shoe)
}

func offsetJoint(_ joint: (Int, Int), by xOffset: Int) -> (Int, Int) {
  (joint.0 + xOffset, joint.1)
}

func drawRunnerSpriteSheet() -> Canvas {
  var canvas = Canvas(width: 128, height: 32)

  let poses = [
    (
      headX: 11, headY: 5, torsoX: 12, torsoY: 13,
      backArm: ((13, 16), (11, 18), (10, 21)),
      frontArm: ((17, 16), (19, 13), (21, 10)),
      backLeg: ((14, 23), (12, 26), (10, 28)),
      frontLeg: ((17, 23), (19, 26), (21, 28))
    ),
    (
      headX: 11, headY: 5, torsoX: 12, torsoY: 13,
      backArm: ((13, 16), (11, 14), (10, 11)),
      frontArm: ((17, 16), (19, 18), (20, 22)),
      backLeg: ((14, 23), (14, 26), (13, 28)),
      frontLeg: ((17, 23), (18, 26), (19, 28))
    ),
    (
      headX: 11, headY: 5, torsoX: 12, torsoY: 13,
      backArm: ((13, 16), (11, 13), (10, 10)),
      frontArm: ((17, 16), (19, 19), (21, 23)),
      backLeg: ((14, 23), (16, 26), (18, 28)),
      frontLeg: ((17, 23), (14, 26), (12, 28))
    ),
    (
      headX: 11, headY: 4, torsoX: 12, torsoY: 12,
      backArm: ((13, 15), (11, 16), (10, 18)),
      frontArm: ((17, 15), (19, 14), (21, 13)),
      backLeg: ((14, 22), (13, 25), (12, 27)),
      frontLeg: ((17, 22), (19, 24), (20, 26))
    ),
  ]

  for frame in 0..<4 {
    let offsetX = frame * 32
    let pose = poses[frame]
    drawSideProfileHead(canvas: &canvas, originX: offsetX + pose.headX, originY: pose.headY)
    drawArm(
      canvas: &canvas,
      shoulder: offsetJoint(pose.backArm.0, by: offsetX),
      elbow: offsetJoint(pose.backArm.1, by: offsetX),
      hand: offsetJoint(pose.backArm.2, by: offsetX),
      sleeve: clothDark,
      forearm: clothDark
    )
    drawSideProfileTorso(canvas: &canvas, originX: offsetX + pose.torsoX, originY: pose.torsoY)
    drawArm(
      canvas: &canvas,
      shoulder: offsetJoint(pose.frontArm.0, by: offsetX),
      elbow: offsetJoint(pose.frontArm.1, by: offsetX),
      hand: offsetJoint(pose.frontArm.2, by: offsetX),
      sleeve: tealDark,
      forearm: skin
    )
    drawLeg(
      canvas: &canvas,
      hip: offsetJoint(pose.backLeg.0, by: offsetX),
      knee: offsetJoint(pose.backLeg.1, by: offsetX),
      foot: offsetJoint(pose.backLeg.2, by: offsetX),
      color: clothDark,
      shoe: ink
    )
    drawLeg(
      canvas: &canvas,
      hip: offsetJoint(pose.frontLeg.0, by: offsetX),
      knee: offsetJoint(pose.frontLeg.1, by: offsetX),
      foot: offsetJoint(pose.frontLeg.2, by: offsetX),
      color: cloth,
      shoe: ink
    )
  }

  return canvas
}

func drawDeathSpriteSheet() -> Canvas {
  var canvas = Canvas(width: 128, height: 32)
  let poses = [
    (
      headX: 11, headY: 5, torsoX: 12, torsoY: 13,
      backArm: ((13, 16), (11, 18), (9, 21)),
      frontArm: ((17, 16), (19, 18), (20, 22)),
      backLeg: ((14, 23), (14, 26), (13, 28)),
      frontLeg: ((17, 23), (18, 26), (19, 28))
    ),
    (
      headX: 10, headY: 7, torsoX: 11, torsoY: 15,
      backArm: ((12, 17), (10, 19), (8, 22)),
      frontArm: ((16, 17), (18, 19), (19, 22)),
      backLeg: ((13, 24), (12, 27), (11, 29)),
      frontLeg: ((16, 24), (17, 27), (18, 29))
    ),
    (
      headX: 8, headY: 12, torsoX: 10, torsoY: 18,
      backArm: ((11, 20), (9, 22), (7, 24)),
      frontArm: ((15, 20), (17, 21), (19, 22)),
      backLeg: ((12, 25), (10, 27), (8, 29)),
      frontLeg: ((15, 25), (17, 26), (19, 27))
    ),
    (
      headX: 18, headY: 18, torsoX: 8, torsoY: 21,
      backArm: ((10, 23), (8, 24), (6, 24)),
      frontArm: ((15, 23), (17, 24), (19, 24)),
      backLeg: ((11, 25), (9, 26), (7, 27)),
      frontLeg: ((14, 25), (16, 26), (18, 27))
    ),
  ]

  for frame in 0..<4 {
    let offsetX = frame * 32
    let pose = poses[frame]
    drawSideProfileHead(canvas: &canvas, originX: offsetX + pose.headX, originY: pose.headY)
    drawArm(
      canvas: &canvas,
      shoulder: offsetJoint(pose.backArm.0, by: offsetX),
      elbow: offsetJoint(pose.backArm.1, by: offsetX),
      hand: offsetJoint(pose.backArm.2, by: offsetX),
      sleeve: clothDark,
      forearm: clothDark
    )
    drawSideProfileTorso(canvas: &canvas, originX: offsetX + pose.torsoX, originY: pose.torsoY, leaning: frame >= 2 ? 1 : 0)
    drawArm(
      canvas: &canvas,
      shoulder: offsetJoint(pose.frontArm.0, by: offsetX),
      elbow: offsetJoint(pose.frontArm.1, by: offsetX),
      hand: offsetJoint(pose.frontArm.2, by: offsetX),
      sleeve: tealDark,
      forearm: skin
    )
    drawLeg(
      canvas: &canvas,
      hip: offsetJoint(pose.backLeg.0, by: offsetX),
      knee: offsetJoint(pose.backLeg.1, by: offsetX),
      foot: offsetJoint(pose.backLeg.2, by: offsetX),
      color: clothDark,
      shoe: ink
    )
    drawLeg(
      canvas: &canvas,
      hip: offsetJoint(pose.frontLeg.0, by: offsetX),
      knee: offsetJoint(pose.frontLeg.1, by: offsetX),
      foot: offsetJoint(pose.frontLeg.2, by: offsetX),
      color: cloth,
      shoe: ink
    )
  }

  return canvas
}

func save(_ canvas: Canvas, named name: String, under assetsURL: URL) throws {
  try canvas.writePNG(to: assetsURL.appendingPathComponent(name))
}

let fileManager = FileManager.default
let workingDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let assetsURL = workingDirectory.appendingPathComponent("assets", isDirectory: true)

try save(drawFloorTopTile(), named: "tile-floor-top.png", under: assetsURL)
try save(drawFloorBaseTile(), named: "tile-floor-base.png", under: assetsURL)
try save(drawGroundTransition(), named: "ground-transition.png", under: assetsURL)
try save(drawObstacleTile(), named: "tile-obstacle.png", under: assetsURL)
try save(drawSkyBackdrop(), named: "bg-sky.png", under: assetsURL)
try save(
  drawParallaxLayer(
    fill: farGreen,
    shade: skyMist,
    highlight: mossLight,
    baseHeight: 52,
    waves: [(8, 1, 0.2), (4, 2, 1.3), (2, 4, 0.8)],
    detailStride: 28
  ),
  named: "bg-parallax-far.png",
  under: assetsURL
)
try save(
  drawParallaxLayer(
    fill: midGreen,
    shade: farGreen,
    highlight: grassLight,
    baseHeight: 58,
    waves: [(10, 1, 1.2), (5, 3, 0.4), (3, 5, 1.9)],
    detailStride: 18
  ),
  named: "bg-parallax-mid.png",
  under: assetsURL
)
try save(
  drawParallaxLayer(
    fill: nearGreen,
    shade: grassDark,
    highlight: grassLight,
    baseHeight: 62,
    waves: [(11, 1, 2.1), (7, 2, 0.2), (3, 6, 1.4)],
    detailStride: 12
  ),
  named: "bg-parallax-near.png",
  under: assetsURL
)
try save(drawStormCloud(), named: "outage-cloud.png", under: assetsURL)
try save(drawGoodCloud(), named: "good-cloud.png", under: assetsURL)
try save(drawFireballSprite(), named: "fireball-sprite.png", under: assetsURL)
try save(drawBugWalkerSprite(), named: "bug-walker-sprite.png", under: assetsURL)
try save(drawDeadBug(), named: "bug-walker-dead.png", under: assetsURL)
try save(drawBugSingle(), named: "bug-walker.png", under: assetsURL)
try save(drawRunnerSpriteSheet(), named: "player-runner-sprite.png", under: assetsURL)
try save(drawDeathSpriteSheet(), named: "player-death-sprite.png", under: assetsURL)

print("Regenerated consistent asset set in \(assetsURL.path)")
