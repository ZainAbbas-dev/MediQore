// Seeded pseudo-random numbers, so the same --seed always produces the same data.
function createRandom(seed) {
  // mulberry32
  let state = seed >>> 0;
  const next = () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };

  const random = {
    next,
    int: (min, max) => min + Math.floor(next() * (max - min + 1)),
    chance: (p) => next() < p,
    pick: (list) => list[Math.floor(next() * list.length)],
    // Normal distribution (Box-Muller), clamped to [min, max].
    normal(mean, sd, min = -Infinity, max = Infinity) {
      const u = 1 - next();
      const v = next();
      const z = Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
      return Math.min(max, Math.max(min, mean + z * sd));
    },
    // Weighted choice: weights is { value: weight }.
    weighted(weights) {
      const entries = Object.entries(weights);
      let r = next() * entries.reduce((sum, [, w]) => sum + w, 0);
      for (const [value, w] of entries) {
        r -= w;
        if (r < 0) return value;
      }
      return entries[entries.length - 1][0];
    },
    // UUID v4 like the app makes on the device, but reproducible.
    uuid() {
      const hex = Array.from({ length: 32 }, () => Math.floor(next() * 16).toString(16));
      hex[12] = '4';
      hex[16] = ((Number.parseInt(hex[16], 16) & 0x3) | 0x8).toString(16);
      const s = hex.join('');
      return `${s.slice(0, 8)}-${s.slice(8, 12)}-${s.slice(12, 16)}-${s.slice(16, 20)}-${s.slice(20)}`;
    },
  };
  return random;
}

const round = (value, digits) => Number(value.toFixed(digits));

module.exports = { createRandom, round };
