# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True
"""
World engine for MCPy.

This module handles all world-related operations, including:
- Procedural world generation
- Chunk loading and management
- Block manipulation and physics
- Advanced terrain features
"""

# Import from standard libraries
from libc.stdlib cimport malloc, free, calloc, realloc
from libc.string cimport memset, memcpy
from cpython cimport PyObject, Py_INCREF, Py_DECREF
from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t
from libc.time cimport time_t, time
from libc.math cimport sqrt, pow, cos, sin, fabs, fmod, ceil, floor

# NumPy imports
import numpy as np
cimport numpy as np
np.import_array()

# Python imports
import logging
import os
import threading
import time as py_time
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple, Any, Union
from concurrent.futures import ThreadPoolExecutor

# Import optional scientific libraries
try:
    from scipy import ndimage
    from scipy.spatial import distance
    HAVE_SCIPY = True
except ImportError:
    HAVE_SCIPY = False

try:
    import noise
    HAVE_NOISE = True
except ImportError:
    HAVE_NOISE = False

# Import for persistence
try:
    import msgpack
    HAVE_MSGPACK = True
except ImportError:
    HAVE_MSGPACK = False

# Define constants
DEF CHUNK_SIZE = 16
DEF MAX_HEIGHT = 384
DEF MIN_HEIGHT = -64
DEF WORLD_HEIGHT = 448  # MAX_HEIGHT - MIN_HEIGHT
DEF SECTION_HEIGHT = 16
DEF SECTIONS_PER_CHUNK = 28  # WORLD_HEIGHT / SECTION_HEIGHT
DEF MAX_LIGHT_LEVEL = 15

# Define biome types
cdef enum BiomeType:
    OCEAN = 0
    PLAINS = 1
    DESERT = 2
    MOUNTAINS = 3
    FOREST = 4
    TAIGA = 5
    SWAMP = 6
    RIVER = 7
    NETHER = 8
    END = 9
    SNOWY_TUNDRA = 10
    MUSHROOM_FIELDS = 11
    JUNGLE = 12
    BADLANDS = 13
    SAVANNA = 14

# Logger
logger = logging.getLogger("mcpy.world_engine")

cdef class ChunkSection:
    """A 16x16x16 section of blocks within a chunk."""
    cdef:
        public uint8_t[:, :, :] blocks
        public uint8_t[:, :, :] blocklight
        public uint8_t[:, :, :] skylight
        public int16_t y_index
        public bint modified
        public bint empty
        public bint all_air
        
    def __cinit__(self, int16_t y_index):
        """Initialize a chunk section at the given Y index."""
        self.y_index = y_index
        self.blocks = np.zeros((CHUNK_SIZE, SECTION_HEIGHT, CHUNK_SIZE), dtype=np.uint8)
        self.blocklight = np.zeros((CHUNK_SIZE, SECTION_HEIGHT, CHUNK_SIZE), dtype=np.uint8)
        self.skylight = np.zeros((CHUNK_SIZE, SECTION_HEIGHT, CHUNK_SIZE), dtype=np.uint8)
        self.modified = False
        self.empty = True
        self.all_air = True
        
    cpdef uint8_t get_block(self, int x, int y, int z) except? 0:
        """Get the block ID at the given position."""
        if not (0 <= x < CHUNK_SIZE and 0 <= y < SECTION_HEIGHT and 0 <= z < CHUNK_SIZE):
            return 0
        return self.blocks[x, y, z]
        
    cpdef bint set_block(self, int x, int y, int z, uint8_t block_id) except? False:
        """Set the block ID at the given position."""
        if not (0 <= x < CHUNK_SIZE and 0 <= y < SECTION_HEIGHT and 0 <= z < CHUNK_SIZE):
            return False
            
        self.blocks[x, y, z] = block_id
        self.modified = True
        
        # Update empty and all_air flags
        if block_id != 0:
            self.empty = False
            self.all_air = False
        else:
            # Check if all blocks are air
            self.all_air = np.all(self.blocks == 0)
            self.empty = self.all_air
            
        return True
        
    cpdef dict to_data(self):
        """Convert the chunk section to a data dictionary for serialization."""
        cdef dict data = {
            'y_index': self.y_index,
            'blocks': np.array(self.blocks).tobytes(),
            'blocklight': np.array(self.blocklight).tobytes(),
            'skylight': np.array(self.skylight).tobytes(),
            'empty': self.empty,
        }
        return data
        
    @staticmethod
    def from_data(dict data):
        """Create a chunk section from data dictionary."""
        cdef int16_t y_index = data['y_index']
        cdef ChunkSection section = ChunkSection(y_index)
        
        # Load blocks and lighting data
        cdef np.ndarray blocks = np.frombuffer(data['blocks'], dtype=np.uint8)
        blocks = blocks.reshape(CHUNK_SIZE, SECTION_HEIGHT, CHUNK_SIZE)
        section.blocks = blocks
        
        cdef np.ndarray blocklight = np.frombuffer(data['blocklight'], dtype=np.uint8)
        blocklight = blocklight.reshape(CHUNK_SIZE, SECTION_HEIGHT, CHUNK_SIZE)
        section.blocklight = blocklight
        
        cdef np.ndarray skylight = np.frombuffer(data['skylight'], dtype=np.uint8)
        skylight = skylight.reshape(CHUNK_SIZE, SECTION_HEIGHT, CHUNK_SIZE)
        section.skylight = skylight
        
        section.empty = data['empty']
        section.all_air = np.all(blocks == 0)
        section.modified = False
        
        return section
        
    cpdef void recalculate_light(self):
        """Recalculate lighting for this section."""
        # This is a placeholder for more complex lighting calculations
        # For performance, lighting would be calculated incrementally and in batches
        pass

cdef class Chunk:
    """A 16x16 column of the world from bottom to top."""
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
        
    def __cinit__(self, int32_t x, int32_t z):
        """Initialize a chunk at the given coordinates."""
        self.x = x
        self.z = z
        self.sections = {}  # Sparse array of sections
        self.biomes = np.zeros((CHUNK_SIZE, CHUNK_SIZE), dtype=np.uint8)
        self.height_map = np.zeros((CHUNK_SIZE, CHUNK_SIZE), dtype=np.uint8)
        self.generated = False
        self.populated = False
        self.modified = False
        self.last_used = <int64_t>time(NULL)
        
    cpdef ChunkSection get_section(self, int16_t y_index):
        """Get the section at the given Y index, creating it if it doesn't exist."""
        if y_index not in self.sections:
            section = ChunkSection(y_index)
            self.sections[y_index] = section
        return self.sections[y_index]
        
    cpdef uint8_t get_block(self, int x, int y, int z) except? 0:
        """Get the block ID at the given position within the chunk."""
        cdef int16_t section_y = y // SECTION_HEIGHT
        cdef int local_y = y % SECTION_HEIGHT
        
        if section_y not in self.sections:
            return 0
            
        return (<ChunkSection>self.sections[section_y]).get_block(x, local_y, z)
        
    cpdef bint set_block(self, int x, int y, int z, uint8_t block_id) except? False:
        """Set the block ID at the given position within the chunk."""
        if not (0 <= x < CHUNK_SIZE and MIN_HEIGHT <= y < MAX_HEIGHT and 0 <= z < CHUNK_SIZE):
            return False
            
        # Calculate section and local coordinates
        cdef int16_t section_y = y // SECTION_HEIGHT
        cdef int local_y = y % SECTION_HEIGHT
        
        # Get or create the section
        cdef ChunkSection section = self.get_section(section_y)
        
        # Set the block
        cdef bint result = section.set_block(x, local_y, z, block_id)
        
        if result:
            self.modified = True
            
            # Update height map if necessary
            if block_id != 0 and y > self.height_map[x, z]:
                self.height_map[x, z] = y
            elif block_id == 0 and y == self.height_map[x, z]:
                # Find new highest block
                for ny in range(y - 1, MIN_HEIGHT - 1, -1):
                    if self.get_block(x, ny, z) != 0:
                        self.height_map[x, z] = ny
                        break
                        
        return result
        
    cpdef void update_last_used(self):
        """Update the last used timestamp for this chunk."""
        self.last_used = <int64_t>time(NULL)
        
    cpdef dict to_data(self):
        """Convert the chunk to a data dictionary for serialization."""
        cdef dict data = {
            'x': self.x,
            'z': self.z,
            'biomes': np.array(self.biomes).tobytes(),
            'height_map': np.array(self.height_map).tobytes(),
            'generated': self.generated,
            'populated': self.populated,
            'sections': {}
        }
        
        # Only save non-empty sections
        for y_index, section in self.sections.items():
            if not section.empty:
                data['sections'][y_index] = section.to_data()
                
        return data
        
    @staticmethod
    def from_data(dict data):
        """Create a chunk from a data dictionary."""
        cdef int32_t x = data['x']
        cdef int32_t z = data['z']
        cdef Chunk chunk = Chunk(x, z)
        
        # Load biomes and height map
        cdef np.ndarray biomes = np.frombuffer(data['biomes'], dtype=np.uint8)
        chunk.biomes = biomes.reshape(CHUNK_SIZE, CHUNK_SIZE)
        
        cdef np.ndarray height_map = np.frombuffer(data['height_map'], dtype=np.uint8)
        chunk.height_map = height_map.reshape(CHUNK_SIZE, CHUNK_SIZE)
        
        chunk.generated = data['generated']
        chunk.populated = data['populated']
        
        # Load sections
        for y_index_str, section_data in data['sections'].items():
            y_index = int(y_index_str)
            chunk.sections[y_index] = ChunkSection.from_data(section_data)
            
        chunk.modified = False
        chunk.update_last_used()
        
        return chunk
        
    cpdef void generate(self, object generator):
        """Generate the terrain for this chunk."""
        if self.generated:
            return
            
        generator.generate_chunk(self)
        self.generated = True
        self.modified = True
        
    cpdef void populate(self, object generator, object world):
        """Populate the chunk with features after terrain generation."""
        if self.populated or not self.generated:
            return
            
        generator.populate_chunk(self, world)
        self.populated = True
        self.modified = True

cdef class TerrainGenerator:
    """Procedural terrain generator using scientific computing techniques."""
    cdef:
        public np.ndarray heightmap_cache
        public np.ndarray biome_map
        public dict noise_params
        public object rng
        public bint using_scientific
        
    def __cinit__(self, seed=None):
        """Initialize the terrain generator with the given seed."""
        if seed is None:
            import time
            seed = int(time.time())
            
        self.rng = np.random.RandomState(seed)
        self.noise_params = {
            'octaves': 6,
            'persistence': 0.5,
            'lacunarity': 2.0,
            'scale': 100.0,
            'offset': 0.0
        }
        
        # Use scientific libraries if available
        self.using_scientific = HAVE_SCIPY and HAVE_NOISE
        if not self.using_scientific:
            logger.warning("Scientific libraries not available, falling back to basic terrain generation")
            
        logger.info(f"Terrain generator initialized with seed {seed}")
        
    def generate_chunk(self, Chunk chunk):
        """Generate terrain for the given chunk."""
        cdef int32_t chunk_x = chunk.x
        cdef int32_t chunk_z = chunk.z
        cdef int world_x, world_z, height, biome
        cdef uint8_t block_id
        
        # Generate heightmap and biomes
        self._generate_heightmap(chunk)
        self._generate_biomes(chunk)
        
        # Generate terrain based on heightmap and biomes
        for x in range(CHUNK_SIZE):
            world_x = chunk_x * CHUNK_SIZE + x
            
            for z in range(CHUNK_SIZE):
                world_z = chunk_z * CHUNK_SIZE + z
                
                # Get height and biome for this column
                height = <int>chunk.height_map[x, z]
                biome = chunk.biomes[x, z]
                
                # Generate column
                self._generate_column(chunk, x, z, height, biome)
                
    def _generate_heightmap(self, Chunk chunk):
        """Generate the heightmap for this chunk."""
        cdef int32_t chunk_x = chunk.x
        cdef int32_t chunk_z = chunk.z
        cdef np.ndarray[np.float64_t, ndim=2] heightmap = np.zeros((CHUNK_SIZE, CHUNK_SIZE), dtype=np.float64)
        
        # Use perlin/simplex noise for smooth terrain
        if self.using_scientific:
            # Use the noise library for high-quality noise
            for x in range(CHUNK_SIZE):
                for z in range(CHUNK_SIZE):
                    world_x = chunk_x * CHUNK_SIZE + x
                    world_z = chunk_z * CHUNK_SIZE + z
                    
                    # Multi-octave noise for realistic terrain
                    h = noise.pnoise2(
                        world_x / self.noise_params['scale'], 
                        world_z / self.noise_params['scale'],
                        octaves=self.noise_params['octaves'],
                        persistence=self.noise_params['persistence'],
                        lacunarity=self.noise_params['lacunarity'],
                        repeatx=1024,
                        repeaty=1024,
                        base=0
                    )
                    
                    # Scale to desired height range (64-128 by default)
                    h = (h + 1) * 32 + 64
                    heightmap[x, z] = h
                    
            # Apply some gaussian smoothing for more natural terrain
            if HAVE_SCIPY:
                heightmap = ndimage.gaussian_filter(heightmap, sigma=1.0)
        else:
            # Simple alternative noise implementation
            for x in range(CHUNK_SIZE):
                for z in range(CHUNK_SIZE):
                    world_x = chunk_x * CHUNK_SIZE + x
                    world_z = chunk_z * CHUNK_SIZE + z
                    
                    # Simple noise function
                    h = self._simple_noise(world_x, world_z)
                    
                    # Scale to desired height range
                    h = h * 32 + 64
                    heightmap[x, z] = h
        
        # Store in chunk
        for x in range(CHUNK_SIZE):
            for z in range(CHUNK_SIZE):
                chunk.height_map[x, z] = <uint8_t>heightmap[x, z]
                
    def _simple_noise(self, double x, double z):
        """Simple noise function for when SciPy is not available."""
        # Very basic noise function using sin/cos
        cdef double nx = x * 0.01
        cdef double nz = z * 0.01
        cdef double noise = 0.0
        
        noise += sin(nx * 1.0 + nz * 0.5) * 0.5
        noise += sin(nx * 0.5 + nz * 1.0) * 0.25
        noise += sin(nx * 0.25 + nz * 0.5) * 0.125
        noise += sin(nx * 0.125 + nz * 0.25) * 0.0625
        
        return noise
                
    def _generate_biomes(self, Chunk chunk):
        """Generate biome distribution for the chunk."""
        cdef int32_t chunk_x = chunk.x
        cdef int32_t chunk_z = chunk.z
        cdef double temp, humidity
        
        # Generate temperature and humidity maps
        for x in range(CHUNK_SIZE):
            for z in range(CHUNK_SIZE):
                world_x = chunk_x * CHUNK_SIZE + x
                world_z = chunk_z * CHUNK_SIZE + z
                height = chunk.height_map[x, z]
                
                # Temperature decreases with height and latitude (distance from equator)
                if self.using_scientific:
                    temp = noise.pnoise2(
                        world_x / 200.0, 
                        world_z / 200.0, 
                        octaves=2,
                        persistence=0.5,
                        lacunarity=2.0
                    )
                    
                    # Humidity noise
                    humidity = noise.pnoise2(
                        world_x / 150.0 + 500, 
                        world_z / 150.0 + 500, 
                        octaves=3,
                        persistence=0.4,
                        lacunarity=2.0
                    )
                else:
                    # Simple temperature and humidity
                    temp = self._simple_noise(world_x * 0.5, world_z * 0.5)
                    humidity = self._simple_noise(world_x * 0.5 + 500, world_z * 0.5 + 500)
                
                # Adjust temperature by height
                temp -= (height - 64) * 0.01
                
                # Determine biome based on temperature and humidity
                biome = self._get_biome(temp, humidity, height)
                chunk.biomes[x, z] = biome
                
    def _get_biome(self, double temp, double humidity, int height):
        """Determine biome type based on temperature and humidity."""
        if height < 60:
            # Water biomes
            return BiomeType.OCEAN
        elif height > 120:
            # Mountain biomes
            if temp < -0.3:
                return BiomeType.SNOWY_TUNDRA
            else:
                return BiomeType.MOUNTAINS
        else:
            # Land biomes
            if temp < -0.5:
                return BiomeType.SNOWY_TUNDRA
            elif temp < 0.0:
                if humidity > 0.3:
                    return BiomeType.TAIGA
                else:
                    return BiomeType.PLAINS
            elif temp < 0.5:
                if humidity > 0.6:
                    return BiomeType.SWAMP
                elif humidity > 0.3:
                    return BiomeType.FOREST
                else:
                    return BiomeType.PLAINS
            else:
                if humidity > 0.6:
                    return BiomeType.JUNGLE
                elif humidity > 0.2:
                    return BiomeType.SAVANNA
                else:
                    return BiomeType.DESERT
                    
    def _generate_column(self, Chunk chunk, int x, int z, int height, int biome):
        """Generate a single column of blocks."""
        cdef int stone_height = height - self.rng.randint(3, 6)
        
        # Set blocks from bottom to top
        for y in range(MIN_HEIGHT, MAX_HEIGHT):
            # Bedrock layer at the bottom
            if y <= MIN_HEIGHT + 3:
                if y == MIN_HEIGHT or self.rng.random() < 0.7:
                    chunk.set_block(x, y, z, 1)  # Bedrock
                else:
                    chunk.set_block(x, y, z, 2)  # Stone
            
            # Stone layer
            elif y <= stone_height:
                chunk.set_block(x, y, z, 2)  # Stone
            
            # Surface layers based on biome
            elif y <= height:
                self._set_surface_block(chunk, x, y, z, biome, height, stone_height)
            
            # Water
            elif y <= 63 and height < 63:
                chunk.set_block(x, y, z, 8)  # Water
                
    def _set_surface_block(self, Chunk chunk, int x, int y, int z, int biome, int height, int stone_height):
        """Set the appropriate surface block based on biome."""
        cdef int depth = height - y
        
        # Top layer (surface block)
        if depth == 0:
            if biome == BiomeType.DESERT:
                chunk.set_block(x, y, z, 12)  # Sand
            elif biome == BiomeType.SNOWY_TUNDRA:
                chunk.set_block(x, y, z, 78)  # Snow
            elif biome in (BiomeType.SWAMP, BiomeType.RIVER, BiomeType.OCEAN) and y <= 65:
                chunk.set_block(x, y, z, 3)  # Dirt
            else:
                chunk.set_block(x, y, z, 4)  # Grass
        
        # Subsurface layers
        elif depth <= 3:
            if biome == BiomeType.DESERT:
                chunk.set_block(x, y, z, 12)  # Sand
            else:
                chunk.set_block(x, y, z, 3)  # Dirt
        
        # Transition to stone
        elif depth <= 5:
            chunk.set_block(x, y, z, 3)  # Dirt with occasional gravel
            if self.rng.random() < 0.2:
                chunk.set_block(x, y, z, 13)  # Gravel
        
        # Below is stone with occasional ores
        else:
            if self.rng.random() < 0.01:
                # Random ore distribution - this would be more complex in real implementation
                ore_chance = self.rng.random()
                if ore_chance < 0.4:
                    chunk.set_block(x, y, z, 14)  # Coal ore
                elif ore_chance < 0.7:
                    chunk.set_block(x, y, z, 15)  # Iron ore
                elif ore_chance < 0.85:
                    chunk.set_block(x, y, z, 16)  # Gold ore
                elif ore_chance < 0.95:
                    chunk.set_block(x, y, z, 17)  # Redstone ore
                else:
                    chunk.set_block(x, y, z, 18)  # Diamond ore
            else:
                chunk.set_block(x, y, z, 2)  # Stone
                
    def populate_chunk(self, Chunk chunk, object world):
        """Add features to a generated chunk."""
        cdef int32_t chunk_x = chunk.x
        cdef int32_t chunk_z = chunk.z
        cdef int biome
        
        # We need surrounding chunks to be generated for proper population
        if not world.are_surrounding_chunks_generated(chunk_x, chunk_z, 1):
            return
            
        # Populate based on biomes
        for x in range(CHUNK_SIZE):
            for z in range(CHUNK_SIZE):
                biome = chunk.biomes[x, z]
                height = chunk.height_map[x, z]
                
                # Only add features on land
                if height > 63:
                    world_x = chunk_x * CHUNK_SIZE + x
                    world_z = chunk_z * CHUNK_SIZE + z
                    
                    # Add trees
                    self._add_trees(chunk, world, x, z, height, biome)
                    
                    # Add vegetation
                    self._add_vegetation(chunk, x, z, height, biome)
                    
                    # Add structures (villages, temples, etc.)
                    # This would be more complex and require multi-chunk coordination
                    
        # Add ore veins
        self._add_ore_veins(chunk)
        
        # Add caves
        self._add_caves(chunk)
        
    def _add_trees(self, Chunk chunk, object world, int x, int z, int height, int biome):
        """Add trees to the chunk based on biome."""
        cdef int world_x = chunk.x * CHUNK_SIZE + x
        cdef int world_z = chunk.z * CHUNK_SIZE + z
        
        # Different tree density and types based on biome
        cdef double tree_chance = 0.01  # Default low chance
        
        if biome == BiomeType.FOREST:
            tree_chance = 0.1
        elif biome == BiomeType.TAIGA:
            tree_chance = 0.08
        elif biome == BiomeType.JUNGLE:
            tree_chance = 0.2
        elif biome == BiomeType.PLAINS:
            tree_chance = 0.02
        elif biome == BiomeType.SWAMP:
            tree_chance = 0.04
        elif biome in (BiomeType.DESERT, BiomeType.SNOWY_TUNDRA, BiomeType.OCEAN):
            tree_chance = 0.0
            
        # Randomize tree placement
        if self.rng.random() < tree_chance:
            # Make sure we're on solid ground
            block_below = chunk.get_block(x, height - 1, z)
            if block_below in (3, 4):  # Dirt or grass
                tree_type = self._get_tree_type(biome)
                self._generate_tree(world, world_x, height, world_z, tree_type)
                
    def _get_tree_type(self, int biome):
        """Determine the type of tree for the given biome."""
        if biome == BiomeType.TAIGA:
            return "spruce"
        elif biome == BiomeType.JUNGLE:
            return "jungle"
        elif biome == BiomeType.SWAMP:
            return "swamp_oak"
        elif biome == BiomeType.FOREST:
            if self.rng.random() < 0.2:
                return "birch"
            else:
                return "oak"
        else:
            return "oak"
            
    def _generate_tree(self, object world, int x, int y, int z, str tree_type):
        """Generate a tree at the given position."""
        # This is a placeholder - a real implementation would have different tree shapes
        cdef int trunk_height
        
        if tree_type == "oak":
            trunk_height = self.rng.randint(4, 6)
            # Trunk
            for dy in range(trunk_height):
                world.set_block(x, y + dy, z, 5)  # Oak wood
                
            # Leaves
            for dx in range(-2, 3):
                for dz in range(-2, 3):
                    for dy in range(trunk_height - 2, trunk_height + 2):
                        if abs(dx) == 2 and abs(dz) == 2:
                            continue  # Skip corners
                        if dy == trunk_height + 1 and (abs(dx) > 1 or abs(dz) > 1):
                            continue  # Top layer is smaller
                        world.set_block(x + dx, y + dy, z + dz, 6)  # Leaves
                        
        elif tree_type == "spruce":
            trunk_height = self.rng.randint(6, 8)
            # Trunk
            for dy in range(trunk_height):
                world.set_block(x, y + dy, z, 5)  # Spruce wood
                
            # Leaves (pyramid shape)
            for layer in range(4):
                size = 3 - layer
                for dx in range(-size, size + 1):
                    for dz in range(-size, size + 1):
                        leaf_y = y + trunk_height - layer - 1
                        world.set_block(x + dx, leaf_y, z + dz, 6)  # Leaves
                        
    def _add_vegetation(self, Chunk chunk, int x, int z, int height, int biome):
        """Add grass, flowers, etc. based on biome."""
        # Simple grass and flowers
        if biome in (BiomeType.PLAINS, BiomeType.FOREST, BiomeType.TAIGA, BiomeType.SWAMP):
            if self.rng.random() < 0.3:  # 30% chance for vegetation
                if chunk.get_block(x, height, z) == 0:  # Air
                    block_below = chunk.get_block(x, height - 1, z)
                    if block_below == 4:  # Grass block
                        # Tall grass or flowers
                        if self.rng.random() < 0.8:
                            chunk.set_block(x, height, z, 31)  # Tall grass
                        else:
                            chunk.set_block(x, height, z, 37)  # Flower
                            
    def _add_ore_veins(self, Chunk chunk):
        """Add ore veins to the chunk."""
        cdef int num_veins = self.rng.randint(5, 12)
        
        for _ in range(num_veins):
            # Random vein parameters
            x = self.rng.randint(0, CHUNK_SIZE)
            y = self.rng.randint(MIN_HEIGHT + 5, 64)
            z = self.rng.randint(0, CHUNK_SIZE)
            size = self.rng.randint(3, 8)
            
            # Determine ore type based on depth
            ore_type = self._get_ore_type(y)
            
            # Generate a small sphere of ore
            for dx in range(-size, size + 1):
                for dy in range(-size, size + 1):
                    for dz in range(-size, size + 1):
                        # Only place within sphere
                        if dx*dx + dy*dy + dz*dz > size*size:
                            continue
                            
                        # Place ore with decreasing probability from center
                        if self.rng.random() < 0.7:
                            nx, ny, nz = x + dx, y + dy, z + dz
                            
                            # Check if within chunk bounds
                            if 0 <= nx < CHUNK_SIZE and MIN_HEIGHT <= ny < MAX_HEIGHT and 0 <= nz < CHUNK_SIZE:
                                if chunk.get_block(nx, ny, nz) == 2:  # If it's stone
                                    chunk.set_block(nx, ny, nz, ore_type)
                                    
    def _get_ore_type(self, int y):
        """Determine ore type based on depth."""
        # Different ore distributions at different heights
        if y < 16:
            # Deep ores
            chance = self.rng.random()
            if chance < 0.01:
                return 18  # Diamond
            elif chance < 0.05:
                return 17  # Redstone
            elif chance < 0.2:
                return 16  # Gold
            else:
                return 15  # Iron
        elif y < 40:
            # Mid-depth ores
            chance = self.rng.random()
            if chance < 0.3:
                return 15  # Iron
            elif chance < 0.6:
                return 14  # Coal
            else:
                return 16  # Gold
        else:
            # Shallow ores
            chance = self.rng.random()
            if chance < 0.7:
                return 14  # Coal
            else:
                return 15  # Iron
                
    def _add_caves(self, Chunk chunk):
        """Add cave systems to the chunk."""
        # This is a placeholder - real cave generation would be more complex
        # and would coordinate across chunks
        pass

cdef class WorldEngine:
    """Main world engine that manages chunks and world operations."""
    cdef:
        public str world_path
        public dict chunks
        public TerrainGenerator generator
        public int view_distance
        public int max_chunks
        public object save_lock
        public object chunk_lock
        public object thread_pool
        
    def __cinit__(self, str world_path, int view_distance=10):
        """Initialize the world engine with the given world path."""
        self.world_path = world_path
        self.view_distance = view_distance
        self.max_chunks = view_distance * view_distance * 4 * 10  # Cache 10x the view area
        self.chunks = {}
        self.save_lock = threading.RLock()
        self.chunk_lock = threading.RLock()
        
        # Create world directory if it doesn't exist
        os.makedirs(world_path, exist_ok=True)
        os.makedirs(os.path.join(world_path, "chunks"), exist_ok=True)
        
        # Create thread pool for async chunk operations
        self.thread_pool = ThreadPoolExecutor(max_workers=4)
        
        # Read world data
        self._load_world_data()
        
        # Initialize terrain generator
        self.generator = TerrainGenerator(seed=42)  # Use a fixed seed for now
        
        logger.info(f"World engine initialized with path {world_path} and view distance {view_distance}")
        
    def _load_world_data(self):
        """Load world metadata."""
        world_data_path = os.path.join(self.world_path, "world.dat")
        
        if os.path.exists(world_data_path):
            try:
                with open(world_data_path, "rb") as f:
                    if HAVE_MSGPACK:
                        data = msgpack.unpackb(f.read(), raw=False)
                    else:
                        import pickle
                        data = pickle.load(f)
                        
                # Process world data
                # (would handle more world metadata in a full implementation)
                logger.info(f"Loaded world data from {world_data_path}")
                
            except Exception as e:
                logger.error(f"Error loading world data: {e}", exc_info=True)
                # Create new world data
                self._save_world_data()
        else:
            # Create new world data
            self._save_world_data()
            
    def _save_world_data(self):
        """Save world metadata."""
        world_data_path = os.path.join(self.world_path, "world.dat")
        
        with self.save_lock:
            try:
                # World data
                data = {
                    "version": 1,
                    "name": "MCPy World",
                    "seed": 42,
                    "time": 0,
                    "spawn_x": 0,
                    "spawn_y": 64,
                    "spawn_z": 0,
                }
                
                with open(world_data_path, "wb") as f:
                    if HAVE_MSGPACK:
                        f.write(msgpack.packb(data, use_bin_type=True))
                    else:
                        import pickle
                        pickle.dump(data, f)
                        
                logger.info(f"Saved world data to {world_data_path}")
                
            except Exception as e:
                logger.error(f"Error saving world data: {e}", exc_info=True)
                
    def update(self, uint64_t tick_number):
        """Update the world state for this tick."""
        # For now, just save chunks periodically
        if tick_number % 20 * 60 * 5 == 0:  # Every 5 minutes (at 20 TPS)
            self.save_all()
            
        # Process chunk updates
        self._process_chunk_updates(tick_number)
        
        # Process pending chunk loads/unloads
        self._process_chunk_queue()
        
    def _process_chunk_updates(self, uint64_t tick_number):
        """Process updates for loaded chunks."""
        # This would handle block updates, physics, etc.
        pass
        
    def _process_chunk_queue(self):
        """Process pending chunk operations."""
        # This would handle asynchronous chunk loading/unloading
        pass
        
    cpdef Chunk get_chunk(self, int32_t chunk_x, int32_t chunk_z, bint generate=True):
        """Get a chunk at the given coordinates, loading or generating it if needed."""
        cdef str chunk_key = f"{chunk_x},{chunk_z}"
        
        with self.chunk_lock:
            if chunk_key in self.chunks:
                chunk = self.chunks[chunk_key]
                chunk.update_last_used()
                return chunk
                
            # Load or generate the chunk
            chunk = self._load_chunk(chunk_x, chunk_z)
            
            if chunk is None and generate:
                chunk = Chunk(chunk_x, chunk_z)
                chunk.generate(self.generator)
                
            if chunk is not None:
                self.chunks[chunk_key] = chunk
                
                # If we have too many chunks loaded, unload some
                if len(self.chunks) > self.max_chunks:
                    self._unload_oldest_chunks()
                    
            return chunk
            
    def _load_chunk(self, int32_t chunk_x, int32_t chunk_z):
        """Load a chunk from disk."""
        chunk_path = self._get_chunk_path(chunk_x, chunk_z)
        
        if not os.path.exists(chunk_path):
            return None
            
        try:
            with open(chunk_path, "rb") as f:
                if HAVE_MSGPACK:
                    data = msgpack.unpackb(f.read(), raw=False)
                else:
                    import pickle
                    data = pickle.load(f)
                    
            chunk = Chunk.from_data(data)
            logger.debug(f"Loaded chunk ({chunk_x}, {chunk_z})")
            return chunk
            
        except Exception as e:
            logger.error(f"Error loading chunk ({chunk_x}, {chunk_z}): {e}", exc_info=True)
            return None
            
    def _save_chunk(self, Chunk chunk):
        """Save a chunk to disk."""
        if not chunk.modified:
            return
            
        chunk_path = self._get_chunk_path(chunk.x, chunk.z)
        
        with self.save_lock:
            try:
                data = chunk.to_data()
                
                with open(chunk_path, "wb") as f:
                    if HAVE_MSGPACK:
                        f.write(msgpack.packb(data, use_bin_type=True))
                    else:
                        import pickle
                        pickle.dump(data, f)
                        
                chunk.modified = False
                logger.debug(f"Saved chunk ({chunk.x}, {chunk.z})")
                
            except Exception as e:
                logger.error(f"Error saving chunk ({chunk.x}, {chunk.z}): {e}", exc_info=True)
                
    def _get_chunk_path(self, int32_t chunk_x, int32_t chunk_z):
        """Get the file path for a chunk."""
        # Use a region-based system for efficient storage
        region_x = chunk_x >> 5  # 32 chunks per region
        region_z = chunk_z >> 5
        
        region_dir = os.path.join(self.world_path, "chunks", f"r.{region_x}.{region_z}")
        os.makedirs(region_dir, exist_ok=True)
        
        # Store each chunk in its own file
        local_x = chunk_x & 31
        local_z = chunk_z & 31
        
        return os.path.join(region_dir, f"c.{local_x}.{local_z}.dat")
        
    def _unload_oldest_chunks(self):
        """Unload the oldest unused chunks."""
        # Find the 10% oldest chunks
        cdef int num_to_unload = max(1, len(self.chunks) // 10)
        
        with self.chunk_lock:
            # Sort chunks by last used time
            chunks_by_age = sorted(self.chunks.items(), key=lambda x: x[1].last_used)
            
            # Unload the oldest chunks
            for i in range(num_to_unload):
                if i >= len(chunks_by_age):
                    break
                    
                chunk_key, chunk = chunks_by_age[i]
                
                # Save chunk if modified
                if chunk.modified:
                    self._save_chunk(chunk)
                    
                # Remove from loaded chunks
                del self.chunks[chunk_key]
                logger.debug(f"Unloaded chunk ({chunk.x}, {chunk.z})")
                
    def save_all(self):
        """Save all modified chunks."""
        save_count = 0
        with self.chunk_lock:
            for chunk in self.chunks.values():
                if chunk.modified:
                    self._save_chunk(chunk)
                    save_count += 1
                    
        logger.info(f"Saved {save_count} modified chunks")
        
        # Save world data
        self._save_world_data()
        
    cpdef uint8_t get_block(self, int x, int y, int z) except? 0:
        """Get the block at the given world coordinates."""
        if not MIN_HEIGHT <= y < MAX_HEIGHT:
            return 0
            
        cdef int32_t chunk_x = x >> 4
        cdef int32_t chunk_z = z >> 4
        cdef int local_x = x & 15
        cdef int local_z = z & 15
        
        cdef Chunk chunk = self.get_chunk(chunk_x, chunk_z, False)
        if chunk is None:
            return 0
            
        return chunk.get_block(local_x, y, local_z)
        
    cpdef bint set_block(self, int x, int y, int z, uint8_t block_id) except? False:
        """Set the block at the given world coordinates."""
        if not MIN_HEIGHT <= y < MAX_HEIGHT:
            return False
            
        cdef int32_t chunk_x = x >> 4
        cdef int32_t chunk_z = z >> 4
        cdef int local_x = x & 15
        cdef int local_z = z & 15
        
        cdef Chunk chunk = self.get_chunk(chunk_x, chunk_z, True)
        if chunk is None:
            return False
            
        return chunk.set_block(local_x, y, local_z, block_id)
        
    def generate_chunk(self, int32_t chunk_x, int32_t chunk_z):
        """Generate a chunk at the given coordinates."""
        with self.chunk_lock:
            chunk = self.get_chunk(chunk_x, chunk_z, False)
            
            if chunk is None:
                chunk = Chunk(chunk_x, chunk_z)
                chunk.generate(self.generator)
                
                chunk_key = f"{chunk_x},{chunk_z}"
                self.chunks[chunk_key] = chunk
                
    def populate_chunk(self, int32_t chunk_x, int32_t chunk_z):
        """Populate a generated chunk with features."""
        with self.chunk_lock:
            chunk = self.get_chunk(chunk_x, chunk_z, False)
            
            if chunk is not None and chunk.generated and not chunk.populated:
                chunk.populate(self.generator, self)
                
    def are_surrounding_chunks_generated(self, int32_t chunk_x, int32_t chunk_z, int radius):
        """Check if all chunks in the given radius are generated."""
        for dx in range(-radius, radius + 1):
            for dz in range(-radius, radius + 1):
                nx, nz = chunk_x + dx, chunk_z + dz
                chunk = self.get_chunk(nx, nz, False)
                
                if chunk is None or not chunk.generated:
                    return False
                    
        return True
        
    def get_loaded_chunk_count(self):
        """Get the number of currently loaded chunks."""
        with self.chunk_lock:
            return len(self.chunks)
            
    def get_world_info(self):
        """Get information about the world."""
        with self.chunk_lock:
            return {
                "path": self.world_path,
                "chunks_loaded": len(self.chunks),
                "view_distance": self.view_distance,
            }
