<p align="center">
  <img src=".github/assets/logo.png" width="128" height="128" alt="Tether">
</p>

<h1 align="center">Tether</h1>

<p align="center">
  Sợi dây vô hình giữa bạn và Mac.<br>
  Mang iPhone, Apple Watch hoặc AirPods đi xa, Mac tự khoá màn hình.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/phiên_bản-0.2.2-2b64f5" alt="Phiên bản 0.2.2">
  <img src="https://img.shields.io/badge/macOS-13%2B-111211?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-menu_bar-0A84FF" alt="SwiftUI">
  <img src="https://img.shields.io/badge/mạng-0_byte-22a55b" alt="Không mạng">
  <img src="https://img.shields.io/badge/giá-miễn_phí-f59e0b" alt="Miễn phí">
</p>

<p align="center">
  <a href="https://tether.hoangphuc.io.vn/" target="_blank">Website</a> •
  <a href="https://tether.hoangphuc.io.vn/#install" target="_blank">Tải về</a> •
  <a href="https://tether.hoangphuc.io.vn/whats-new/" target="_blank">Có gì mới</a> •
  <a href="https://github.com/HPhucDev/tether-app/issues" target="_blank">Báo lỗi</a> •
  <a href="https://hoangphuc.io.vn/" target="_blank">Tác giả</a>
</p>

---

<p align="center">
  <img src=".github/assets/hero.png" width="800" alt="Tether trên thanh menu macOS đang bảo vệ, theo dõi iPhone và Apple Watch">
</p>

Tether là app nhỏ trên thanh menu macOS, viết bằng Swift và SwiftUI. Nó lắng nghe sóng Bluetooth mà iPhone, Apple Watch hay AirPods vốn đã tự phát, ước lượng bạn đang ở xa hay gần, và **khoá Mac ngay sau lưng bạn** khi bạn rời bàn. Không cần cài gì lên thiết bị, không kết nối, không gửi dữ liệu đi đâu. Tether chỉ khoá, mở khoá vẫn do macOS lo (mật khẩu, Touch ID hoặc Apple Watch).

## Cài đặt

Tải file `.dmg` mới nhất trên [website](https://tether.hoangphuc.io.vn/#install), mở ra rồi kéo **Tether** vào thư mục **Applications**.

<p align="center">
  <img src="scripts/assets/dmg-background@2x.png" width="560" alt="Cửa sổ DMG: kéo Tether vào Applications, kèm hướng dẫn mở lần đầu">
</p>

> [!IMPORTANT]
> Tether chưa được Apple notarize nên **lần mở đầu tiên** macOS sẽ báo *“Tether” Not Opened*:
> 1. Bấm **Done** (đừng bấm *Move to Trash*).
> 2. Mở **Cài đặt hệ thống › Quyền riêng tư & Bảo mật**, kéo xuống và bấm **Vẫn mở** (*Open Anyway*).
>
> Chỉ cần làm một lần. App vẫn chạy trong App Sandbox và không có quyền mạng.

## Tính năng

### Tự khoá khi bạn rời đi

- **Theo dõi thụ động:** iPhone, Watch, AirPods luôn tự phát gói Bluetooth (Handoff, AirDrop…). Tether chỉ nghe và đo độ mạnh sóng (RSSI), không kết nối, không gửi lệnh.
- **Hai thiết bị cùng lúc:** khoá khi *cả hai* đi xa (mặc định) hoặc khi *một trong hai* đi xa.
- **Chống khoá nhầm:** làm mượt sóng, dùng hai ngưỡng tách nhau (mức khoá và mức quay lại), và chỉ khoá khi bạn ở xa liên tục đủ số giây bạn chọn (mặc định 8 giây).
- **Mất tín hiệu cũng tính là đi xa**, và có thể chọn khoá luôn khi Bluetooth bị tắt.

### Thiết lập trong một phút

- **Hướng dẫn lần đầu:** chọn thiết bị, đo sóng ở bàn làm việc và ở chỗ muốn khoá (ví dụ cửa phòng), Tether tự tính khoảng cách cho căn phòng của bạn.
- **Khoảng cách theo mét** (1 · 2 · 3 · 4 · 6 · 8 m) và thời gian chờ 3 · 5 · 8 · 15 giây. Muốn chỉnh tay thì có biểu đồ sóng 5 phút trong mục *Nâng cao*.
- **Độ nhạy 4 mức** (Thấp · Vừa · Cao · Rất cao): càng cao càng nhận ra bạn rời đi nhanh, nhưng dễ khoá nhầm hơn. Rất cao đo sóng mỗi 1 giây.
- **Báo khi bỏ quên thiết bị:** mở khoá Mac mà iPhone hay Watch vẫn ở xa, Tether báo cho bạn và tạm dừng theo dõi tới khi thiết bị quay về.
- **Nhận lại thiết bị** theo tên khi mã Bluetooth của nó đổi.
- **Đặt lại và xem lại hướng dẫn:** đưa mọi cài đặt về mặc định, hoặc chạy lại phần thiết lập bất cứ lúc nào.

### Tự động

- **Lịch hoạt động:** chỉ bảo vệ trong những ngày, giờ bạn chọn (kể cả khung giờ qua đêm). Ngoài lịch, icon trên thanh menu đổi thành 🌙.
- **Sáng màn hình khi quay lại:** Mac sáng sẵn để bạn mở khoá ngay bằng Touch ID hoặc Apple Watch. Tether vẫn không tự mở khoá.
- **Phím tắt:** chọn phím tắt chạy khi rời đi và khi quay lại (dừng nhạc, tắt tiếng, đổi trạng thái Slack…). App Phím tắt cũng có sẵn thao tác của Tether: Tạm dừng, Tiếp tục, Bật/tắt, Khoá Mac ngay, Trạng thái.

### Thời gian ngồi bàn

- **Thống kê** thời gian bạn ngồi ở bàn hôm nay và 7 ngày qua, chỉ lưu trên Mac.
- **Nhắc nghỉ:** thông báo đứng dậy sau 30 · 45 · 60 · 90 phút hoặc số phút bạn tự nhập.

### Gọn trên thanh menu

- Một chạm để **tạm dừng** (15 phút → tới sáng mai), **khoá thử** hoặc mở cài đặt.
- **Lịch sử 50 lần khoá** gần nhất kèm lý do và sóng của từng thiết bị, lưu ngay trên Mac.
- **Mở cùng máy**, tuỳ chọn hiện icon ở Dock, thông báo khi khoá.

### Cập nhật khi bạn muốn

- Bấm **Kiểm tra cập nhật…** (Cài đặt › Chung, tab Giới thiệu hoặc menu app). Có bản mới thì Tether hiện số phiên bản và changelog; bạn bấm cài mới tải, cài và mở lại.
- **Không bao giờ tự kiểm tra hay tự cập nhật.** Dùng [Sparkle 2](https://sparkle-project.org): bản cập nhật ký EdDSA, việc tải chạy trong `Downloader.xpc` riêng nên Tether vẫn không có quyền mạng.

### Bảo vệ bạn, không theo dõi bạn

| | |
|---|---|
| **Không mạng** | App Sandbox chỉ có đúng một quyền `com.apple.security.device.bluetooth`. macOS chặn mọi kết nối của Tether. Chỉ khi bạn bấm *Kiểm tra cập nhật*, trình tải riêng của Sparkle (`Downloader.xpc`) mới hỏi `tether.hoangphuc.io.vn`. |
| **Không thu thập** | Không analytics, không telemetry, không cloud. Tự kiểm chứng: Activity Monitor › Network luôn 0 byte. |
| **Quyền tối thiểu** | Chỉ Bluetooth và Thông báo. Không file, không vị trí, không camera. |
| **Tiết kiệm pin** | Bộ lọc gói trùng của chip Bluetooth, ngừng quét hẳn khi màn hình khoá hoặc Mac ngủ. |

## Cách hoạt động

```
iPhone / Watch / AirPods ──(gói Bluetooth tự phát)──▶ BluetoothService ──RSSI──▶ ProximityEngine ──▶ ScreenLocker
                                                         (lọc, nhận diện)        (EMA, hysteresis,      (khoá ngay,
                                                                                  độ trễ, chính sách)    dự phòng)
```

- **ProximityEngine** (`TetherCore`): làm mượt EMA 0,7/0,3 cho từng thiết bị, hysteresis −75 / −65 dBm, mất tín hiệu quá lâu tính là xa, xa liên tục *N* giây mới khoá.
- **ScreenLocker:** khoá tức thì. Nếu sau 1 giây màn hình chưa khoá thì bật trình bảo vệ màn hình làm phương án dự phòng (cần bật “Yêu cầu mật khẩu ngay”).
- **Quét tiết kiệm:** không lấy gói trùng và khởi động lại phiên quét mỗi 1,5 giây (1 giây ở độ nhạy Rất cao), nên mỗi thiết bị chỉ báo về khoảng một lần mỗi chu kỳ.
- **Khoảng cách** hiển thị chỉ là ước lượng (−59 dBm ≈ 1 m, hệ số suy hao 2,5). Cơ thể, tường và túi quần đều làm sóng yếu đi.

## Build từ mã nguồn

```bash
cd TetherCore && swift test     # chạy unit test phần logic
cd .. && open Tether.xcodeproj  # mở project trong Xcode
scripts/make-dmg.sh             # build Release universal → build/Tether-<version>.dmg
scripts/publish-update.sh       # ký DMG cho Sparkle, ghi appcast.xml (changelog từ website) vào ../tether-website/public
```

Phát hành có ký Developer ID và notarize (để Gatekeeper không hỏi lại):

```bash
DEVELOPER_ID="Developer ID Application: Tên (TEAMID)" NOTARY_PROFILE=tether-notary scripts/make-dmg.sh
```

Phát hành một bản mới:

1. Thêm mục changelog cho phiên bản đó vào `tether-website/lib/changelog.ts`.
2. Nâng `MARKETING_VERSION` và `CURRENT_PROJECT_VERSION`, chạy `scripts/make-dmg.sh` rồi `scripts/publish-update.sh`.
3. Chép DMG vào `tether-website/public/downloads/`, sửa `lib/site.ts`, commit và push website.

> [!WARNING]
> Khoá riêng EdDSA để ký bản cập nhật nằm trong Keychain của máy phát hành. **Hãy sao lưu nó** (`generate_keys -x <file>` trong thư mục `artifacts/sparkle/Sparkle/bin` của Swift package). Mất khoá thì người dùng hiện tại không nhận được bản cập nhật nào nữa.

Xem log khi debug:

```bash
log stream --predicate 'subsystem == "com.simple.tether"' --level debug
```

### Cấu trúc dự án

| Thư mục | Nội dung |
|---|---|
| `TetherCore/` | Swift package logic thuần, có unit test: `ProximityEngine` (nhiều thiết bị, hysteresis, độ trễ), `ActiveSchedule` (lịch hoạt động), `DeskTime` (thời gian ngồi bàn, nhắc nghỉ), `RSSIHistory`, `Calibration`, `DistanceEstimate`. |
| `Tether/` | App thanh menu (`com.simple.tether`): `BluetoothService`, `ScreenLocker`, `SystemObserver`, `SettingsStore`, `LockHistory`, `DeskTimeStore`, phím tắt và đánh thức màn hình (`Automation`), thao tác cho app Phím tắt (`Intents/`) và giao diện SwiftUI. |
| `scripts/icon/` | Bộ tạo icon Liquid Glass dùng chung cho các app (`make-icon.py`), xem [`scripts/icon/README.md`](scripts/icon/README.md). |
| `scripts/dmg-art/` | Nền cửa sổ DMG (800×580) vẽ bằng HTML. Sửa `background.html` rồi chạy `render.sh` (cần Google Chrome) để xuất ảnh. |
| `scripts/make-dmg.sh` | Build Release và đóng gói DMG kéo-thả, có icon ổ đĩa và bố cục cửa sổ. |

## Yêu cầu hệ thống

- **macOS:** 13 Ventura trở lên (Apple Silicon hoặc Intel)
- **Thiết bị:** iPhone, Apple Watch hoặc AirPods đăng nhập cùng Apple ID với Mac, hoặc đã ghép đôi Bluetooth
- **Xcode:** 26 trở lên (để build từ mã nguồn, vì icon dùng định dạng Icon Composer)

## Audit và đóng góp

Mã nguồn Tether công khai để bạn tự kiểm tra: app có gửi gì ra ngoài không (gợi ý: xem `Tether.entitlements` và tìm thử `URLSession`), khoá Mac ra sao (`ScreenLocker`), quyết định khi nào khoá thế nào (`TetherCore/ProximityEngine`).

- **Báo lỗi, góp ý:** mở [Issue](https://github.com/HPhucDev/tether-app/issues) hoặc gửi mail tới [hoangphucdeveloper@gmail.com](mailto:hoangphucdeveloper@gmail.com?subject=Tether%20feedback).
- **Đóng góp code:** fork repo, chạy `cd TetherCore && swift test` cho chắc rồi gửi [Pull request](https://github.com/HPhucDev/tether-app/pulls). Mỗi PR nên gọn và nói rõ vì sao cần thay đổi.

Nếu thấy Tether hữu ích, mời mình một ly cà phê qua mã QR trong tab **Giới thiệu** của app nhé ☕

## Bản quyền

© 2026 Nguyễn Hoàng Phúc (S1mple). Mọi quyền được bảo lưu.
