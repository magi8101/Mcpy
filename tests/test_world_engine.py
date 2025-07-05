"""
Tests for the MCPy world engine.
"""

import os
import shutil
import tempfile
import unittest

import numpy as np

from mcpy.core.world_engine import WorldEngine, TerrainGenerator, Chunk, ChunkSection


class TestChunkSection(unittest.TestCase):
    """Test the ChunkSection class."""
    
    def setUp(self):
        """Set up test environment."""
        self.section = ChunkSection(0)
        
    def test_get_set_block(self):
        """Test getting and setting blocks."""
        # Initial state should be empty
        self.assertTrue(self.section.empty)
        self.assertTrue(self.section.all_air)
        
        # Get a block that hasn't been set
        block_id = self.section.get_block(0, 0, 0)
        self.assertEqual(block_id, 0)  # Should be air
        
        # Set a block
        success = self.section.set_block(0, 0, 0, 1)
        self.assertTrue(success)
        self.assertTrue(self.section.modified)
        self.assertFalse(self.section.empty)
        self.assertFalse(self.section.all_air)
        
        # Get the block we just set
        block_id = self.section.get_block(0, 0, 0)
        self.assertEqual(block_id, 1)
        
        # Set the block back to air
        success = self.section.set_block(0, 0, 0, 0)
        self.assertTrue(success)
        self.assertTrue(self.section.modified)
        self.assertTrue(self.section.all_air)
        
        # Try to set a block outside the valid range
        success = self.section.set_block(16, 0, 0, 1)
        self.assertFalse(success)
        
    def test_to_from_data(self):
        """Test conversion to and from data dictionaries."""
        # Set some blocks
        self.section.set_block(0, 0, 0, 1)
        self.section.set_block(1, 1, 1, 2)
        self.section.set_block(2, 2, 2, 3)
        
        # Convert to data
        data = self.section.to_data()
        self.assertEqual(data['y_index'], 0)
        self.assertFalse(data['empty'])
        
        # Create a new section from the data
        new_section = ChunkSection.from_data(data)
        self.assertEqual(new_section.y_index, 0)
        self.assertFalse(new_section.empty)
        self.assertFalse(new_section.all_air)
        
        # Check that the blocks were preserved
        self.assertEqual(new_section.get_block(0, 0, 0), 1)
        self.assertEqual(new_section.get_block(1, 1, 1), 2)
        self.assertEqual(new_section.get_block(2, 2, 2), 3)


class TestChunk(unittest.TestCase):
    """Test the Chunk class."""
    
    def setUp(self):
        """Set up test environment."""
        self.chunk = Chunk(0, 0)
        
    def test_get_set_block(self):
        """Test getting and setting blocks."""
        # Set a block in a section that doesn't exist yet
        success = self.chunk.set_block(0, 64, 0, 1)
        self.assertTrue(success)
        self.assertTrue(self.chunk.modified)
        
        # Check that the section was created
        section_y = 64 // 16
        self.assertIn(section_y, self.chunk.sections)
        
        # Get the block we just set
        block_id = self.chunk.get_block(0, 64, 0)
        self.assertEqual(block_id, 1)
        
        # Set a block outside the chunk
        success = self.chunk.set_block(16, 64, 0, 1)
        self.assertFalse(success)
        
    def test_height_map(self):
        """Test that the height map is updated correctly."""
        # Set a block
        self.chunk.set_block(0, 64, 0, 1)
        self.assertEqual(self.chunk.height_map[0, 0], 64)
        
        # Set a higher block
        self.chunk.set_block(0, 70, 0, 1)
        self.assertEqual(self.chunk.height_map[0, 0], 70)
        
        # Set a lower block
        self.chunk.set_block(0, 60, 0, 1)
        self.assertEqual(self.chunk.height_map[0, 0], 70)  # Should still be 70
        
        # Remove the highest block
        self.chunk.set_block(0, 70, 0, 0)
        self.assertEqual(self.chunk.height_map[0, 0], 64)  # Should be updated to 64
        
        # Remove the remaining block
        self.chunk.set_block(0, 64, 0, 0)
        self.assertEqual(self.chunk.height_map[0, 0], 60)  # Should be updated to 60
        
    def test_to_from_data(self):
        """Test conversion to and from data dictionaries."""
        # Set some blocks
        self.chunk.set_block(0, 64, 0, 1)
        self.chunk.set_block(1, 65, 1, 2)
        self.chunk.set_block(2, 66, 2, 3)
        
        # Set generated and populated flags
        self.chunk.generated = True
        self.chunk.populated = True
        
        # Convert to data
        data = self.chunk.to_data()
        self.assertEqual(data['x'], 0)
        self.assertEqual(data['z'], 0)
        self.assertTrue(data['generated'])
        self.assertTrue(data['populated'])
        
        # Create a new chunk from the data
        new_chunk = Chunk.from_data(data)
        self.assertEqual(new_chunk.x, 0)
        self.assertEqual(new_chunk.z, 0)
        self.assertTrue(new_chunk.generated)
        self.assertTrue(new_chunk.populated)
        
        # Check that the blocks were preserved
        self.assertEqual(new_chunk.get_block(0, 64, 0), 1)
        self.assertEqual(new_chunk.get_block(1, 65, 1), 2)
        self.assertEqual(new_chunk.get_block(2, 66, 2), 3)


class TestTerrainGenerator(unittest.TestCase):
    """Test the TerrainGenerator class."""
    
    def setUp(self):
        """Set up test environment."""
        self.generator = TerrainGenerator(seed=42)
        
    def test_generate_chunk(self):
        """Test generating a chunk."""
        chunk = Chunk(0, 0)
        self.generator.generate_chunk(chunk)
        
        self.assertTrue(chunk.generated)
        self.assertTrue(chunk.modified)
        
        # Check that the chunk has been populated with blocks
        has_blocks = False
        for section in chunk.sections.values():
            if not section.all_air:
                has_blocks = True
                break
                
        self.assertTrue(has_blocks)
        
        # Check that the height map has been populated
        self.assertTrue(np.any(chunk.height_map > 0))
        
        # Check that biomes have been assigned
        self.assertTrue(np.any(chunk.biomes > 0))


class TestWorldEngine(unittest.TestCase):
    """Test the WorldEngine class."""
    
    def setUp(self):
        """Set up test environment."""
        self.temp_dir = tempfile.mkdtemp()
        self.world = WorldEngine(self.temp_dir, view_distance=4)
        
    def tearDown(self):
        """Clean up test environment."""
        shutil.rmtree(self.temp_dir)
        
    def test_get_chunk(self):
        """Test getting a chunk."""
        # Get a chunk that doesn't exist yet
        chunk = self.world.get_chunk(0, 0, True)
        
        self.assertIsNotNone(chunk)
        self.assertEqual(chunk.x, 0)
        self.assertEqual(chunk.z, 0)
        self.assertTrue(chunk.generated)
        
        # Check that the chunk is cached
        self.assertIn("0,0", self.world.chunks)
        
        # Get the same chunk again
        same_chunk = self.world.get_chunk(0, 0, True)
        self.assertIs(same_chunk, chunk)
        
    def test_get_set_block(self):
        """Test getting and setting blocks."""
        # Set a block
        success = self.world.set_block(0, 64, 0, 1)
        self.assertTrue(success)
        
        # Get the block we just set
        block_id = self.world.get_block(0, 64, 0)
        self.assertEqual(block_id, 1)
        
        # Set a block in a different chunk
        success = self.world.set_block(16, 64, 16, 2)
        self.assertTrue(success)
        
        # Get the block we just set
        block_id = self.world.get_block(16, 64, 16)
        self.assertEqual(block_id, 2)
        
    def test_save_load_chunk(self):
        """Test saving and loading chunks."""
        # Generate a chunk and modify it
        chunk = self.world.get_chunk(0, 0, True)
        chunk.set_block(0, 64, 0, 1)
        chunk.modified = True
        
        # Save the chunk
        self.world._save_chunk(chunk)
        
        # Remove the chunk from memory
        del self.world.chunks["0,0"]
        
        # Load the chunk back
        loaded_chunk = self.world._load_chunk(0, 0)
        
        self.assertIsNotNone(loaded_chunk)
        self.assertEqual(loaded_chunk.x, 0)
        self.assertEqual(loaded_chunk.z, 0)
        self.assertEqual(loaded_chunk.get_block(0, 64, 0), 1)
        
    def test_unload_oldest_chunks(self):
        """Test unloading oldest chunks."""
        # Generate several chunks
        chunks_to_generate = 20
        for i in range(chunks_to_generate):
            self.world.get_chunk(i, 0, True)
            
        # Check that they're all loaded
        self.assertEqual(len(self.world.chunks), chunks_to_generate)
        
        # Access a chunk to update its last_used time
        chunk = self.world.get_chunk(0, 0, False)
        chunk.update_last_used()
        
        # Force unloading
        self.world._unload_oldest_chunks()
        
        # Check that some chunks were unloaded
        self.assertLess(len(self.world.chunks), chunks_to_generate)
        
        # The most recently used chunk should still be loaded
        self.assertIn("0,0", self.world.chunks)


if __name__ == '__main__':
    unittest.main()
