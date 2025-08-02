#!/bin/bash
# Build script for NumPy with Intel OneAPI floating-point exception fix
# 
# This script addresses the issue where Intel OneAPI with -fp-model=strict
# doesn't properly raise FloatingPointError for divmod(inf, inf)
#
# Usage: ./build_numpy_intel_fix.sh [option]
# Options:
#   precise  - Use precise floating-point model (recommended)
#   strict   - Use strict model with exception flags
#   fast     - Use fast model with exception control
#   gcc      - Use GCC instead of Intel compiler

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a NumPy source directory
if [ ! -f "setup.py" ] && [ ! -f "pyproject.toml" ]; then
    print_error "This script must be run from the NumPy source directory"
    exit 1
fi

# Default to precise model
BUILD_TYPE=${1:-precise}

print_status "Building NumPy with Intel OneAPI floating-point fix"
print_status "Build type: $BUILD_TYPE"

# Set up build directory
BUILD_DIR="build_intel_${BUILD_TYPE}"
print_status "Using build directory: $BUILD_DIR"

# Clean previous build if it exists
if [ -d "$BUILD_DIR" ]; then
    print_status "Cleaning previous build directory..."
    rm -rf "$BUILD_DIR"
fi

# Set compiler flags based on build type
case $BUILD_TYPE in
    "precise")
        print_status "Using precise floating-point model (recommended)"
        export CC=icx
        export CXX=icpx
        export FC=ifx
        export CFLAGS='-fveclib=none -fp-model=precise -fPIC -xHost'
        export FFLAGS='-fp-model=precise -fPIC -xHost'
        export CXXFLAGS='-fp-model=precise -fPIC -xHost'
        ;;
    "strict")
        print_status "Using strict floating-point model with exception flags"
        export CC=icx
        export CXX=icpx
        export FC=ifx
        export CFLAGS='-fveclib=none -fp-model=strict -fPIC -xHost -fpe0 -fp-trap=invalid,zero,overflow'
        export FFLAGS='-fp-model=strict -fPIC -xHost -fpe0 -fp-trap=invalid,zero,overflow'
        export CXXFLAGS='-fp-model=strict -fPIC -xHost -fpe0 -fp-trap=invalid,zero,overflow'
        ;;
    "fast")
        print_status "Using fast floating-point model with exception control"
        export CC=icx
        export CXX=icpx
        export FC=ifx
        export CFLAGS='-fveclib=none -fp-model=fast=1 -fPIC -xHost -fpe-all=0'
        export FFLAGS='-fp-model=fast=1 -fPIC -xHost -fpe-all=0'
        export CXXFLAGS='-fp-model=fast=1 -fPIC -xHost -fpe-all=0'
        ;;
    "gcc")
        print_status "Using GCC compiler (alternative to Intel)"
        export CC=gcc
        export CXX=g++
        export FC=gfortran
        export CFLAGS='-fPIC -O2'
        export FFLAGS='-fPIC -O2'
        export CXXFLAGS='-fPIC -O2'
        ;;
    *)
        print_error "Unknown build type: $BUILD_TYPE"
        print_status "Available options: precise, strict, fast, gcc"
        exit 1
        ;;
esac

# Display current environment
print_status "Build environment:"
echo "  CC: $CC"
echo "  CXX: $CXX"
echo "  FC: $FC"
echo "  CFLAGS: $CFLAGS"
echo "  FFLAGS: $FFLAGS"
echo "  CXXFLAGS: $CXXFLAGS"

# Check if Intel OneAPI is available (for Intel builds)
if [[ $BUILD_TYPE != "gcc" ]]; then
    if ! command -v icx &> /dev/null; then
        print_error "Intel OneAPI compiler (icx) not found in PATH"
        print_warning "Make sure Intel OneAPI is installed and sourced"
        print_status "You can source it with: source /opt/intel/oneapi/setvars.sh"
        exit 1
    fi
    
    # Display Intel compiler version
    print_status "Intel compiler version:"
    icx --version
fi

# Build NumPy
print_status "Building NumPy..."
python -m pip install --no-build-isolation -v . \
    -Cbuild-dir="$BUILD_DIR" \
    -Csetup-args=-Dallow-noblas=false \
    -Csetup-args=-Dblas-order=mkl \
    -Csetup-args=-Dlapack-order=mkl \
    -Csetup-args=-Dblas=mkl-dynamic-lp64-iomp \
    -Csetup-args=-Dlapack=mkl-dynamic-lp64-iomp

if [ $? -eq 0 ]; then
    print_success "NumPy build completed successfully!"
else
    print_error "NumPy build failed!"
    exit 1
fi

# Test the build
print_status "Testing the build..."
python -c "
import numpy as np
print(f'NumPy version: {np.__version__}')
print(f'NumPy configuration:')
print(np.show_config())
"

# Run the specific failing test
print_status "Running floating-point exception test..."
python -c "
import numpy as np
import sys

def test_fp_exceptions():
    test_cases = [
        ('divmod(inf, inf)', lambda: np.divmod(np.inf, np.inf), {'invalid': 'raise'}),
        ('divmod(1, 0)', lambda: np.divmod(1.0, 0.0), {'divide': 'raise'}),
        ('divmod(0, 0)', lambda: np.divmod(0.0, 0.0), {'invalid': 'raise'})
    ]
    
    passed = 0
    failed = 0
    
    for name, test_func, errstate in test_cases:
        try:
            with np.errstate(**errstate):
                result = test_func()
                print(f'❌ {name}: FAILED - No exception raised')
                failed += 1
        except FloatingPointError:
            print(f'✅ {name}: PASSED - Exception raised as expected')
            passed += 1
        except Exception as e:
            print(f'⚠️  {name}: UNEXPECTED - {type(e).__name__}: {e}')
            failed += 1
    
    print(f'\\nSummary: {passed} passed, {failed} failed')
    return failed == 0

if test_fp_exceptions():
    print('\\n🎉 All floating-point exception tests passed!')
    sys.exit(0)
else:
    print('\\n❌ Some floating-point exception tests failed')
    sys.exit(1)
"

TEST_RESULT=$?

if [ $TEST_RESULT -eq 0 ]; then
    print_success "All tests passed! The fix is working correctly."
else
    print_warning "Some tests failed. You may need to try a different build type."
    print_status "Try running: ./build_numpy_intel_fix.sh [precise|strict|fast|gcc]"
fi

print_status "Build completed. NumPy is ready to use!" 