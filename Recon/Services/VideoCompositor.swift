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

        // Scale front camera to 25%
        let scale = 0.25
        let scaledFront = frontFrame.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Apply rounded corners to front camera
        let frontSize = scaledFront.extent.size
        let roundedFront = applyRoundedCorners(to: scaledFront, cornerRadius: 12)

        // Position front camera to top-right corner with padding
        let padding: CGFloat = 16
        let xOffset = backSize.width - frontSize.width - padding
        let yOffset = backSize.height - frontSize.height - padding
        let positionedFront = roundedFront.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))

        // Composite front on top of back
        var result = positionedFront.composited(over: backFrame)

        // Burn timestamp into bottom-left of video
        if let timestamp = timestamp {
            let timestampImage = renderTimestamp(timestamp)
            // Position at bottom-left with padding
            let positioned = timestampImage.transformed(by: CGAffineTransform(translationX: 16, y: 16))
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
        let fontSize: CGFloat = 16
        let padding: CGFloat = 8

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor.white
        ]

        let textSize = (text as NSString).size(withAttributes: attributes)
        let bgSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)

        let renderer = UIGraphicsImageRenderer(size: bgSize)
        let image = renderer.image { _ in
            // Semi-transparent black background
            UIColor.black.withAlphaComponent(0.5).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: bgSize), cornerRadius: 6).fill()

            // Draw text
            let textRect = CGRect(x: padding, y: padding, width: textSize.width, height: textSize.height)
            (text as NSString).draw(in: textRect, withAttributes: attributes)
        }

        return CIImage(image: image) ?? CIImage()
    }
}
