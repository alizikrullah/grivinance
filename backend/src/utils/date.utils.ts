// Database simpan UTC, tapi batas hari yang dipakai user adalah WIB (UTC+7).
// Offset di-hardcode: Indonesia tidak punya DST dan app ini khusus WIB.
// Kalau nanti perlu WITA/WIT, ubah konstanta ini jadi parameter.
const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

export type DateRange = { gte: Date; lt: Date };

const pad = (n: number) => String(n).padStart(2, "0");

/** Awal hari WIB untuk "YYYY-MM-DD", dalam epoch UTC. */
function wibStartOf(isoDate: string): number {
  const ms = new Date(`${isoDate}T00:00:00.000Z`).getTime();
  if (Number.isNaN(ms)) throw new Error(`Tanggal tidak valid: ${isoDate}`);
  return ms - WIB_OFFSET_MS;
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
