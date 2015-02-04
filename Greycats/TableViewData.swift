//
//  TableViewData.swift
//
//  Created by Rex Sheng on 1/29/15.
//  Copyright (c) 2015 iLabs. All rights reserved.
//

// available in pod 'Greycats', '~> 0.1.5'

import UIKit

private let skipHeightCalculation = UIDevice.currentDevice().systemVersion.compare("8.0", options: NSStringCompareOptions.NumericSearch) != .OrderedAscending

public protocol SectionData: NSObjectProtocol {
	var section: Int {get set}
	var tableView: UITableView? {get set}
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
	func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
	func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) -> UIViewController?
}

public class TableViewData<T, U: UITableViewCell>: NSObject, SectionData {
	typealias Element = T
	typealias Cell = U
	public var section: Int = 0
	public var cacheKey: (T -> String)?
	public var cellIdentifier = "cell"
	
	private var data: [T] = []
	private var preRender: (U -> Void)?
	private var renderCell: ((U, T, dispatch_block_t) -> Void)?
	private var select: ((T) -> UIViewController?)?
	private var renderHeader: ((String) -> UIView?)?
	private var title: String?
	
	private weak var _tableView: UITableView?
	private let cell = U(style: .Default, reuseIdentifier: "-placeholder-")
	private let rendering_cache = NSCache()
	private var height_cache: [Int: CGFloat] = [:]
	
	public var tableView: UITableView? {
		set(t) {
			_tableView = t
			cellIdentifier += "-\(section)"
			println("register cell \(cellIdentifier)")
			_tableView?.registerClass(U.self, forCellReuseIdentifier: cellIdentifier)
		}
		get {
			return _tableView
		}
	}
	
	func render(cell: U, index: Int) -> CGFloat {
		let object = data[index]
		if let c = cacheKey {
			let key = c(object)
			var data = rendering_cache.objectForKey(key) as? NSData
			if data == nil {
				renderCell?(cell, object) {
					var mdata = NSMutableData()
					let coder = NSKeyedArchiver(forWritingWithMutableData: mdata)
					cell.encodeRestorableStateWithCoder(coder)
					coder.finishEncoding()
					self.rendering_cache.setObject(mdata, forKey: key)
				}
			} else {
				let coder = NSKeyedUnarchiver(forReadingWithData: data!)
				cell.decodeRestorableStateWithCoder(coder)
			}
		} else {
			renderCell?(cell, object) {}
		}
		if !skipHeightCalculation {
			if let height = height_cache[index] {
				return height
			}
			cell.layoutIfNeeded()
			let height = CGFloat(ceil(cell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height))
			println("height for \(object) = \(height)")
			height_cache[index] = height
			return height
		}
		return UITableViewAutomaticDimension
	}
	
	public required init(title: String?) {
		self.title = title
		cellIdentifier = "\(NSStringFromClass(U))"
		cell.setTranslatesAutoresizingMaskIntoConstraints(false)
		super.init()
	}
	
	public func preRender(block: (cell: U) -> Void) -> Self {
		preRender = block
		return self
	}
	
	public func onRender(block: (cell: U, object: T) -> Void) -> Self {
		renderCell = {
			block(cell: $0, object: $1)
			$2()
		}
		return self
	}
	
	public func onFutureRender(render: (Cell, T, dispatch_block_t) -> Void) -> Self {
		renderCell = render
		return self
	}
	
	public func onSelect(block: (T) -> UIViewController?) -> Self {
		select = block
		return self
	}
	
	public func onHeader(block: (String) -> UIView?) -> Self {
		renderHeader = block
		return self
	}
	
	public var source: [T] {
		set(data) {
			self.data = data
			self.tableView?.reloadSections(NSIndexSet(index: section), withRowAnimation: .None)
		}
		get {
			return self.data
		}
	}
	
	public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return data.count
	}
	
	public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		if skipHeightCalculation {
			return UITableViewAutomaticDimension
		}
		preRender?(cell)
		return render(cell, index: indexPath.row)
	}
	
	public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as Cell
		preRender?(cell)
		render(cell, index: indexPath.row)
		return cell
	}
	
	public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if self.title != nil {
			return 40
		}
		return 0
	}
	
	public func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return renderHeader?(title!)
	}
	
	public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) -> UIViewController? {
		tableView.deselectRowAtIndexPath(indexPath, animated: true)
		return select?(data[indexPath.row])
	}
}

class TableViewJoinedData: NSObject, UITableViewDataSource, UITableViewDelegate {
	var joined: [SectionData]
	private weak var viewController: UIViewController?
	
	init(_ tableView: UITableView, sections: [SectionData]) {
		joined = sections
		for (index, obj) in enumerate(sections) {
			obj.section = index
			obj.tableView = tableView
		}
		super.init()
		if skipHeightCalculation {
			tableView.estimatedRowHeight = 80
		}
		tableView.delegate = self
		tableView.dataSource = self
	}
	
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return joined.count
	}
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return joined[section].tableView(tableView, numberOfRowsInSection: section)
	}
	
	func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if joined[section].tableView(tableView, numberOfRowsInSection: section) == 0 {
			return 0
		}
		return joined[section].tableView(tableView, heightForHeaderInSection: section)
	}
	
	func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return joined[section].tableView(tableView, viewForHeaderInSection: section)
	}
	
	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return joined[indexPath.section].tableView(tableView, heightForRowAtIndexPath: indexPath)
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		return joined[indexPath.section].tableView(tableView, cellForRowAtIndexPath: indexPath)
	}
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		if let vc = joined[indexPath.section].tableView(tableView, didSelectRowAtIndexPath: indexPath) {
			viewController?.navigationController?.pushViewController(vc, animated: true)
		}
	}
}

private var joinedAssociationKey: UInt8 = 0

extension UIViewController {
	
	var _joined_sections: TableViewJoinedData! {
		get {
			return objc_getAssociatedObject(self, &joinedAssociationKey) as? TableViewJoinedData
		}
		set(newValue) {
			objc_setAssociatedObject(self, &joinedAssociationKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))
		}
	}
	
	public func connectTableView(tableView: UITableView, sections: [SectionData]) {
		let joined = TableViewJoinedData(tableView, sections: sections)
		joined.viewController = self
		_joined_sections = joined
	}
}
