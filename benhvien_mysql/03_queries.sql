-- =====================================================================
-- 03_queries.sql | 8 truy van - Quan ly Benh vien & EHR
-- DBMS: MySQL 8.0.16+ (can CTE + window function)
-- Thu tu chay: 01_schema.sql -> 02_data.sql (hoac gen_data.py) -> 03_queries.sql
-- Cac moc "thang vua qua" / "trong nam" tinh dong theo CURDATE().
-- Ten khoa dung LIKE '%xuong khop%' de chay duoc ca voi 02_data.sql ("Co xuong khop")
-- lan gen_data.py ("Xuong khop").
-- =====================================================================
USE benhvien0;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- Q1 (Co ban): Benh nhan nhap vien voi chan doan ban dau chua "Sot xuat huyet"
-- ---------------------------------------------------------------------
SELECT bn.MaBN, bn.HoTen, bn.GioiTinh, k.TenKhoa,
       nv.MaNV, nv.NgayVao, nv.NgayRa, nv.TrangThai, nv.ChanDoanBanDau
FROM NhapVien nv
JOIN BenhNhan bn ON bn.MaBN   = nv.MaBN
JOIN Khoa     k  ON k.MaKhoa  = nv.MaKhoa
WHERE nv.ChanDoanBanDau LIKE '%Sốt xuất huyết%'
ORDER BY nv.NgayVao DESC;

-- ---------------------------------------------------------------------
-- Q2 (Inner Join): Don thuoc chi tiet cua ca kham KB1002
-- ---------------------------------------------------------------------
SELECT d.MaDon, t.TenThuoc, ct.LieuDung, ct.CachDung,
       ct.SoLuong, ct.DonGiaKe, ct.TienThuoc
FROM CaKham ck
JOIN DonThuoc        d  ON d.MaCaKham = ck.MaCaKham
JOIN ChiTietDonThuoc ct ON ct.MaDon   = d.MaDon
JOIN Thuoc           t  ON t.MaThuoc  = ct.MaThuoc
WHERE ck.MaCaKham = 'KB1002'
ORDER BY t.TenThuoc;

-- ---------------------------------------------------------------------
-- Q3 (Group By): Tong vien phi thu duoc theo tung Khoa trong THANG VUA QUA
-- (thang lich truoc thang hien tai; khoa = khoa cua bac si thuc hien ca kham)
-- ---------------------------------------------------------------------
SELECT k.MaKhoa, k.TenKhoa,
       COUNT(hd.MaHD)        AS SoHoaDon,
       SUM(hd.TongTien)      AS TongVienPhi,
       SUM(hd.BHYTChiTra)    AS BHYTChiTra,
       SUM(hd.BenhNhanTra)   AS BenhNhanTra
FROM HoaDon hd
JOIN CaKham ck ON ck.MaCaKham = hd.MaCaKham
JOIN BacSi  bs ON bs.MaBS     = ck.MaBS
JOIN Khoa   k  ON k.MaKhoa    = bs.MaKhoa
WHERE hd.TrangThai = 'DaThanhToan'
  AND hd.NgayThanhToan >= CAST(DATE_FORMAT(CURDATE() - INTERVAL 1 MONTH, '%Y-%m-01') AS DATE)
  AND hd.NgayThanhToan <  CAST(DATE_FORMAT(CURDATE(), '%Y-%m-01') AS DATE)
GROUP BY k.MaKhoa, k.TenKhoa
ORDER BY TongVienPhi DESC;

-- ---------------------------------------------------------------------
-- Q4 (Having): Bac si kham > 50 ca trong thang vua qua
--              va thoi gian kham trung binh / benh nhan < 10 phut
-- ---------------------------------------------------------------------
SELECT bs.MaBS, bs.HoTen, k.TenKhoa,
       COUNT(*) AS SoCaKham,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, TIMESTAMP(ck.NgayKham, ck.GioBatDau),
                                        TIMESTAMP(ck.NgayKham, ck.GioKetThuc))), 2) AS PhutTrungBinh
FROM CaKham ck
JOIN BacSi bs ON bs.MaBS  = ck.MaBS
JOIN Khoa  k  ON k.MaKhoa = bs.MaKhoa
WHERE ck.NgayKham >= CAST(DATE_FORMAT(CURDATE() - INTERVAL 1 MONTH, '%Y-%m-01') AS DATE)
  AND ck.NgayKham <  CAST(DATE_FORMAT(CURDATE(), '%Y-%m-01') AS DATE)
GROUP BY bs.MaBS, bs.HoTen, k.TenKhoa
HAVING COUNT(*) > 50
   AND AVG(TIMESTAMPDIFF(MINUTE, TIMESTAMP(ck.NgayKham, ck.GioBatDau),
                                 TIMESTAMP(ck.NgayKham, ck.GioKetThuc))) < 10
ORDER BY SoCaKham DESC;

-- ---------------------------------------------------------------------
-- Q5 (Outer Join): Moi thuoc trong kho + so lan duoc ke don
--                  (ke ca thuoc chua tung duoc ke -> SoLanKe = 0)
-- ---------------------------------------------------------------------
SELECT t.MaThuoc, t.TenThuoc, t.SoLuongTon,
       COUNT(ct.MaDon)                 AS SoLanKe,
       COALESCE(SUM(ct.SoLuong), 0)    AS TongSoLuongDaKe
FROM Thuoc t
LEFT JOIN ChiTietDonThuoc ct ON ct.MaThuoc = t.MaThuoc
GROUP BY t.MaThuoc, t.TenThuoc, t.SoLuongTon
ORDER BY SoLanKe ASC, t.MaThuoc;

-- ---------------------------------------------------------------------
-- Q6 (Correlated Subquery): Benh nhan co SO LAN TAI KHAM CAO NHAT trong nam
--     tai khoa "Noi tieu hoa". "Trong nam" = 12 thang gan nhat (rolling),
--     de khong mat du lieu cuoi nam truoc khi chay vao dau nam.
--     NOT EXISTS tham chieu tk.SoLan cua dong ngoai => truy van tuong quan.
-- ---------------------------------------------------------------------
WITH tk AS (
    SELECT ba.MaBN, COUNT(*) AS SoLan
    FROM CaKham ck
    JOIN BenhAn ba ON ba.MaBA  = ck.MaBA
    JOIN BacSi  bs ON bs.MaBS  = ck.MaBS
    JOIN Khoa   k  ON k.MaKhoa = bs.MaKhoa
    WHERE k.TenKhoa = 'Nội tiêu hóa'
      AND ck.LoaiKham = 'TaiKham'
      AND ck.NgayKham >= CURDATE() - INTERVAL 1 YEAR
    GROUP BY ba.MaBN
)
SELECT bn.MaBN, bn.HoTen, tk.SoLan AS SoLanTaiKham
FROM tk
JOIN BenhNhan bn ON bn.MaBN = tk.MaBN
WHERE NOT EXISTS (SELECT 1 FROM tk t2 WHERE t2.SoLan > tk.SoLan)
ORDER BY bn.MaBN;

-- ---------------------------------------------------------------------
-- Q7 (Subquery voi IN): Benh nhan da tung kham tai CA HAI khoa
--                       "Tim mach" va "Xuong khop"
-- ---------------------------------------------------------------------
SELECT bn.MaBN, bn.HoTen, bn.NgaySinh, bn.GioiTinh
FROM BenhNhan bn
WHERE bn.MaBN IN (SELECT ba.MaBN
                  FROM CaKham ck
                  JOIN BenhAn ba ON ba.MaBA  = ck.MaBA
                  JOIN BacSi  bs ON bs.MaBS  = ck.MaBS
                  JOIN Khoa   k  ON k.MaKhoa = bs.MaKhoa
                  WHERE k.TenKhoa = 'Tim mạch')
  AND bn.MaBN IN (SELECT ba.MaBN
                  FROM CaKham ck
                  JOIN BenhAn ba ON ba.MaBA  = ck.MaBA
                  JOIN BacSi  bs ON bs.MaBS  = ck.MaBS
                  JOIN Khoa   k  ON k.MaKhoa = bs.MaKhoa
                  WHERE k.TenKhoa LIKE '%xương khớp%')
ORDER BY bn.MaBN;

-- ---------------------------------------------------------------------
-- Q8 (Window Functions): So ngay trung binh giua cac lan kham lien tiep
--     cua tung benh nhan MAN TINH (theo tung benh man tinh cua ho).
--     LAG lay ngay kham ngay truoc do; DATEDIFF tinh khoang cach.
-- ---------------------------------------------------------------------
WITH luot AS (
    SELECT ba.MaBN, ba.MaBenh, ck.MaCaKham, ck.NgayKham,
           LAG(ck.NgayKham) OVER (PARTITION BY ba.MaBN, ba.MaBenh
                                  ORDER BY ck.NgayKham, ck.MaCaKham) AS NgayKhamTruoc
    FROM CaKham ck
    JOIN BenhAn      ba ON ba.MaBA    = ck.MaBA
    JOIN DanhMucBenh d  ON d.MaBenh   = ba.MaBenh
    WHERE d.LaManTinh = TRUE
)
SELECT bn.MaBN, bn.HoTen, d.TenBenh,
       COUNT(*)                                          AS SoKhoangCach,
       ROUND(AVG(DATEDIFF(l.NgayKham, l.NgayKhamTruoc)), 1) AS SoNgayTrungBinh
FROM luot l
JOIN BenhNhan    bn ON bn.MaBN  = l.MaBN
JOIN DanhMucBenh d  ON d.MaBenh = l.MaBenh
WHERE l.NgayKhamTruoc IS NOT NULL
GROUP BY bn.MaBN, bn.HoTen, d.MaBenh, d.TenBenh
ORDER BY SoNgayTrungBinh, bn.MaBN;
