#!/usr/bin/env python3
"""
Test script to reproduce and verify NumPy floating-point exception issue with Intel OneAPI.

This script reproduces the failing test case from:
https://github.com/numpy/numpy/issues/[issue_number]

Usage:
    python test_numpy_fp_issue.py
"""

import numpy as np
import sys
import os
import platform

def test_fp_exceptions():
    """Test floating-point exception handling."""
    print("=" * 60)
    print("NumPy Floating-Point Exception Test")
    print("=" * 60)
    
    # System information
    print(f"NumPy version: {np.__version__}")
    print(f"Python version: {sys.version}")
    print(f"Platform: {platform.platform()}")
    print(f"Architecture: {platform.machine()}")
    
    # Check if Intel OneAPI is being used
    if 'icx' in os.environ.get('CC', '') or 'intel' in platform.processor().lower():
        print("Intel OneAPI compiler detected")
    else:
        print("Intel OneAPI compiler not detected")
    
    print("\n" + "=" * 60)
    print("Testing Floating-Point Exceptions")
    print("=" * 60)
    
    # Test cases that should raise FloatingPointError
    test_cases = [
        {
            'name': 'divmod(inf, inf) - should raise FloatingPointError',
            'test': lambda: np.divmod(np.inf, np.inf),
            'errstate': {'invalid': 'raise'}
        },
        {
            'name': 'divmod(1, 0) - should raise FloatingPointError',
            'test': lambda: np.divmod(1.0, 0.0),
            'errstate': {'divide': 'raise'}
        },
        {
            'name': 'divmod(0, 0) - should raise FloatingPointError',
            'test': lambda: np.divmod(0.0, 0.0),
            'errstate': {'invalid': 'raise'}
        }
    ]
    
    results = []
    
    for i, case in enumerate(test_cases, 1):
        print(f"\nTest {i}: {case['name']}")
        print("-" * 40)
        
        try:
            with np.errstate(**case['errstate']):
                result = case['test']()
                print(f"❌ FAILED: No exception raised")
                print(f"   Result: {result}")
                results.append(('FAILED', case['name'], 'No exception raised', str(result)))
        except FloatingPointError as e:
            print(f"✅ PASSED: FloatingPointError raised as expected")
            print(f"   Exception: {e}")
            results.append(('PASSED', case['name'], 'FloatingPointError', str(e)))
        except Exception as e:
            print(f"⚠️  UNEXPECTED: Different exception raised")
            print(f"   Exception type: {type(e).__name__}")
            print(f"   Exception: {e}")
            results.append(('UNEXPECTED', case['name'], type(e).__name__, str(e)))
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    passed = sum(1 for r in results if r[0] == 'PASSED')
    failed = sum(1 for r in results if r[0] == 'FAILED')
    unexpected = sum(1 for r in results if r[0] == 'UNEXPECTED')
    
    print(f"Total tests: {len(results)}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"Unexpected: {unexpected}")
    
    if failed > 0 or unexpected > 0:
        print("\n❌ ISSUE DETECTED: Some tests failed or raised unexpected exceptions")
        print("This indicates a problem with floating-point exception handling.")
        return False
    else:
        print("\n✅ ALL TESTS PASSED: Floating-point exception handling works correctly")
        return True

def test_compiler_flags():
    """Test different compiler flag combinations."""
    print("\n" + "=" * 60)
    print("COMPILER FLAG RECOMMENDATIONS")
    print("=" * 60)
    
    recommendations = [
        {
            'name': 'Precise Model (Recommended)',
            'flags': {
                'CFLAGS': '-fveclib=none -fp-model=precise -fPIC -xHost',
                'FFLAGS': '-fp-model=precise -fPIC -xHost',
                'CXXFLAGS': '-fp-model=precise -fPIC -xHost'
            }
        },
        {
            'name': 'Strict Model with Exception Flags',
            'flags': {
                'CFLAGS': '-fveclib=none -fp-model=strict -fPIC -xHost -fpe0 -fp-trap=invalid,zero,overflow',
                'FFLAGS': '-fp-model=strict -fPIC -xHost -fpe0 -fp-trap=invalid,zero,overflow',
                'CXXFLAGS': '-fp-model=strict -fPIC -xHost -fpe0 -fp-trap=invalid,zero,overflow'
            }
        },
        {
            'name': 'Fast Model with Exception Control',
            'flags': {
                'CFLAGS': '-fveclib=none -fp-model=fast=1 -fPIC -xHost -fpe-all=0',
                'FFLAGS': '-fp-model=fast=1 -fPIC -xHost -fpe-all=0',
                'CXXFLAGS': '-fp-model=fast=1 -fPIC -xHost -fpe-all=0'
            }
        }
    ]
    
    for i, rec in enumerate(recommendations, 1):
        print(f"\n{i}. {rec['name']}")
        print("   Compilation command:")
        print("   CC=icx CXX=icpx FC=ifx \\")
        for var, flags in rec['flags'].items():
            print(f"   {var}='{flags}' \\")
        print("   python -m pip install --no-build-isolation -v . \\")
        print("   -Cbuild-dir=build \\")
        print("   -Csetup-args=-Dallow-noblas=false \\")
        print("   -Csetup-args=-Dblas-order=mkl \\")
        print("   -Csetup-args=-Dlapack-order=mkl \\")
        print("   -Csetup-args=-Dblas=mkl-dynamic-lp64-iomp \\")
        print("   -Csetup-args=-Dlapack=mkl-dynamic-lp64-iomp")

if __name__ == '__main__':
    success = test_fp_exceptions()
    test_compiler_flags()
    
    if not success:
        sys.exit(1)
    else:
        sys.exit(0) 