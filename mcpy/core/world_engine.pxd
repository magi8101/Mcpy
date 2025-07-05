from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t
import numpy as np
cimport numpy as np

cdef class ChunkSection:
    cdef:
        public uint8_t[:, :, :] blocks
        public uint8_t[:, :, :] blocklight
        public uint8_t[:, :, :] skylight
        public int16_t y_index
        public bint modified
        public bint empty
        public bint all_air
        
    cpdef uint8_t get_block(self, int x, int y, int z) except? 0
    cpdef bint set_block(self, int x, int y, int z, uint8_t block_id) except? False
    cpdef dict to_data(self)
    cpdef void recalculate_light(self)

cdef class Chunk:
    cdef:
        public int32_t x
        public int32_t z
        public object sections
        public uint8_t[:, :] biomes
        public uint8_t[:, :] height_map
        public bint generated
        public bint populated
        public bint modified
        public int64_t last_used
        
    cpdef ChunkSection get_section(self, int16_t y_index)
    cpdef uint8_t get_block(self, int x, int y, int z) except? 0
    cpdef bint set_block(self, int x, int y, int z, uint8_t block_id) except? False
    cpdef void update_last_used(self)
    cpdef dict to_data(self)
    cpdef void generate(self, object generator)
    cpdef void populate(self, object generator, object world)

cdef class TerrainGenerator:
    cdef:
        public np.ndarray heightmap_cache
        public np.ndarray biome_map
        public dict noise_params
        public object rng
        public bint using_scientific
        
    cdef double _simple_noise(self, double x, double z)

cdef class WorldEngine:
    cdef:
        public str world_path
        public dict chunks
        public TerrainGenerator generator
        public int view_distance
        public int max_chunks
        public object save_lock
        public object chunk_lock
        public object thread_pool
        
    cpdef Chunk get_chunk(self, int32_t chunk_x, int32_t chunk_z, bint generate=*)
    cpdef uint8_t get_block(self, int x, int y, int z) except? 0
    cpdef bint set_block(self, int x, int y, int z, uint8_t block_id) except? False
