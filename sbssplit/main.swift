//
//  main.swift
//  sbssplit
//
//  Created by Scott Jann on 5/9/24.
//

import Foundation
import CoreImage
import UniformTypeIdentifiers

func savePng(_ image: CGImage, to url: URL, properties: CFDictionary) {
	guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 2, nil) else {
		print("Can't to create \(url.path())")
		exit(1)
	}
	print("Writing image to \(url.path())")
	CGImageDestinationAddImage(destination, image, properties)
	guard CGImageDestinationFinalize(destination) else {
		print("Can't to save image \(url.path())")
		exit(1)
	}
}

for arg in CommandLine.arguments.dropFirst() {
	let url = URL(fileURLWithPath: arg)

	guard FileManager.default.fileExists(atPath: arg) else {
		print("Can't open \(arg)")
		exit(1)
	}

	guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
		print("Can't open image \(arg)")
		exit(1)
	}

	let imageCount = CGImageSourceGetCount(imageSource)
	guard imageCount == 1 else {
		print("Unexpected number of images in \(arg): \(imageCount)")
		exit(1)
	}

	guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
		print("Can't load image \(arg)")
		exit(1)
	}

	// load EXIF data to copy to destination images
	guard var properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary? else {
		print("Unable to load metadata for \(arg)")
		exit(1)
	}

	let leftRect = CGRect(x: 0, y: 0, width: image.width / 2, height: image.height)
	let rightRect = CGRect(x: image.width / 2, y: 0, width: image.width / 2, height: image.height)
	let leftFile = URL(fileURLWithPath: url.deletingPathExtension().path() + "-0.png")
	let rightFile = URL(fileURLWithPath: url.deletingPathExtension().path() + "-1.png")

	guard let left = image.cropping(to: leftRect), let right = image.cropping(to: rightRect) else {
		print("Can't split image \(arg)")
		exit(1)
	}

	// the EXIF data for QooCam images is missing the Camera Make/Model, so add it
	if let userData = properties[kCGImagePropertyExifDictionary]?[kCGImagePropertyExifUserComment] as? String {
		if userData.hasPrefix("QooCam+EGO") {
			if var tiffProperties = properties[kCGImagePropertyTIFFDictionary] as? Dictionary<CFString, Any> {
				print("Adding QooCam EGO Camera info...")
				tiffProperties.updateValue("Kandao", forKey: kCGImagePropertyTIFFMake)
				tiffProperties.updateValue("QooCam EGO", forKey: kCGImagePropertyTIFFModel)
				properties.updateValue(tiffProperties as CFDictionary, forKey: kCGImagePropertyTIFFDictionary)
			}
		}
	}

	savePng(left, to: leftFile, properties: properties as CFDictionary)
	savePng(right, to: rightFile, properties: properties as CFDictionary)
}
