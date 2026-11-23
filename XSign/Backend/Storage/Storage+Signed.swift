//
//  Storage+Signed.swift
//  XSign
//
//  Created by samara on 17.04.2025.
//

import CoreData
import UIKit.UIImpactFeedbackGenerator

// MARK: - Class extension: Signed Apps
extension Storage {
	func addSigned(
		uuid: String,
		source: URL? = nil,
		certificate: CertificatePair? = nil,
		
		appName: String? = nil,
		appIdentifier: String? = nil,
		appVersion: String? = nil,
		appIcon: String? = nil,
		
		completion: @escaping (Error?) -> Void
	) {
		context.perform { [weak self] in
			guard let self else {
				DispatchQueue.main.async { completion(nil) }
				return
			}
		
		let new = Signed(context: self.context)
		
		new.uuid = uuid
		new.source = source
		new.date = Date()
		// if nil, we assume adhoc or certificate was deleted afterwards
		new.certificate = certificate
		// could possibly be nil, but thats fine.
		new.identifier = appIdentifier
		new.name = appName
		new.icon = appIcon
		new.version = appVersion
		
		self.saveContext()
		DispatchQueue.main.async {
			let generator = UIImpactFeedbackGenerator(style: .light)
			generator.impactOccurred()
			completion(nil)
		}
						} 
	}
}
