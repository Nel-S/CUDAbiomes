#ifndef BIOMETREE_H_
#define BIOMETREE_H_

#include "layers.cuh"

/*
	The biome trees for 1.18-1.20.x.
	Their arrays are far too large for CUDA's __constant__ memory. But since I seriously doubt xoroshrio128++ will ever allow
	us to implement a tree cracker for 1.18+, I'm not too worried about fixing that now; I'll cross this bridge if and when
	everything else becomes possible.
*/
// #include "tables/btree18.cuh"
// #include "tables/btree192.cuh"
// #include "tables/btree19.cuh"
// #include "tables/btree20.cuh"

STRUCT(BiomeTree)
{
	const uint32_t *steps;
	const int32_t  *param;
	const uint64_t *nodes;
	uint32_t order;
	uint32_t len;
};

__managed__ BiomeTree g_btree[MC_NEWEST - MC_1_18 + 1] = {
//     // MC_1_18 (== MC_1_18_2)
//     { btree18_steps, &btree18_param[0][0], btree18_nodes, btree18_order,
//         sizeof(btree18_nodes) / sizeof(uint64_t) },
//     // MC_1_19_2
//     { btree192_steps, &btree192_param[0][0], btree192_nodes, btree192_order,
//         sizeof(btree192_nodes) / sizeof(uint64_t) },
//     // MC_1_19
//     { btree19_steps, &btree19_param[0][0], btree19_nodes, btree19_order,
//         sizeof(btree19_nodes) / sizeof(uint64_t) },
//     // MC_1_20
//     { btree20_steps, &btree20_param[0][0], btree20_nodes, btree20_order,
//         sizeof(btree20_nodes) / sizeof(uint64_t) },
};

#endif