# Hướng dẫn thiết lập WireGuard Client-to-Site

Tài liệu này hướng dẫn cách sử dụng hai script setup_server.sh và setup_client.sh để thiết lập hệ thống VPN WireGuard kết nối từ máy khách (Client) về máy chủ (Server/Site).

## Yêu cầu trước khi thiết lập

1. Cả máy chủ (Server) và máy khách (Client) cần được cài đặt WireGuard.
   Ví dụ trên Ubuntu/Debian:
   sudo apt update && sudo apt install -y wireguard

2. Cấp quyền thực thi cho các script:
   chmod +x setup_server.sh setup_client.sh uninstall.sh

## Các bước thiết lập

### Bước 1: Cấu hình trên máy chủ (Server)

1. Chạy script `setup_server.sh` trên máy chủ:
   ./setup_server.sh

   Sau khi chạy, script sẽ:
   - Tạo ra các tệp khóa của Server (`server_private.key`, `server_public.key`).
   - Tạo ra cấu hình máy chủ `wg0.conf` có sẵn phần khai báo peer `Client1 EdgeNode` với IP `10.8.0.2/32` (Khóa công khai của client tạm thời được gán bằng giá trị placeholder).
   - Tự động sao chép cấu hình `wg0.conf` vào `/etc/wireguard/` và khởi động WireGuard ngay lập tức bằng quyền sudo.

2. Mở cổng (Port Forwarding) trên Modem/Router:
   - Đăng nhập vào giao diện quản lý modem/router của nhà mạng.
   - Cấu hình Port Forwarding cổng UDP 51820 trỏ về địa chỉ IP LAN của máy chủ.

### Bước 2: Cấu hình trên máy khách (Client) và đăng ký khóa

1. Chạy script `setup_client.sh` trên máy khách. Bạn truyền thêm địa chỉ IP công khai của Server, Server Public Key, và (tùy chọn) thông tin SSH để tự động đồng bộ khóa lên máy chủ:
   ./setup_client.sh <server_public_ip_or_domain> <server_public_key> [server_ssh_user] [server_ssh_port]

   Ví dụ (tự động đăng ký qua SSH):
   ./setup_client.sh 203.0.113.5 abcdef1234567890... hiengyen 22

   Sau khi chạy, script sẽ:
   - Tạo khóa và cấu hình `client_wg0.conf` mới cho máy khách sử dụng IP tĩnh `10.8.0.2/32` (và các thông số DNS=1.1.1.1, ListenPort=51820).
   - Tự động SSH vào máy chủ để thay thế khóa công khai thực tế của client vào block cấu hình `Client1 EdgeNode` đã tạo ở Bước 1 và tải lại cấu hình server.
   - Tự động sao chép file cấu hình client_wg0.conf vào thư mục `/etc/wireguard/` và kích hoạt kết nối VPN bằng quyền sudo.

### Bước 3: Đăng ký khóa thủ công (Nếu không tự động đồng bộ qua SSH ở Bước 2)

Nếu chọn không đồng bộ khóa tự động qua SSH ở Bước 2, bạn cần cập nhật thủ công trên máy chủ:
1. Quay lại máy chủ (Server), mở file cấu hình `/etc/wireguard/wg0.conf` để chỉnh sửa:
   sudo nano /etc/wireguard/wg0.conf

2. Tìm đoạn cấu hình `[Peer]` của `Client1 EdgeNode` và dán khóa công khai của client (được in ra ở cuối Bước 2) vào phần `PublicKey`:
   [Peer]
   # Client1  EdgeNode
   PublicKey  = <KHOA_CONG_KHAI_CUA_CLIENT>
   AllowedIPs = 10.8.0.2/32

3. Tải lại cấu hình trên máy chủ để áp dụng thay đổi:
   sudo wg syncconf wg0 <(sudo wg-quick strip wg0)

### Bước 4: Kiểm tra kết nối từ Client

1. Kết nối VPN đã được tự động thiết lập và chạy bằng quyền sudo.

2. Kiểm tra kết nối bằng cách ping hoặc kết nối SSH đến máy chủ thông qua địa chỉ IP VPN (10.8.0.1):
   ping 10.8.0.1
   ssh user@10.8.0.1

Để ngắt kết nối trên máy khách, dùng lệnh:
sudo wg-quick down client_wg0

## Gỡ bỏ cấu hình (Uninstall)

Để gỡ bỏ cấu hình WireGuard và xóa các tệp khóa đã tạo, bạn có thể chạy script `uninstall.sh`:
```bash
./uninstall.sh
```

Script này sẽ:
- Dừng giao diện kết nối WireGuard (cả Client hoặc Server nếu đang chạy).
- Xóa tệp cấu hình tương ứng trong `/etc/wireguard/`.
- Dọn dẹp sạch sẽ các tệp khóa (`.key`) và tệp cấu hình tạo ra trong thư mục hiện tại.
