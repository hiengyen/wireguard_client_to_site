# Hướng dẫn thiết lập WireGuard Client-to-Site

Tài liệu này hướng dẫn cách sử dụng hai script setup_server.sh và setup_client.sh để thiết lập hệ thống VPN WireGuard kết nối từ máy khách (Client) về máy chủ (Server/Site).

## Yêu cầu trước khi thiết lập

1. Cả máy chủ (Server) và máy khách (Client) cần được cài đặt WireGuard.
   Ví dụ trên Ubuntu/Debian:
   sudo apt update && sudo apt install -y wireguard

2. Cấp quyền thực thi cho các script:
   chmod +x setup_server.sh setup_client.sh

## Các bước thiết lập

### Bước 1: Cấu hình trên máy chủ (Server)

1. Chạy script setup_server.sh trên máy chủ:
   ./setup_server.sh

   Sau khi chạy, script sẽ:
   - Tạo ra các file khóa: server_private.key, server_public.key
   - Tạo ra file cấu hình: wg0.conf
   - Hiển thị khóa công khai của Server (Server Public Key) trên màn hình. Hãy lưu lại khóa này để dùng cấu hình cho máy khách.
   - Hỏi bạn có muốn tự động sao chép cấu hình vào `/etc/wireguard/` và khởi động WireGuard ngay lập tức hay không. Nếu bạn đồng ý (y), script sẽ thực hiện tự động bằng quyền sudo.

2. Mở cổng (Port Forwarding) trên Modem/Router:
   - Đăng nhập vào giao diện quản lý modem/router của nhà mạng.
   - Cấu hình Port Forwarding cổng UDP 51820 trỏ về địa chỉ IP LAN của máy chủ.

### Bước 2: Cấu hình trên máy khách (Client)

1. Chạy script setup_client.sh trên máy khách với 2 tham số: Địa chỉ IP công khai (hoặc tên miền) của máy chủ và khóa công khai của máy chủ (Server Public Key) lấy từ Bước 1.
   ./setup_client.sh <server_public_ip_or_domain> <server_public_key>

   Ví dụ:
   ./setup_client.sh 203.0.113.5 abcdef1234567890...

   Sau khi chạy, script sẽ:
   - Tạo ra các khóa cho client: client_private.key, client_public.key
   - Tạo ra file cấu hình: client_wg0.conf
   - In ra màn hình khối cấu hình dạng [Peer] chứa khóa công khai của máy khách. Hãy sao chép khối thông tin này để đăng ký với Server ở bước sau.
   - Hỏi bạn có muốn tự động sao chép file cấu hình client_wg0.conf vào thư mục `/etc/wireguard/` và kích hoạt kết nối VPN trên máy khách hay không.

### Bước 3: Đăng ký Client với Server

1. Quay lại máy chủ (Server), mở file cấu hình /etc/wireguard/wg0.conf để chỉnh sửa:
   sudo nano /etc/wireguard/wg0.conf

2. Dán đoạn cấu hình [Peer] của Client (vừa copy ở cuối Bước 2) vào cuối file:
   [Peer]
   PublicKey = <KHOA_CONG_KHAI_CUA_CLIENT>
   AllowedIPs = 10.8.0.2/32

3. Lưu file và tải lại cấu hình trên máy chủ để áp dụng thay đổi:
   sudo wg-quick down wg0
   sudo wg-quick up wg0

### Bước 4: Kiểm tra kết nối từ Client

1. Nếu bạn đã chọn tự động kích hoạt kết nối ở Bước 2, kết nối VPN đã được thiết lập.
   Nếu chưa, bạn có thể thực hiện thủ công:
   sudo cp client_wg0.conf /etc/wireguard/
   sudo wg-quick up client_wg0

2. Kiểm tra kết nối bằng cách ping hoặc kết nối SSH đến máy chủ thông qua địa chỉ IP VPN (10.8.0.1):
   ping 10.8.0.1
   ssh user@10.8.0.1

Để ngắt kết nối trên máy khách, dùng lệnh:
sudo wg-quick down client_wg0
