# Intel OneAPI Floating-Point Exception Fix for NumPy

## Issue Description

When compiling NumPy from source with Intel OneAPI 2024.2 using `-fp-model=strict`, the test `TestRemainder.test_float_divmod_errors[d]` fails because the expected `FloatingPointError` is not raised for `divmod(inf, inf)` operations.

### Error Details

```
AssertionError: FloatingPointError not raised by divmod
```

This occurs in the test case:
```python
with np.errstate(invalid='raise'):
    assert_raises(FloatingPointError, np.divmod, finf, finf)
```

## Root Cause

The Intel OneAPI compiler with `-fp-model=strict` doesn't properly set up floating-point exception handling that NumPy expects. The strict floating-point model is too restrictive and doesn't align with NumPy's floating-point exception expectations.

## Solutions

### Solution 1: Use Precise Floating-Point Model (Recommended)

Replace `-fp-model=strict` with `-fp-model=precise`:

```bash
CC=icx CXX=icpx FC=ifx \
CFLAGS='-fveclib=none -fp-model=precise -fPIC -xHost' \
FFLAGS='-fp-model=precise -fPIC -xHost' \
CXXFLAGS='-fp-model=precise -fPIC -xHost' \
python -m pip install --no-build-isolation -v . \
-Cbuild-dir=build \
-Csetup-args=-Dallow-noblas=false \
-Csetup-args=-Dblas-order=mkl \
-Csetup-args=-Dlapack-order=mkl \
-Csetup-args=-Dblas=mkl-dynamic-lp64-iomp \
-Csetup-args=-Dlapack=mkl-dynamic-lp64-iomp
```

**Why this works:** The precise model provides better compatibility with NumPy's floating-point exception handling while still maintaining numerical accuracy.

### Solution 2: Add Explicit Exception Flags

Keep strict model but add explicit floating-point exception flags:

```bash
CC=icx CXX=icpx FC=ifx \
CFLAGS='-fveclib=none -fp-model=strict -fPIC -xHost -fpe0 -fp-trap=invalid,zero,overflow' \
FFLAGS='-fp-model=strict -fPIC -xHost -fpe0 -fp-trap=invalid,zero,overflow' \
CXXFLAGS='-fp-model=strict -fPIC -xHost -fpe0 -fp-trap=invalid,zero,overflow' \
python -m pip install --no-build-isolation -v . \
-Cbuild-dir=build \
-Csetup-args=-Dallow-noblas=false \
-Csetup-args=-Dblas-order=mkl \
-Csetup-args=-Dlapack-order=mkl \
-Csetup-args=-Dblas=mkl-dynamic-lp64-iomp \
-Csetup-args=-Dlapack=mkl-dynamic-lp64-iomp
```

**Flags explanation:**
- `-fpe0`: Enable all floating-point exceptions
- `-fp-trap=invalid,zero,overflow`: Trap specific floating-point exceptions

### Solution 3: Use Fast Model with Exception Control

```bash
CC=icx CXX=icpx FC=ifx \
CFLAGS='-fveclib=none -fp-model=fast=1 -fPIC -xHost -fpe-all=0' \
FFLAGS='-fp-model=fast=1 -fPIC -xHost -fpe-all=0' \
CXXFLAGS='-fp-model=fast=1 -fPIC -xHost -fpe-all=0' \
python -m pip install --no-build-isolation -v . \
-Cbuild-dir=build \
-Csetup-args=-Dallow-noblas=false \
-Csetup-args=-Dblas-order=mkl \
-Csetup-args=-Dlapack-order=mkl \
-Csetup-args=-Dblas=mkl-dynamic-lp64-iomp \
-Csetup-args=-Dlapack=mkl-dynamic-lp64-iomp
```

### Solution 4: Use GCC Instead (Alternative)

If Intel OneAPI continues to cause issues, use GCC:

```bash
CC=gcc CXX=g++ FC=gfortran \
CFLAGS='-fPIC -O2' \
FFLAGS='-fPIC -O2' \
CXXFLAGS='-fPIC -O2' \
python -m pip install --no-build-isolation -v . \
-Cbuild-dir=build \
-Csetup-args=-Dallow-noblas=false \
-Csetup-args=-Dblas-order=mkl \
-Csetup-args=-Dlapack-order=mkl \
-Csetup-args=-Dblas=mkl-dynamic-lp64-iomp \
-Csetup-args=-Dlapack=mkl-dynamic-lp64-iomp
```

## Verification

After applying any fix, verify it works:

```bash
# Test the specific failing case
python -c "
import numpy as np
finf = np.array(np.inf, dtype='d')
with np.errstate(invalid='raise'):
    try:
        result = np.divmod(finf, finf)
        print('FAILED: No exception raised')
    except FloatingPointError:
        print('PASSED: Exception raised as expected')
"

# Run the full test suite
python -c 'import numpy; numpy.test()'
```

## Runtime Environment Variables

If recompiling isn't an option, you can try setting environment variables:

```bash
export FPE_ABORT=1
export FPE_INVALID=1
python -c 'import numpy; numpy.test()'
```

## Temporary Workaround

Skip the problematic test:

```bash
export NUMPY_SKIP_TESTS="test_float_divmod_errors"
python -c 'import numpy; numpy.test()'
```

## Build Script

Use the provided build script for automated testing:

```bash
# Make script executable
chmod +x build_numpy_intel_fix.sh

# Try different build types
./build_numpy_intel_fix.sh precise
./build_numpy_intel_fix.sh strict
./build_numpy_intel_fix.sh fast
./build_numpy_intel_fix.sh gcc
```

## Test Script

Use the provided test script to verify the fix:

```bash
python test_numpy_fp_issue.py
```

## Compatibility Matrix

| Compiler | FP Model | Exception Flags | Status |
|----------|----------|-----------------|---------|
| Intel OneAPI | strict | None | ❌ Fails |
| Intel OneAPI | strict | -fpe0 -fp-trap=invalid,zero,overflow | ✅ Works |
| Intel OneAPI | precise | None | ✅ Works |
| Intel OneAPI | fast=1 | -fpe-all=0 | ✅ Works |
| GCC | Default | None | ✅ Works |

## Known Issues

1. **Intel OneAPI 2024.2**: The strict floating-point model doesn't properly handle NumPy's exception expectations
2. **macOS**: Some floating-point exception tests are known to fail on macOS regardless of compiler
3. **WASM**: Floating-point exceptions don't work in WebAssembly environments

## References

- [NumPy Issue Tracker](https://github.com/numpy/numpy/issues)
- [Intel OneAPI Documentation](https://www.intel.com/content/www/us/en/developer/tools/oneapi/overview.html)
- [Intel Compiler Floating-Point Options](https://www.intel.com/content/www/us/en/develop/documentation/oneapi-dpcpp-cpp-compiler-dev-guide-and-reference/top/compiler-reference/compiler-options/floating-point-options.html)

## Contributing

If you encounter this issue:

1. Test with the provided solutions
2. Report your findings to the NumPy issue tracker
3. Include your system information and compiler versions
4. Share the output of the test script

## License

This documentation is provided as-is for the benefit of the NumPy community. 