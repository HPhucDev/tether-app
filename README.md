# Tether

Mang iPhone, Apple Watch hoặc AirPods đi xa khỏi Mac thì Mac tự khoá màn hình. Không cần cài app gì lên thiết bị. Chỉ khoá, không tự mở khoá.

## Cấu trúc

| Thư mục | Nội dung |
|---|---|
| `TetherCore/` | Swift package logic thuần: `ProximityEngine` (nhiều thiết bị, hysteresis, độ trễ), `RSSIHistory`, `Calibration`, `DistanceEstimate` (dBm → mét). Có unit test. |
| `Tether/` | App thanh menu macOS 13+ (`com.simple.tether`): `BluetoothService`, `ScreenLocker`, `SystemObserver`, `SettingsStore`, UI. |
| `scripts/icon/` | Bộ tạo icon Liquid Glass light dùng chung cho hệ sinh thái (`make-icon.py` + `tether.json`), xem `scripts/icon/README.md`. |
| `scripts/render-art.swift` | Vẽ nền DMG. |
| `scripts/make-dmg.sh` | Build Release universal và đóng gói DMG kéo-thả. |

## Chạy và đóng gói

```bash
cd TetherCore && swift test        # test logic
scripts/make-dmg.sh                # → build/Tether-<version>.dmg
```

Phát hành công khai (để Gatekeeper không chặn):

```bash
DEVELOPER_ID="Developer ID Application: Tên (TEAMID)" NOTARY_PROFILE=tether-notary scripts/make-dmg.sh
```

Không có Developer ID thì app chỉ ký ad-hoc: người dùng phải vào Cài đặt hệ thống › Quyền riêng tư & Bảo mật › "Vẫn mở" lần đầu.

Xem log:

```bash
log stream --predicate 'subsystem == "com.simple.tether"' --level debug
```

## Cách hoạt động

- **Theo dõi thụ động**: iPhone và Watch luôn tự phát gói Bluetooth (Handoff, AirDrop…). Mac nghe các gói đó và đo độ mạnh sóng (RSSI). Không kết nối, không cần app.
- **Tiết kiệm CPU**: quét không lấy gói trùng (bộ điều khiển Bluetooth tự lọc) và khởi động lại phiên quét mỗi 1,5 s, nên mỗi thiết bị chỉ báo về khoảng một lần mỗi chu kỳ.
- **Danh sách thiết bị** chỉ hiện thiết bị cùng Apple ID (macOS biết tên thật dù gói không chứa tên) hoặc đã ghép đôi Bluetooth.
- **Nhận lại thiết bị** theo tên khi mã Bluetooth đổi.
- **ProximityEngine**: EMA 0.7/0.3 cho từng thiết bị, hysteresis −75/−65 dBm, mất tín hiệu > 10 s tính là xa, xa liên tục N giây mới khoá. Hai thiết bị: khoá khi cả hai đi xa (mặc định) hoặc một trong hai.
- **Khoá**: `SACLockScreenImmediate` (private). Nếu sau 1 giây màn hình chưa khoá thì bật trình bảo vệ màn hình (khoá khi bật "Yêu cầu mật khẩu ngay").
- **Pin**: ngừng quét hoàn toàn khi màn hình đang khoá hoặc Mac sleep.
- **Lịch sử khoá**: 50 lần gần nhất, lưu trong UserDefaults của máy (tab Lịch sử).

## Quyền riêng tư

- App Sandbox bật, entitlements chỉ có `com.apple.security.device.bluetooth` (xem `Tether.entitlements`). Không có quyền mạng nên macOS chặn mọi kết nối.
- Không analytics, không telemetry, không cloud. Kiểm chứng: Activity Monitor › Network.
- Bản Release không có `get-task-allow`, sẵn sàng notarize.
- **Số mét** chỉ là ước lượng (−59 dBm ≈ 1 m, hệ số suy hao 2,5).
