//
//  VideoCompositor.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-12.
//

// Take two camera frames (front + back) and combine into one, frame by frame - called 30 times a second
// Back camera frame stays full, front frame is 25% in top-right corner
// Return a CIImage (per frame) which will be passed to VideoWriter

import CoreImage

class VideCompositor {
    func compose(backFrame: CIImage, frontFrame: CIImage) -> CIImage {
        let backSize = backFrame.extent.size
        
        // Scale front camera to 25%
        let scale = 0.25
        let scaledFront = frontFrame.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // Position front camera to top-right corner with padding
        let padding: CGFloat = 16
        let frontSize = scaledFront.extent.size
        let xOffset = backSize.width - frontSize.width - padding
        let yOffset = backSize.height - frontSize.height - padding
        let positionedFront = scaledFront.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))
        
        // Composite front on top of back
        return positionedFront.composited(over: backFrame)
    }
}
