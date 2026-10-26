# Armbian trên box TV "A98Max+" (Allwinner H313), bán dưới tên "Tanix TX3 mini Plus"

Chạy **Armbian từ thẻ microSD** trên một box Android có nhãn *TX3 mini Plus 2GB+16GB+2.4G+5G*. Bên trong **không phải chip Amlogic của Tanix chính hãng**
mà là **Allwinner H313** (họ H616). Repo này chứa những thứ cần để nó chạy: bản dựng bootloader, device tree, cách sửa Ethernet, driver Wi-Fi đã port, và ghi chú cách tìm ra từng lỗi.

> **Trạng thái: chạy được trên một máy (máy của tác giả).** Các box khác cùng tên có thể khác. Repo **không đụng vào eMMC** của box: rút thẻ SD ra là box vào lại Android.
> Repo không chứa image Armbian, firmware Android hay firmware Seekwave. Tự chịu rủi ro khi dùng.

## Đã kiểm tra

| Tính năng | Trạng thái | Ghi chú |
|---|---|---|
| Boot từ thẻ SD (U-Boot 2026.10 + TF-A 2.15 tự dựng) | chạy | xem [`uboot/`](uboot) |
| Màn hình console HDMI | chạy | đã thấy trên TV |
| Ethernet 100M | chạy | cần sửa xung nhịp PHY AC300: [`scripts/ac300-ephy-clk.py`](scripts/ac300-ephy-clk.py) |
| Wi-Fi 2,4 GHz (Seekwave EA6521QF) | chạy | quét, kết nối WPA2, khoảng 44 Mbit/s, tự nối lại sau khi khởi động. **Chưa thử 5 GHz** |
| Docker 29.x | chạy | đã thử `hello-world`, giới hạn RAM/pids/CPU, mạng NAT |
| Lỗi `setup TXBA failed` trong nhật ký Wi-Fi | vô hại | mỗi lần kết nối có một dòng: hai lệnh Block-Ack gửi sát nhau, lệnh thứ hai bị từ chối rồi thử lại thành công sau ~150 ms. Chi tiết trong [docs/pitfalls.md](docs/pitfalls.md) |
| Màn hình số phía trước (FD650, 4 chữ số) | chạy | hiện giờ (HHMM) bằng `scripts/fd650.py clock`, chủ máy đã xác nhận. Chưa kiểm kỹ thứ tự chữ số và dấu hai chấm nhấp nháy |
| Bluetooth, âm thanh, IR | chưa thử | |

## Cách làm lại (tóm tắt, chi tiết ở [README.md](README.md))

1. Tự tải image gốc `Armbian-unofficial_26.02.0-trunk_X96q-v1-3_bookworm_current_6.12.64_minimal.img.xz` của sicXnull (bản cộng đồng không chính thức), ghi vào thẻ **thật** (kiểm bằng `f3probe`, đừng tin dung lượng ghi trên thẻ).
2. Ghi u-boot của repo vào offset 8 KiB: `sudo dd if=u-boot-sunxi-with-spl.bin of=/dev/sdX bs=1k seek=8 conv=fsync`.
3. Tạo DTB bằng `dts/make-a98max-dtb.py`, rồi chạy `tools/patch-rootfs.sh` trên rootfs của thẻ (đã gắn trên Linux).
4. Boot có HDMI và cáp LAN. Wi-Fi là tùy chọn: dựng module bằng `wifi/build-modules.sh`, lấy 4 file firmware từ chính phân vùng Android của box ([`docs/wifi.md`](docs/wifi.md)).

`tools/patch-rootfs.sh` đã được thử trên một cây thư mục giả trong container Linux (chạy hai lần để chắc không nhân đôi cấu hình). Toàn bộ quy trình đã được làm tay trên máy thật, nhưng **chưa được chạy lại từ đầu theo đúng các bước ở trên**.

## Những bài học chính

* Ba thẻ SD thử thì hai thẻ có vấn đề (một thẻ giả dung lượng: báo 62,5 GB, thật chỉ 7,77 GB).
* U-Boot của X96Q treo vì sai PMIC (AXP305 thay vì AXP1530), sai điện áp RAM (1,2 V cho LPDDR3 thay vì 1,5 V cho DDR3) và sai chân phát hiện thẻ.
* Ethernet báo `No PHY found` vì PHY AC300 cần xung 24 MHz mà chỉ Android mới bật (PWM5 trên PA12).
* Wi-Fi không sẵn sàng vì thiếu xung 32,768 kHz trên PG10, và tên clock trong `mmc-pwrseq-simple` phải là `ext_clock`.
* Firmware Android của box tự khai là *Google Pixel 6 Pro*: đừng tin nhãn hay thông tin máy.

Chi tiết: [docs/hardware.md](docs/hardware.md), [docs/pitfalls.md](docs/pitfalls.md), [docs/wifi.md](docs/wifi.md). Giấy phép: [LICENSE](LICENSE), [NOTICE.md](NOTICE.md).
