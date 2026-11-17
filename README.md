# Website đăng ký khám bệnh EHR

Website demo localhost cho đồ án Cơ sở dữ liệu. Frontend dùng React, TypeScript và Vite; backend dùng Express, TypeScript và MySQL connection pool. Dữ liệu khoa, bác sĩ, lịch trống và kết quả đặt lịch đều được đọc hoặc ghi qua API, không hardcode dữ liệu nghiệp vụ trong giao diện.

> Chỉ sử dụng dữ liệu giả khi trình bày. Đây không phải hệ thống y tế thực tế.

## Yêu cầu

- Node.js 20.19+ hoặc 22.12+
- npm
- MySQL 8.0.16+
- Database demo `benhvien_ehr_test` có đủ 15 bảng và dữ liệu mẫu
- Database gốc `benhvien0` chỉ dùng để đối chiếu trong MySQL Workbench
- Tài khoản ứng dụng `ehr_app`, không dùng `root`

## Cài đặt

```bash
cd backend
npm install

cd ../frontend
npm install
```

Sao chép `backend/.env.example` thành `backend/.env` và tự điền mật khẩu trên máy:

```dotenv
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=benhvien_ehr_test
DB_USER=ehr_app
DB_PASSWORD=mat_khau_tren_may
```

Không commit hoặc chia sẻ file `.env`. Backend của website luôn dùng `benhvien_ehr_test`; không đổi `DB_NAME` về database gốc.

## Chạy localhost

Mở hai terminal.

Terminal 1:

```bash
cd backend
npm run dev
```

Terminal 2:

```bash
cd frontend
npm run dev
```

Mở `http://127.0.0.1:5173`. Vite chuyển tiếp các request `/api` đến backend tại `http://127.0.0.1:3000`.

## Kiểm tra build

```bash
cd backend && npm run build
cd ../frontend && npm run build
```

## API

| Method | Đường dẫn | Chức năng |
| --- | --- | --- |
| GET | `/api/health` | Kiểm tra Express |
| GET | `/api/health/db` | Kiểm tra MySQL và số bảng |
| GET | `/api/khoa` | Danh sách khoa |
| GET | `/api/khoa/:maKhoa/bac-si` | Bác sĩ đang làm việc theo khoa |
| GET | `/api/bac-si/:maBS/lich-trong?ngayHen=YYYY-MM-DD` | Số chỗ còn theo ca |
| POST | `/api/lich-hen` | Tạo bệnh nhân và lịch hẹn trong một transaction |

## Database thử nghiệm

File `benhvien_mysql/04_schema_test.sql` tạo 15 bảng, trigger, function và procedure trên database `benhvien_ehr_test`. File không chứa `DROP DATABASE`, `DROP TABLE`, `TRUNCATE` hoặc dữ liệu mẫu. Không chạy lại file khi database demo đã có bảng.

Khi cần dựng mới trên một database test rỗng:

1. Xác nhận database đích tồn tại và rỗng.
2. Xác nhận `ehr_app` có quyền cần thiết trên `benhvien_ehr_test`.
3. Kiểm tra câu `USE benhvien_ehr_test` trong file.

Không chạy `01_schema.sql` trên database đang dùng vì file đó có `DROP DATABASE benhvien0`.

## Quy trình demo trước giảng viên

1. Mở MySQL Workbench và xác nhận `benhvien0` và `benhvien_ehr_test` đều có 15 bảng.
2. Chạy backend, mở `/api/health/db` để hiển thị `totalTables: 15`.
3. Chạy frontend và mở trang tại `127.0.0.1:5173`.
4. Chọn một khoa; giao diện tải đúng bác sĩ đang làm việc từ MySQL.
5. Chọn bác sĩ và ngày khám; chỉ ra số lịch đã đặt và số chỗ còn trong ba ca.
6. Nhập thông tin bệnh nhân giả, chọn ca và xác nhận.
7. Ghi lại `MaBN`, `MaLH` trên màn hình thành công.
8. Trong Workbench, truy vấn hai mã vừa tạo ở `BenhNhan` và `LichHen` để chứng minh transaction đã lưu dữ liệu.

Ví dụ kiểm tra trong Workbench khi đang dùng database thử nghiệm:

```sql
USE benhvien_ehr_test;

SELECT bn.MaBN, bn.HoTen, lh.MaLH, lh.MaBS, lh.NgayHen, lh.Ca, lh.TrangThai
FROM BenhNhan bn
JOIN LichHen lh ON lh.MaBN = bn.MaBN
ORDER BY lh.MaLH DESC;
```

Mọi thao tác của website dùng `benhvien_ehr_test`. Giữ `benhvien0` chỉ đọc để đối chiếu dữ liệu gốc.

# Chu_de_5_mon_CSDL
