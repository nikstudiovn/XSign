//
//  Storage+Sources.swift
//  XSign
//
//  Created by samara on 12.04.2025.
//

import CoreData
import AltSourceKit
import OSLog
import UIKit.UIImpactFeedbackGenerator

// MARK: - Class extension: Sources
extension Storage {
	/// Retrieve sources in an array, we don't normally need this in swiftUI but we have it for the copy sources action
	func getSources() -> [AltSource] {
		let request: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		return (try? context.fetch(request)) ?? []
	}
	
	func addSource(
		_ url: URL,
		name: String? = "Unknown",
		identifier: String,
		iconURL: URL? = nil,
		deferSave: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		context.perform { [weak self] in
						 guard let self else { DispatchQueue.main.async { completion(nil) }; return }
						 if self.sourceExists(identifier) {
			DispatchQueue.main.async { completion(nil) }
			Logger.misc.debug("ignoring \(identifier)")
			return
		}
		
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		let new = AltSource(context: self.context)
		new.name = name
		new.date = Date()
		new.identifier = identifier
		new.sourceURL = url
		new.iconURL = iconURL
		
		do {
			if !deferSave {
				try self.context.save()
				DispatchQueue.main.async { generator.impactOccurred() }
			}
			DispatchQueue.main.async { completion(nil) }
		} catch {
			DispatchQueue.main.async { completion(error) }
		}
						}
	}
	
	func addSource(
		_ url: URL,
		repository: ASRepository,
		id: String = "",
		deferSave: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		addSource(
			url,
			name: repository.name,
			identifier: !id.isEmpty
				? id
				: (repository.id ?? url.absoluteString),
			iconURL: repository.currentIconURL,
			deferSave: deferSave,
			completion: completion
		)
	}

	func addSources(
		repos: [URL: ASRepository],
		completion: @escaping (Error?) -> Void
	) {
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		for (url, repo) in repos {
			addSource(
				url,
				repository: repo,
				deferSave: true,
				completion: { error in
					if let error {
						completion(error)
					}
				}
			)
		}
		
		context.perform { [weak self] in
						 guard let self else { DispatchQueue.main.async { completion(nil) }; return }
						 self.saveContext()
		DispatchQueue.main.async {
								  generator.impactOccurred()
		completion(nil)
		}
						}
	}

	func deleteSource(for source: AltSource) {
		context.perform { [weak self] in
						 guard let self else { return }
						 self.context.delete(source)
		self.saveContext()
						}
	}

	func sourceExists(_ identifier: String) -> Bool {
		let fetchRequest: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "identifier == %@", identifier)

		do {
			let count = try context.count(for: fetchRequest)
			return count > 0
		} catch {
			Logger.misc.error("Error checking if repository exists: \(error)")
			return false
		}
	}
}
