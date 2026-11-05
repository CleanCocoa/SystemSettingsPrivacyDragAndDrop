import CoreGraphics

/// Whether the union of `covers` contains all of `rect`.
func isFullyCovered(_ rect: CGRect, by covers: [CGRect]) -> Bool {
    covers.reduce([rect]) { uncovered, cover in
        uncovered.flatMap { subtract(cover, from: $0) }
    }.isEmpty
}

/// The parts of `rect` outside `cover`, as up to four non-overlapping rects.
private func subtract(_ cover: CGRect, from rect: CGRect) -> [CGRect] {
    let overlap = rect.intersection(cover)
    guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { return [rect] }
    return [
        CGRect(x: rect.minX, y: rect.minY, width: overlap.minX - rect.minX, height: rect.height),
        CGRect(x: overlap.maxX, y: rect.minY, width: rect.maxX - overlap.maxX, height: rect.height),
        CGRect(x: overlap.minX, y: rect.minY, width: overlap.width, height: overlap.minY - rect.minY),
        CGRect(x: overlap.minX, y: overlap.maxY, width: overlap.width, height: rect.maxY - overlap.maxY),
    ].filter { $0.width > 0 && $0.height > 0 }
}
