export interface Khoa {
  MaKhoa: string;
  TenKhoa: string;
  SoDienThoai: string | null;
}

export interface BacSi {
  MaBS: string;
  HoTen: string;
  ChuyenMon: string | null;
  MaKhoa: string;
}

export type TenCa = 'Sang' | 'Chieu' | 'Toi';

export interface CaTrong {
  TenCa: TenCa;
  DaDat: number;
  ConTrong: number;
}

export interface LichTrong {
  MaBS: string;
  NgayHen: string;
  Ca: CaTrong[];
}

export interface KetQuaDatLich {
  MaLH: string;
  MaBN: string;
  MaBS: string;
  NgayHen: string;
  Ca: TenCa;
  TrangThai: 'ChoKham';
}

type ApiErrorBody = { message?: string };

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, init);
  const body = await response.json().catch(() => null) as T | ApiErrorBody | null;
  if (!response.ok) {
    const message = body && typeof body === 'object' && 'message' in body && body.message
      ? body.message
      : 'Không thể kết nối máy chủ. Vui lòng thử lại.';
    throw new Error(message);
  }
  return body as T;
}

export const api = {
  layKhoa: () => request<Khoa[]>('/api/khoa'),
  layBacSi: (maKhoa: string) => request<BacSi[]>(`/api/khoa/${encodeURIComponent(maKhoa)}/bac-si`),
  layLichTrong: (maBS: string, ngayHen: string) => request<LichTrong>(
    `/api/bac-si/${encodeURIComponent(maBS)}/lich-trong?ngayHen=${encodeURIComponent(ngayHen)}`,
  ),
  datLich: (payload: unknown) => request<KetQuaDatLich>('/api/lich-hen', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  }),
};
