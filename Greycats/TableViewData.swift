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
	weak var navigationController: UINavigationController? {get set}
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
	func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
	func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
}

protocol SectionDataSource: SectionData {
	typealias Element
	var source: [Element] { get set }
}

public protocol TableViewDataNibCell {
	class var nibName: String { get }
}

public class TableViewDataNib<T, U: UITableViewCell where U: TableViewDataNibCell>: TableViewData<T, U> {
	public required init(title: String?) {
		super.init(title: title)
	}
	
	public override func didSetTableView(tableView: UITableView?) {
		_tableView?.registerNib(UINib(nibName: U.nibName, bundle: nil), forCellReuseIdentifier: cellIdentifier)
	}
}

public class TableViewData<T, U: UITableViewCell>: NSObject, SectionDataSource {
	typealias Element = T
	typealias Cell = U
	public var section: Int = 0
	public var cacheKey: (T -> String)?
	public var cellIdentifier = "cell"
	var className: String?
	
	private var data: [T] = []
	private var preRender: (U -> Void)?
	private var renderCell: ((U, T, dispatch_block_t) -> Void)?
	private var select: ((T) -> UIViewController?)?
	private var renderHeader: ((String) -> UIView?)?
	private var title: String?
	public var alwaysDisplaySectionHeader = false
	private weak var _tableView: UITableView?
	weak public var navigationController: UINavigationController?
	private var placeholder: U!
	
	private let rendering_cache = NSCache()
	
	public var tableView: UITableView? {
		set(t) {
			if let t = t {
				_tableView = t
				cellIdentifier = "\(className!)-\(section)"
				println("\(self) register cell \(cellIdentifier)")
				didSetTableView(t)
			}
		}
		get {
			return _tableView
		}
	}
	
	public func didSetTableView(tableView: UITableView?) {
		_tableView?.registerClass(U.self, forCellReuseIdentifier: cellIdentifier)
	}
	
	func render(cell: U, index: Int) {
		let object = data[index]
		if let c = cacheKey {
			let key = c(object)
			var data = rendering_cache.objectForKey(key) as? NSData
			if data == nil {
				renderCell?(cell, object) {[weak self] _ in
					var mdata = NSMutableData()
					let coder = NSKeyedArchiver(forWritingWithMutableData: mdata)
					cell.encodeRestorableStateWithCoder(coder)
					coder.finishEncoding()
					self!.rendering_cache.setObject(mdata, forKey: key)
					if !skipHeightCalculation {
						self!._tableView?.reloadRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: self!.section)], withRowAnimation: .None)
					}
				}
			} else {
				let coder = NSKeyedUnarchiver(forReadingWithData: data!)
				cell.decodeRestorableStateWithCoder(coder)
			}
		} else {
			renderCell?(cell, object) {}
		}
	}
	
	public required init(title: String?) {
		self.title = title
		className = "\(NSStringFromClass(U))"
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
	
	var rowAnimation = UITableViewRowAnimation.None
	
	public var source: [T] {
		set(data) {
			self.data = data
			switch rowAnimation {
			case .None:
				self.tableView?.reloadData()
			default:
				self.tableView?.reloadSections(NSIndexSet(index: section), withRowAnimation: rowAnimation)
			}
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
		if placeholder == nil {
			let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as Cell
			placeholder = cell
			placeholder.setTranslatesAutoresizingMaskIntoConstraints(false)
		}
		preRender?(placeholder)
		render(placeholder, index: indexPath.row)
		placeholder.setNeedsLayout()
		placeholder.layoutIfNeeded()
		let height = CGFloat(ceil(placeholder.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height)) + 0.5
		return height
	}
	
	public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as Cell
		preRender?(cell)
		render(cell, index: indexPath.row)
		return cell
	}
	
	public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if self.title != nil {
			let view = renderHeader?(title!)
			return view?.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height ?? 44
		}
		return 0
	}
	
	public func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return renderHeader?(title!)
	}
	
	public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		tableView.deselectRowAtIndexPath(indexPath, animated: true)
		if let vc = select?(data[indexPath.row]) {
			navigationController?.pushViewController(vc, animated: true)
		}
	}
}

class TableViewJoinedData: NSObject, UITableViewDataSource, UITableViewDelegate {
	var joined: [SectionData]
	var alwaysDisplaySectionHeader: Bool
	
	init(_ tableView: UITableView, sections: [SectionData], alwaysDisplaySectionHeader: Bool) {
		joined = sections
		self.alwaysDisplaySectionHeader = alwaysDisplaySectionHeader
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
		if !alwaysDisplaySectionHeader && joined[section].tableView(tableView, numberOfRowsInSection: section) == 0 {
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
		joined[indexPath.section].tableView(tableView, didSelectRowAtIndexPath: indexPath)
	}
}

private var joinedAssociationKey: UInt8 = 0x01

extension NSObject {
	var _joined_sections: [String: TableViewJoinedData] {
		get {
			if let cache = objc_getAssociatedObject(self, &joinedAssociationKey) as? [String: TableViewJoinedData] {
				return cache
			} else {
				var newValue: [String: TableViewJoinedData] = [:]
				objc_setAssociatedObject(self, &joinedAssociationKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))
				return newValue
			}
		}
		set(newValue) {
			objc_setAssociatedObject(self, &joinedAssociationKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))
		}
	}
	
	public func connectTableView(tableView: UITableView, sections: [SectionData], alwaysDisplaySectionHeader: Bool = false, key: String = "default", navigationController: UINavigationController?) {
		if let joinedData = _joined_sections[key] {
			for data in joinedData.joined {
				data.tableView = nil
			}
		}
		
		let joined = TableViewJoinedData(tableView, sections: sections, alwaysDisplaySectionHeader: alwaysDisplaySectionHeader)
		for section in sections {
			section.navigationController = navigationController
		}
		_joined_sections[key] = joined
		tableView.reloadData()
	}
}

extension UIViewController {
	public func connectTableView(tableView: UITableView, sections: [SectionData], alwaysDisplaySectionHeader: Bool = false, key: String = "default") {
		super.connectTableView(tableView, sections: sections, alwaysDisplaySectionHeader: alwaysDisplaySectionHeader, key: key, navigationController: self.navigationController)
	}
}
