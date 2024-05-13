#include "biomenoise.cuh"

#include "tables/btree18.cuh"
#include "tables/btree192.cuh"
#include "tables/btree19.cuh"
#include "tables/btree20.cuh"

STRUCT(BiomeTree)
{
    const uint32_t *steps;
    const int32_t  *param;
    const uint64_t *nodes;
    uint32_t order;
    uint32_t len;
};

__managed__ BiomeTree g_btree[MC_NEWEST - MC_1_18 + 1] = 
{
    // MC_1_18 (== MC_1_18_2)
    { btree18_steps, &btree18_param[0][0], btree18_nodes, btree18_order,
        sizeof(btree18_nodes) / sizeof(uint64_t) },
    // MC_1_19_2
    { btree192_steps, &btree192_param[0][0], btree192_nodes, btree192_order,
        sizeof(btree192_nodes) / sizeof(uint64_t) },
    // MC_1_19
    { btree19_steps, &btree19_param[0][0], btree19_nodes, btree19_order,
        sizeof(btree19_nodes) / sizeof(uint64_t) },
    // MC_1_20
    { btree20_steps, &btree20_param[0][0], btree20_nodes, btree20_order,
        sizeof(btree20_nodes) / sizeof(uint64_t) },
};

