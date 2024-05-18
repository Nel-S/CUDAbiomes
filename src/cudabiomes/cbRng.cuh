#ifndef RNG_H_
#define RNG_H_

#define __STDC_FORMAT_MACROS 1

#include <cstdlib>
#include <cstddef>
#include <cinttypes>
#include <cuda.h>
// #include "../RNG.cuh"


///=============================================================================
///                      Compiler and Platform Features
///=============================================================================

#define STRUCT(S) typedef struct S S; struct S

#if __GNUC__

#define PREFETCH(PTR,RW,LOC)    __builtin_prefetch(PTR,RW,LOC)
#define unlikely(COND)          (__builtin_expect((COND),0))
#define ATTR(...)               __attribute__((__VA_ARGS__))
#define BSWAP32(X)              __builtin_bswap32(X)
// #define UNREACHABLE()           __builtin_unreachable()

#else

#define PREFETCH(PTR,RW,LOC)
#define unlikely(COND)          (COND)
#define ATTR(...)
__host__ __device__ static inline uint32_t BSWAP32(uint32_t x) {
	x = ((x & 0x000000ff) << 24) | ((x & 0x0000ff00) <<  8) |
		((x & 0x00ff0000) >>  8) | ((x & 0xff000000) >> 24);
	return x;
}
// #if _MSC_VER
// #define UNREACHABLE()           __assume(0)
// #else
// #define UNREACHABLE()           exit(1) // [[noreturn]]
// #endif

#endif

/// imitate amd64/x64 rotate instructions

__host__ __device__ static inline ATTR(const, always_inline, artificial) uint64_t rotl64(uint64_t x, uint8_t b) {
	return (x << b) | (x >> (64-b));
}

__host__ __device__ static inline ATTR(const, always_inline, artificial) uint32_t rotr32(uint32_t a, uint8_t b) {
	return (a >> b) | (a << (32-b));
}

///=============================================================================
///                    C implementation of Java Random
///=============================================================================

__host__ __device__ static inline void setSeed(uint64_t *seed, uint64_t value)
{
	*seed = (value ^ 0x5deece66d) & ((1ULL << 48) - 1);
}

__host__ __device__ static inline int next(uint64_t *seed, const int bits)
{
	*seed = (*seed * 0x5deece66d + 0xb) & ((1ULL << 48) - 1);
	return (int) ((int64_t)*seed >> (48 - bits));
}

__host__ __device__ static inline int nextInt(uint64_t *seed, const int n)
{
	int bits, val;
	const int m = n - 1;

	if ((m & n) == 0) {
		uint64_t x = n * (uint64_t)next(seed, 31);
		return (int) ((int64_t) x >> 31);
	}

	do {
		bits = next(seed, 31);
		val = bits % n;
	}
	while (bits - val + m < 0);
	return val;
}

__host__ __device__ static inline double nextDouble(uint64_t *seed)
{
	uint64_t x = (uint64_t)next(seed, 26);
	x <<= 27;
	x += next(seed, 27);
	return (int64_t) x / (double) (1ULL << 53);
}

/* Jumps forwards in the random number sequence by simulating 'n' calls to next.
 */
__host__ __device__ static inline void skipNextN(uint64_t *seed, uint64_t n)
{
	uint64_t m = 1;
	uint64_t a = 0;
	uint64_t im = 0x5deece66dULL;
	uint64_t ia = 0xb;
	uint64_t k;

	for (k = n; k; k >>= 1)
	{
		if (k & 1)
		{
			m *= im;
			a = im * a + ia;
		}
		ia = (im + 1) * ia;
		im *= im;
	}

	*seed = *seed * m + a;
	*seed &= 0xffffffffffffULL;
}


///=============================================================================
///                               Xoroshiro 128
///=============================================================================

STRUCT(Xoroshiro)
{
	uint64_t lo, hi;
};

__host__ __device__ static inline void xSetSeed(Xoroshiro *xr, uint64_t value)
{
	const uint64_t XL = 0x9e3779b97f4a7c15ULL;
	const uint64_t XH = 0x6a09e667f3bcc909ULL;
	const uint64_t A = 0xbf58476d1ce4e5b9ULL;
	const uint64_t B = 0x94d049bb133111ebULL;
	uint64_t l = value ^ XH;
	uint64_t h = l + XL;
	l = (l ^ (l >> 30)) * A;
	h = (h ^ (h >> 30)) * A;
	l = (l ^ (l >> 27)) * B;
	h = (h ^ (h >> 27)) * B;
	l = l ^ (l >> 31);
	h = h ^ (h >> 31);
	xr->lo = l;
	xr->hi = h;
}

__host__ __device__ static inline uint64_t xNextLong(Xoroshiro *xr)
{
	uint64_t l = xr->lo;
	uint64_t h = xr->hi;
	uint64_t n = rotl64(l + h, 17) + l;
	h ^= l;
	xr->lo = rotl64(l, 49) ^ h ^ (h << 21);
	xr->hi = rotl64(h, 28);
	return n;
}

__host__ __device__ static inline int xNextInt(Xoroshiro *xr, uint32_t n)
{
	uint64_t r = (xNextLong(xr) & 0xFFFFFFFF) * n;
	if ((uint32_t)r < n)
	{
		while ((uint32_t)r < (~n + 1) % n)
		{
			r = (xNextLong(xr) & 0xFFFFFFFF) * n;
		}
	}
	return r >> 32;
}

__host__ __device__ static inline double xNextDouble(Xoroshiro *xr)
{
	return (xNextLong(xr) >> (64-53)) * 1.1102230246251565E-16;
}


//==============================================================================
//                              MC Seed Helpers
//==============================================================================

/**
 * The seed pipeline:
 *
 * getLayerSalt(n)                -> layerSalt (ls)
 * layerSalt (ls), worldSeed (ws) -> startSalt (st), startSeed (ss)
 * startSeed (ss), coords (x,z)   -> chunkSeed (cs)
 *
 * The chunkSeed alone is enough to generate the first PRNG integer with:
 *   mcFirstInt(cs, mod)
 * subsequent PRNG integers are generated by stepping the chunkSeed forwards,
 * salted with startSalt:
 *   cs_next = mcStepSeed(cs, st)
 */

__host__ __device__ static inline uint64_t mcStepSeed(uint64_t s, uint64_t salt)
{
	return s * (s * 6364136223846793005ULL + 1442695040888963407ULL) + salt;
}

__host__ __device__ static inline int mcFirstInt(uint64_t s, int mod)
{
	int ret = (int)(((int64_t)s >> 24) % mod);
	if (ret < 0)
		ret += mod;
	return ret;
}

__host__ __device__ static inline int mcFirstIsZero(uint64_t s, int mod)
{
	return (int)(((int64_t)s >> 24) % mod) == 0;
}

__host__ __device__ static inline uint64_t getChunkSeed(uint64_t ss, int x, int z)
{
	uint64_t cs = ss + x;
	cs = mcStepSeed(cs, z);
	cs = mcStepSeed(cs, x);
	cs = mcStepSeed(cs, z);
	return cs;
}

__host__ __device__ static inline uint64_t getLayerSalt(uint64_t salt)
{
	uint64_t ls = mcStepSeed(salt, salt);
	ls = mcStepSeed(ls, salt);
	ls = mcStepSeed(ls, salt);
	return ls;
}

__host__ __device__ static inline uint64_t getStartSalt(uint64_t ws, uint64_t ls)
{
	uint64_t st = ws;
	st = mcStepSeed(st, ls);
	st = mcStepSeed(st, ls);
	st = mcStepSeed(st, ls);
	return st;
}

__host__ __device__ static inline uint64_t getStartSeed(uint64_t ws, uint64_t ls)
{
	uint64_t ss = ws;
	ss = getStartSalt(ss, ls);
	ss = mcStepSeed(ss, 0);
	return ss;
}


///============================================================================
///                               Arithmetic
///============================================================================


/* Linear interpolations
 */
__host__ __device__ static inline double lerp(double part, double from, double to)
{
	return from + part * (to - from);
}

#endif /* RNG_H_ */