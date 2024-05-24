#ifndef BIOMENOISE_H_
#define BIOMENOISE_H_

#include "biometree.cuh"


STRUCT(Range)
{
	// Defines an area or volume for the biome generation. It is given by a
	// position, size and scaling in the horizontal axes, and an optional
	// vertical range. The vertical scaling is equal to 1:1 iff scale == 1,
	// and 1:4 (default biome scale) in all other cases!
	//
	// @scale:  Horizontal scale factor, should be one of 1, 4, 16, 64, or 256
	//          additionally a value of zero bypasses scaling and expects a
	//          manual generation entry layer.
	// @x,z:    Horizontal position, i.e. coordinates of north-west corner.
	// @sx,sz:  Horizontal size (width and height for 2D), should be positive.
	// @y       Vertical position, 1:1 iff scale==1, 1:4 otherwise.
	// @sy      Vertical size. Values <= 0 are treated equivalent to 1.
	//
	// Volumes generated with a range are generally indexed as:
	//  out [ i_y*sx*sz + i_z*sx + i_x ]
	// where i_x, i_y, i_z are indecies in their respective directions.
	//
	// EXAMPLES
	// Area at normal biome scale (1:4):
	//  Range r_2d = {4, x,z, sx,sz};
	// (C99 syntax allows ommission of the trailing zero-initialization.)
	//
	// Area at block scale (1:1) at sea level:
	//  Range r_surf = {1, x,z, sx,sz, 63};
	// (Block level scale uses voronoi sampling with 1:1 vertical scaling.)
	//
	// Area at chunk scale (1:16) near sea level:
	//  Range r_surf16 = {16, x,z, sx,sz, 15};
	// (Note that the vertical scaling is always 1:4 for non-voronoi scales.)
	//
	// Volume at scale (1:4):
	//  Range r_vol = {4, x,z, sx,sz, y,sy};

	int scale;
	int x, z, sx, sz;
	int y, sy;
};

STRUCT(SurfaceNoiseBeta)
{
	OctaveNoise octmin;
	OctaveNoise octmax;
	OctaveNoise octmain;
	OctaveNoise octcontA;
	OctaveNoise octcontB;
	PerlinNoise oct[16+16+8+10+16];
};

STRUCT(SeaLevelColumnNoiseBeta)
{
	double contASample;
	double contBSample;
	double minSample[2];
	double maxSample[2];
	double mainSample[2];
};

STRUCT(Spline)
{
	int len, typ;
	float loc[12];
	float der[12];
	Spline *val[12];
};

STRUCT(FixSpline)
{
	int len;
	float val;
};

STRUCT(SplineStack)
{   // the stack size here is just sufficient for overworld generation
	Spline stack[42];
	FixSpline fstack[151];
	int len, flen;
};


enum
{
	NP_TEMPERATURE      = 0,
	NP_HUMIDITY         = 1,
	NP_CONTINENTALNESS  = 2,
	NP_EROSION          = 3,
	NP_SHIFT            = 4, NP_DEPTH = NP_SHIFT, // not a real climate
	NP_WEIRDNESS        = 5,
	NP_MAX
};
// Overworld biome generator for 1.18+
STRUCT(BiomeNoise)
{
	DoublePerlinNoise climate[NP_MAX];
	PerlinNoise oct[2*23]; // buffer for octaves in double perlin noise
	Spline *sp;
	SplineStack ss;
	int nptype;
	int mc;
};
// Overworld biome generator for pre-Beta 1.8
STRUCT(BiomeNoiseBeta)
{
	OctaveNoise climate[3];
	PerlinNoise oct[10];
	int nptype;
	int mc;
};


// #ifdef __cplusplus
// extern "C"
// {
// #endif

//==============================================================================
// Globals
//==============================================================================

// The global biome tree definitions.
// By default, these are defined in biometree.c and tables/btreeXX.h
// extern BiomeTree g_btree[MC_NEWEST - MC_1_18 + 1];


//==============================================================================
// Noise
//==============================================================================

__host__ __device__ void initSurfaceNoiseBeta(SurfaceNoiseBeta *snb, uint64_t seed);

//==============================================================================
// End (1.9+), Nether (1.16+) and Overworld (1.18+) Biome Noise Generation
//==============================================================================

/**
 * In 1.18 the Overworld uses a new noise map system for the biome generation.
 * The random number generation also has updated to a Xiroshiro128 algorithm.
 * The scale is 1:4, and is sampled at each point individually as there is
 * currently not much benefit from generating a volume as a whole.
 *
 * The 1.18 End generation remains similar to 1.17 and does NOT use the
 * biome noise.
 */
enum {
	SAMPLE_NO_SHIFT = 0x1,  // skip local distortions
	SAMPLE_NO_DEPTH = 0x2,  // skip depth sampling for vertical biomes
	SAMPLE_NO_BIOME = 0x4,  // do not apply climate noise to biome mapping
};
__host__ __device__ void initBiomeNoise(BiomeNoise *bn, int mc);
__host__ __device__ void setBiomeSeed(BiomeNoise *bn, uint64_t seed, int large);
__host__ __device__ void setBetaBiomeSeed(BiomeNoiseBeta *bnb, uint64_t seed);
__host__ __device__ int sampleBiomeNoise(const BiomeNoise *bn, int64_t *np, int x, int y, int z,
	uint64_t *dat, uint32_t sample_flags);
__host__ __device__ int sampleBiomeNoiseBeta(const BiomeNoiseBeta *bnb, int64_t *np, double *nv,
	int x, int z);

/**
 * (Alpha 1.2 - Beta 1.7) 
 * Temperature and humidity values to biome.
 */
__host__ __device__ int getOldBetaBiome(float t, float h);

/**
 * Uses the global biome tree definition (g_btree) to map a noise point
 * (i.e. climate) to the corresponding overworld biome.
 */
__host__ __device__ int climateToBiome(int mc, const uint64_t np[6], uint64_t *dat);

__host__ __device__ double sampleClimatePara(const BiomeNoise *bn, int64_t *np, double x, double z);

/**
 * The scaled biome noise generation applies for the Overworld version 1.18+.
 * The 'sha' hash of the seed is only required for voronoi at scale 1:1.
 * A scale of zero is interpreted as the default 1:4 scale.
 */
__host__ __device__ int genBiomeNoiseScaled(const BiomeNoise *bn, int *out, Range r, uint64_t sha);

/**
 * Generates the biomes for Beta 1.7, the surface noise is optional and enables
 * ocean mapping in areas that fall below the sea level.
 */
__host__ __device__ int genBiomeNoiseBetaScaled(const BiomeNoiseBeta *bnb, const SurfaceNoiseBeta *snb,
	int *out, Range r);


// Gets the range in the parent/source layer which may be accessed by voronoi.
__host__ __device__ Range getVoronoiSrcRange(Range r);



//==============================================================================
// Noise
//==============================================================================


__host__ __device__ void initSurfaceNoiseBeta(SurfaceNoiseBeta *snb, uint64_t seed) {
	Random random(seed);
	octaveInitBeta(&snb->octmin, random, snb->oct+0, 16, 684.412, 0.5, 1.0, 2.0);
	octaveInitBeta(&snb->octmax, random, snb->oct+16, 16, 684.412, 0.5, 1.0, 2.0);
	octaveInitBeta(&snb->octmain, random, snb->oct+32, 8, 684.412/80.0, 0.5, 1.0, 2.0);
	random.skip<262*8>();
	octaveInitBeta(&snb->octcontA, random, snb->oct+40, 10, 1.121, 0.5, 1.0, 2.0);
	octaveInitBeta(&snb->octcontB, random, snb->oct+50, 16, 200.0, 0.5, 1.0, 2.0);
}

//==============================================================================
// Overworld and Nether Biome Generation 1.18
//==============================================================================

__host__ __device__ static int init_climate_seed(DoublePerlinNoise *dpn, PerlinNoise *oct, uint64_t xlo, uint64_t xhi, int large, int nptype, int nmax) {
	Xoroshiro pxr;
	int n = 0;

	switch (nptype) {
	case NP_SHIFT: {
		static const double amp[] = {1, 1, 1, 0};
		// md5 "minecraft:offset"
		pxr = Xoroshiro::withState(xlo ^ 0x080518cf6af25384, xhi ^ 0x3f3dfb40a54febd5);
		n += doublePerlinInit(dpn, pxr, oct, amp, -3, 4, nmax);
		} break;

	case NP_TEMPERATURE: {
		static const double amp[] = {1.5, 0, 1, 0, 0, 0};
		// md5 "minecraft:temperature" or "minecraft:temperature_large"
		pxr = Xoroshiro::withState(xlo ^ (large ? 0x944b0073edf549db : 0x5c7e6b29735f0d7f), xhi ^ (large ? 0x4ff44347e9d22b96 : 0xf7d86f1bbc734988));
		n += doublePerlinInit(dpn, pxr, oct, amp, large ? -12 : -10, 6, nmax);
		} break;

	case NP_HUMIDITY: {
		static const double amp[] = {1, 1, 0, 0, 0, 0};
		// md5 "minecraft:vegetation" or "minecraft:vegetation_large"
		pxr = Xoroshiro::withState(xlo ^ (large ? 0x71b8ab943dbd5301 : 0x81bb4d22e8dc168e), xhi ^ (large ? 0xbb63ddcf39ff7a2b : 0xf1c8b4bea16303cd));
		n += doublePerlinInit(dpn, pxr, oct, amp, large ? -10 : -8, 6, nmax);
		} break;

	case NP_CONTINENTALNESS: {
		static const double amp[] = {1, 1, 2, 2, 2, 1, 1, 1, 1};
		// md5 "minecraft:continentalness" or "minecraft:continentalness_large"
		pxr = Xoroshiro::withState(xlo ^ (large ? 0x9a3f51a113fce8dc : 0x83886c9d0ae3a662), xhi ^ (large ? 0xee2dbd157e5dcdad : 0xafa638a61b42e8ad));
		n += doublePerlinInit(dpn, pxr, oct, amp, large ? -11 : -9, 9, nmax);
		} break;

	case NP_EROSION: {
		static const double amp[] = {1, 1, 0, 1, 1};
		// md5 "minecraft:erosion" or "minecraft:erosion_large"
		pxr = Xoroshiro::withState(xlo ^ (large ? 0x8c984b1f8702a951 : 0xd02491e6058f6fd8), xhi ^ (large ? 0xead7b1f92bae535f : 0x4792512c94c17a80));
		n += doublePerlinInit(dpn, pxr, oct, amp, large ? -11 : -9, 5, nmax);
		} break;

	case NP_WEIRDNESS: {
		static const double amp[] = {1, 2, 1, 0, 0, 0};
		// md5 "minecraft:ridge"
		pxr = Xoroshiro::withState(xlo ^ 0xefc8ef4d36102b34, xhi ^ 0x1beeeb324a0f24ea);
		n += doublePerlinInit(dpn, pxr, oct, amp, -7, 6, nmax);
		} break;

	default:
		printf("unsupported climate parameter %d\n", nptype);
		// exit(1);
		return 1;
	}
	return n;
}

__host__ __device__ void setBiomeSeed(BiomeNoise *bn, uint64_t seed, int large) {
	Xoroshiro pxr(seed);
	uint64_t xlo = pxr.nextLong();
	uint64_t xhi = pxr.nextLong();

	int n = 0;
	for (int i = 0; i < NP_MAX; i++) n += init_climate_seed(&bn->climate[i], bn->oct+n, xlo, xhi, large, i, -1);

	if ((size_t)n > sizeof(bn->oct) / sizeof(*bn->oct)) {
		printf("setBiomeSeed(): BiomeNoise is malformed, buffer too small\n");
		// exit(1);
		return;
	}
	bn->nptype = -1;
}

__host__ __device__ void setBetaBiomeSeed(BiomeNoiseBeta *bnb, uint64_t seed) {
	Random random(seed*9871);
	octaveInitBeta(bnb->climate, random, bnb->oct, 4, 0.025/1.5, 0.25, 0.55, 2.0);
	random.setSeed(seed*39811);
	octaveInitBeta(bnb->climate+1, random, bnb->oct+4, 4, 0.05/1.5, 1./3, 0.55, 2.0);
	random.setSeed(seed*543321);
	octaveInitBeta(bnb->climate+2, random, bnb->oct+8, 2, 0.25/1.5, 10./17, 0.55, 2.0);
	bnb->nptype = -1;
}


enum { SP_CONTINENTALNESS, SP_EROSION, SP_RIDGES, SP_WEIRDNESS };

__host__ __device__ static void addSplineVal(Spline *rsp, float loc, Spline *val, float der)
{
	rsp->loc[rsp->len] = loc;
	rsp->val[rsp->len] = val;
	rsp->der[rsp->len] = der;
	rsp->len++;
	//if (rsp->len > 12) {
	//    printf("addSplineVal(): too many spline points\n");
	//    exit(1);
	//}
}

__host__ __device__ static Spline *createFixSpline(SplineStack *ss, float val)
{
	FixSpline *sp = &ss->fstack[ss->flen++];
	sp->len = 1;
	sp->val = val;
	return (Spline*)sp;
}

__host__ __device__ static float getOffsetValue(float weirdness, float continentalness)
{
	float f0 = 1.0F - (1.0F - continentalness) * 0.5F;
	float f1 = 0.5F * (1.0F - continentalness);
	float f2 = (weirdness + 1.17F) * 0.46082947F;
	float off = f2 * f0 - f1;
	if (weirdness < -0.7F)
		return off > -0.2222F ? off : -0.2222F;
	else
		return off > 0 ? off : 0;
}

__host__ __device__ static Spline *createSpline_38219(SplineStack *ss, float f, int bl)
{
	Spline *sp = &ss->stack[ss->len++];
	sp->typ = SP_RIDGES;

	float i = getOffsetValue(-1.0F, f);
	float k = getOffsetValue( 1.0F, f);
	float l = 1.0F - (1.0F - f) * 0.5F;
	float u = 0.5F * (1.0F - f);
	l = u / (0.46082947F * l) - 1.17F;

	if (-0.65F < l && l < 1.0F)
	{
		float p, q, r, s;
		u = getOffsetValue(-0.65F, f);
		p = getOffsetValue(-0.75F, f);
		q = (p - i) * 4.0F;
		r = getOffsetValue(l, f);
		s = (k - r) / (1.0F - l);

		addSplineVal(sp, -1.0F,     createFixSpline(ss, i), q);
		addSplineVal(sp, -0.75F,    createFixSpline(ss, p), 0);
		addSplineVal(sp, -0.65F,    createFixSpline(ss, u), 0);
		addSplineVal(sp, l-0.01F,   createFixSpline(ss, r), 0);
		addSplineVal(sp, l,         createFixSpline(ss, r), s);
		addSplineVal(sp, 1.0F,      createFixSpline(ss, k), s);
	}
	else
	{
		u = (k - i) * 0.5F;
		if (bl) {
			addSplineVal(sp, -1.0F, createFixSpline(ss, i > 0.2 ? i : 0.2), 0);
			addSplineVal(sp,  0.0F, createFixSpline(ss, lerp(0.5F, i, k)), u);
		} else {
			addSplineVal(sp, -1.0F, createFixSpline(ss, i), u);
		}
		addSplineVal(sp, 1.0F,      createFixSpline(ss, k), u);
	}
	return sp;
}

__host__ __device__ static Spline *createFlatOffsetSpline(
	SplineStack *ss, float f, float g, float h, float i, float j, float k)
{
	Spline *sp = &ss->stack[ss->len++];
	sp->typ = SP_RIDGES;

	float l = 0.5F * (g - f); if (l < k) l = k;
	float m = 5.0F * (h - g);

	addSplineVal(sp, -1.0F, createFixSpline(ss, f), l);
	addSplineVal(sp, -0.4F, createFixSpline(ss, g), l < m ? l : m);
	addSplineVal(sp,  0.0F, createFixSpline(ss, h), m);
	addSplineVal(sp,  0.4F, createFixSpline(ss, i), 2.0F*(i-h));
	addSplineVal(sp,  1.0F, createFixSpline(ss, j), 0.7F*(j-i));

	return sp;
}

__host__ __device__ static Spline *createLandSpline(
	SplineStack *ss, float f, float g, float h, float i, float j, float k, int bl)
{
	Spline *sp1 = createSpline_38219(ss, lerp(i, 0.6F, 1.5F), bl);
	Spline *sp2 = createSpline_38219(ss, lerp(i, 0.6F, 1.0F), bl);
	Spline *sp3 = createSpline_38219(ss, i, bl);
	const float ih = 0.5F * i;
	Spline *sp4 = createFlatOffsetSpline(ss, f-0.15F, ih, ih, ih, i*0.6F, 0.5F);
	Spline *sp5 = createFlatOffsetSpline(ss, f, j*i, g*i, ih, i*0.6F, 0.5F);
	Spline *sp6 = createFlatOffsetSpline(ss, f, j, j, g, h, 0.5F);
	Spline *sp7 = createFlatOffsetSpline(ss, f, j, j, g, h, 0.5F);

	Spline *sp8 = &ss->stack[ss->len++];
	sp8->typ = SP_RIDGES;
	addSplineVal(sp8, -1.0F, createFixSpline(ss, f), 0.0F);
	addSplineVal(sp8, -0.4F, sp6, 0.0F);
	addSplineVal(sp8,  0.0F, createFixSpline(ss, h + 0.07F), 0.0F);

	Spline *sp9 = createFlatOffsetSpline(ss, -0.02F, k, k, g, h, 0.0F);
	Spline *sp = &ss->stack[ss->len++];
	sp->typ = SP_EROSION;
	addSplineVal(sp, -0.85F, sp1, 0.0F);
	addSplineVal(sp, -0.7F,  sp2, 0.0F);
	addSplineVal(sp, -0.4F,  sp3, 0.0F);
	addSplineVal(sp, -0.35F, sp4, 0.0F);
	addSplineVal(sp, -0.1F,  sp5, 0.0F);
	addSplineVal(sp,  0.2F,  sp6, 0.0F);
	if (bl) {
		addSplineVal(sp, 0.4F,  sp7, 0.0F);
		addSplineVal(sp, 0.45F, sp8, 0.0F);
		addSplineVal(sp, 0.55F, sp8, 0.0F);
		addSplineVal(sp, 0.58F, sp7, 0.0F);
	}
	addSplineVal(sp, 0.7F, sp9, 0.0F);
	return sp;
}

__host__ __device__ float getSpline(const Spline *sp, const float *vals)
{
	if (!sp || sp->len <= 0 || sp->len >= 12)
	{
		printf("getSpline(): bad parameters\n");
		// exit(1);
		return 1;
	}

	if (sp->len == 1)
		return ((FixSpline*)sp)->val;

	float f = vals[sp->typ];
	int i;

	for (i = 0; i < sp->len; i++)
		if (sp->loc[i] >= f)
			break;
	if (i == 0 || i == sp->len)
	{
		if (i) i--;
		float v = getSpline(sp->val[i], vals);
		return v + sp->der[i] * (f - sp->loc[i]);
	}
	const Spline *sp1 = sp->val[i-1];
	const Spline *sp2 = sp->val[i];
	float g = sp->loc[i-1];
	float h = sp->loc[i];
	float k = (f - g) / (h - g);
	float l = sp->der[i-1];
	float m = sp->der[i];
	float n = getSpline(sp1, vals);
	float o = getSpline(sp2, vals);
	float p = l * (h - g) - (o - n);
	float q = -m * (h - g) + (o - n);
	float r = lerp(k, n, o) + k * (1.0F - k) * lerp(k, p, q);
	return r;
}

__host__ __device__ void initBiomeNoise(BiomeNoise *bn, int mc) {
	SplineStack *ss = &bn->ss;
	memset(ss, 0, sizeof(*ss));
	Spline *sp = &ss->stack[ss->len++];
	sp->typ = SP_CONTINENTALNESS;

	Spline *sp1 = createLandSpline(ss, -0.15F, 0.00F, 0.0F, 0.1F, 0.00F, -0.03F, 0);
	Spline *sp2 = createLandSpline(ss, -0.10F, 0.03F, 0.1F, 0.1F, 0.01F, -0.03F, 0);
	Spline *sp3 = createLandSpline(ss, -0.10F, 0.03F, 0.1F, 0.7F, 0.01F, -0.03F, 1);
	Spline *sp4 = createLandSpline(ss, -0.05F, 0.03F, 0.1F, 1.0F, 0.01F,  0.01F, 1);

	addSplineVal(sp, -1.10F, createFixSpline(ss,  0.044F), 0.0F);
	addSplineVal(sp, -1.02F, createFixSpline(ss, -0.2222F), 0.0F);
	addSplineVal(sp, -0.51F, createFixSpline(ss, -0.2222F), 0.0F);
	addSplineVal(sp, -0.44F, createFixSpline(ss, -0.12F), 0.0F);
	addSplineVal(sp, -0.18F, createFixSpline(ss, -0.12F), 0.0F);
	addSplineVal(sp, -0.16F, sp1, 0.0F);
	addSplineVal(sp, -0.15F, sp1, 0.0F);
	addSplineVal(sp, -0.10F, sp2, 0.0F);
	addSplineVal(sp,  0.25F, sp3, 0.0F);
	addSplineVal(sp,  1.00F, sp4, 0.0F);

	bn->sp = sp;
	bn->mc = mc;
}


/// Biome sampler for MC 1.18
__host__ __device__ int sampleBiomeNoise(const BiomeNoise *bn, int64_t *np, int x, int y, int z, uint64_t *dat, uint32_t sample_flags) {
	if (bn->nptype >= 0) {   // initialized for a specific climate parameter
		if (np)
			memset(np, 0, NP_MAX*sizeof(*np));
		int64_t id = (int64_t) (10000.0 * sampleClimatePara(bn, np, x, z));
		return (int) id;
	}

	float t = 0, h = 0, c = 0, e = 0, d = 0, w = 0;
	double px = x, pz = z;
	if (!(sample_flags & SAMPLE_NO_SHIFT)) {
		px += sampleDoublePerlin(&bn->climate[NP_SHIFT], x, 0, z) * 4.0;
		pz += sampleDoublePerlin(&bn->climate[NP_SHIFT], z, x, 0) * 4.0;
	}

	c = sampleDoublePerlin(&bn->climate[NP_CONTINENTALNESS], px, 0, pz);
	e = sampleDoublePerlin(&bn->climate[NP_EROSION], px, 0, pz);
	w = sampleDoublePerlin(&bn->climate[NP_WEIRDNESS], px, 0, pz);

	if (!(sample_flags & SAMPLE_NO_DEPTH)) {
		float np_param[] = {
			c, e, -3.0F * ( fabsf( fabsf(w) - 0.6666667F ) - 0.33333334F ), w,
		};
		double off = getSpline(bn->sp, np_param) + 0.015F;

		//double py = y + sampleDoublePerlin(&bn->shift, y, z, x) * 4.0;
		d = 1.0 - (y * 4) / 128.0 - 83.0/160.0 + off;
	}

	t = sampleDoublePerlin(&bn->climate[NP_TEMPERATURE], px, 0, pz);
	h = sampleDoublePerlin(&bn->climate[NP_HUMIDITY], px, 0, pz);

	int64_t l_np[6];
	int64_t *p_np = np ? np : l_np;
	p_np[0] = (int64_t)(10000.0F*t);
	p_np[1] = (int64_t)(10000.0F*h);
	p_np[2] = (int64_t)(10000.0F*c);
	p_np[3] = (int64_t)(10000.0F*e);
	p_np[4] = (int64_t)(10000.0F*d);
	p_np[5] = (int64_t)(10000.0F*w);

	int id = none;
	if (!(sample_flags & SAMPLE_NO_BIOME)) id = climateToBiome(bn->mc, (const uint64_t*)p_np, dat);
	return id;
}

// Note: Climate noise is sampled at a 1:1 scale.
__host__ __device__ int sampleBiomeNoiseBeta(const BiomeNoiseBeta *bnb, int64_t *np, double *nv,
	int x, int z)
{
	if (bnb->nptype >= 0 && np)
		memset(np, 0, 2*sizeof(*np));
	double t, h, f;
	f = sampleOctaveBeta17Biome(&bnb->climate[2], x, z) * 1.1 + 0.5;

	t = (sampleOctaveBeta17Biome(&bnb->climate[0], x, z) *
		0.15 + 0.7) * 0.99 + f * 0.01;
	t = 1 - (1 - t) * (1 - t);
	t = (t < 0) ? 0 : t;
	t = (t > 1) ? 1 : t;
	if (bnb->nptype == NP_TEMPERATURE)
		return (int64_t) (10000.0F * t);

	h = (sampleOctaveBeta17Biome(&bnb->climate[1], x, z) *
		0.15 + 0.5) * 0.998 + f * 0.002;
	h = (h < 0) ? 0 : h;
	h = (h > 1) ? 1 : h;
	if (bnb->nptype == NP_HUMIDITY)
		return (int64_t) (10000.0F * h * t);

	if (nv)
	{
		nv[0] = t;
		nv[1] = h;
	}
	return getOldBetaBiome((float) t, (float) h);
}


__host__ __device__ int getOldBetaBiome(float t, float h)
{
	static const uint8_t biome_table_beta_1_7[64*64] = 
	{
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,1,1,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,1,1,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,9,9,9,9,9,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,9,9,9,9,9,9,9,9,9,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,9,9,9,9,9,9,9,9,9,9,9,9,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,6,6,6,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,6,6,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,6,6,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,6,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,6,6,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,6,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,2,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		6,6,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,2,2,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,0,0,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,
		9,9,9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,
		9,9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,
		9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,
		9,9,9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,
		9,9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,
		9,9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,
		9,9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,
		9,9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,
		9,9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,
		9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,
		9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,
		9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,
		9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,2,2,2,2,2,2,2,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,2,2,2,2,2,2,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,2,2,2,2,2,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,2,2,2,2,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,2,2,2,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,2,2,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,2,2,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,2,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,2,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,2,4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,7,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,4,4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,7,8,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,2,4,4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,8,8,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,4,4,4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,8,8,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,2,4,4,4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,8,8,
		5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,4,4,4,4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,8,8,
		5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		2,4,4,4,4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,8,8,
		5,5,5,5,5,5,5,5,5,5,5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
		4,4,4,4,4,4,4,4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,8,8,
	};
	static const int bmap[] = {
		plains, desert, forest, taiga, swamp, snowy_tundra, savanna,
		seasonal_forest, rainforest, shrubland
	};
	int idx = (int)(t * 63) + (int)(h * 63) * 64;
	return bmap[ biome_table_beta_1_7[idx] ];
}


__host__ __device__ 
static inline ATTR(hot, pure, always_inline) uint64_t get_np_dist(const uint64_t np[6], const BiomeTree *bt, int idx) {
	uint64_t ds = 0, node = bt->nodes[idx];
	uint64_t a, b, d;
	uint32_t i;

	for (i = 0; i < 6; i++)
	{
		idx = (node >> 8*i) & 0xFF;
		a = np[i] - bt->param[2*idx + 1];
		b = bt->param[2*idx + 0] - np[i];
		d = (int64_t)a > 0 ? a : (int64_t)b > 0 ? b : 0;
		d = d * d;
		ds += d;
	}
	return ds;
}

__host__ __device__ static inline ATTR(hot, pure) int get_resulting_node(const uint64_t np[6], const BiomeTree *bt, int idx, int alt, uint64_t ds, int depth) {
	if (!bt->steps[depth]) return idx;
	uint32_t step;
	do {
		step = bt->steps[depth];
		++depth;
	} while (idx + step >= bt->len);

	uint64_t node = bt->nodes[idx];
	uint16_t inner = node >> 48;

	int leaf = alt;
	uint32_t i, n;

	for (i = 0, n = bt->order; i < n; i++) {
		uint64_t ds_inner = get_np_dist(np, bt, inner);
		if (ds_inner < ds) {
			int leaf2 = get_resulting_node(np, bt, inner, leaf, ds, depth);
			uint64_t ds_leaf2 = (inner == leaf2) ? ds_inner : get_np_dist(np, bt, leaf2);
			if (ds_leaf2 < ds) {
				ds = ds_leaf2;
				leaf = leaf2;
			}
		}

		inner += step;
		if (inner >= bt->len) break;
	}
	return leaf;
}

__host__ __device__ int climateToBiome(int mc, const uint64_t np[6], uint64_t *dat) {
	if (mc < MC_1_18 || MC_NEWEST < mc) return -1;
	
	const BiomeTree *bt = &g_btree[mc - MC_1_18];
	int alt = 0;
	int idx;
	uint64_t ds = UINT64_MAX;

	if (dat) {
		alt = (int) *dat;
		ds = get_np_dist(np, bt, alt);
	}

	idx = get_resulting_node(np, bt, 0, alt, ds, 0);
	if (dat) *dat = (uint64_t) idx;
	
	return (bt->nodes[idx] >> 48) & 0xFF;
}

__host__ __device__ double sampleClimatePara(const BiomeNoise *bn, int64_t *np, double x, double z)
{
	if (bn->nptype == NP_DEPTH)
	{
		float c, e, w;
		c = sampleDoublePerlin(bn->climate + NP_CONTINENTALNESS, x, 0, z);
		e = sampleDoublePerlin(bn->climate + NP_EROSION, x, 0, z);
		w = sampleDoublePerlin(bn->climate + NP_WEIRDNESS, x, 0, z);

		float np_param[] = {
			c, e, -3.0F * ( fabsf( fabsf(w) - 0.6666667F ) - 0.33333334F ), w,
		};
		double off = getSpline(bn->sp, np_param) + 0.015F;
		int y = 0;
		float d = 1.0 - (y * 4) / 128.0 - 83.0/160.0 + off;
		if (np)
		{
			np[2] = (int64_t)(10000.0F*c);
			np[3] = (int64_t)(10000.0F*e);
			np[4] = (int64_t)(10000.0F*d);
			np[5] = (int64_t)(10000.0F*w);
		}
		return d;
	}
	double p = sampleDoublePerlin(bn->climate + bn->nptype, x, 0, z);
	if (np)
		np[bn->nptype] = (int64_t)(10000.0F*p);
	return p;
}

__host__ __device__ static void genBiomeNoise3D(const BiomeNoise *bn, int *out, Range r, int opt)
{
	uint64_t dat = 0;
	uint64_t *p_dat = opt ? &dat : NULL;
	uint32_t flags = opt ? SAMPLE_NO_SHIFT : 0;
	int i, j, k;
	int *p = out;
	int scale = r.scale > 4 ? r.scale / 4 : 1;
	int mid = scale / 2;
	for (k = 0; k < r.sy; k++)
	{
		int yk = (r.y+k);
		for (j = 0; j < r.sz; j++)
		{
			int zj = (r.z+j)*scale + mid;
			for (i = 0; i < r.sx; i++)
			{
				int xi = (r.x+i)*scale + mid;
				*p = sampleBiomeNoise(bn, NULL, xi, yk, zj, p_dat, flags);
				p++;
			}
		}
	}
}

__host__ __device__ int genBiomeNoiseScaled(const BiomeNoise *bn, int *out, Range r, uint64_t sha) {
	if (r.sy == 0) r.sy = 1;

	uint64_t siz = (uint64_t)r.sx*r.sy*r.sz;
	int i, j, k;

	if (r.scale == 1)
	{
		Range s = getVoronoiSrcRange(r);
		int *src;
		if (siz > 1) {   // the source range is large enough that we can try optimizing
			src = out + siz;
			genBiomeNoise3D(bn, src, s, 0);
		}
		else src = NULL;

		int *p = out;
		for (k = 0; k < r.sy; k++)
		{
			for (j = 0; j < r.sz; j++)
			{
				for (i = 0; i < r.sx; i++)
				{
					int x4, z4, y4;
					voronoiAccess3D(sha, r.x+i, r.y+k, r.z+j, &x4, &y4, &z4);
					if (src)
					{
						x4 -= s.x; y4 -= s.y; z4 -= s.z;
						*p = src[(int64_t)y4*s.sx*s.sz + (int64_t)z4*s.sx + x4];
					}
					else *p = sampleBiomeNoise(bn, 0, x4, y4, z4, 0, 0);
					p++;
				}
			}
		}
	}
	else
	{
		// There is (was?) an optimization that causes MC-241546, and should
		// not be enabled for accurate results. However, if the scale is higher
		// than 1:4, the accuracy becomes questionable anyway. Furthermore
		// situations that want to use a higher scale are usually better off
		// with a faster, if imperfect, result.
		genBiomeNoise3D(bn, out, r, r.scale > 4);
	}
	return 0;
}

__host__ __device__ static void genColumnNoise(const SurfaceNoiseBeta *snb, SeaLevelColumnNoiseBeta *dest,
	double cx, double cz, double lacmin)
{
	dest->contASample = sampleOctaveAmp(&snb->octcontA, cx, 0, cz, 0, 0, 1);
	dest->contBSample = sampleOctaveAmp(&snb->octcontB, cx, 0, cz, 0, 0, 1);
	sampleOctaveBeta17Terrain(&snb->octmin, dest->minSample, cx, cz, 0, lacmin);
	sampleOctaveBeta17Terrain(&snb->octmax, dest->maxSample, cx, cz, 0, lacmin);
	sampleOctaveBeta17Terrain(&snb->octmain, dest->mainSample, cx, cz, 1, lacmin);
}

__host__ __device__ static void processColumnNoise(double *out, const SeaLevelColumnNoiseBeta *src,
	const double climate[2])
{
	double humi = 1 - climate[0] * climate[1];
	humi *= humi;
	humi *= humi;
	humi = 1 - humi;
	double contA = (src->contASample + 256) / 512 * humi;
	contA = (contA > 1) ? 1.0 : contA;
	double contB = src->contBSample / 8000;
	if (contB < 0)
		contB = -contB * 0.3;
	contB = contB*3-2;
	if (contB < 0)
	{
		contB /= 2;
		contB = (contB < -1) ? -1.0 / 1.4 / 2 : contB / 1.4 / 2;
		contA = 0;
	}
	else
	{
		contB = (contB > 1) ? 1.0/8 : contB/8;
	}
	contA = (contA < 0) ? 0.5 : contA+0.5;
	contB = (contB * 17.0) / 16;
	contB = 17.0 / 2 + contB * 4;
	const double *low = src->minSample;
	const double *high = src->maxSample;
	const double *selector = src->mainSample;
	int i;
	for (i = 0; i <= 1; i++)
	{
		double chooseLHS;
		double procCont = ((i + 7 - contB) * 12) / contA;
		procCont = (procCont < 0) ? procCont*4 : procCont;
		double lSample = low[i] / 512;
		double hSample = high[i] / 512;
		double sSample = (selector[i] / 10 + 1) / 2;
		chooseLHS = (sSample < 0.0) ? lSample : (sSample > 1) ? hSample :
			lSample + (hSample - lSample) * sSample;
		chooseLHS -= procCont;
		out[i] = chooseLHS;
	}
}

__host__ __device__ static double lerp4(
	const double a[2], const double b[2], const double c[2], const double d[2],
	double dy, double dx, double dz)
{
	double b00 = a[0] + (a[1] - a[0]) * dy;
	double b01 = b[0] + (b[1] - b[0]) * dy;
	double b10 = c[0] + (c[1] - c[0]) * dy;
	double b11 = d[0] + (d[1] - d[0]) * dy;
	double b0 = b00 + (b10 - b00) * dz;
	double b1 = b01 + (b11 - b01) * dz;
	return b0 + (b1 - b0) * dx;
}

__host__ __device__ int genBiomeNoiseBetaScaled(const BiomeNoiseBeta *bnb, const SurfaceNoiseBeta *snb, int *out, Range r) {
	if (!snb || r.scale >= 4)
	{
		int i, j;
		int mid = r.scale >> 1;
		for (j = 0; j < r.sz; j++)
		{
			int z = (r.z+j)*r.scale + mid;
			for (i = 0; i < r.sx; i++)
			{
				double climate[2];
				int x = (r.x+i)*r.scale + mid;
				int id = sampleBiomeNoiseBeta(bnb, NULL, climate, x, z);

				if (snb)
				{
					double cols[2];
					SeaLevelColumnNoiseBeta colNoise;
					genColumnNoise(snb, &colNoise, x*0.25, z*0.25, 4.0/r.scale);
					processColumnNoise(cols, &colNoise, climate);
					if (cols[0]*0.125 + cols[1]*0.875 <= 0)
						id = (climate[0] < 0.5) ? frozen_ocean : ocean;
				}
				out[(int64_t)j*r.sx + i] = id;
			}
		}
		return 0;
	}

	int cellwidth = r.scale >> 1;
	int cx1 = r.x >> (2 >> cellwidth);
	int cz1 = r.z >> (2 >> cellwidth);
	int cx2 = cx1 + (r.sx >> (2 >> cellwidth)) + 1;
	int cz2 = cz1 + (r.sz >> (2 >> cellwidth)) + 1;
	int steps = 4 >> cellwidth;
	int minDim, maxDim;
	if (cx2-cx1 > cz2-cz1) {
		maxDim = cx2-cx1;
		minDim = cz2-cz1;
	} else {
		maxDim = cz2-cz1;
		minDim = cx2-cx1;
	}
	int bufLen = minDim * 2 + 1;

	int i, j, x, z, cx, cz;
	int xStart = cx1;
	int zStart = cz1;
	int idx = 0;
	SeaLevelColumnNoiseBeta *buf = (SeaLevelColumnNoiseBeta*) (out + (int64_t)r.sx * r.sz);
	SeaLevelColumnNoiseBeta *colNoise;
	double cols[8];
	double climate[2];
	static const int off[] = { 1, 4, 7, 10, 13 };

	// Diagonal traversal of range region, in order to minimize size of saved
	// column noise buffer
	int stripe;
	for (stripe = 0; stripe < maxDim + minDim - 1; stripe++)
	{
		cx = xStart;
		cz = zStart;
		while (cx < cx2 && cz >= cz1)
		{
			int csx = (cx * 4) & ~15; // start of chunk coordinates
			int csz = (cz * 4) & ~15;
			int ci = cx & 3;
			int cj = cz & 3;

			colNoise = &buf[idx];
			if (stripe == 0)
				genColumnNoise(snb, colNoise, cx, cz, 0);
			sampleBiomeNoiseBeta(bnb, NULL, climate, csx+off[ci], csz+off[cj]);
			processColumnNoise(&cols[0], colNoise, climate);

			colNoise = &buf[(idx + minDim + 1) % bufLen];
			if (cz == cz1)
				genColumnNoise(snb, colNoise, cx+1, cz, 0);
			sampleBiomeNoiseBeta(bnb, NULL, climate, csx+off[ci+1], csz+off[cj]);
			processColumnNoise(&cols[2], colNoise, climate);

			colNoise = &buf[(idx + minDim) % bufLen];
			if (cx == cx1)
				genColumnNoise(snb, colNoise, cx, cz+1, 0);
			sampleBiomeNoiseBeta(bnb, NULL, climate, csx+off[ci], csz+off[cj+1]);
			processColumnNoise(&cols[4], colNoise, climate);

			colNoise = &buf[idx];
			genColumnNoise(snb, colNoise, cx+1, cz+1, 0);
			sampleBiomeNoiseBeta(bnb, NULL, climate, csx+off[ci+1], csz+off[cj+1]);
			processColumnNoise(&cols[6], colNoise, climate);

			// scale=1: cellwidth=0, steps=4
			// scale=4: cellwidth=2, steps=1
			for (j = 0; j < steps; j++)
			{
				z = cz * steps + j;
				if (z < r.z || z >= r.z + r.sz)
					continue;
				for (i = 0; i < steps; i++)
				{
					x = cx * steps + i;
					if (x < r.x || x >= r.x + r.sx)
						continue;
					int mid = r.scale >> 1;
					int bx = x * r.scale + mid;
					int bz = z * r.scale + mid;
					int id = sampleBiomeNoiseBeta(bnb, NULL, climate, bx, bz);
					double dx = (bx & 3) * 0.25;
					double dz = (bz & 3) * 0.25;
					if (lerp4(cols+0, cols+2, cols+4, cols+6, 7./8, dx, dz) <= 0)
						id = (climate[0] < 0.5) ? frozen_ocean : ocean;
					out[(int64_t)(z - r.z) * r.sx + (x - r.x)] = id;
				}
			}

			cx++;
			cz--;
			idx = (idx+1) % bufLen;
		}
		if (zStart < cz2-1)
			zStart++;
		else
			xStart++;
		if (stripe+1 < minDim)
			idx = (idx + minDim-stripe-1) % bufLen;
		else if (stripe+1 > maxDim)
			idx = (idx + stripe-maxDim+2) % bufLen;
		else if (xStart > cx1)
			idx = (idx + 1) % bufLen;
	}
	return 0;
}

__host__ __device__ Range getVoronoiSrcRange(Range r)
{
	if (r.scale != 1)
	{
		printf("getVoronoiSrcRange() expects input range with scale 1:1\n");
		// exit(1);
		return Range();
	}

	Range s; // output has scale 1:4
	int x = r.x - 2;
	int z = r.z - 2;
	s.scale = 4;
	s.x = x >> 2;
	s.z = z >> 2;
	s.sx = ((x + r.sx) >> 2) - s.x + 2;
	s.sz = ((z + r.sz) >> 2) - s.z + 2;
	if (r.sy < 1)
	{
		s.y = s.sy = 0;
	}
	else
	{
		int ty = r.y - 2;
		s.y = ty >> 2;
		s.sy = ((ty + r.sy) >> 2) - s.y + 2;
	}
	return s;
}


// #ifdef __cplusplus
// }
// #endif

#endif /* BIOMENOISE_H_ */