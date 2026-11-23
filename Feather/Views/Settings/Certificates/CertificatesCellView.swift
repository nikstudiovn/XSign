import SwiftUI
import NimbleViews
import Security
import CoreData

// MARK: - OCSP Status
enum XSignOCSPStatus: String {
	case good
	case revoked
	case unknown
	case checking
}

@MainActor
final class XSignOCSPCache: ObservableObject {
	static let shared = XSignOCSPCache()

	private struct CacheEntry {
		let status: XSignOCSPStatus
		let checkedAt: Date
	}

	@Published private var cache: [String: CacheEntry] = [:]
	private let cacheTTL: TimeInterval = 24 * 60 * 60

	private init() {}

	func status(for cert: CertificatePair) -> XSignOCSPStatus? {
		guard let uuid = cert.uuid, let entry = cache[uuid] else {
			return nil
		}
		if entry.status == .checking {
			return .checking
		}
		if Date().timeIntervalSince(entry.checkedAt) < cacheTTL {
			return entry.status
		}
		return nil
	}

	func checkIfNeeded(for cert: CertificatePair) {
		if status(for: cert) == nil {
			check(for: cert)
		}
	}

	func check(for cert: CertificatePair) {
		guard let uuid = cert.uuid else { return }
		if cache[uuid]?.status == .checking { return }

		cache[uuid] = CacheEntry(status: .checking, checkedAt: Date())

		let certURL = Storage.shared.getFile(.certificate, from: cert)
		let password = cert.password ?? ""
		let certObjectID = cert.objectID

		Task.detached(priority: .utility) {
			let result = Self.performOCSPCheck(certURL: certURL, password: password)
			await MainActor.run {
				self.cache[uuid] = CacheEntry(status: result, checkedAt: Date())
				self._reportLiveActivityIfDefault(certObjectID, status: result)
			}
		}
	}

	/// Live Activity certAlert: chỉ cho chứng chỉ mặc định (XSign.selectedCert), khi bị thu hồi
	/// hoặc còn ≤ 3 ngày. XSignLiveActivityManager giới hạn tối đa 1 lần/phiên.
	private func _reportLiveActivityIfDefault(_ certObjectID: NSManagedObjectID, status: XSignOCSPStatus) {
		guard let cert = try? Storage.shared.context.existingObject(with: certObjectID) as? CertificatePair else { return }
		let request = NSFetchRequest<CertificatePair>(entityName: "CertificatePair")
		request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
		guard let all = try? Storage.shared.context.fetch(request) else { return }
		let index = UserDefaults.standard.integer(forKey: "XSign.selectedCert")
		guard all.indices.contains(index), all[index].objectID == cert.objectID else { return }
		
		let revoked = status == .revoked || cert.revoked == true
		var days = Int.max
		if let expiration = cert.expiration {
			days = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
		}
		guard revoked || days <= 3 else { return }
		
		let name = cert.nickname ?? Storage.shared.getProvisionFileDecoded(for: cert)?.Name ?? .localized("Unknown")
		XSignLiveActivityManager.shared.reportCertificate(
			name: name,
			revoked: revoked,
			daysRemaining: days
		)
	}

	nonisolated private static func performOCSPCheck(certURL: URL?, password: String) -> XSignOCSPStatus {
		guard let certURL,
			  let p12Data = try? Data(contentsOf: certURL) else {
			return .unknown
		}

		var items: CFArray?
		let options: [String: Any] = [kSecImportExportPassphrase as String: password]
		let importStatus = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)
		guard importStatus == errSecSuccess,
			  let itemArray = items as? [[String: Any]],
			  let firstItem = itemArray.first else {
			return .unknown
		}

		var certificates: [SecCertificate] = []
		if let identity = firstItem[kSecImportItemIdentity as String] {
			var secCert: SecCertificate?
			if SecIdentityCopyCertificate(identity as! SecIdentity, &secCert) == errSecSuccess, let secCert {
				certificates.append(secCert)
			}
		}
		if let chain = firstItem[kSecImportItemCertChain as String] as? [SecCertificate] {
			for item in chain where !certificates.contains(where: { $0 == item }) {
				certificates.append(item)
			}
		}

		guard !certificates.isEmpty else {
			return .unknown
		}

		let basicPolicy = SecPolicyCreateBasicX509()
		guard let revocationPolicy = SecPolicyCreateRevocation(
			kSecRevocationOCSPMethod | kSecRevocationRequirePositiveResponse
		) else {
			return .unknown
		}

		var trust: SecTrust?
		let trustStatus = SecTrustCreateWithCertificates(
			certificates as CFArray,
			[basicPolicy, revocationPolicy] as CFArray,
			&trust
		)
		guard trustStatus == errSecSuccess, let trust else {
			return .unknown
		}

		SecTrustSetNetworkFetchAllowed(trust, true)

		var error: CFError?
		if SecTrustEvaluateWithError(trust, &error) {
			return .good
		}

		if let error {
			let code = CFErrorGetCode(error)
			if code == Int(errSecCertificateRevoked) {
				return .revoked
			}
		}

		return .unknown
	}
}

// MARK: - View
struct CertificatesCellView: View {
	@State var data: Certificate?

	@ObservedObject var cert: CertificatePair
	@ObservedObject private var ocspCache = XSignOCSPCache.shared

	private var ocspStatus: XSignOCSPStatus? {
		ocspCache.status(for: cert)
	}

	private var isExpired: Bool {
		guard let expiration = cert.expiration else { return false }
		return expiration <= Date()
	}

	private var daysRemaining: Int {
		guard let expiration = cert.expiration else { return 0 }
		return max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0)
	}

	private var isRevoked: Bool {
		ocspStatus == .revoked || cert.revoked == true
	}

	private var statusLabel: String {
		if isRevoked {
			return xsignT("Thu hồi OCSP", "OCSP Revoked")
		}
		if isExpired {
			return xsignT("Hết hạn", "Expired")
		}
		if daysRemaining <= 7 {
			return xsignT("Sắp hết hạn", "Expiring Soon")
		}
		return xsignT("Còn hạn", "Valid")
	}

	private var statusColor: Color {
		if isRevoked || isExpired {
			return .red
		}
		if daysRemaining <= 7 {
			return .orange
		}
		return .green
	}

	private var countdownProgress: Double {
		if isExpired { return 0 }
		return min(max(Double(daysRemaining) / 365.0, 0.0), 1.0)
	}

	// MARK: Body
	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			let title = {
				var title = cert.nickname ?? data?.Name ?? .localized("Unknown")

				if let getTaskAllow = data?.Entitlements?["get-task-allow"]?.value as? Bool, getTaskAllow == true {
					title = "🐞 \(title)"
				}

				return title
			}()

			HStack(alignment: .center, spacing: 8) {
				NBTitleWithSubtitleView(
					title: title,
					subtitle: data?.AppIDName ?? .localized("Unknown")
				)
				Spacer(minLength: 4)
				Text(statusLabel)
					.font(.caption2.weight(.semibold))
					.padding(.horizontal, 8)
					.padding(.vertical, 3)
					.background(statusColor.opacity(0.16))
					.foregroundColor(statusColor)
					.clipShape(Capsule())
			}

			VStack(alignment: .leading, spacing: 4) {
				ProgressView(value: countdownProgress)
					.tint(statusColor)

				HStack(spacing: 8) {
					Text(isExpired ? xsignT("Đã hết hạn", "Expired") : xsignT("Còn \(daysRemaining) ngày", "\(daysRemaining) days left"))
						.font(.caption2)
						.foregroundColor(.secondary)

					Spacer()

					Button {
						ocspCache.check(for: cert)
					} label: {
						HStack(spacing: 4) {
							if ocspStatus == .checking {
								ProgressView()
									.controlSize(.mini)
							} else {
								Image(systemName: "checkmark.shield")
									.font(.caption2)
							}
							Text(xsignT("Kiểm tra OCSP", "Check OCSP"))
								.font(.caption2.weight(.medium))
						}
					}
					.buttonStyle(.bordered)
					.controlSize(.mini)
					.disabled(ocspStatus == .checking)
				}
			}

			_certInfoPill(data: cert)
		}
		.frame(minHeight: 80)
		.contentTransition(.opacity)
		.frame(maxWidth: .infinity, alignment: .leading)
		.onAppear {
			withAnimation {
				data = Storage.shared.getProvisionFileDecoded(for: cert)
			}
			ocspCache.checkIfNeeded(for: cert)
		}
	}
}

// MARK: - Extension: View
extension CertificatesCellView {
	@ViewBuilder
	private func _certInfoPill(data: CertificatePair) -> some View {
		let pills = _buildPills(from: data)
		HStack(spacing: 6) {
			ForEach(Array(pills.enumerated()), id: \.offset) { index, pill in
				NBPillView(
					title: pill.title,
					icon: pill.icon,
					color: pill.color,
					index: index,
					count: pills.count
				)
			}
		}
	}

	private func _buildPills(from cert: CertificatePair) -> [NBPillItem] {
		var pills: [NBPillItem] = []

		if cert.ppQCheck == true {
			pills.append(NBPillItem(title: "PPQCheck", icon: "checkmark.shield", color: .red))
		}

		if cert.revoked == true {
			pills.append(NBPillItem(title: "Revoked", icon: "xmark.octagon", color: .red))
		}

		if let info = cert.expiration?.expirationInfo() {
			pills.append(NBPillItem(
				title: info.formatted,
				icon: info.icon,
				color: info.color
			))
		}

		return pills
	}
}
