# Hướng dẫn Đóng góp / Contributing to XSign

<p>
  <a href="#tiếng-việt"><strong>🇻🇳 Tiếng Việt</strong></a> &nbsp;|&nbsp; <a href="#english"><strong>🇺🇸 English</strong></a>
</p>

---

<a id="tiếng-việt"></a>
## 🇻🇳 Tiếng Việt

Cảm ơn bạn đã quan tâm và đóng góp cho **XSign**! Mọi đóng góp đều cần tuân thủ [Quy tắc Ứng xử](./CODE_OF_CONDUCT.md) và các nguyên tắc dưới đây.

### Quy tắc cốt lõi
- **Giữ app chạy ổn định trên iOS stock:** Không thêm bất kỳ mã khai thác lỗ hổng (exploit) nào dưới mọi hình thức; mọi tính năng phải hoạt động chuẩn trên iOS nguyên bản.
- **Không đưa chứng chỉ bên thứ ba lên repo:** Nghiêm cấm đính kèm, lưu trữ hoặc thêm cơ chế thu thập chứng chỉ ký của tổ chức/bên thứ ba vào mã nguồn.
- **Giấy phép phù hợp:** Mã nguồn đóng góp cho XSign tuân thủ giấy phép **GPL-3.0** của dự án.
- **Thảo luận trước với thay đổi lớn:** Nếu bạn dự định thêm tính năng lớn hoặc thay đổi kiến trúc, hãy mở **Issue** trước để trao đổi.

### Quy trình tạo nhánh & mở Pull Request (PR) vào `main`
1. **Fork** kho lưu trữ và tạo nhánh mới từ nhánh `main` (ví dụ: `feat/ten-tinh-nang` hoặc `fix/mo-ta-loi`).
2. Thực hiện thay đổi gọn gàng, rõ ràng; giữ commit có ý nghĩa.
3. Mở **Pull Request** hướng vào nhánh `main`.

### Yêu cầu kiểm duyệt bắt buộc đối với mọi PR
- **Tự rà soát kỹ mã nguồn:** Mọi PR — dù viết tay hoàn toàn hay có công cụ hỗ trợ — đều phải được tác giả tự đọc lại, kiểm tra kỹ logic, bảo mật và dọn sạch mã thừa trước khi gửi.
- **Vượt qua workflow Release build `XSign.ipa` với 0 lỗi:** Đảm bảo dự án biên dịch thành công qua workflow `.github/workflows/release.yml` (và/hoặc `make` trên macOS/Xcode) không phát sinh lỗi build.
- **Mô tả rõ cách kiểm thử trên iPhone:** Trong phần mô tả PR, hãy ghi rõ phiên bản iOS, thiết bị iPhone đã kiểm thử, các bước tái hiện và kết quả thực tế (đính kèm ảnh/video nếu liên quan đến UI).

---

<a id="english"></a>
## 🇺🇸 English

Thank you for your interest in contributing to **XSign**! All contributions must follow our [Code of Conduct](./CODE_OF_CONDUCT.md) and the guidelines below.

### Core Rules
- **Keep XSign stable on stock iOS:** Do not introduce exploits of any kind; all features must rely strictly on stock iOS capabilities and remain stable.
- **No third-party certificates in the repository:** Never commit, bundle, or add mechanisms to retrieve signing certificates belonging to third parties or companies.
- **Appropriate licensing:** Contributions to XSign are subject to the project's **GPL-3.0** license.
- **Discuss major changes first:** For large features or architectural changes, please open an **Issue** beforehand to align on the approach.

### Branching & Opening a Pull Request (PR) to `main`
1. **Fork** the repository and create a new branch from `main` (e.g., `feat/feature-name` or `fix/issue-summary`).
2. Keep changes focused, clean, and well-structured with clear commit messages.
3. Open a **Pull Request** targeting the `main` branch.

### Mandatory PR Verification Requirements
- **Thorough self-review:** Every PR—whether written manually or with tool assistance—must be carefully reviewed by the author for correctness, stability, and clean code before submission.
- **Pass the Release build `XSign.ipa` workflow with 0 errors:** Your changes must compile cleanly in `.github/workflows/release.yml` (and/or `make` with Xcode on macOS) with zero build errors.
- **Document iPhone testing clearly:** Include your iOS version, iPhone model, test steps, and observed results in the PR description (along with screenshots/recordings for UI changes).
