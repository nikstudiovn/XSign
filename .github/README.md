<p align="center">
  <img src="../docs/images/xsign_readme_4screens_4k.png" alt="XSign – On-Device iOS IPA Signer" width="100%" />
</p>

<h1 align="center">XSign</h1>

<p align="center">
  <strong>Trình ký và cài đặt IPA trực tiếp trên iPhone/iPad với giao diện Liquid Glass iOS 26 • On-Device iOS IPA Signer with Liquid Glass iOS 26 UI</strong>
</p>

<p align="center">
  <a href="#tiếng-việt"><strong>🇻🇳 Tiếng Việt</strong></a> &nbsp;|&nbsp; <a href="#english"><strong>🇺🇸 English</strong></a>
</p>

---

<a id="tiếng-việt"></a>
## 🇻🇳 Tiếng Việt

### Tính năng nổi bật

#### 1. Cài đặt Bán cục bộ (Semi-Local OTA)
- Sử dụng **Cloudflare Worker HTTPS + `127.0.0.1`**, giúp ký và cài đặt ứng dụng trực tiếp ngay trên thiết bị.
- Hoạt động ổn định trên cả **Wi-Fi** lẫn **4G/5G** mà không phụ thuộc mạng nội bộ phức tạp.
- Tự động xử lý quy trình cài đặt, **bỏ qua hộp thoại xác nhận Safari / iTunes prompt**.

#### 2. Lõi ký & Quản lý chứng chỉ
- **Nhập chứng chỉ linh hoạt:** Nhập nhanh từ tệp `.zip` hoặc lấy trực tiếp từ thư mục **`InputFile`** (hỗ trợ `.p12`, `.mobileprovision`, `.zip`).
- **Ký & cài 1 chạm Liquid Glass:** Thao tác nhanh chỉ với một chạm; **nhấn giữ** nút để đổi nhanh chứng chỉ đang dùng.
- **Ký hàng loạt:** Chọn nhiều tệp IPA cùng lúc và gán **chứng chỉ riêng** cho từng ứng dụng.
- **Màn hình tiến trình ký 6 bước:** Hiển thị trực quan từng giai đoạn giải nén, chèn tweak, ký mã và đóng gói.
- **Preset ký thông minh:** Hỗ trợ các cấu hình *Mặc định*, *Clone app*, *Không tweak* và **tự động lưu** tùy chọn theo thói quen sử dụng.
- **Kiểm tra OCSP trực tuyến:** Truy vấn trực tiếp máy chủ OCSP của Apple, hiển thị **thanh đếm ngày hết hạn** và **cảnh báo trạng thái chứng chỉ** ngay trên tab Thư viện.

#### 3. Dynamic Island & Live Activity (6 chế độ hợp nhất)
Theo dõi mọi tác vụ nền ngay trên màn hình khóa và Dynamic Island:
1. **Tải IPA** từ nguồn ứng dụng hoặc liên kết ngoài.
2. **Ký đơn / Ký hàng loạt** kèm tiến độ xử lý.
3. **Máy chủ cài đặt** (Semi-Local Server) đang phục vụ cài đặt.
4. **Chốt sau khi ký:** Thao tác nhanh *Cài ngay* hoặc *Chia sẻ qua `xsign://`*.
5. **Giải nén tệp nặng** (`.ipa` / `.zip`).
6. **Cảnh báo OCSP** khi chứng chỉ gặp sự cố hoặc sắp hết hạn.

#### 4. Tab Thư mục & Dọn dẹp bộ nhớ nhanh
- Quản lý trực tiếp thư mục **`InputFile`** trong ứng dụng.
- Thanh tìm kiếm **luôn hiển thị**, hỗ trợ **vuốt để xóa**, **giải nén ZIP** tại chỗ và xem trước tài liệu/ảnh bằng **QuickLook có nút Đóng**.
- **Dọn dẹp bộ nhớ nhanh:** Thống kê và cho phép tích chọn xóa từng nhóm tệp rác/tạm theo dung lượng.

#### 5. Giao diện & Cá nhân hóa
- Thiết kế **Liquid Glass iOS 26** hiện đại (có giao diện dự phòng tối ưu cho iOS cũ hơn).
- Bộ **7 màu icon Kính lỏng** siêu chi tiết: *Chính, Tím, Xanh, Bạc, Ngọc, Đen, Ruby*.
- **Đa ngôn ngữ Tiếng Việt / English** chuyển đổi trực tiếp ngay trong ứng dụng không cần khởi động lại.
- Tích hợp **hoạt ảnh mở app Liquid Glass** mượt mà và **màn hình chào mừng Onboarding** trực quan.

### Hướng dẫn cài đặt

1. Tải tệp `XSign.ipa` mới nhất từ trang [Releases](https://github.com/nikstudiovn/XSign/releases/latest).
2. Ký và cài đặt `XSign.ipa` lên iPhone/iPad bằng chứng chỉ Apple Developer của bạn hoặc qua các công cụ hỗ trợ nguồn AltSource.
3. Mở XSign, vào **Cài đặt → Chứng chỉ** (hoặc chép tệp chứng chỉ vào thư mục **`InputFile`**) để nhập `.p12` và `.mobileprovision` (hoặc `.zip`).

**Liên kết nguồn AltSource chính thức:**

    https://raw.githubusercontent.com/nikstudiovn/XSign/refs/heads/main/app-repo.json

### Tự build từ mã nguồn

Yêu cầu **macOS** kèm **Xcode** mới nhất:

    git clone --recursive https://github.com/nikstudiovn/XSign
    cd XSign
    make

Tệp `.ipa` sau khi build sẽ nằm tại `packages/XSign.ipa`.

### Hỗ trợ & Cộng đồng

- Kênh Telegram hỗ trợ chính thức: **[@nikvn21](https://t.me/nikvn21)** (`https://t.me/nikvn21`)

### Giấy phép

XSign được phát hành theo giấy phép **GNU General Public License v3.0 (GPL-3.0)**. Xem toàn văn tại tệp [LICENSE](../LICENSE).

---

<a id="english"></a>
## 🇺🇸 English

### Key Features

#### 1. Semi-Local OTA Installation
- Powered by **Cloudflare Worker HTTPS + `127.0.0.1`**, enabling reliable on-device signing and installation.
- Works seamlessly over both **Wi-Fi** and **4G/5G** without complex local network workarounds.
- Streamlined install flow that **bypasses Safari / iTunes confirmation prompts**.

#### 2. Signing Core & Certificate Management
- **Flexible Certificate Import:** Quick import from `.zip` archives or directly from the **`InputFile`** folder (`.p12`, `.mobileprovision`, `.zip`).
- **One-Tap Liquid Glass Sign & Install:** Sign and install in a single tap, or **long-press** the button to switch certificates on the fly.
- **Batch Signing:** Select multiple IPAs at once and assign an **individual certificate** per app.
- **6-Step Signing Progress Screen:** Clear visual breakdown of extraction, tweak injection, code signing, and packaging.
- **Smart Signing Presets:** Choose between *Default*, *Clone App*, and *No Tweak* presets with **auto-saved preferences**.
- **Online OCSP Verification:** Queries Apple's OCSP servers directly, displaying an **expiration countdown bar** and **certificate status alerts** in the Library tab.

#### 3. Unified Dynamic Island & Live Activity (6 Modes)
Monitor background tasks directly on the Lock Screen and Dynamic Island:
1. **IPA Downloads** from repositories or external links.
2. **Single / Batch Signing** with live progress.
3. **Install Server** (Semi-Local Server) status.
4. **Post-Sign Actions:** Quick *Install Now* or *Share via `xsign://`*.
5. **Large Archive Extraction** (`.ipa` / `.zip`).
6. **OCSP Alerts** when a certificate is revoked or nearing expiration.

#### 4. Files Tab & Quick Storage Cleanup
- Direct management of the **`InputFile`** folder inside the app.
- **Always-visible search bar**, **swipe-to-delete**, in-place **ZIP extraction**, and **QuickLook preview with a Close button**.
- **Quick Storage Cleanup:** Categorized cache/temp cleanup with size-based selection.

#### 5. Interface & Personalization
- Modern **iOS 26 Liquid Glass** design (with graceful fallback styling for older iOS versions).
- **7 detailed Liquid Glass app icons:** *Default, Purple, Blue, Silver, Jade, Black, Ruby*.
- **In-app Vietnamese / English switching** without restarting.
- Smooth **Liquid Glass launch animation** and guided **Onboarding** experience.

### Installation Guide

1. Download the latest `XSign.ipa` from [Releases](https://github.com/nikstudiovn/XSign/releases/latest).
2. Sign and install `XSign.ipa` on your iPhone/iPad using your Apple Developer certificate or an AltSource-compatible signer.
3. Open XSign, go to **Settings → Certificates** (or place your files in **`InputFile`**) to import your `.p12` and `.mobileprovision` (or `.zip`).

**Official AltSource Repository URL:**

    https://raw.githubusercontent.com/nikstudiovn/XSign/refs/heads/main/app-repo.json

### Building from Source

Requires **macOS** with the latest **Xcode**:

    git clone --recursive https://github.com/nikstudiovn/XSign
    cd XSign
    make

The compiled `.ipa` will be generated at `packages/XSign.ipa`.

### Support & Community

- Official Telegram support channel: **[@nikvn21](https://t.me/nikvn21)** (`https://t.me/nikvn21`)

### License

XSign is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See [LICENSE](../LICENSE) for details.
