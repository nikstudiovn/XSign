//
//  ZsignHandler.swift
//  XSign
//
//  Created by samara on 17.04.2025.
//

import Foundation
import Zsign
import UIKit

final class ZsignHandler {
	var hadError: Error?
	
	private var _appUrl: URL
	private var _options: Options
	private var _certificate: CertificatePair?
	
	init(
		appUrl: URL,
		options: Options = OptionsManager.shared.options,
		cert: CertificatePair? = nil
	) {
		self._appUrl = appUrl
		self._options = options
		self._certificate = cert
	}
	
	func disinject() async throws {
		guard !_options.disInjectionFiles.isEmpty else {
			return
		}
		
		let bundle = Bundle(url: _appUrl)
		guard let execName = bundle?.exec, !execName.isEmpty else { throw SigningFileHandlerError.corruptedMachO }
		let execURL = _appUrl.appendingPathComponent(execName)
		guard FileManager.default.fileExists(atPath: execURL.path) else { throw SigningFileHandlerError.corruptedMachO }
		let execPath = execURL.relativePath
		
		if !Zsign.removeDylibs(appExecutable: execPath, using: _options.disInjectionFiles) {
			throw SigningFileHandlerError.disinjectFailed
		}
	}
	
	func sign() async throws {
		guard let cert = _certificate else {
			throw SigningFileHandlerError.missingCertifcate
		}

		guard let provisionURL = Storage.shared.getFile(.provision, from: cert), FileManager.default.fileExists(atPath: provisionURL.path), let p12URL = Storage.shared.getFile(.certificate, from: cert), FileManager.default.fileExists(atPath: p12URL.path) else { throw SigningFileHandlerError.certificateFileMissing }
		let _ = Zsign.sign(
			appPath: _appUrl.relativePath,
			provisionPath: provisionURL.path,
			p12Path: p12URL.path,
			p12Password: cert.password ?? "",
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			removeProvision: !_options.removeProvisioning,
			completion: { success in
				if !success {
					self.hadError = SigningFileHandlerError.signFailed
				}
			}
		)
	}
	
	func adhocSign() async throws {
		let _ = Zsign.sign(
			appPath: _appUrl.relativePath,
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			adhoc: true,
			removeProvision: !_options.removeProvisioning,
			completion: { success in
				if !success {
					self.hadError = SigningFileHandlerError.signFailed
				}
			}
		)
	}
}
