# Bộ icon chung cho hệ sinh thái

Mọi app dùng chung một phong cách: **macOS 26 Tahoe Liquid Glass, light mode**.

- Nền: tấm kính sáng (`system-light`). macOS tự thêm viền kính, chiều sâu và bóng đổ.
- Glyph: 2–5 **mảng màu như gel**, mỗi mảng là một lớp kính riêng. Mỗi mảng có sẵn dải sáng từ trên xuống và một điểm sáng, nên vẫn trông nổi khối trên macOS cũ.
- Kết quả là một gói `.icon` (định dạng Icon Composer). Xcode 26+ build trực tiếp, và tự tạo `.icns` dự phòng cho macOS 13–15.

## Tạo icon cho app mới

1. Copy `tether.json` thành `<app>.json` và vẽ các mảng trên khung 1024×1024:

   ```json
   {
     "pieces": [
       { "name": "body", "color": "#1E7BFF", "d": "M… Z", "evenodd": true },
       { "name": "accent", "color": "#34C759", "d": "M… Z" }
     ]
   }
   ```

   Mảng đầu tiên nằm trên cùng. `evenodd` dùng để khoét lỗ (như lỗ khoá).

2. Sinh icon:

   ```bash
   python3 scripts/icon/make-icon.py scripts/icon/<app>.json <App>/AppIcon.icon
   ```

3. Trong target: đặt `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` và để `AppIcon.icon` trong thư mục nguồn của app.

## Bảng màu gợi ý

| Màu | Hex | Gợi ý dùng |
|---|---|---|
| Xanh dương | `#1E7BFF` | Mảng chính, khối lớn |
| Tím | `#7B5CFF` | Chi tiết phụ |
| Cyan | `#22C3EE` | Sóng, tín hiệu |
| Xanh lá | `#34C759` | Trạng thái tốt |
| Cam | `#FF8A1F` | Cảnh báo, nhấn |
| Hồng | `#FF4F8B` | Nhấn |

Muốn chỉnh tay (độ kính, bóng, vị trí từng mảng) thì mở file `.icon` bằng **Icon Composer** trong Xcode.
