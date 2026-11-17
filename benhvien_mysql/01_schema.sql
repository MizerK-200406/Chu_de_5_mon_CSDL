-- =====================================================================
-- 01_schema.sql | Quan ly Benh vien & Ho so Suc khoe Dien tu (EHR)
-- DBMS: MySQL 8.0.16+ (InnoDB, utf8mb4)
-- Thu tu chay: 01_schema.sql -> 02_data.sql -> 03_queries.sql -> 04_tests.sql
-- Luu y: file nay DROP va tao lai database benhvien0 (dung de reset khi demo)
-- =====================================================================
SET NAMES utf8mb4;
DROP DATABASE IF EXISTS benhvien0;
CREATE DATABASE benhvien0 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE benhvien0;

-- =====================================================================
-- PHAN 1: TAO BANG (theo thu tu phu thuoc khoa ngoai)
-- =====================================================================

-- ---------- Cum 1: To chuc va con nguoi ----------
CREATE TABLE Khoa (
    MaKhoa       VARCHAR(10)  NOT NULL,
    TenKhoa      VARCHAR(100) NOT NULL,
    SoDienThoai  VARCHAR(15),
    CONSTRAINT pk_Khoa PRIMARY KEY (MaKhoa),
    CONSTRAINT uq_Khoa_TenKhoa UNIQUE (TenKhoa)
) ENGINE=InnoDB;

CREATE TABLE BacSi (
    MaBS         VARCHAR(10)  NOT NULL,
    HoTen        VARCHAR(100) NOT NULL,
    GioiTinh     ENUM('Nam','Nu') NOT NULL,
    NgaySinh     DATE,
    ChuyenMon    VARCHAR(100),
    SoDienThoai  VARCHAR(15),
    TrangThai    ENUM('DangLamViec','TamNghi','NghiViec') NOT NULL DEFAULT 'DangLamViec',
    MaKhoa       VARCHAR(10)  NOT NULL,
    CONSTRAINT pk_BacSi PRIMARY KEY (MaBS),
    CONSTRAINT fk_BacSi_Khoa FOREIGN KEY (MaKhoa) REFERENCES Khoa (MaKhoa)
) ENGINE=InnoDB;

CREATE TABLE BenhNhan (
    MaBN         VARCHAR(10)  NOT NULL,
    HoTen        VARCHAR(100) NOT NULL,
    NgaySinh     DATE         NOT NULL,
    GioiTinh     ENUM('Nam','Nu') NOT NULL,
    CCCD         CHAR(12),
    SoDienThoai  VARCHAR(15),
    DiaChi       VARCHAR(255),
    CONSTRAINT pk_BenhNhan PRIMARY KEY (MaBN),
    CONSTRAINT uq_BenhNhan_CCCD UNIQUE (CCCD)
) ENGINE=InnoDB;

CREATE TABLE TheBHYT (
    SoThe        VARCHAR(15)  NOT NULL,
    MaBN         VARCHAR(10)  NOT NULL,
    MucHuong     TINYINT UNSIGNED NOT NULL,
    NgayHieuLuc  DATE         NOT NULL,
    NgayHetHan   DATE         NOT NULL,
    NoiDangKy    VARCHAR(150),
    CONSTRAINT pk_TheBHYT PRIMARY KEY (SoThe),
    CONSTRAINT fk_TheBHYT_BenhNhan FOREIGN KEY (MaBN) REFERENCES BenhNhan (MaBN),
    -- Rang buoc CHECK 3: MucHuongBHYT in [80, 100]
    CONSTRAINT chk_TheBHYT_MucHuong CHECK (MucHuong BETWEEN 80 AND 100),
    CONSTRAINT chk_TheBHYT_HanDung  CHECK (NgayHetHan >= NgayHieuLuc)
) ENGINE=InnoDB;

-- ---------- Cum 2: Lich hen va kham benh ----------
CREATE TABLE LichHen (
    MaLH       VARCHAR(10) NOT NULL,
    MaBN       VARCHAR(10) NOT NULL,
    MaBS       VARCHAR(10) NOT NULL,
    NgayHen    DATE        NOT NULL,
    Ca         ENUM('Sang','Chieu','Toi') NOT NULL,
    TrangThai  ENUM('ChoKham','DaKham','Huy') NOT NULL DEFAULT 'ChoKham',
    CONSTRAINT pk_LichHen PRIMARY KEY (MaLH),
    CONSTRAINT fk_LichHen_BenhNhan FOREIGN KEY (MaBN) REFERENCES BenhNhan (MaBN),
    CONSTRAINT fk_LichHen_BacSi    FOREIGN KEY (MaBS) REFERENCES BacSi (MaBS),
    INDEX idx_LichHen_BS_Ngay_Ca (MaBS, NgayHen, Ca)
) ENGINE=InnoDB;

CREATE TABLE DanhMucBenh (
    MaBenh     VARCHAR(10)  NOT NULL,
    TenBenh    VARCHAR(150) NOT NULL,
    LaManTinh  BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_DanhMucBenh PRIMARY KEY (MaBenh)
) ENGINE=InnoDB;

CREATE TABLE BenhAn (
    MaBA     VARCHAR(10) NOT NULL,
    MaBN     VARCHAR(10) NOT NULL,
    MaBenh   VARCHAR(10) NOT NULL,
    NgayMo   DATE        NOT NULL,
    GhiChu   VARCHAR(255),
    CONSTRAINT pk_BenhAn PRIMARY KEY (MaBA),
    CONSTRAINT fk_BenhAn_BenhNhan   FOREIGN KEY (MaBN)   REFERENCES BenhNhan (MaBN),
    CONSTRAINT fk_BenhAn_DanhMucBenh FOREIGN KEY (MaBenh) REFERENCES DanhMucBenh (MaBenh)
) ENGINE=InnoDB;

CREATE TABLE CaKham (
    MaCaKham    VARCHAR(10) NOT NULL,            -- vi du: KB1002
    MaBA        VARCHAR(10) NOT NULL,
    MaBS        VARCHAR(10) NOT NULL,
    MaLH        VARCHAR(10) NULL,                -- NULL = kham vang lai, khong co lich hen
    NgayKham    DATE        NOT NULL,
    GioBatDau   TIME        NOT NULL,
    GioKetThuc  TIME        NOT NULL,
    LoaiKham    ENUM('LanDau','TaiKham') NOT NULL DEFAULT 'LanDau',
    TrieuChung  VARCHAR(255),
    KetLuan     VARCHAR(255),
    CONSTRAINT pk_CaKham PRIMARY KEY (MaCaKham),
    CONSTRAINT uq_CaKham_LichHen UNIQUE (MaLH),
    CONSTRAINT fk_CaKham_BenhAn  FOREIGN KEY (MaBA) REFERENCES BenhAn (MaBA),
    CONSTRAINT fk_CaKham_BacSi   FOREIGN KEY (MaBS) REFERENCES BacSi (MaBS),
    CONSTRAINT fk_CaKham_LichHen FOREIGN KEY (MaLH) REFERENCES LichHen (MaLH),
    CONSTRAINT chk_CaKham_Gio CHECK (GioKetThuc > GioBatDau),
    INDEX idx_CaKham_NgayKham (NgayKham),
    INDEX idx_CaKham_BS_Ngay (MaBS, NgayKham)
) ENGINE=InnoDB;

CREATE TABLE NhapVien (
    MaNV            VARCHAR(10)  NOT NULL,
    MaBN            VARCHAR(10)  NOT NULL,
    MaKhoa          VARCHAR(10)  NOT NULL,
    NgayVao         DATE         NOT NULL,
    NgayRa          DATE         NULL,
    ChanDoanBanDau  VARCHAR(255) NOT NULL,
    TrangThai       ENUM('DangDieuTri','DaXuatVien') NOT NULL DEFAULT 'DangDieuTri',
    CONSTRAINT pk_NhapVien PRIMARY KEY (MaNV),
    CONSTRAINT fk_NhapVien_BenhNhan FOREIGN KEY (MaBN)   REFERENCES BenhNhan (MaBN),
    CONSTRAINT fk_NhapVien_Khoa     FOREIGN KEY (MaKhoa) REFERENCES Khoa (MaKhoa),
    CONSTRAINT chk_NhapVien_Ngay CHECK (NgayRa IS NULL OR NgayRa >= NgayVao)
) ENGINE=InnoDB;

-- ---------- Cum 3: Can lam sang ----------
CREATE TABLE DichVu (
    MaDV    VARCHAR(10)  NOT NULL,
    TenDV   VARCHAR(150) NOT NULL,
    LoaiDV  ENUM('XetNghiem','CDHA') NOT NULL,
    DonGia  DECIMAL(12,2) NOT NULL,
    CONSTRAINT pk_DichVu PRIMARY KEY (MaDV),
    CONSTRAINT chk_DichVu_DonGia CHECK (DonGia >= 0)
) ENGINE=InnoDB;

CREATE TABLE KetQuaXN (
    MaKQ          VARCHAR(10) NOT NULL,
    MaCaKham      VARCHAR(10) NOT NULL,
    MaDV          VARCHAR(10) NOT NULL,
    NgayChiDinh   DATE        NOT NULL,
    NgayCoKetQua  DATE        NULL,
    KetQua        VARCHAR(255),
    KetLuan       VARCHAR(255),
    DonGia        DECIMAL(12,2) NOT NULL DEFAULT 0,   -- gia chot, trigger tu lay tu DichVu neu = 0
    CONSTRAINT pk_KetQuaXN PRIMARY KEY (MaKQ),
    CONSTRAINT fk_KetQuaXN_CaKham FOREIGN KEY (MaCaKham) REFERENCES CaKham (MaCaKham),
    CONSTRAINT fk_KetQuaXN_DichVu FOREIGN KEY (MaDV)     REFERENCES DichVu (MaDV),
    CONSTRAINT chk_KetQuaXN_Ngay CHECK (NgayCoKetQua IS NULL OR NgayCoKetQua >= NgayChiDinh),
    CONSTRAINT chk_KetQuaXN_DonGia CHECK (DonGia >= 0)
) ENGINE=InnoDB;

-- ---------- Cum 4: Duoc ----------
CREATE TABLE Thuoc (
    MaThuoc     VARCHAR(10)  NOT NULL,
    TenThuoc    VARCHAR(150) NOT NULL,
    HoatChat    VARCHAR(150),
    DonViTinh   VARCHAR(20)  NOT NULL,
    DonGia      DECIMAL(12,2) NOT NULL,
    SoLuongTon  INT NOT NULL DEFAULT 0,
    CONSTRAINT pk_Thuoc PRIMARY KEY (MaThuoc),
    CONSTRAINT chk_Thuoc_DonGia CHECK (DonGia >= 0),
    CONSTRAINT chk_Thuoc_Ton    CHECK (SoLuongTon >= 0)
) ENGINE=InnoDB;

CREATE TABLE DonThuoc (
    MaDon     VARCHAR(10) NOT NULL,
    MaCaKham  VARCHAR(10) NOT NULL,
    NgayKe    DATE        NOT NULL,
    LoiDan    VARCHAR(255),
    CONSTRAINT pk_DonThuoc PRIMARY KEY (MaDon),
    CONSTRAINT uq_DonThuoc_CaKham UNIQUE (MaCaKham),
    CONSTRAINT fk_DonThuoc_CaKham FOREIGN KEY (MaCaKham) REFERENCES CaKham (MaCaKham)
) ENGINE=InnoDB;

CREATE TABLE ChiTietDonThuoc (
    MaDon      VARCHAR(10) NOT NULL,
    MaThuoc    VARCHAR(10) NOT NULL,
    SoLuong    INT         NOT NULL,
    LieuDung   VARCHAR(100),
    CachDung   VARCHAR(150),
    DonGiaKe   DECIMAL(12,2) NOT NULL DEFAULT 0,      -- gia chot, trigger tu lay tu Thuoc neu = 0
    TienThuoc  DECIMAL(14,2) GENERATED ALWAYS AS (SoLuong * DonGiaKe) STORED,
    CONSTRAINT pk_ChiTietDonThuoc PRIMARY KEY (MaDon, MaThuoc),
    CONSTRAINT fk_CTDT_DonThuoc FOREIGN KEY (MaDon)   REFERENCES DonThuoc (MaDon),
    CONSTRAINT fk_CTDT_Thuoc    FOREIGN KEY (MaThuoc) REFERENCES Thuoc (MaThuoc),
    -- Rang buoc CHECK 2: SoLuongThuocKe > 0
    CONSTRAINT chk_CTDT_SoLuong CHECK (SoLuong > 0),
    CONSTRAINT chk_CTDT_DonGiaKe CHECK (DonGiaKe >= 0)
) ENGINE=InnoDB;

-- ---------- Cum 5: Thanh toan ----------
CREATE TABLE HoaDon (
    MaHD           VARCHAR(10) NOT NULL,
    MaCaKham       VARCHAR(10) NOT NULL,
    SoThe          VARCHAR(15) NULL,                  -- NULL = thanh toan vien phi tu tra
    NgayThanhToan  DATETIME    NOT NULL,
    TienKham       DECIMAL(12,2) NOT NULL DEFAULT 0,
    TongTien       DECIMAL(14,2) NOT NULL DEFAULT 0,
    BHYTChiTra     DECIMAL(14,2) NOT NULL DEFAULT 0,
    BenhNhanTra    DECIMAL(14,2) NOT NULL DEFAULT 0,
    TrangThai      ENUM('ChuaThanhToan','DaThanhToan') NOT NULL DEFAULT 'DaThanhToan',
    PhuongThuc     ENUM('TienMat','ChuyenKhoan','The') NOT NULL DEFAULT 'TienMat',
    CONSTRAINT pk_HoaDon PRIMARY KEY (MaHD),
    CONSTRAINT uq_HoaDon_CaKham UNIQUE (MaCaKham),
    CONSTRAINT fk_HoaDon_CaKham FOREIGN KEY (MaCaKham) REFERENCES CaKham (MaCaKham),
    CONSTRAINT fk_HoaDon_TheBHYT FOREIGN KEY (SoThe)   REFERENCES TheBHYT (SoThe),
    CONSTRAINT chk_HoaDon_Tien CHECK (TongTien >= 0 AND BHYTChiTra >= 0 AND BenhNhanTra >= 0),
    CONSTRAINT chk_HoaDon_ChiaTien CHECK (BHYTChiTra + BenhNhanTra = TongTien),
    INDEX idx_HoaDon_NgayThanhToan (NgayThanhToan)
) ENGINE=InnoDB;

-- =====================================================================
-- PHAN 2: HAM, TRIGGER, STORED PROCEDURE
-- =====================================================================
DELIMITER $$

-- ---------- Ham kiem tra bac si dang lam viec ----------
CREATE FUNCTION fn_BacSiDangLamViec(p_MaBS VARCHAR(10))
RETURNS TINYINT(1)
READS SQL DATA
BEGIN
    RETURN EXISTS (SELECT 1 FROM BacSi WHERE MaBS = p_MaBS AND TrangThai = 'DangLamViec');
END$$

-- ---------- CaKham: NgayKham <= ngay hien tai; bac si phai DangLamViec ----------
CREATE TRIGGER trg_CaKham_bi BEFORE INSERT ON CaKham
FOR EACH ROW
BEGIN
    IF NEW.NgayKham > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NgayKham khong duoc lon hon ngay hien tai';
    END IF;
    IF NOT fn_BacSiDangLamViec(NEW.MaBS) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bac si kham khong ton tai hoac khong o trang thai DangLamViec';
    END IF;
END$$

CREATE TRIGGER trg_CaKham_bu BEFORE UPDATE ON CaKham
FOR EACH ROW
BEGIN
    IF NEW.NgayKham > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NgayKham khong duoc lon hon ngay hien tai';
    END IF;
    -- chi kiem tra trang thai khi doi bac si (tranh chan sua ca kham cu cua bac si da nghi)
    IF NEW.MaBS <> OLD.MaBS AND NOT fn_BacSiDangLamViec(NEW.MaBS) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bac si kham khong ton tai hoac khong o trang thai DangLamViec';
    END IF;
END$$

-- ---------- LichHen: bac si DangLamViec; toi da 30 lich hen / bac si / ngay / ca ----------
CREATE TRIGGER trg_LichHen_bi BEFORE INSERT ON LichHen
FOR EACH ROW
BEGIN
    DECLARE v_dem INT DEFAULT 0;
    IF NOT fn_BacSiDangLamViec(NEW.MaBS) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bac si khong ton tai hoac khong o trang thai DangLamViec';
    END IF;
    IF NEW.TrangThai <> 'Huy' THEN
        SELECT COUNT(*) INTO v_dem
        FROM LichHen
        WHERE MaBS = NEW.MaBS AND NgayHen = NEW.NgayHen AND Ca = NEW.Ca AND TrangThai <> 'Huy';
        IF v_dem >= 30 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bac si da du 30 lich hen trong ca lam viec nay';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_LichHen_bu BEFORE UPDATE ON LichHen
FOR EACH ROW
BEGIN
    DECLARE v_dem INT DEFAULT 0;
    IF NEW.MaBS <> OLD.MaBS AND NOT fn_BacSiDangLamViec(NEW.MaBS) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bac si khong ton tai hoac khong o trang thai DangLamViec';
    END IF;
    IF NEW.TrangThai <> 'Huy'
       AND (NEW.MaBS <> OLD.MaBS OR NEW.NgayHen <> OLD.NgayHen OR NEW.Ca <> OLD.Ca OR OLD.TrangThai = 'Huy') THEN
        SELECT COUNT(*) INTO v_dem
        FROM LichHen
        WHERE MaBS = NEW.MaBS AND NgayHen = NEW.NgayHen AND Ca = NEW.Ca
          AND TrangThai <> 'Huy' AND MaLH <> NEW.MaLH;
        IF v_dem >= 30 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bac si da du 30 lich hen trong ca lam viec nay';
        END IF;
    END IF;
END$$

-- ---------- ChiTietDonThuoc: ton kho phai LON HON so luong ke; tru kho; chot gia ----------
-- Ghi chu: de cho phep ke bang dung ton, doi dieu kien "v_ton <= NEW.SoLuong" thanh "v_ton < NEW.SoLuong".
CREATE TRIGGER trg_CTDT_bi BEFORE INSERT ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    DECLARE v_ton INT;
    DECLARE v_gia DECIMAL(12,2);
    SELECT SoLuongTon, DonGia INTO v_ton, v_gia
    FROM Thuoc WHERE MaThuoc = NEW.MaThuoc FOR UPDATE;
    IF v_ton IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thuoc khong ton tai';
    END IF;
    IF v_ton <= NEW.SoLuong THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ton kho khong du: SoLuongTon phai lon hon so luong ke';
    END IF;
    IF NEW.DonGiaKe IS NULL OR NEW.DonGiaKe = 0 THEN
        SET NEW.DonGiaKe = v_gia;
    END IF;
END$$

CREATE TRIGGER trg_CTDT_ai AFTER INSERT ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    UPDATE Thuoc SET SoLuongTon = SoLuongTon - NEW.SoLuong WHERE MaThuoc = NEW.MaThuoc;
END$$

CREATE TRIGGER trg_CTDT_bu BEFORE UPDATE ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    IF NEW.MaThuoc <> OLD.MaThuoc OR NEW.SoLuong <> OLD.SoLuong OR NEW.MaDon <> OLD.MaDon THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khong sua thuoc/so luong, hay xoa dong nay va ke lai';
    END IF;
END$$

CREATE TRIGGER trg_CTDT_ad AFTER DELETE ON ChiTietDonThuoc
FOR EACH ROW
BEGIN
    UPDATE Thuoc SET SoLuongTon = SoLuongTon + OLD.SoLuong WHERE MaThuoc = OLD.MaThuoc;
END$$

-- ---------- KetQuaXN: tu chot gia dich vu luc chi dinh ----------
CREATE TRIGGER trg_KetQuaXN_bi BEFORE INSERT ON KetQuaXN
FOR EACH ROW
BEGIN
    IF NEW.DonGia IS NULL OR NEW.DonGia = 0 THEN
        SET NEW.DonGia = (SELECT DonGia FROM DichVu WHERE MaDV = NEW.MaDV);
    END IF;
END$$

-- ---------- Thu tuc lap hoa don (BHYT chi tra phan trong pham vi bao hiem) ----------
-- TongTien = TienKham + tien thuoc + tien xet nghiem/CDHA cua ca kham
-- The BHYT hop le = cua dung benh nhan va con han tai NgayKham
-- BHYTChiTra = TongTien * MucHuong / 100; BenhNhanTra = TongTien - BHYTChiTra
CREATE PROCEDURE sp_LapHoaDon(
    IN p_MaHD          VARCHAR(10),
    IN p_MaCaKham      VARCHAR(10),
    IN p_TienKham      DECIMAL(12,2),
    IN p_PhuongThuc    VARCHAR(20),   -- 'TienMat' | 'ChuyenKhoan' | 'The'
    IN p_NgayThanhToan DATETIME       -- NULL = thoi diem hien tai
)
BEGIN
    DECLARE v_NgayKham DATE DEFAULT NULL;
    DECLARE v_MaBN     VARCHAR(10) DEFAULT NULL;
    DECLARE v_SoThe    VARCHAR(15) DEFAULT NULL;
    DECLARE v_Muc      TINYINT UNSIGNED DEFAULT 0;
    DECLARE v_Thuoc    DECIMAL(14,2) DEFAULT 0;
    DECLARE v_XN       DECIMAL(14,2) DEFAULT 0;
    DECLARE v_Tong     DECIMAL(14,2) DEFAULT 0;
    DECLARE v_BHYT     DECIMAL(14,2) DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT ck.NgayKham, ba.MaBN INTO v_NgayKham, v_MaBN
    FROM CaKham ck JOIN BenhAn ba ON ba.MaBA = ck.MaBA
    WHERE ck.MaCaKham = p_MaCaKham;

    IF v_NgayKham IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ca kham khong ton tai';
    END IF;

    SELECT COALESCE(SUM(ct.TienThuoc), 0) INTO v_Thuoc
    FROM DonThuoc d JOIN ChiTietDonThuoc ct ON ct.MaDon = d.MaDon
    WHERE d.MaCaKham = p_MaCaKham;

    SELECT COALESCE(SUM(DonGia), 0) INTO v_XN
    FROM KetQuaXN WHERE MaCaKham = p_MaCaKham;

    SET v_Tong = p_TienKham + v_Thuoc + v_XN;

    -- the BHYT hop le: dung benh nhan, con han tai ngay kham; neu nhieu the lay muc cao nhat
    SELECT SoThe, MucHuong INTO v_SoThe, v_Muc
    FROM TheBHYT
    WHERE MaBN = v_MaBN AND NgayHieuLuc <= v_NgayKham AND NgayHetHan >= v_NgayKham
    ORDER BY MucHuong DESC
    LIMIT 1;

    IF v_SoThe IS NOT NULL THEN
        SET v_BHYT = ROUND(v_Tong * v_Muc / 100, 2);
    END IF;

    INSERT INTO HoaDon (MaHD, MaCaKham, SoThe, NgayThanhToan, TienKham,
                        TongTien, BHYTChiTra, BenhNhanTra, TrangThai, PhuongThuc)
    VALUES (p_MaHD, p_MaCaKham, v_SoThe, COALESCE(p_NgayThanhToan, NOW()), p_TienKham,
            v_Tong, v_BHYT, v_Tong - v_BHYT, 'DaThanhToan', p_PhuongThuc);

    COMMIT;

    SELECT * FROM HoaDon WHERE MaHD = p_MaHD;
END$$

DELIMITER ;

-- =====================================================================
-- PHAN 3: KIEM TRA NHANH SAU KHI TAO
-- =====================================================================
SHOW TABLES;
SELECT TRIGGER_NAME, EVENT_MANIPULATION, EVENT_OBJECT_TABLE, ACTION_TIMING
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'benhvien0'
ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING, EVENT_MANIPULATION;
