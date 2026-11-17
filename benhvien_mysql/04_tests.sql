-- =====================================================================
-- 04_tests.sql | Kich ban kiem thu rang buoc de demo truc tiep
-- Chay SAU 01_schema.sql + 02_data.sql (hoac du lieu gen_data.py).
--
-- CACH CHAY: chay TUNG CAU (Ctrl+Enter trong Workbench) de thay loi cua tung cau vi pham.
-- Neu chay ca file: Workbench/mysql se dung o cau loi dau tien. Voi mysql CLI dung:
--     mysql -u root -p --force --default-character-set=utf8mb4 benhvien0 < 04_tests.sql
-- Cac cau [OK] phai thanh cong, cac cau [LOI] phai bi chan (ghi ma loi mong doi).
--
-- PHAN A (muc 1-6) chay trong 1 transaction va ROLLBACK o cuoi => khong lam ban du lieu.
-- PHAN B (muc 7) goi sp_LapHoaDon (thu tuc tu COMMIT) => tu don dep bang DELETE.
-- Du lieu test dung ma bat dau bang TEST / TL / TESTHD; BN, bac si, thuoc lay dong tu du lieu co san.
-- =====================================================================
USE benhvien0;
SET NAMES utf8mb4;

-- ---- Bien dung chung (lay dong de chay duoc voi moi bo du lieu) ----
SET @bn      = (SELECT MaBN FROM BenhNhan ORDER BY MaBN LIMIT 1);
SET @bs      = (SELECT MaBS FROM BacSi WHERE TrangThai = 'DangLamViec' ORDER BY MaBS LIMIT 1);
SET @bs_nghi = (SELECT MaBS FROM BacSi WHERE TrangThai <> 'DangLamViec' ORDER BY MaBS LIMIT 1);
SET @ba      = (SELECT MaBA FROM BenhAn ORDER BY MaBA LIMIT 1);
SET @thuoc1  = (SELECT MaThuoc FROM Thuoc WHERE SoLuongTon > 50 ORDER BY MaThuoc LIMIT 1);
SET @thuoc2  = (SELECT MaThuoc FROM Thuoc WHERE SoLuongTon > 50 AND MaThuoc <> @thuoc1 ORDER BY MaThuoc LIMIT 1);
SELECT @bn AS BN, @bs AS BS_DangLamViec, @bs_nghi AS BS_TamNghi_NghiViec, @ba AS BenhAn, @thuoc1 AS Thuoc1, @thuoc2 AS Thuoc2;
-- (Neu @bs_nghi la NULL: hay doi 1 bac si sang TamNghi truoc: UPDATE BacSi SET TrangThai='TamNghi' WHERE MaBS='BS024';)

-- =====================================================================
-- PHAN A
-- =====================================================================
START TRANSACTION;

-- ---------------------------------------------------------------------
-- 1. NgayKham <= ngay hien tai  (trigger trg_CaKham_bi / trg_CaKham_bu)
-- ---------------------------------------------------------------------
-- [OK] Kham hom nay (bien hop le)
INSERT INTO CaKham (MaCaKham, MaBA, MaBS, MaLH, NgayKham, GioBatDau, GioKetThuc, LoaiKham, TrieuChung, KetLuan)
VALUES ('TESTCK01', @ba, @bs, NULL, CURDATE(), '08:00:00', '08:10:00', 'LanDau', 'Test hop le', 'Test');
SELECT MaCaKham, NgayKham FROM CaKham WHERE MaCaKham = 'TESTCK01';

-- [LOI] Kham vao ngay mai -> 1644 'NgayKham khong duoc lon hon ngay hien tai'
INSERT INTO CaKham (MaCaKham, MaBA, MaBS, MaLH, NgayKham, GioBatDau, GioKetThuc, LoaiKham, TrieuChung, KetLuan)
VALUES ('TESTCK02', @ba, @bs, NULL, CURDATE() + INTERVAL 1 DAY, '08:00:00', '08:10:00', 'LanDau', 'Test vi pham', 'Test');

-- [LOI] Sua ngay kham thanh tuong lai -> 1644 (trigger BEFORE UPDATE)
UPDATE CaKham SET NgayKham = CURDATE() + INTERVAL 1 DAY WHERE MaCaKham = 'TESTCK01';

-- ---------------------------------------------------------------------
-- 2. SoLuong ke > 0  (CHECK chk_CTDT_SoLuong)
-- ---------------------------------------------------------------------
INSERT INTO DonThuoc (MaDon, MaCaKham, NgayKe, LoiDan) VALUES ('TESTDT01', 'TESTCK01', CURDATE(), 'Test');

-- [OK] SoLuong = 5 (DonGiaKe = 0 -> trigger tu lay gia tu bang Thuoc)
INSERT INTO ChiTietDonThuoc (MaDon, MaThuoc, SoLuong, LieuDung, CachDung, DonGiaKe)
VALUES ('TESTDT01', @thuoc1, 5, '1 viên x 2 lần/ngày', 'Uống sau ăn', 0);
SELECT MaDon, MaThuoc, SoLuong, DonGiaKe, TienThuoc FROM ChiTietDonThuoc WHERE MaDon = 'TESTDT01';

-- [LOI] SoLuong = 0 -> 3819 Check constraint 'chk_CTDT_SoLuong' is violated
INSERT INTO ChiTietDonThuoc (MaDon, MaThuoc, SoLuong, LieuDung, CachDung, DonGiaKe)
VALUES ('TESTDT01', @thuoc2, 0, '1 viên', 'Uống', 0);

-- [LOI] SoLuong am -> 3819
INSERT INTO ChiTietDonThuoc (MaDon, MaThuoc, SoLuong, LieuDung, CachDung, DonGiaKe)
VALUES ('TESTDT01', @thuoc2, -3, '1 viên', 'Uống', 0);

-- ---------------------------------------------------------------------
-- 3. MucHuong BHYT trong [80, 100]  (CHECK chk_TheBHYT_MucHuong)
-- ---------------------------------------------------------------------
-- [OK] Muc huong 90
INSERT INTO TheBHYT (SoThe, MaBN, MucHuong, NgayHieuLuc, NgayHetHan, NoiDangKy)
VALUES ('TESTBHYT0001', @bn, 90, CURDATE(), CURDATE() + INTERVAL 1 YEAR, 'BV Test');
SELECT SoThe, MucHuong FROM TheBHYT WHERE SoThe = 'TESTBHYT0001';

-- [LOI] Muc huong 70 (< 80) -> 3819 Check constraint 'chk_TheBHYT_MucHuong' is violated
INSERT INTO TheBHYT (SoThe, MaBN, MucHuong, NgayHieuLuc, NgayHetHan, NoiDangKy)
VALUES ('TESTBHYT0002', @bn, 70, CURDATE(), CURDATE() + INTERVAL 1 YEAR, 'BV Test');

-- [LOI] Muc huong 101 (> 100) -> 3819
INSERT INTO TheBHYT (SoThe, MaBN, MucHuong, NgayHieuLuc, NgayHetHan, NoiDangKy)
VALUES ('TESTBHYT0003', @bn, 101, CURDATE(), CURDATE() + INTERVAL 1 YEAR, 'BV Test');

-- ---------------------------------------------------------------------
-- 4. Bac si phai ton tai va DangLamViec  (FK + trigger tren LichHen, CaKham)
-- ---------------------------------------------------------------------
-- [OK] Dat lich voi bac si dang lam viec
INSERT INTO LichHen (MaLH, MaBN, MaBS, NgayHen, Ca, TrangThai)
VALUES ('TESTLH01', @bn, @bs, CURDATE() + INTERVAL 300 DAY, 'Sang', 'ChoKham');
SELECT MaLH, MaBS, NgayHen, Ca FROM LichHen WHERE MaLH = 'TESTLH01';

-- [LOI] Dat lich voi bac si TamNghi/NghiViec -> 1644 'Bac si khong ton tai hoac khong o trang thai DangLamViec'
INSERT INTO LichHen (MaLH, MaBN, MaBS, NgayHen, Ca, TrangThai)
VALUES ('TESTLH02', @bn, @bs_nghi, CURDATE() + INTERVAL 300 DAY, 'Sang', 'ChoKham');

-- [LOI] Ca kham do bac si TamNghi/NghiViec thuc hien -> 1644
INSERT INTO CaKham (MaCaKham, MaBA, MaBS, MaLH, NgayKham, GioBatDau, GioKetThuc, LoaiKham, TrieuChung, KetLuan)
VALUES ('TESTCK03', @ba, @bs_nghi, NULL, CURDATE(), '09:00:00', '09:10:00', 'LanDau', 'Test', 'Test');

-- [LOI] Bac si khong ton tai -> 1644 (trigger bat truoc khi FK kiem tra)
INSERT INTO LichHen (MaLH, MaBN, MaBS, NgayHen, Ca, TrangThai)
VALUES ('TESTLH03', @bn, 'BS_KHONGCO', CURDATE() + INTERVAL 300 DAY, 'Sang', 'ChoKham');

-- ---------------------------------------------------------------------
-- 5. Toi da 30 lich hen / bac si / ngay / ca  (trigger trg_LichHen_bi)
-- ---------------------------------------------------------------------
SET @ngay_full = CURDATE() + INTERVAL 400 DAY;

-- [OK] 30 lich hen dau tien (ca Toi) deu duoc nhan
INSERT INTO LichHen (MaLH, MaBN, MaBS, NgayHen, Ca, TrangThai)
WITH RECURSIVE n (i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 30)
SELECT CONCAT('TL', LPAD(i, 4, '0')), @bn, @bs, @ngay_full, 'Toi', 'ChoKham' FROM n;
SELECT COUNT(*) AS SoLichCaToi FROM LichHen WHERE MaBS = @bs AND NgayHen = @ngay_full AND Ca = 'Toi';  -- = 30

-- [LOI] Lich thu 31 cung bac si, cung ngay, cung ca -> 1644 'Bac si da du 30 lich hen trong ca lam viec nay'
INSERT INTO LichHen (MaLH, MaBN, MaBS, NgayHen, Ca, TrangThai)
VALUES ('TL0031', @bn, @bs, @ngay_full, 'Toi', 'ChoKham');

-- [OK] Cung bac si, cung ngay nhung CA KHAC (Sang) -> van nhan duoc
INSERT INTO LichHen (MaLH, MaBN, MaBS, NgayHen, Ca, TrangThai)
VALUES ('TL0032', @bn, @bs, @ngay_full, 'Sang', 'ChoKham');
SELECT Ca, COUNT(*) AS SoLich FROM LichHen WHERE MaBS = @bs AND NgayHen = @ngay_full GROUP BY Ca;

-- ---------------------------------------------------------------------
-- 6. Ton kho > so luong ke; tu tru kho khi ke, hoan kho khi xoa dong
--    (trigger trg_CTDT_bi / _ai / _ad)
-- ---------------------------------------------------------------------
SELECT SoLuongTon INTO @ton FROM Thuoc WHERE MaThuoc = @thuoc2;
SELECT @thuoc2 AS Thuoc, @ton AS TonTruoc;

-- [OK] Ke 5 don vi -> ton giam 5
INSERT INTO ChiTietDonThuoc (MaDon, MaThuoc, SoLuong, LieuDung, CachDung, DonGiaKe)
VALUES ('TESTDT01', @thuoc2, 5, '1 viên x 1 lần/ngày', 'Uống sáng', 0);
SELECT MaThuoc, SoLuongTon AS TonSauKe, @ton - 5 AS TonKyVong FROM Thuoc WHERE MaThuoc = @thuoc2;

-- [OK] Xoa dong thuoc -> hoan kho ve nhu cu
DELETE FROM ChiTietDonThuoc WHERE MaDon = 'TESTDT01' AND MaThuoc = @thuoc2;
SELECT MaThuoc, SoLuongTon AS TonSauHoan, @ton AS TonBanDau FROM Thuoc WHERE MaThuoc = @thuoc2;

-- [LOI] Ke bang DUNG ton kho (ton phai LON HON so luong ke) -> 1644 'Ton kho khong du ...'
INSERT INTO ChiTietDonThuoc (MaDon, MaThuoc, SoLuong, LieuDung, CachDung, DonGiaKe)
VALUES ('TESTDT01', @thuoc2, @ton, '1 viên', 'Uống', 0);

-- [LOI] Ke vuot ton kho -> 1644
INSERT INTO ChiTietDonThuoc (MaDon, MaThuoc, SoLuong, LieuDung, CachDung, DonGiaKe)
VALUES ('TESTDT01', @thuoc2, @ton + 10, '1 viên', 'Uống', 0);
SELECT MaThuoc, SoLuongTon FROM Thuoc WHERE MaThuoc = @thuoc2;   -- ton khong doi sau cac cau bi chan

-- ---- Ket thuc PHAN A: huy toan bo du lieu test ----
ROLLBACK;
SELECT (SELECT COUNT(*) FROM CaKham   WHERE MaCaKham LIKE 'TEST%') AS CaKhamTest,
       (SELECT COUNT(*) FROM LichHen  WHERE MaLH LIKE 'TL%' OR MaLH LIKE 'TESTLH%') AS LichHenTest,
       (SELECT COUNT(*) FROM TheBHYT  WHERE SoThe LIKE 'TESTBHYT%') AS TheTest;   -- ky vong 0, 0, 0

-- =====================================================================
-- PHAN B
-- 7. Thanh toan BHYT qua sp_LapHoaDon
--    TongTien = TienKham + tien thuoc + tien XN; neu the con han:
--    BHYTChiTra = TongTien * MucHuong / 100, BenhNhanTra = TongTien - BHYTChiTra
--    (sp tu COMMIT nen cuoi phan nay co buoc DELETE don dep)
-- =====================================================================
-- Ca kham chua co hoa don, benh nhan co the BHYT con han tai ngay kham
SET @ck_bhyt = (SELECT ck.MaCaKham
                FROM CaKham ck
                JOIN BenhAn ba ON ba.MaBA = ck.MaBA
                WHERE NOT EXISTS (SELECT 1 FROM HoaDon h WHERE h.MaCaKham = ck.MaCaKham)
                  AND EXISTS (SELECT 1 FROM TheBHYT t
                              WHERE t.MaBN = ba.MaBN
                                AND ck.NgayKham BETWEEN t.NgayHieuLuc AND t.NgayHetHan)
                ORDER BY ck.MaCaKham LIMIT 1);
-- Ca kham chua co hoa don, benh nhan KHONG co the con han
SET @ck_khongthe = (SELECT ck.MaCaKham
                    FROM CaKham ck
                    JOIN BenhAn ba ON ba.MaBA = ck.MaBA
                    WHERE NOT EXISTS (SELECT 1 FROM HoaDon h WHERE h.MaCaKham = ck.MaCaKham)
                      AND NOT EXISTS (SELECT 1 FROM TheBHYT t
                                      WHERE t.MaBN = ba.MaBN
                                        AND ck.NgayKham BETWEEN t.NgayHieuLuc AND t.NgayHetHan)
                    ORDER BY ck.MaCaKham LIMIT 1);
SELECT @ck_bhyt AS CaKham_CoThe, @ck_khongthe AS CaKham_KhongThe;

-- [OK] Co the BHYT: BHYTChiTra = TongTien * MucHuong / 100
CALL sp_LapHoaDon('TESTHD01', @ck_bhyt, 150000, 'TienMat', NULL);

-- Doi chieu thu cong: tien thuoc + tien XN + tien kham, nhan voi muc huong cua the
SELECT hd.MaHD, hd.SoThe, t.MucHuong, hd.TienKham, hd.TongTien, hd.BHYTChiTra, hd.BenhNhanTra,
       ROUND(hd.TongTien * t.MucHuong / 100, 2) AS BHYT_KyVong,
       (SELECT COALESCE(SUM(ct.TienThuoc), 0) FROM DonThuoc d JOIN ChiTietDonThuoc ct ON ct.MaDon = d.MaDon
        WHERE d.MaCaKham = hd.MaCaKham)
     + (SELECT COALESCE(SUM(x.DonGia), 0) FROM KetQuaXN x WHERE x.MaCaKham = hd.MaCaKham)
     + hd.TienKham AS TongTien_KyVong
FROM HoaDon hd JOIN TheBHYT t ON t.SoThe = hd.SoThe
WHERE hd.MaHD = 'TESTHD01';

-- [OK] Khong co the hop le: BHYTChiTra = 0, benh nhan tra toan bo, SoThe = NULL
CALL sp_LapHoaDon('TESTHD02', @ck_khongthe, 150000, 'ChuyenKhoan', NULL);

-- [LOI] Ca kham khong ton tai -> 1644 'Ca kham khong ton tai'
CALL sp_LapHoaDon('TESTHD03', 'KHONGCO', 150000, 'TienMat', NULL);

-- [LOI] Lap hoa don lan 2 cho cung ca kham -> 1062 Duplicate entry ... uq_HoaDon_CaKham (sp tu ROLLBACK)
CALL sp_LapHoaDon('TESTHD04', @ck_bhyt, 150000, 'TienMat', NULL);

-- ---- Don dep ----
DELETE FROM HoaDon WHERE MaHD LIKE 'TESTHD%';
SELECT COUNT(*) AS HoaDonTestConLai FROM HoaDon WHERE MaHD LIKE 'TESTHD%';   -- ky vong 0
