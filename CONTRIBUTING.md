# Contributing to MCPy

Thank you for your interest in contributing to MCPy! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project. We expect all contributors to adhere to the following principles:

- Be respectful of differing viewpoints and experiences
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards other community members

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include as many details as possible:

- Use a clear and descriptive title
- Describe the exact steps to reproduce the problem
- Describe the behavior you observed and what you expected to happen
- Include screenshots if applicable
- Include details about your environment (OS, Python version, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- Use a clear and descriptive title
- Provide a detailed description of the proposed feature
- Explain why this enhancement would be useful
- List potential implementation approaches if possible
- Include mockups or examples if applicable

### Pull Requests

- Fill in the required template
- Follow the Python coding style (PEP 8)
- Include appropriate tests
- Update documentation as needed
- End files with a newline
- Place imports in the following order:
  - Standard library imports
  - Related third-party imports
  - Local application/library specific imports
- Include meaningful commit messages

## Development Environment Setup

1. Fork and clone the repository
2. Create a virtual environment:
   ```bash
   python -m venv venv
   ```
3. Activate the virtual environment:
   - Windows: `venv\Scripts\activate`
   - Unix/macOS: `source venv/bin/activate`
4. Install development dependencies:
   ```bash
   pip install -r _requirements.txt
   pip install -e ".[dev]"
   ```
5. Build the Cython modules:
   ```bash
   python setup.py build_ext --inplace
   ```

## Cython Development Guidelines

When working with Cython code:

1. Define types for all variables and function arguments
2. Use appropriate compiler directives
3. Minimize Python API calls in performance-critical sections
4. Leverage NumPy's C API where appropriate
5. Test performance gains with benchmarks

Example of good Cython code:

```cython
# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True
from libc.math cimport sqrt, pow
import numpy as np
cimport numpy as np

cdef double calculate_distance(double x1, double y1, double x2, double y2) nogil:
    cdef double dx = x2 - x1
    cdef double dy = y2 - y1
    return sqrt(dx * dx + dy * dy)

def process_points(np.ndarray[double, ndim=2] points):
    cdef int i, j
    cdef int n = points.shape[0]
    cdef np.ndarray[double, ndim=2] result = np.zeros((n, n), dtype=np.float64)
    
    for i in range(n):
        for j in range(n):
            result[i, j] = calculate_distance(
                points[i, 0], points[i, 1],
                points[j, 0], points[j, 1]
            )
    
    return result
```

## Testing

- Write tests for all new features and bug fixes
- Run the test suite before submitting a pull request:
  ```bash
  pytest
  ```
- Aim for high test coverage

## Documentation

- Update the README.md if needed
- Document all public functions, classes, and methods
- Use docstrings that follow Google or NumPy style
- Create or update examples as appropriate

## Performance Considerations

MCPy is designed for high performance. Please keep these principles in mind:

1. Use profiling to identify bottlenecks
2. Prioritize algorithm efficiency over micro-optimizations
3. Consider memory usage implications
4. Test performance on various hardware configurations
5. Document performance characteristics of new features

## Current Build/Contribution Blockers

We are currently experiencing several Cython compilation errors in `mcpy/core/entity_system.pyx` and related files. **Community assistance is highly encouraged to help resolve these errors.** 

Please see `CYTHON_ERROR.md` in the repository for the complete error log and details. A summary of the issues:

- C attributes (like `health`, `max_health`, `ai_controller`, `hostile`) are being redeclared in the `.pyx` file, but were already declared in the corresponding `.pxd` file (`C attributes cannot be added in implementation part of extension type defined in a pxd`).
- Several methods declared in the `.pxd` file (such as `can_attack`, `attack`, `_get_attack_damage`, `can_breed`, `breed`, `add_passenger`, `remove_passenger`, `create_entity`, `_configure_mob_properties`, `_get_mob_health`) are **not defined** in the `.pyx` file (`C method ... is declared but not defined`).
- There are warnings about `noexcept` clauses being ignored for functions returning Python objects.

**If you have experience with Cython or similar issues, your contributions or suggestions would be extremely helpful!**

## Additional Notes

### Git Workflow

1. Create a new branch for each feature or fix
2. Make commits of logical units
3. Use clear and consistent commit messages
4. Rebase your branch before submitting a PR
5. Squash related commits if appropriate

### Issue and Pull Request Labels

- `bug`: Something isn't working as expected
- `enhancement`: New feature or request
- `documentation`: Documentation improvements
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention is needed
- `performance`: Related to performance improvements
- `testing`: Related to testing

## Thank You!

Your contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

---
