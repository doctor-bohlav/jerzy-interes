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
      if (((x / 2) + (y / 2)) % 6) < 2 {
        color = highlight
      } else if (((x / 3) * 2 + (y / 2)) % 7) < 2 {
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

func darkenTopBand(
  canvas: inout Canvas,
  bandHeight: Int,
  maxDarken: Double,
  extraDarkenRows: Int = 0,
  extraDarken: Double = 0
) {
  let height = min(canvas.height, max(0, bandHeight))
  guard height > 0 else {
    return
  }

  let extraRows = min(height, max(0, extraDarkenRows))

  for y in 0..<height {
    let amount = height <= 1 ? 1.0 : 1.0 - (Double(y) / Double(height - 1))
    var multiplier = max(0, 1.0 - maxDarken * amount)

    if extraRows > 0, y < extraRows {
      let extraAmount = extraRows <= 1 ? 1.0 : 1.0 - (Double(y) / Double(extraRows - 1))
      multiplier *= max(0, 1.0 - extraDarken * extraAmount)
    }

    for x in 0..<canvas.width {
      let index = (y * canvas.width + x) * 4
      let alpha = canvas.pixels[index + 3]
      if alpha == 0 {
        continue
      }

      canvas.pixels[index] = UInt8((Double(canvas.pixels[index]) * multiplier).rounded())
      canvas.pixels[index + 1] = UInt8((Double(canvas.pixels[index + 1]) * multiplier).rounded())
      canvas.pixels[index + 2] = UInt8((Double(canvas.pixels[index + 2]) * multiplier).rounded())
    }
  }
}

func drawFloorTopTile(variant: Int = 0) -> Canvas {
  var canvas = Canvas(width: 48, height: 48)
  let turf = profile(
    width: canvas.width,
    base: 10 + Double((variant % 2) - 1),
    waves: [
      (1.2 + Double(variant) * 0.22, 4, 0.2 + Double(variant) * 0.35),
      (0.7 + Double(variant) * 0.12, 8 - Double(variant % 2), 1.1 + Double(variant) * 0.28)
    ]
  )

  fillTerrain(canvas: &canvas, topProfile: turf.map { $0 + 7 }, fill: soil, shade: soilDark, highlight: soilLight)

  for x in 0..<canvas.width {
    let grassTop = clamp(turf[x], min: 4, max: 14)
    for y in grassTop..<(grassTop + 8) {
      let color: Color =
        ((x + y + variant * 3) % (7 + variant) < 2)
          ? grassLight
          : (((x * (2 + variant) + y + variant * 5) % (5 + variant)) == 0 ? grassDark : grass)
      canvas.setPixel(x, y, color)
    }
    canvas.setPixel(x, grassTop, ink)
    canvas.setPixel(x, min(grassTop + 1, canvas.height - 1), mossLight)
  }

  addGrassTufts(
    canvas: &canvas,
    topProfile: turf,
    color: variant == 2 ? grassLight : mossLight,
    count: 18 + variant * 4,
    stride: max(5, 7 - variant)
  )
  if variant == 1 {
    canvas.sprinkle(
      inRectX: 5,
      y: 22,
      width: 38,
      height: 18,
      colors: [soilLight, stone, stoneLight],
      spacingX: 9,
      spacingY: 5,
      offset: 11
    )
  } else if variant == 2 {
    canvas.sprinkle(
      inRectX: 4,
      y: 21,
      width: 40,
      height: 20,
      colors: [soilLight, mossLight, stoneLight],
      spacingX: 8,
      spacingY: 5,
      offset: 19
    )
    canvas.fillRect(30, 18, 5, 2, grassDark)
    canvas.fillRect(31, 17, 3, 1, mossLight)
  } else {
    canvas.sprinkle(inRectX: 6, y: 22, width: 36, height: 20, colors: [soilLight, stoneLight], spacingX: 11, spacingY: 6, offset: 3)
  }

  darkenTopBand(canvas: &canvas, bandHeight: 10, maxDarken: 0.34, extraDarkenRows: 5, extraDarken: 0.22)
  return canvas
}

func drawFloorBaseTile(variant: Int = 0) -> Canvas {
  var canvas = Canvas(width: 48, height: 48, background: soil)
  canvas.checkerRect(0, 0, 48, 48, soil, variant == 2 ? clothDark : soilDark, step: max(2, 4 - variant))
  canvas.sprinkle(
    inRectX: 3,
    y: 5,
    width: 42,
    height: 38,
    colors: variant == 1 ? [soilLight, stone, stoneLight, mossLight] : [soilLight, stone, stoneLight],
    spacingX: max(6, 10 - variant * 2),
    spacingY: 5,
    offset: 9 + variant * 7
  )

  for x in stride(from: 6, to: 42, by: 11) {
    let xOffset = variant == 2 ? 1 : 0
    canvas.line(x + xOffset, 4, x - 2 + xOffset, 44, shadeColor(for: x + variant * 3))
  }

  if variant == 1 {
    for y in stride(from: 10, to: 42, by: 9) {
      canvas.line(5, y, 42, y - 2, stone)
    }
  } else if variant == 2 {
    canvas.fillRect(8, 12, 12, 3, soilDark)
    canvas.fillRect(26, 26, 14, 4, clothDark)
    canvas.fillRect(28, 18, 5, 2, soilLight)
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
    let bandY = (y / 3) * 3
    let amount = Double(bandY) / Double(canvas.height - 1)
    let baseColor: Color
    if amount < 0.55 {
      baseColor = mix(skyTop, skyMid, amount: amount / 0.55)
    } else {
      baseColor = mix(skyMid, skyBottom, amount: (amount - 0.55) / 0.45)
    }

    for x in 0..<canvas.width {
      let shimmer = (((x / 2) * 5 + (y / 3) * 3) % 23 == 0) ? skyMist : baseColor
      canvas.setPixel(x, y, shimmer)
    }
  }

  let backMountains = quantizeProfile(
    profile(
      width: canvas.width,
      base: 112,
      waves: [(12.0, 1.6, 0.3), (8.0, 3.3, 1.1), (4.0, 7.0, 0.4)]
    ),
    segmentWidth: 12,
    verticalStep: 3
  )
  let frontMountains = quantizeProfile(
    profile(
      width: canvas.width,
      base: 136,
      waves: [(13.0, 1.9, 2.2), (7.0, 4.4, 0.2), (3.0, 10.0, 1.4)]
    ),
    segmentWidth: 8,
    verticalStep: 2
  )
  let valley = quantizeProfile(
    profile(
      width: canvas.width,
      base: 155,
      waves: [(10.0, 1.5, 1.7), (5.0, 3.8, 0.6), (2.0, 11.0, 1.0)]
    ),
    segmentWidth: 6,
    verticalStep: 1
  )

  fillDistantTerrain(
    canvas: &canvas,
    topProfile: backMountains,
    fill: mix(hex("#A4B9E4"), hex("#8098D5"), amount: 0.5),
    shade: hex("#7A8FC2"),
    highlight: hex("#DCE6FB"),
    ditherStep: 8
  )
  fillDistantTerrain(
    canvas: &canvas,
    topProfile: frontMountains,
    fill: hex("#6E86BE"),
    shade: hex("#536A98"),
    highlight: hex("#BFD1F4"),
    ditherStep: 7
  )
  fillTerrain(
    canvas: &canvas,
    topProfile: valley,
    fill: grass,
    shade: grassDark,
    highlight: grassLight
  )
  addPixelPines(
    canvas: &canvas,
    topProfile: valley,
    foliage: nearGreen,
    shade: grassDark,
    trunk: soilDark,
    stride: 10,
    minHeight: 9,
    maxHeight: 16,
    seed: 4
  )

  drawBlockCloud(
    canvas: &canvas,
    originX: 26,
    originY: 20,
    fill: hex("#F4F6EE", alpha: 220),
    shade: hex("#DDE6F0", alpha: 210),
    highlight: hex("#FFFFFF", alpha: 230),
    outline: nil
  )
  drawBlockCloud(
    canvas: &canvas,
    originX: 210,
    originY: 15,
    fill: hex("#F3F5EC", alpha: 210),
    shade: hex("#DBE3EE", alpha: 195),
    highlight: hex("#FFFFFF", alpha: 220),
    outline: nil
  )
  drawBlockCloud(
    canvas: &canvas,
    originX: 102,
    originY: 58,
    fill: hex("#F4F6EE", alpha: 200),
    shade: hex("#D9E2ED", alpha: 190),
    highlight: hex("#FFFFFF", alpha: 215),
    outline: nil
  )

  for x in stride(from: 12, to: 308, by: 28) {
    let hazeY = 120 + (x / 28) % 5
    canvas.fillRect(x, hazeY, 12, 1, hex("#E8EFD8", alpha: 120))
  }

  return canvas
}

func quantizeProfile(_ source: [Int], segmentWidth: Int, verticalStep: Int) -> [Int] {
  guard !source.isEmpty else {
    return source
  }

  let safeSegmentWidth = max(segmentWidth, 1)
  let safeVerticalStep = max(verticalStep, 1)
  var result = source

  for start in stride(from: 0, to: source.count, by: safeSegmentWidth) {
    let end = min(start + safeSegmentWidth, source.count)
    let average = source[start..<end].reduce(0, +) / max(end - start, 1)
    let snapped = (average / safeVerticalStep) * safeVerticalStep
    for index in start..<end {
      result[index] = snapped
    }
  }

  return result
}

func addPixelPines(
  canvas: inout Canvas,
  topProfile: [Int],
  foliage: Color,
  shade: Color,
  trunk: Color,
  stride: Int,
  minHeight: Int,
  maxHeight: Int,
  seed: Int
) {
  guard stride > 0, !topProfile.isEmpty else {
    return
  }

  let heightSpan = max(1, maxHeight - minHeight + 1)
  let treeCount = max(1, canvas.width / stride)

  for index in 0..<treeCount {
    let xJitter = (index * 5 + seed * 3) % max(2, stride / 2)
    let x = min(canvas.width - 2, index * stride + 4 + xJitter)
    let ridgeY = clamp(topProfile[x], min: maxHeight + 4, max: canvas.height - 4)
    let treeHeight = minHeight + ((index * 7 + seed) % heightSpan)
    let trunkTopY = ridgeY - 1
    canvas.setPixel(x, trunkTopY, trunk)

    for level in 0..<treeHeight {
      let y = ridgeY - 2 - level
      let halfWidth = max(0, (treeHeight - level + 1) / 4)
      for dx in -halfWidth...halfWidth {
        let color = dx == 0 || level % 2 == 0 ? foliage : shade
        canvas.setPixel(x + dx, y, color)
      }

      if halfWidth > 0 && level % 3 == 0 {
        canvas.setPixel(x + halfWidth, y, foliage)
        canvas.setPixel(x - halfWidth, y, foliage)
      }
    }

    canvas.setPixel(x, ridgeY - treeHeight - 1, mossLight)
  }
}

func addCliffBlocks(
  canvas: inout Canvas,
  topProfile: [Int],
  fill: Color,
  shade: Color,
  highlight: Color,
  stride: Int,
  seed: Int
) {
  guard stride > 0, !topProfile.isEmpty else {
    return
  }

  let blockCount = max(1, canvas.width / stride)
  for index in 0..<blockCount {
    let centerX = min(canvas.width - 8, index * stride + 8 + ((index * 3 + seed) % 5))
    let ridgeY = clamp(topProfile[centerX], min: 10, max: canvas.height - 18)
    let blockWidth = 7 + ((index + seed) % 3) * 3
    let blockHeight = 3 + ((index * 2 + seed) % 3) * 2
    let blockX = clamp(centerX - blockWidth / 2, min: 1, max: canvas.width - blockWidth - 1)
    let blockY = ridgeY + 5 + ((index + seed) % 4) * 2

    canvas.fillRect(blockX, blockY, blockWidth, blockHeight, fill)
    canvas.fillRect(blockX, blockY, blockWidth, 1, highlight)
    if blockHeight > 1 {
      canvas.fillRect(blockX, blockY + 1, max(2, blockWidth - 2), blockHeight - 1, shade)
    }
    canvas.setPixel(blockX, blockY, ink)
    canvas.setPixel(blockX + blockWidth - 1, blockY, ink)
  }
}

func fillDistantTerrain(
  canvas: inout Canvas,
  topProfile: [Int],
  fill: Color,
  shade: Color,
  highlight: Color,
  ditherStep: Int
) {
  let safeDitherStep = max(2, ditherStep)

  for x in 0..<canvas.width {
    let topY = clamp(topProfile[x], min: 0, max: canvas.height - 1)
    for y in topY..<canvas.height {
      let depth = y - topY
      let color: Color
      if depth == 0 {
        color = ink
      } else if depth == 1 {
        color = ((x / 2) + y) % (safeDitherStep + 1) == 0 ? highlight : fill
      } else if depth < 6 && ((x / 4) + y) % safeDitherStep == 0 {
        color = highlight
      } else if ((x / 5) + (y / 2)) % (safeDitherStep + 1) == 0 {
        color = shade
      } else {
        color = fill
      }
      canvas.setPixel(x, y, color)
    }
  }
}

func drawBlockCloud(
  canvas: inout Canvas,
  originX: Int,
  originY: Int,
  fill: Color,
  shade: Color,
  highlight: Color,
  outline: Color? = ink
) {
  let puffs = [
    (2, 14, 18, 8),
    (14, 8, 20, 10),
    (30, 12, 18, 8),
    (20, 3, 12, 8),
    (0, 17, 14, 5),
    (40, 16, 12, 5),
  ]

  for puff in puffs {
    canvas.fillRect(originX + puff.0, originY + puff.1, puff.2, puff.3, fill)
  }

  let shadeRects = [
    (5, 18, 14, 3),
    (18, 15, 16, 3),
    (33, 18, 11, 3),
  ]
  for rect in shadeRects {
    canvas.fillRect(originX + rect.0, originY + rect.1, rect.2, rect.3, shade)
  }

  let highlightRects = [
    (17, 9, 8, 2),
    (23, 5, 6, 2),
    (35, 13, 6, 2),
    (8, 15, 6, 2),
  ]
  for rect in highlightRects {
    canvas.fillRect(originX + rect.0, originY + rect.1, rect.2, rect.3, highlight)
  }

  if let outline {
    for rect in [
      (2, 14, 18, 8),
      (14, 8, 20, 10),
      (30, 12, 18, 8),
      (20, 3, 12, 8),
    ] {
      canvas.strokeRect(originX + rect.0, originY + rect.1, rect.2, rect.3, outline)
    }
    canvas.line(originX + 3, originY + 22, originX + 47, originY + 22, outline)
  }
}

func drawFarParallaxLayer() -> Canvas {
  var canvas = Canvas(width: 320, height: 96)
  let farBack = quantizeProfile(
    profile(
      width: canvas.width,
      base: 46,
      waves: [(5.0, 1.2, 0.4), (2.4, 2.8, 1.3), (1.2, 6.5, 0.2)]
    ),
    segmentWidth: 18,
    verticalStep: 3
  )
  let farMid = quantizeProfile(
    profile(
      width: canvas.width,
      base: 58,
      waves: [(6.5, 1.4, 1.2), (3.2, 3.1, 0.5), (1.6, 8.0, 1.8)]
    ),
    segmentWidth: 12,
    verticalStep: 2
  )
  let farFront = quantizeProfile(
    profile(
      width: canvas.width,
      base: 69,
      waves: [(7.0, 1.8, 2.3), (3.6, 3.8, 0.3), (2.0, 9.0, 1.0)]
    ),
    segmentWidth: 8,
    verticalStep: 2
  )

  fillDistantTerrain(
    canvas: &canvas,
    topProfile: farBack,
    fill: mix(skyMist, farGreen, amount: 0.42),
    shade: mix(skyTop, farGreen, amount: 0.22),
    highlight: mix(skyMid, mossLight, amount: 0.35),
    ditherStep: 8
  )
  fillDistantTerrain(
    canvas: &canvas,
    topProfile: farMid,
    fill: farGreen,
    shade: mix(farGreen, skyMist, amount: 0.32),
    highlight: mix(mossLight, skyMist, amount: 0.48),
    ditherStep: 7
  )
  fillDistantTerrain(
    canvas: &canvas,
    topProfile: farFront,
    fill: mix(farGreen, midGreen, amount: 0.4),
    shade: midGreen,
    highlight: mossLight,
    ditherStep: 6
  )

  addPixelPines(
    canvas: &canvas,
    topProfile: farMid,
    foliage: mix(farGreen, skyMist, amount: 0.55),
    shade: farGreen,
    trunk: soilDark,
    stride: 20,
    minHeight: 4,
    maxHeight: 7,
    seed: 3
  )
  addPixelPines(
    canvas: &canvas,
    topProfile: farFront,
    foliage: midGreen,
    shade: nearGreen,
    trunk: soilDark,
    stride: 14,
    minHeight: 6,
    maxHeight: 10,
    seed: 7
  )

  for y in [49, 57, 66] {
    canvas.fillRect(0, y, canvas.width, 1, hex("#E7EFE6", alpha: 75))
    canvas.fillRect(0, y + 1, canvas.width, 1, hex("#C8D8D0", alpha: 45))
  }

  for x in stride(from: 6, to: canvas.width, by: 18) {
    let mistY = 61 + (x / 18) % 6
    canvas.fillRect(x, mistY, 8, 1, hex("#EEF5EB", alpha: 95))
  }

  return canvas
}

func drawMidParallaxLayer() -> Canvas {
  var canvas = Canvas(width: 256, height: 96)
  let backRidge = quantizeProfile(
    profile(
      width: canvas.width,
      base: 54,
      waves: [(6.5, 1.7, 0.9), (3.0, 3.6, 1.8), (1.5, 8.5, 0.2)]
    ),
    segmentWidth: 10,
    verticalStep: 2
  )
  let frontRidge = quantizeProfile(
    profile(
      width: canvas.width,
      base: 66,
      waves: [(8.0, 2.1, 2.0), (4.0, 4.4, 0.3), (2.0, 10.5, 1.1)]
    ),
    segmentWidth: 6,
    verticalStep: 1
  )

  fillTerrain(
    canvas: &canvas,
    topProfile: backRidge,
    fill: midGreen,
    shade: farGreen,
    highlight: grassLight
  )
  fillTerrain(
    canvas: &canvas,
    topProfile: frontRidge,
    fill: mix(midGreen, nearGreen, amount: 0.5),
    shade: nearGreen,
    highlight: mossLight
  )

  addCliffBlocks(
    canvas: &canvas,
    topProfile: frontRidge,
    fill: grassDark,
    shade: mix(grassDark, nearGreen, amount: 0.5),
    highlight: grassLight,
    stride: 18,
    seed: 5
  )
  addPixelPines(
    canvas: &canvas,
    topProfile: frontRidge,
    foliage: grassLight,
    shade: grassDark,
    trunk: soilDark,
    stride: 12,
    minHeight: 7,
    maxHeight: 11,
    seed: 9
  )

  for x in stride(from: 0, to: canvas.width, by: 17) {
    let stripeY = clamp(frontRidge[min(x + 4, canvas.width - 1)] + 10, min: 24, max: canvas.height - 6)
    canvas.fillRect(x, stripeY, 10, 1, mossLight)
  }

  canvas.fillRect(0, canvas.height - 5, canvas.width, 5, nearGreen)
  return canvas
}

func drawParallaxLayer(fill: Color, shade: Color, highlight: Color, baseHeight: Double, waves: [(Double, Double, Double)], detailStride: Int) -> Canvas {
  var canvas = Canvas(width: 256, height: 96)
  let ridge = quantizeProfile(
    profile(width: canvas.width, base: baseHeight, waves: waves.map { ($0.0, $0.1, $0.2) }),
    segmentWidth: max(4, detailStride / 2),
    verticalStep: 1
  )
  fillTerrain(canvas: &canvas, topProfile: ridge, fill: fill, shade: shade, highlight: highlight)

  addCliffBlocks(
    canvas: &canvas,
    topProfile: ridge,
    fill: shade,
    shade: mix(shade, fill, amount: 0.55),
    highlight: highlight,
    stride: max(12, detailStride + 2),
    seed: detailStride
  )
  addPixelPines(
    canvas: &canvas,
    topProfile: ridge,
    foliage: highlight,
    shade: shade,
    trunk: soilDark,
    stride: max(11, detailStride),
    minHeight: 6,
    maxHeight: 10,
    seed: detailStride + 3
  )

  for x in stride(from: 0, to: canvas.width, by: max(10, detailStride)) {
    let stripeY = clamp(ridge[min(x + 3, canvas.width - 1)] + 8, min: 22, max: canvas.height - 8)
    canvas.fillRect(x, stripeY, max(4, detailStride - 3), 1, highlight)
  }

  canvas.fillRect(0, canvas.height - 4, canvas.width, 4, shade)
  return canvas
}

func drawStormCloud() -> Canvas {
  var canvas = Canvas(width: 96, height: 48)
  drawBlockCloud(
    canvas: &canvas,
    originX: 18,
    originY: 6,
    fill: storm,
    shade: stormDark,
    highlight: stormLight
  )
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
  drawBlockCloud(
    canvas: &canvas,
    originX: 18,
    originY: 6,
    fill: goodMid,
    shade: tealDark,
    highlight: goodLight
  )
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

func drawShrubSprite(variant: Int = 0) -> Canvas {
  var canvas = Canvas(width: 32, height: 24)
  let fill = variant == 0 ? grass : mix(grass, nearGreen, amount: 0.38)
  let shade = variant == 0 ? grassDark : nearGreen
  let highlight = variant == 0 ? grassLight : mossLight
  let clumps =
    variant == 0
      ? [(4, 11, 10, 7), (11, 8, 11, 9), (19, 11, 9, 7), (2, 14, 6, 5), (23, 14, 5, 4)]
      : [(3, 12, 8, 6), (9, 9, 12, 8), (19, 12, 10, 6), (6, 15, 5, 4), (22, 14, 6, 4)]

  for clump in clumps {
    canvas.fillRect(clump.0, clump.1, clump.2, clump.3, fill)
  }

  let shadeRects =
    variant == 0
      ? [(6, 15, 7, 2), (13, 13, 8, 3), (21, 15, 5, 2)]
      : [(4, 16, 6, 2), (12, 13, 7, 3), (21, 15, 6, 2)]
  for rect in shadeRects {
    canvas.fillRect(rect.0, rect.1, rect.2, rect.3, shade)
  }

  let highlightRects =
    variant == 0
      ? [(7, 12, 4, 2), (14, 10, 5, 2), (21, 12, 3, 2)]
      : [(5, 13, 3, 2), (13, 11, 4, 2), (22, 13, 4, 2)]
  for rect in highlightRects {
    canvas.fillRect(rect.0, rect.1, rect.2, rect.3, highlight)
  }

  canvas.fillRect(12, 18, 2, 3, soilDark)
  canvas.fillRect(17, 18, 2, 3, soilDark)
  canvas.line(4, 18, 27, 18, ink)
  return canvas
}

func drawTreeSprite(variant: Int = 0) -> Canvas {
  var canvas = Canvas(width: 40, height: 56)
  let fill = variant == 0 ? nearGreen : mix(grass, nearGreen, amount: 0.5)
  let shade = variant == 0 ? grassDark : nearGreen
  let highlight = variant == 0 ? grassLight : mossLight
  let trunkX = variant == 0 ? 17 : 18

  canvas.fillRect(trunkX, 35, 5, 18, soil)
  canvas.fillRect(trunkX, 35, 2, 18, soilDark)
  canvas.fillRect(trunkX + 2, 35, 1, 16, soilLight)
  canvas.line(trunkX, 35, trunkX, 52, ink)
  canvas.line(trunkX + 4, 35, trunkX + 4, 52, ink)

  let layers =
    variant == 0
      ? [(15, 6, 10, 7), (11, 13, 18, 8), (8, 20, 24, 8), (6, 28, 28, 7)]
      : [(16, 7, 8, 6), (12, 14, 16, 8), (9, 22, 22, 8), (7, 30, 26, 7)]
  for layer in layers {
    canvas.fillRect(layer.0, layer.1, layer.2, layer.3, fill)
  }

  let shadeRects =
    variant == 0
      ? [(13, 17, 12, 3), (10, 24, 18, 3), (9, 31, 20, 2)]
      : [(13, 18, 10, 3), (11, 26, 16, 3), (10, 33, 18, 2)]
  for rect in shadeRects {
    canvas.fillRect(rect.0, rect.1, rect.2, rect.3, shade)
  }

  let highlightRects =
    variant == 0
      ? [(17, 8, 4, 2), (14, 15, 6, 2), (12, 22, 8, 2)]
      : [(18, 9, 3, 2), (14, 16, 5, 2), (12, 24, 7, 2)]
  for rect in highlightRects {
    canvas.fillRect(rect.0, rect.1, rect.2, rect.3, highlight)
  }

  canvas.line(15, 12, 24, 12, ink)
  canvas.line(11, 20, 28, 20, ink)
  canvas.line(8, 28, 31, 28, ink)
  canvas.line(7, 35, 32, 35, ink)
  canvas.fillRect(10, 47, 20, 3, shade)
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

typealias PixelPoint = (Int, Int)
typealias ArmPose = (shoulder: PixelPoint, elbow: PixelPoint, hand: PixelPoint)
typealias LegPose = (hip: PixelPoint, knee: PixelPoint, foot: PixelPoint)

struct RunnerPose {
  let head: PixelPoint
  let torso: PixelPoint
  let lean: Int
  let backArm: ArmPose
  let frontArm: ArmPose
  let backLeg: LegPose
  let frontLeg: LegPose
}

func drawJoint(canvas: inout Canvas, center: PixelPoint, color: Color, size: Int = 2) {
  let offset = size / 2
  canvas.fillRect(center.0 - offset, center.1 - offset, size, size, color)
}

func drawSideProfileHead(canvas: inout Canvas, originX: Int, originY: Int) {
  canvas.fillRect(originX + 1, originY + 2, 4, 5, skin)
  canvas.fillRect(originX + 5, originY + 3, 1, 3, skin)
  canvas.setPixel(originX + 6, originY + 4, skin)
  canvas.setPixel(originX + 5, originY + 6, skin)
  canvas.fillRect(originX + 2, originY + 7, 3, 1, skin)
  canvas.fillRect(originX + 2, originY + 8, 2, 1, skin)

  canvas.fillRect(originX, originY + 2, 2, 5, hair)
  canvas.fillRect(originX + 1, originY + 1, 4, 2, hair)
  canvas.fillRect(originX + 2, originY, 2, 1, hair)
  canvas.setPixel(originX + 1, originY + 7, hair)
  canvas.setPixel(originX + 2, originY + 6, hair)

  canvas.line(originX + 1, originY + 1, originX + 4, originY + 1, ink)
  canvas.line(originX, originY + 2, originX, originY + 6, ink)
  canvas.line(originX + 5, originY + 2, originX + 6, originY + 3, ink)
  canvas.line(originX + 6, originY + 4, originX + 5, originY + 6, ink)
  canvas.line(originX + 4, originY + 7, originX + 2, originY + 8, ink)
  canvas.setPixel(originX + 4, originY + 4, ink)
  canvas.setPixel(originX + 5, originY + 5, redDark)
}

func drawSideProfileTorso(canvas: inout Canvas, originX: Int, originY: Int, leaning: Int = 0) {
  canvas.fillRect(originX, originY + 2, 2, 8, clothDark)
  canvas.fillRect(originX + 1, originY + 1, 6, 9, tealDark)
  canvas.fillRect(originX + 2, originY + 2, 3, 7, cream)
  canvas.fillRect(originX + 5, originY + 2, 2, 6, teal)
  canvas.fillRect(originX + 3, originY + 2, 1, 6, tealLight)
  canvas.fillRect(originX + 2, originY, 2, 2, skin)
  canvas.fillRect(originX + 2, originY + 9, 4, 2, clothDark)
  canvas.setPixel(originX + 6, originY + 8, tealDark)
  canvas.setPixel(originX + 5, originY + 9, tealDark)
  canvas.line(originX + 1, originY + 1, originX + 5 + leaning, originY + 1, ink)
  canvas.line(originX, originY + 2, originX, originY + 9, ink)
  canvas.line(originX + 6, originY + 2, originX + 6, originY + 8, ink)
  canvas.line(originX + 2, originY + 10, originX + 5, originY + 10, ink)
  canvas.line(originX + 5, originY + 2, originX + 3, originY + 6, ink)
}

func drawArm(
  canvas: inout Canvas,
  shoulder: PixelPoint,
  elbow: PixelPoint,
  hand: PixelPoint,
  sleeve: Color,
  forearm: Color,
  thickness: Int,
  handColor: Color
) {
  thickLine(canvas: &canvas, shoulder.0, shoulder.1, elbow.0, elbow.1, sleeve, thickness: thickness)
  thickLine(canvas: &canvas, elbow.0, elbow.1, hand.0, hand.1, forearm, thickness: thickness)
  drawJoint(canvas: &canvas, center: shoulder, color: sleeve, size: max(1, thickness + 1))
  drawJoint(canvas: &canvas, center: elbow, color: forearm, size: max(1, thickness + 1))
  canvas.fillRect(hand.0 - 1, hand.1 - 1, max(1, thickness + 1), max(1, thickness + 1), handColor)
}

func drawLeg(
  canvas: inout Canvas,
  hip: PixelPoint,
  knee: PixelPoint,
  foot: PixelPoint,
  color: Color,
  shoe: Color,
  thickness: Int
) {
  thickLine(canvas: &canvas, hip.0, hip.1, knee.0, knee.1, color, thickness: thickness)
  thickLine(canvas: &canvas, knee.0, knee.1, foot.0, foot.1, color, thickness: thickness)
  drawJoint(canvas: &canvas, center: hip, color: color, size: max(1, thickness + 1))
  drawJoint(canvas: &canvas, center: knee, color: color, size: max(1, thickness + 1))
  canvas.fillRect(foot.0 - 1, foot.1 + 1, 4, 2, shoe)
  canvas.setPixel(foot.0 + 3, foot.1 + 1, shoe)
}

func offsetPoint(_ point: PixelPoint, by xOffset: Int) -> PixelPoint {
  (point.0 + xOffset, point.1)
}

func drawRunnerPose(canvas: inout Canvas, pose: RunnerPose, offsetX: Int) {
  drawLeg(
    canvas: &canvas,
    hip: offsetPoint(pose.backLeg.hip, by: offsetX),
    knee: offsetPoint(pose.backLeg.knee, by: offsetX),
    foot: offsetPoint(pose.backLeg.foot, by: offsetX),
    color: clothDark,
    shoe: ink,
    thickness: 1
  )
  drawArm(
    canvas: &canvas,
    shoulder: offsetPoint(pose.backArm.shoulder, by: offsetX),
    elbow: offsetPoint(pose.backArm.elbow, by: offsetX),
    hand: offsetPoint(pose.backArm.hand, by: offsetX),
    sleeve: clothDark,
    forearm: clothDark,
    thickness: 1,
    handColor: clothDark
  )
  drawSideProfileTorso(canvas: &canvas, originX: offsetX + pose.torso.0, originY: pose.torso.1, leaning: pose.lean)
  drawSideProfileHead(canvas: &canvas, originX: offsetX + pose.head.0, originY: pose.head.1)
  drawArm(
    canvas: &canvas,
    shoulder: offsetPoint(pose.frontArm.shoulder, by: offsetX),
    elbow: offsetPoint(pose.frontArm.elbow, by: offsetX),
    hand: offsetPoint(pose.frontArm.hand, by: offsetX),
    sleeve: tealDark,
    forearm: skin,
    thickness: 2,
    handColor: skin
  )
  drawLeg(
    canvas: &canvas,
    hip: offsetPoint(pose.frontLeg.hip, by: offsetX),
    knee: offsetPoint(pose.frontLeg.knee, by: offsetX),
    foot: offsetPoint(pose.frontLeg.foot, by: offsetX),
    color: cloth,
    shoe: ink,
    thickness: 2
  )
}

func drawRunnerSpriteSheet() -> Canvas {
  var canvas = Canvas(width: 128, height: 32)
  let poses = [
    RunnerPose(
      head: (14, 5),
      torso: (11, 12),
      lean: 1,
      backArm: ((13, 16), (11, 18), (9, 20)),
      frontArm: ((17, 16), (20, 13), (22, 11)),
      backLeg: ((13, 22), (10, 25), (8, 28)),
      frontLeg: ((16, 22), (19, 25), (22, 29))
    ),
    RunnerPose(
      head: (14, 6),
      torso: (11, 13),
      lean: 1,
      backArm: ((13, 17), (11, 14), (10, 11)),
      frontArm: ((17, 17), (19, 20), (21, 23)),
      backLeg: ((13, 23), (15, 26), (17, 29)),
      frontLeg: ((16, 23), (15, 26), (14, 29))
    ),
    RunnerPose(
      head: (14, 5),
      torso: (11, 12),
      lean: 1,
      backArm: ((13, 16), (11, 13), (9, 11)),
      frontArm: ((17, 16), (19, 19), (21, 23)),
      backLeg: ((13, 22), (16, 25), (20, 29)),
      frontLeg: ((16, 22), (13, 25), (10, 28))
    ),
    RunnerPose(
      head: (15, 4),
      torso: (12, 11),
      lean: 2,
      backArm: ((14, 15), (12, 12), (10, 10)),
      frontArm: ((18, 15), (20, 17), (22, 19)),
      backLeg: ((14, 21), (12, 24), (10, 27)),
      frontLeg: ((17, 21), (20, 18), (23, 20))
    ),
  ]

  for frame in 0..<4 {
    drawRunnerPose(canvas: &canvas, pose: poses[frame], offsetX: frame * 32)
  }

  return canvas
}

func drawDeathSpriteSheet() -> Canvas {
  var canvas = Canvas(width: 128, height: 32)
  let poses = [
    RunnerPose(
      head: (14, 6),
      torso: (11, 13),
      lean: 1,
      backArm: ((13, 17), (11, 18), (9, 20)),
      frontArm: ((17, 17), (19, 19), (21, 22)),
      backLeg: ((13, 23), (14, 26), (14, 29)),
      frontLeg: ((16, 23), (17, 26), (18, 29))
    ),
    RunnerPose(
      head: (13, 9),
      torso: (10, 16),
      lean: 1,
      backArm: ((12, 19), (10, 21), (8, 24)),
      frontArm: ((16, 19), (18, 21), (20, 24)),
      backLeg: ((12, 25), (11, 28), (10, 30)),
      frontLeg: ((15, 25), (16, 28), (17, 30))
    ),
    RunnerPose(
      head: (11, 14),
      torso: (8, 19),
      lean: 1,
      backArm: ((10, 22), (8, 24), (6, 25)),
      frontArm: ((14, 22), (16, 23), (18, 24)),
      backLeg: ((10, 26), (8, 28), (6, 29)),
      frontLeg: ((13, 26), (15, 27), (17, 28))
    ),
    RunnerPose(
      head: (18, 18),
      torso: (8, 21),
      lean: 0,
      backArm: ((10, 23), (8, 24), (6, 24)),
      frontArm: ((14, 23), (16, 24), (18, 24)),
      backLeg: ((10, 25), (8, 26), (6, 27)),
      frontLeg: ((13, 25), (15, 26), (17, 27))
    ),
  ]

  for frame in 0..<4 {
    drawRunnerPose(canvas: &canvas, pose: poses[frame], offsetX: frame * 32)
  }

  return canvas
}

func save(_ canvas: Canvas, named name: String, under assetsURL: URL) throws {
  try canvas.writePNG(to: assetsURL.appendingPathComponent(name))
}

let fileManager = FileManager.default
let workingDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let assetsURL = workingDirectory.appendingPathComponent("assets", isDirectory: true)

try save(drawFloorTopTile(variant: 0), named: "tile-floor-top.png", under: assetsURL)
try save(drawFloorTopTile(variant: 1), named: "tile-floor-top-2.png", under: assetsURL)
try save(drawFloorTopTile(variant: 2), named: "tile-floor-top-3.png", under: assetsURL)
try save(drawFloorBaseTile(variant: 0), named: "tile-floor-base.png", under: assetsURL)
try save(drawFloorBaseTile(variant: 1), named: "tile-floor-base-2.png", under: assetsURL)
try save(drawFloorBaseTile(variant: 2), named: "tile-floor-base-3.png", under: assetsURL)
try save(drawGroundTransition(), named: "ground-transition.png", under: assetsURL)
try save(drawObstacleTile(), named: "tile-obstacle.png", under: assetsURL)
try save(drawSkyBackdrop(), named: "bg-sky.png", under: assetsURL)
try save(drawFarParallaxLayer(), named: "bg-parallax-far.png", under: assetsURL)
try save(drawMidParallaxLayer(), named: "bg-parallax-mid.png", under: assetsURL)
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
try save(drawShrubSprite(variant: 0), named: "foliage-shrub-1.png", under: assetsURL)
try save(drawShrubSprite(variant: 1), named: "foliage-shrub-2.png", under: assetsURL)
try save(drawTreeSprite(variant: 0), named: "foliage-tree-1.png", under: assetsURL)
try save(drawTreeSprite(variant: 1), named: "foliage-tree-2.png", under: assetsURL)
try save(drawFireballSprite(), named: "fireball-sprite.png", under: assetsURL)
try save(drawBugWalkerSprite(), named: "bug-walker-sprite.png", under: assetsURL)
try save(drawDeadBug(), named: "bug-walker-dead.png", under: assetsURL)
try save(drawBugSingle(), named: "bug-walker.png", under: assetsURL)
try save(drawRunnerSpriteSheet(), named: "player-runner-sprite.png", under: assetsURL)
try save(drawDeathSpriteSheet(), named: "player-death-sprite.png", under: assetsURL)

print("Regenerated consistent asset set in \(assetsURL.path)")
