//
//  Breadcrumb.swift
//
//  Created by Rex Sheng on 2/2/15.
//  Copyright (c) 2015 iLabs. All rights reserved.
//

// available in pod 'Greycats', '~> 0.1.5'

import UIKit

public protocol BreadcrumbPickle {
	init(pickle: [String: AnyObject])
	func pickle() -> [String: AnyObject]
}

class TapTap: NSObject {
	var block: (UIGestureRecognizer -> Void)?
	func tapped(tap: UITapGestureRecognizer!) {
		self.block?(tap)
	}
}

public class Breadcrumb<T: BreadcrumbPickle> {
	private let attributes: [NSObject: AnyObject]
	private let highlightAttributes: [NSObject: AnyObject]?
	private let transform: T -> String
	public var slash = "/"
	public var dots = "..."
	public var within: CGSize = CGSizeMake(CGFloat.max, CGFloat.max)
	
	public init(attributes: [NSObject: AnyObject], highlightAttributes: [NSObject: AnyObject]?, transform: T -> String) {
		self.attributes = attributes
		self.highlightAttributes = highlightAttributes
		self.transform = transform
	}
	
	public init(attributes: [NSObject: AnyObject], transform: T -> String) {
		self.attributes = attributes
		self.transform = transform
	}
	
	func join(elements: [T], highlight: NSRegularExpression? = nil) -> (NSMutableAttributedString, [NSRange]) {
		var attempt = NSMutableAttributedString()
		let slash = NSAttributedString(string: "\(self.slash)", attributes: attributes)
		let lastIndex = elements.count - 1
		var ranges: [NSRange] = []
		
		for (index, el) in enumerate(elements) {
			let str = transform(el)
			var attr = attributes
			attr["-pickle-"] = el.pickle()
			var text = NSMutableAttributedString(string: str, attributes: attr)
			
			if index != lastIndex {
				ranges.append(NSMakeRange(attempt.length, text.length + 1))
			} else {
				if let highlight = highlight {
					if let highlightAttributes = highlightAttributes {
						var attr = highlightAttributes
						attr["-pickle-"] = el.pickle()
						let matches = highlight.matchesInString(str, options: nil, range: NSMakeRange(0, str.utf16Count))
						for match in matches {
							if let n = match.numberOfRanges {
								for i in 1..<n {
									text.addAttributes(attr, range: match.rangeAtIndex(i))
								}
							}
						}
					}
				}
				ranges.append(NSMakeRange(attempt.length, text.length))
			}
			attempt.appendAttributedString(text)
			if index != lastIndex {
				attempt.appendAttributedString(slash)
			}
		}
		return (attempt, ranges)
	}
	
	func fit(attr: NSAttributedString) -> Bool {
		let rect = attr.boundingRectWithSize(CGSizeMake(within.width, CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil)
		println("\"\(attr.string)\" rect = \(rect)")
		return rect.size.height <= within.height
	}
	
	func cut(attempt: NSMutableAttributedString, ranges: [NSRange]) {
		let dots = NSAttributedString(string: "\(self.dots)\(self.slash)", attributes: attributes)
		if fit(attempt) {
			return
		}
		for range in ranges {
			attempt.deleteCharactersInRange(NSMakeRange(0, range.length))
			attempt.insertAttributedString(dots, atIndex: 0)
			if fit(attempt) {
				return
			} else {
				attempt.deleteCharactersInRange(NSMakeRange(0, dots.length))
			}
		}
	}
	
	public func create(elements: [T], highlight: NSRegularExpression? = nil) -> NSMutableAttributedString {
		var (attempt, ranges) = join(elements, highlight: highlight)
		cut(attempt, ranges: ranges)
		return attempt
	}
	
	private var taptap = TapTap()
	
	public func onClick(textView: UITextView, block: T -> Void) {
		textView.addGestureRecognizer(UITapGestureRecognizer(target: taptap, action: Selector("tapped:")))
		taptap.block = {[unowned textView] tap in
			var loc = tap.locationInView(textView)
			loc.x -= textView.textContainerInset.left
			loc.y -= textView.textContainerInset.top
			let index = textView.layoutManager.characterIndexForPoint(loc, inTextContainer: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
			if index < textView.textStorage.length {
				if let value = textView.attributedText.attribute("-pickle-", atIndex: index, effectiveRange: nil) as? [String: AnyObject] {
					let category = T(pickle: value)
					println("click \(value)")
					block(category)
				}
			}
		}
	}
}