import { AppError } from "./response.utils";

// Database simpan UTC, tapi batas hari yang dipakai user adalah WIB (UTC+7).
// Offset di-hardcode: Indonesia tidak punya DST dan app ini khusus WIB.
// Kalau nanti perlu WITA/WIT, ubah konstanta ini jadi parameter.
const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

export type DateRange = { gte: Date; lt: Date };

const pad = (n: number) => String(n).padStart(2, "0");

/** "2026-09-01" yang beneran ada di kalender — "2026-02-30" dan "2026-13-01" ditolak. */
export function isCalendarDate(value: unknown): boolean {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const ms = Date.parse(`${value}T00:00:00.000Z`);
  return !Number.isNaN(ms) && new Date(ms).toISOString().startsWith(value);
}

/** Awal hari WIB untuk "YYYY-MM-DD", dalam epoch UTC. */
function wibStartOf(isoDate: string): number {
  if (!isCalendarDate(isoDate)) throw new AppError(422, `Tanggal tidak valid: ${isoDate}`);
  return Date.parse(`${isoDate}T00:00:00.000Z`) - WIB_OFFSET_MS;
}

/** "2026-09-01" -> 2026-08-31T17:00Z s/d 2026-09-01T17:00Z */
export function wibDayRange(dateStr: string): DateRange {
  const start = wibStartOf(dateStr);
  return { gte: new Date(start), lt: new Date(start + DAY_MS) };
}

export function wibMonthRange(year: number, month: number): DateRange {
  const start = wibStartOf(`${year}-${pad(month)}-01`);
  const end = wibStartOf(
    month === 12 ? `${year + 1}-01-01` : `${year}-${pad(month + 1)}-01`,
  );
  return { gte: new Date(start), lt: new Date(end) };
}

export function wibYearRange(year: number): DateRange {
  return {
    gte: new Date(wibStartOf(`${year}-01-01`)),
    lt: new Date(wibStartOf(`${year + 1}-01-01`)),
  };
}

/** Bulan WIB (1-12) dari sebuah timestamp UTC. Dipakai bucket summary tahunan. */
export function wibMonthOf(date: Date): number {
  return new Date(date.getTime() + WIB_OFFSET_MS).getUTCMonth() + 1;
}

/** Tanggal WIB "YYYY-MM-DD" dari sebuah timestamp UTC. */
export function wibDateKey(date: Date): string {
  return new Date(date.getTime() + WIB_OFFSET_MS).toISOString().slice(0, 10);
}

/** Geser tanggal "YYYY-MM-DD" sejumlah hari. */
export function addDays(dateKey: string, days: number): string {
  return new Date(Date.parse(`${dateKey}T00:00:00.000Z`) + days * DAY_MS)
    .toISOString()
    .slice(0, 10);
}

export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

/**
 * Tanggal transaksi dari klien. Yang bawa offset atau `Z` dipakai apa adanya.
 * Yang tanpa offset dianggap jam WIB: APK lama mengirim jam lokal HP tanpa
 * offset (BUG-2), dan container produksi jalan di UTC — kalau diserahkan ke
 * `new Date()`, jamnya geser 7 jam.
 */
export function parseClientDate(value: string): Date {
  if (/(Z|[+-]\d{2}:?\d{2})$/i.test(value)) return new Date(value);
  return new Date(value.includes("T") ? `${value}+07:00` : `${value}T00:00:00+07:00`);
}
