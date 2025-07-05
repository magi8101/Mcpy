#!/usr/bin/env python
from setuptools import Extension, setup
from Cython.Build import cythonize
import numpy as np
import os
import sys

# Define Cython extension modules
extensions = [
    Extension(
        name="mcpy.core.server_core",
        sources=["mcpy/core/server_core.pyx"],
        include_dirs=[np.get_include()],
        extra_compile_args=["-O3", "-march=native", "-ffast-math"],
        language="c++",
    ),
    Extension(
        name="mcpy.core.world_engine",
        sources=["mcpy/core/world_engine.pyx"],
        include_dirs=[np.get_include()],
        extra_compile_args=["-O3", "-march=native", "-ffast-math"],
        language="c++",
    ),
    Extension(
        name="mcpy.core.network_core",
        sources=["mcpy/core/network_core.pyx"],
        include_dirs=[np.get_include()],
        extra_compile_args=["-O3", "-march=native", "-ffast-math"],
        language="c++",
    ),
    Extension(
        name="mcpy.core.entity_system",
        sources=["mcpy/core/entity_system.pyx"],
        include_dirs=[np.get_include()],
        extra_compile_args=["-O3", "-march=native", "-ffast-math"],
        language="c++",
    ),
]

# Windows-specific compiler flags
if sys.platform == 'win32':
    for e in extensions:
        e.extra_compile_args = ["/O2", "/arch:AVX2", "/fp:fast"]

setup(
    ext_modules=cythonize(
        extensions,
        compiler_directives={
            "language_level": 3,
            "boundscheck": False,
            "wraparound": False,
            "cdivision": True,
            "embedsignature": True,
            "initializedcheck": False,
            "nonecheck": False,
        },
    ),
)
