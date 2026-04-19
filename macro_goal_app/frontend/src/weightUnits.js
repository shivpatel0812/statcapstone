/** Exact conversion; backend + R stay in kg. */

export const LB_PER_KG = 2.2046226218487757;

export function kgToLbs(kg) {
  const n = Number(kg);
  if (!Number.isFinite(n)) return 0;
  return n * LB_PER_KG;
}

export function lbsToKg(lbs) {
  const n = Number(lbs);
  if (!Number.isFinite(n)) return 0;
  return n / LB_PER_KG;
}
