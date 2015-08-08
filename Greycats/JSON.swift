//
//  JSON.swift
//  Trusted
//
//  Created by Rex Sheng on 6/23/15.
//  Copyright (c) 2015 Trusted. All rights reserved.
//

public struct JSON {
	public enum Type {
		case Number
		case String
		case Dictionary
		case Array
		case Null
	}
	public let type: Type
	public typealias RawValue = AnyObject
	public let object: RawValue?
	
	public init(_ json: RawValue?) {
		switch json {
		case let string as String:
			type = .String
			object = json
		case let number as Double:
			type = .Number
			object = json
		case let raw as [RawValue]:
			type = .Array
			object = json
		case let raw as [String: RawValue]:
			type = .Dictionary
			object = json
		default:
			type = .Null
			object = nil
		}
	}
	
	public var int: Int? {
		if type == .Number {
			return object as? Int
		}
		return nil
	}
	
	public var double: Double? {
		if type == .Number {
			return object as? Double
		}
		return nil
	}
	
	public var string: String? {
		if type == .String {
			return object as? String
		}
		return nil
	}
	
	public var bool: Bool {
		if type == .Number {
			return (object as? Bool)!
		}
		return false
	}
	
	public var array: [JSON]? {
		if type == .Array {
			let array: [JSON] = (object as! [RawValue]).map { JSON($0) }
			return array
		}
		return nil
	}
	
	public var dictionary: [String: JSON]? {
		if type == .Dictionary {
			var dictionary: [String: JSON] = [:]
			for (k, v) in object as! [String: RawValue] {
				dictionary[k] = JSON(v)
			}
			return dictionary
		}
		return nil
	}

	public var json: AnyObject {
		if let o: AnyObject = object {
			return o
		} else {
			return NSNull()
		}
	}
	
	public subscript (key: Int) -> JSON {
		if type == .Array {
			if let object = object as? [RawValue] {
				return JSON(object[key])
			}
		}
		return JSON(nil)
	}
	
	public subscript (key: String) -> JSON {
		if let object = object as? [String: AnyObject] {
			return JSON(object[key])
		}
		return JSON(nil)
	}
}

extension JSON: NilLiteralConvertible {
	public init(nilLiteral: ()) {
		self.init(nil)
	}
}