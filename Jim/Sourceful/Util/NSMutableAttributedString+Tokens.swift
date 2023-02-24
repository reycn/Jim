//
//  NSMutableAttributedString+Tokens.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 02/05/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation
import AppKit

public extension NSMutableAttributedString {
	
	convenience init(source: String, tokens: [Token], theme: SyntaxColorTheme) {
		
		self.init(string: source)
		
		var attributes = [NSAttributedString.Key: Any]()
		
		let spaceAttrString = NSAttributedString(string: " ", attributes: [.font: theme.font])
		let spaceWidth = spaceAttrString.size().width
		
		let themeInfo = ThemeInfo(theme: theme, spaceWidth: spaceWidth)
		
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.paragraphSpacing = 2.0
		paragraphStyle.defaultTabInterval = themeInfo.spaceWidth * 4
		paragraphStyle.tabStops = []
		
		// Improve performance by manually specifying writing direction.
		paragraphStyle.baseWritingDirection = .leftToRight
		paragraphStyle.alignment = .left
		
		let wholeRange = NSRange(location: 0, length: source.count)
		
		attributes[.paragraphStyle] = paragraphStyle

		for (attr, value) in theme.globalAttributes() {
			attributes[attr] = value
		}

		self.setAttributes(attributes, range: wholeRange)
		
		for token in tokens {
			
			if token.isPlain {
				continue
			}
			
			let tokenRange = token.range
			
			let range = source.nsRange(fromRange: tokenRange)
			
			self.setAttributes(theme.attributes(for: token), range: range)
			
		}
		
	}
	
}
