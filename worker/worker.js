// XSign manifest worker
// Generates an OTA install manifest (manifest.plist) over valid HTTPS so iOS accepts
// itms-services links. The IPA itself is still served by XSign on the device; this
// worker never sees the app binary.
//
// GET /genPlist?bundleid=...&name=...&version=...&fetchurl=http://127.0.0.1:PORT/UUID.ipa
// GET /health  -> "ok"
// Compatible with the api.palera.in/genPlist parameters.

const PRIVATE_HOST =
	/^(localhost|127(\.\d{1,3}){3}|10(\.\d{1,3}){3}|192\.168(\.\d{1,3}){2}|172\.(1[6-9]|2\d|3[01])(\.\d{1,3}){2}|169\.254(\.\d{1,3}){2})$/;
const BUNDLE_ID = /^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$/;

const xml = (s) =>
	String(s)
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/"/g, "&quot;")
		.replace(/'/g, "&apos;");

const text = (body, status = 200) =>
	new Response(body, {
		status,
		headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" },
	});

function isAllowedFetchUrl(value) {
	let u;
	try {
		u = new URL(value);
	} catch {
		return false;
	}
	return (
		(u.protocol === "http:" || u.protocol === "https:") &&
		PRIVATE_HOST.test(u.hostname) &&
		u.pathname.toLowerCase().endsWith(".ipa")
	);
}

export default {
	async fetch(request) {
		if (request.method !== "GET" && request.method !== "HEAD") {
			return text("Method not allowed", 405);
		}

		const url = new URL(request.url);

		if (url.pathname === "/health") return text("ok");
		if (url.pathname !== "/genPlist" && url.pathname !== "/manifest.plist") {
			return text("Not found", 404);
		}

		const p = url.searchParams;
		const bundleId = (p.get("bundleid") || "").trim();
		const name = (p.get("name") || "").trim();
		const version = (p.get("version") || "").trim();
		const fetchUrl = (p.get("fetchurl") || "").trim();

		if (!BUNDLE_ID.test(bundleId)) return text("Invalid bundleid", 400);
		if (!name || name.length > 256) return text("Invalid name", 400);
		if (!version || version.length > 64) return text("Invalid version", 400);
		if (!isAllowedFetchUrl(fetchUrl)) return text("Invalid fetchurl (local .ipa URL only)", 400);

		const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>items</key>
	<array>
		<dict>
			<key>assets</key>
			<array>
				<dict>
					<key>kind</key>
					<string>software-package</string>
					<key>url</key>
					<string>${xml(fetchUrl)}</string>
				</dict>
			</array>
			<key>metadata</key>
			<dict>
				<key>bundle-identifier</key>
				<string>${xml(bundleId)}</string>
				<key>bundle-version</key>
				<string>${xml(version)}</string>
				<key>kind</key>
				<string>software</string>
				<key>title</key>
				<string>${xml(name)}</string>
			</dict>
		</dict>
	</array>
</dict>
</plist>
`;

		return new Response(request.method === "HEAD" ? null : plist, {
			headers: {
				"Content-Type": "application/xml; charset=utf-8",
				"Cache-Control": "no-store",
			},
		});
	},
};
