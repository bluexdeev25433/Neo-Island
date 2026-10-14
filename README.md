# Neo Island

## Mục lục

- [Giới thiệu](#giới-thiệu)
- [Trước khi cài đặt](#trước-khi-cài-đặt)
- [Cài đặt](#cài-đặt)
- [Sử dụng](#sử-dụng)
- [Khắc phục sự cố](#khắc-phục-sự-cố)
- [Gỡ cài đặt](#gỡ-cài-đặt)
- [Build và kiểm thử](#build-và-kiểm-thử)
- [Quyền riêng tư](#quyền-riêng-tư)
- [Điều khoản sử dụng](#điều-khoản-sử-dụng)
- [Giấy phép và bản quyền](#giấy-phép-và-bản-quyền)
- [Phiên bản và hỗ trợ](#phiên-bản-và-hỗ-trợ)

## Giới thiệu

Neo Island là tweak jailbreak tạo pill mô phỏng Dynamic Island trên một số iPhone đời cũ. Tweak có thể hiển thị thông tin nhạc, pin, âm lượng, kết nối âm thanh, trạng thái kết nối mạng, hẹn giờ riêng và văn bản tùy chỉnh. Đây là giao diện mô phỏng; Neo Island không thay thế Dynamic Island hoặc Live Activities của Apple.

Phiên bản mã nguồn hiện đặt mục tiêu iOS 15.0 trở lên. Một số mã định danh iPhone 8 đến iPhone 14 được nhận diện; thiết bị có Dynamic Island nguyên bản và thiết bị không nhận diện được sẽ bị bỏ qua mặc định. Danh sách này chưa được kiểm chứng trên thiết bị thực.

| Môi trường | Trạng thái xác minh |
|---|---|
| Rootful | Build/package đã xác minh trong container Ubuntu; chưa cài trên thiết bị |
| Rootless | Build/package đã xác minh trong container Ubuntu; chưa cài trên thiết bị |
| iOS 15 trở lên | Mức phiên bản mục tiêu; chưa xác minh tương thích thực tế theo từng phiên bản |

Release `v1.1.0` đã được publish với gói Rootful, Rootless, source archive và SHA-256. CI đã build và kiểm tra metadata, install paths cùng arm64/arm64e. Các gói chưa được cài hoặc kiểm thử runtime trên iPhone.

Phiên bản mới nhất là `1.1.0`. Bản này bổ sung state manager cho chế độ hiển thị, cập nhật volume theo sự kiện, khôi phục trạng thái timer khi ứng dụng hoạt động lại và nhận diện một số tuyến âm thanh ngoài. Việc kiểm thử runtime trên iPhone vẫn chưa thực hiện.

## Website và Sileo

- Website: [Neo Island](https://bluexdeev25433.github.io/Neo-Island/).
- Sileo/APT source: `https://bluexdeev25433.github.io/Neo-Island/repo/`.
- [GitHub Release v1.1.0](https://github.com/bluexdeev25433/Neo-Island/releases/tag/v1.1.0) có hai gói cài đặt, source archive và SHA-256.
- APT `Release` và hai architecture indexes đã được đọc bằng `apt-get`; chưa thử add source trực tiếp trong ứng dụng Sileo.

## Trước khi cài đặt

- Cần iPhone đã jailbreak, chạy iOS 15 trở lên và thuộc nhóm thiết bị được nhận diện. Tweak không hỗ trợ iPad.
- Bootstrap jailbreak phải tương thích với MobileSubstrate hoặc ElleKit và có PreferenceLoader. Tên/gói dependency có thể khác tùy môi trường jailbreak.
- Chỉ cài gói `.deb` được tạo cho đúng loại jailbreak đang dùng. Gói Rootless và Rootful không thể thay thế lẫn nhau.
- Chưa có tổ hợp thiết bị, phiên bản iOS, jailbreak hoặc bootstrap nào được xác minh bằng cài đặt thực tế. Hãy chuẩn bị cách vào Safe Mode hoặc quy trình recovery của jailbreak trước khi thử.

## Cài đặt

Gói cài đặt chỉ được cung cấp qua release có checksum sau khi workflow build và kiểm tra cấu trúc hoàn tất; đây không phải chứng nhận đã thử trên thiết bị. Khi cài trên thiết bị thử nghiệm:

1. Xác định jailbreak của thiết bị là Rootful hay Rootless.
2. Chọn đúng gói `com.neoisland.tweak_1.1.0_iphoneos-arm.deb` (Rootful) hoặc `com.neoisland.tweak_1.1.0_iphoneos-arm64.deb` (Rootless); không cài gói của loại jailbreak còn lại.
3. Chuyển gói vào thiết bị và cài bằng trình quản lý gói jailbreak; xác nhận các dependency được yêu cầu.
4. Respring nếu trình quản lý gói yêu cầu hoặc nếu giao diện chưa cập nhật.
5. Mở ứng dụng **Cài đặt** và chọn **Dynamic Island**.

## Sử dụng

### Pill và thao tác

Chạm hoặc nhấn giữ pill để mở rộng/thu gọn. Renderer chọn compact, expanded, minimal hoặc activity từ state và dữ liệu module; notification mode chỉ có giao diện state, chưa có provider notification. Khi có nhiều trạng thái khả dụng, vuốt ngang để chuyển theo định danh module ổn định, tránh nhảy selection khi dữ liệu refresh. Pill tự thu gọn theo thời gian đã đặt; đặt thời gian tự thu gọn về `0` để tắt hành vi này. Cử chỉ chỉ được xử lý trong vùng pill.

### Module

Trong **Cài đặt > Dynamic Island**, bật hoặc tắt từng module:

| Module | Cách hoạt động và giới hạn |
|---|---|
| Nhạc | Hiển thị tên bài, nghệ sĩ và ảnh bìa khi trình phát cung cấp metadata. Mở rộng pill để phát/tạm dừng hoặc chuyển bài. Điều khiển được gửi tới trình phát hệ thống; ứng dụng phát nhạc bên thứ ba có thể không nhận lệnh. |
| Music Pill | Là trạng thái nhạc trong pill mô phỏng, không phải Dynamic Island gốc. Không có metadata thì module không hiện. |
| Pin | Hiển thị phần trăm và trạng thái sạc khi thiết bị cung cấp dữ liệu. |
| Cảnh báo pin 20% | Khi mức pin được quan sát chuyển từ trên 20% xuống 20% hoặc thấp hơn, pill hiển thị nhắc nhở trong khoảng 8 giây. Cảnh báo được khóa lặp cho tới khi pin vượt 22%. Bật tweak khi pin đã thấp không tự tạo cảnh báo chuyển ngưỡng. Đây là nhắc nhở trong pill, không phải thông báo iOS. |
| Âm lượng | Chỉ đọc mức âm lượng đầu ra; không thay đổi âm lượng. Thay đổi âm lượng được theo dõi để làm mới module. |
| Kết nối mạng | Hiển thị trạng thái reachability tổng quát; không xác định chính xác tên Wi-Fi hoặc loại kết nối trong mọi trường hợp. Khi không có dữ liệu, module bị ẩn. |
| Tuyến âm thanh | Hiển thị tuyến Bluetooth, tai nghe có dây, AirPlay hoặc car audio khi hệ thống cung cấp. Không đọc mức pin từng bên AirPods. |
| Hẹn giờ Neo Island | Đặt thời lượng rồi chọn **Start timer**. Có thể tạm dừng, tiếp tục hoặc hủy trong Cài đặt; khi pill mở rộng có thể tạm dừng/tiếp tục. Hẹn giờ có mốc thời gian lưu qua respring nhưng không kết nối ứng dụng Đồng hồ, không phát chuông báo và có thể bị ảnh hưởng nếu đổi giờ hệ thống. |
| Văn bản tùy chỉnh | Bật module và nhập nội dung. Nội dung trống sẽ không hiển thị. |
| Pill nhàn rỗi | **Always show idle pill** giữ pill trên màn hình ngay cả khi không có module dữ liệu. Tắt để ẩn pill khi không có hoạt động. |

Chế độ chuông/im lặng, đèn pin, quay màn hình, cuộc gọi đến, nội dung thông báo, điều hướng và Live Activities chưa được hỗ trợ; hiện không có công tắc điều khiển các chức năng này. Neo Island không tích hợp hẹn giờ của ứng dụng Đồng hồ.

### Màn hình khóa

**Show on Lock Screen** cho phép hiển thị pill khi thiết bị bị khóa theo tín hiệu bảo vệ dữ liệu của iOS. Hành vi này chưa được kiểm tra trên thiết bị thực. Thông tin nhạc nhạy cảm bị ẩn khi dữ liệu được bảo vệ, trừ khi người dùng bật **Allow sensitive metadata while locked**. Tùy chọn này làm lộ metadata trên màn hình khóa; chỉ bật khi phù hợp.

**Force overlay on unrecognized hardware** bỏ qua kiểm tra mã thiết bị đã nhận diện. Tùy chọn này có thể làm pill chồng lên giao diện hệ thống, đặc biệt trên iPhone có Dynamic Island; chỉ dùng khi chủ động thử nghiệm.

### Thanh trượt

Thay đổi được lưu tự động và áp dụng ngay. Kích thước/vị trí được giới hạn trong vùng màn hình khả dụng.

| Thanh trượt | Ý nghĩa | Phạm vi, mặc định |
|---|---|---|
| Timer duration (minutes) | Thời lượng khi bắt đầu hẹn giờ | 1–180 phút, mặc định 5 |
| Pill width | Chiều rộng pill khi thu gọn | 120–320 điểm, mặc định 180 |
| Pill height | Chiều cao pill khi thu gọn | 36–100 điểm, mặc định 48 |
| Content size | Tỷ lệ cỡ chữ trong pill | 0,7–1,5, mặc định 1 |
| Horizontal offset | Dịch pill sang trái/phải | −100 đến 100 điểm, mặc định 0 |
| Vertical offset | Dịch pill theo chiều dọc so với vùng an toàn | −20 đến 100 điểm, mặc định 8 |
| Open/close speed | Thời lượng chuyển động mở/đóng | 0,08–1,2 giây, mặc định 0,32 |
| Spring bounce | Độ nảy của chuyển động; giá trị thấp hơn nảy rõ hơn | 0,45–1, mặc định 0,78 |
| Auto-collapse seconds | Thời gian trước khi pill thu gọn; `0` tắt tự thu gọn | 0–30 giây, mặc định 5 |

Chọn **Restore defaults** để đặt lại công tắc, thanh trượt, widget và trạng thái timer về mặc định. Việc đặt lại không xóa ứng dụng Neo Island.

## Khắc phục sự cố

**Pill không xuất hiện:** kiểm tra **Enabled**, thiết bị iPhone và phiên bản iOS; xác nhận đã cài đúng loại gói và respring. iPhone có Dynamic Island nguyên bản cùng model chưa nhận diện bị bỏ qua mặc định. Có thể thử Force overlay, nhưng tùy chọn này có nguy cơ chồng giao diện.

**Một module không hoạt động:** module chỉ hiện khi có dữ liệu thật. Kiểm tra trình phát có đang cung cấp metadata, thiết bị có báo mức pin, tai nghe có đang là đầu ra âm thanh, hoặc thiết bị có kết nối mạng. Một số trình phát bên thứ ba không nhận lệnh điều khiển.

**Cài đặt không được lưu:** thoát rồi mở lại trang **Dynamic Island**, kiểm tra tweak đã bật và thử respring. Nếu vẫn lỗi, khôi phục mặc định rồi cấu hình lại.

**Giao diện lệch hoặc chồng lấn:** dùng các thanh trượt vị trí/kích thước hoặc chọn **Restore defaults**. Tắt Force overlay nếu đang dùng trên phần cứng Dynamic Island.

**SpringBoard gặp sự cố:** vào Safe Mode theo hướng dẫn của jailbreak, tắt hoặc gỡ Neo Island bằng trình quản lý gói rồi respring. Nếu không vào được Safe Mode, làm theo quy trình recovery/disable-tweaks của jailbreak; không xóa file hệ thống thủ công.

## Gỡ cài đặt

Gỡ **Neo Island** bằng trình quản lý gói jailbreak. Không cần xóa file hệ thống thủ công.

Các tùy chọn, văn bản widget, trạng thái ngưỡng pin và dữ liệu timer được lưu trong cài đặt ứng dụng trên thiết bị. Gói hiện không có bước tự xóa dữ liệu này khi gỡ, nên một phần cài đặt có thể còn lại. Muốn đặt lại trước khi gỡ, dùng **Restore defaults** trong trang Cài đặt; thao tác này đặt dữ liệu về mặc định chứ không xóa thủ công tệp cấu hình.

## Build và kiểm thử

Phần này dành cho người đóng gói Neo Island. Cần Theos, iPhoneOS SDK 16.5 (mục tiêu triển khai trong Makefile là iOS 15.0), cross-compiler iOS phù hợp arm64/arm64e, `ldid`, `fakeroot`, `dpkg-deb`, clang, make, perl, rsync, zip và libxml2. Workflow GitHub Actions cài các dependency này trên Ubuntu 24.04.

Build Rootful:

```sh
make clean package FINALPACKAGE=1
```

Build Rootless:

```sh
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

Gói nằm trong `packages/`. Trước khi cài, kiểm tra metadata và nội dung bằng `dpkg-deb -f <goi.deb> Package Version Architecture Depends` và `dpkg-deb -c <goi.deb>`. Gói Rootless phải đặt nội dung dưới `var/jb/`; không cài nhầm loại gói. CI chạy test, build riêng hai scheme, xác minh install paths/architecture và lưu log làm artifact.

Phiên bản rootless đang được build bằng clang 19 từ bản phát hành prerelease của toolchain Linux iOS. Build đã thành công trong container này, nhưng toolchain prerelease và PreferenceLoader/private Preferences framework vẫn cần được kiểm tra trên jailbreak thực tế trước khi phát hành rộng.

## Quyền riêng tư

Neo Island đọc metadata/ảnh bìa trình phát đang hoạt động, mức và trạng thái pin, mức âm lượng đầu ra, tên tuyến âm thanh, trạng thái reachability tổng quát, trạng thái bảo vệ dữ liệu của thiết bị và văn bản widget do người dùng nhập. Tweak lưu tùy chọn, nội dung widget, mốc thời gian/trạng thái timer và thông tin tối thiểu để tránh lặp cảnh báo pin trên thiết bị.

Đã rà soát mã nguồn hiện tại: không thấy chức năng gửi dữ liệu tới máy chủ, gọi địa chỉ web hoặc tải nội dung từ xa. Module kết nối chỉ đọc trạng thái kết nối do hệ thống cung cấp. Chẩn đoán được ghi trên thiết bị ở mức thông báo bật/tắt chung, không kèm metadata nhạc hay văn bản widget. Không có tài khoản, phân tích sử dụng hoặc đồng bộ đám mây trong phiên bản này.

## Điều khoản sử dụng

Neo Island dành cho thiết bị đã jailbreak. Người dùng tự chịu trách nhiệm về việc cài đặt, cấu hình và rủi ro đối với thiết bị; không bảo đảm tweak tương thích với mọi thiết bị, bản iOS, jailbreak hoặc bootstrap. Không sử dụng Neo Island để gây hại, xâm phạm quyền riêng tư hoặc phá hoại thiết bị của người khác. Neo Island không phải sản phẩm chính thức, không được Apple tài trợ hoặc chứng nhận. Trách nhiệm pháp lý được áp dụng theo giấy phép và quy định hiện hành tại nơi sử dụng.

## Giấy phép và bản quyền

Dự án sử dụng giấy phép MIT theo tệp [LICENSE](LICENSE). Tệp giấy phép ghi bản quyền năm 2026 thuộc `bluexdeev25433`. Không có thông tin đơn vị hỗ trợ hoặc thỏa thuận bảo hành riêng được công bố.

## Phiên bản và hỗ trợ

- Phiên bản source: **1.1.0**.
- Website: **https://bluexdeev25433.github.io/Neo-Island/**. Sileo source: **https://bluexdeev25433.github.io/Neo-Island/repo/**.
- Release: [Neo Island v1.1.0](https://github.com/bluexdeev25433/Neo-Island/releases/tag/v1.1.0), gồm Rootful/Rootless `.deb`, source ZIP và SHA-256.
- Nhật ký thay đổi: **1.1.0** — tách quản lý trạng thái khỏi renderer, thêm các mode compact/expanded/minimal/activity/notification, chuyển lựa chọn module sang định danh ổn định, thêm material và kích thước theo mode, làm mới volume theo sự kiện, khôi phục timer theo sự kiện foreground/đổi giờ và nhận diện tuyến AirPlay/car audio.
- Nhật ký thay đổi: **1.0.1** — sửa timer tự dừng tại deadline, hủy state khi tắt module, sửa lỗi compile Darwin notification/KVC/UI, chuẩn hóa quyền package staging và thêm CI build Rootful/Rootless.
- Rootful và Rootless: Theos CI đã build và kiểm tra metadata, install paths, cùng arm64/arm64e cho source `1.1.0`; chưa cài lên thiết bị.
- Tương thích runtime theo thiết bị/iOS: **chưa xác minh**. Target deployment là iOS 15.0; không có tuyên bố thiết bị/iOS đã test.
- Chưa có kênh hỗ trợ chính thức được cung cấp. Các chức năng chưa hỗ trợ được liệt kê trong mục [Sử dụng](#sử-dụng).