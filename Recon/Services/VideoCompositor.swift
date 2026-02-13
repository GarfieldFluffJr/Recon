//
//  VideoCompositor.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-12.
//

// Take two camera frames (front + back) and combine into one, frame by frame - called 30 times a second
// Back camera frame stays full, front frame is 25% in top-right corner with rounded corners
// Optionally burns a timestamp into the video
// Return a CIImage (per frame) which will be passed to VideoWriter

import CoreImage
import UIKit

class VideoCompositor {
    func compose(backFrame: CIImage, frontFrame: CIImage, timestamp: String? = nil) -> CIImage {
        let backSize = backFrame.extent.size

        // Scale front camera to 25% and reset origin to (0,0)
        let scale = 0.25
        let scaledFront = frontFrame
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(
                translationX: -frontFrame.extent.origin.x * scale,
                y: -frontFrame.extent.origin.y * scale
            ))

        // Apply rounded corners to front camera
        let frontSize = scaledFront.extent.size
        let roundedFront = applyRoundedCorners(to: scaledFront, cornerRadius: 8)

        // Position front camera flush in top-right corner
        let xOffset = backSize.width - frontSize.width + backFrame.extent.origin.x
        let yOffset = backSize.height - frontSize.height + backFrame.extent.origin.y
        let positionedFront = roundedFront.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))

        // Composite front on top of back
        var result = positionedFront.composited(over: backFrame)

        // Burn timestamp inside the video, bottom-left corner
        if let timestamp = timestamp {
            let timestampImage = renderTimestamp(timestamp)
            let xPos = backFrame.extent.origin.x + 12
            let yPos = backFrame.extent.origin.y + 12
            let positioned = timestampImage.transformed(by: CGAffineTransform(translationX: xPos, y: yPos))
            result = positioned.composited(over: result)
        }

        return result
    }

    // Create a rounded rectangle mask and apply it to the image
    private func applyRoundedCorners(to image: CIImage, cornerRadius: CGFloat) -> CIImage {
        let size = image.extent.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let maskUIImage = renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: cornerRadius).fill()
        }

        guard let maskCI = CIImage(image: maskUIImage) else { return image }

        // Position mask at the same origin as the image
        let positionedMask = maskCI.transformed(by: CGAffineTransform(
            translationX: image.extent.origin.x,
            y: image.extent.origin.y
        ))

        return image.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputMaskImageKey: positionedMask
        ])
    }

    // Render timestamp text as a CIImage
    private func renderTimestamp(_ text: String) -> CIImage {
        let fontSize: CGFloat = 8
        let displayText = "[\(text)]"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor.orange
        ]

        let textSize = (displayText as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 2
        let canvasSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let image = renderer.image { _ in
            let textRect = CGRect(x: padding, y: padding, width: textSize.width, height: textSize.height)
            (displayText as NSString).draw(in: textRect, withAttributes: attributes)
        }

        return CIImage(image: image) ?? CIImage()
    }
}
