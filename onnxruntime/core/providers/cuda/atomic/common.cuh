/**
* Copyright (c) 2016-present, Facebook, Inc.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

/* Modifications Copyright (c) Microsoft. */

#pragma once
#include "cuda.h"
#include "cuda_fp16.h"
#include "cuda_runtime.h"
#include "core/framework/float16.h"

namespace onnxruntime {
namespace cuda {

__device__ __forceinline__ void atomic_add(float *address, float value) {
    atomicAdd(address, value);
}

__device__ __forceinline__ void atomic_add(double *address, double value) {
#if __CUDA_ARCH__ < 600
  unsigned long long* raw_address = reinterpret_cast<unsigned long long*>(address);
  unsigned long long raw_old_value = 0ULL;
  unsigned long long raw_new_value = 0ULL;
  unsigned long long seen_old_value = 0ULL;
  double* const p_old_value = reinterpret_cast<double*>(&raw_old_value);
  double* const p_new_value = reinterpret_cast<double*>(&raw_new_value);
  do {
    *p_old_value = *address;
    *p_new_value = *address + value;
     seen_old_value = atomicCAS(raw_address, raw_old_value, raw_new_value);
  } while (seen_old_value != raw_old_value);
#else
  atomicAdd(address, value);
#endif
}

//
// ref: https://github.com/pytorch/pytorch/blob/master/aten/src/THC/THCAtomics.cuh
//
__device__ __forceinline__ void atomic_add(half *address, half value) {
#if __CUDA_ARCH__ < 700
  unsigned int* base_address = (unsigned int*)((char*)address - ((size_t)address & 2));
  unsigned int old = *base_address;
  unsigned int assumed;
  unsigned short x;

  do {
    assumed = old;
    x = (size_t)address & 2 ? (old >> 16) : (old & 0xffff);
    x = __half_as_short(__float2half(__half2float(*reinterpret_cast<const __half*>(&x)) + __half2float(value)));
    old = (size_t)address & 2 ? (old & 0xffff) | (x << 16) : (old & 0xffff0000) | x;
    old = atomicCAS(base_address, assumed, old);
  } while (assumed != old);
#else
  atomicAdd(address, value);
#endif
}

__device__ __forceinline__ void atomic_add(BFloat16* address, BFloat16 value) {
  unsigned int* base_address =
      reinterpret_cast<unsigned int*>(reinterpret_cast<char*>(address) - (reinterpret_cast<size_t>(address) & 2));
  unsigned int old = *base_address;
  unsigned int assumed;
  BFloat16 bsum;
  do {
    assumed = old;
    bsum.val = reinterpret_cast<size_t>(address) & 2 ? (old >> 16) : (old & 0xffff);
    bsum = bsum + value;
    old = reinterpret_cast<size_t>(address) & 2 ? (old & 0xffff) | (bsum.val << 16) : (old & 0xffff0000) | bsum.val;
    old = atomicCAS(base_address, assumed, old);
  } while (assumed != old);
}

}  // namespace cuda
}  // namespace onnxruntime