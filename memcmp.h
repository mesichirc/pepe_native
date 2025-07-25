#ifndef MEMCMP_H
#define MEMCMP_H
#if !defined(PEPE_DISABLE_SIMD) && (defined(__x86_64__) || defined(_M_X64) || defined(_M_AMD64))
#include <emmintrin.h>
#elif !defined(PEPE_DISABLE_SIMD) && defined(__aarch64__)
#include <arm_neon.h>
#endif


bool Pepe_MemCmp(u8 *s1, u8 *s2, u64 length);
#if !defined(PEPE_DISABLE_SIMD) && (defined(__x86_64__) || defined(_M_X64) || defined(_M_AMD64))
    bool Pepe_MemCmp(u8 *s1, u8 *s2, u64 length) {
        while (length >= 16) {
            __m128i v1 = _mm_loadu_si128((const __m128i *)s1);
            __m128i v2 = _mm_loadu_si128((const __m128i *)s2);

            if (_mm_movemask_epi8(_mm_cmpeq_epi8(v1, v2)) != 0xFFFF) { // If any byte differs
                return false;
            }

            s1 += 16;
            s2 += 16;
            length -= 16;
        }

        // Handle remaining bytes
        while (length--) {
            if (*s1 != *s2) {
                return false;
            }
            s1++;
            s2++;
        }

        return true;
    }
#elif !defined(PEPE_DISABLE_SIMD) && defined(__aarch64__)
    bool Pepe_MemCmp(u8 *s1, u8 *s2, int32_t length) {
        while (length >= 16) {
            uint8x16_t v1 = vld1q_u8((const u8 *)s1);
            uint8x16_t v2 = vld1q_u8((const u8 *)s2);

            // Compare vectors
            if (vminvq_u32(vreinterpretq_u32_u8(vceqq_u8(v1, v2))) != 0xFFFFFFFF) { // If there's a difference
                return false;
            }

            s1 += 16;
            s2 += 16;
            length -= 16;
        }

        // Handle remaining bytes
        while (length--) {
            if (*s1 != *s2) {
                return false;
            }
            s1++;
            s2++;
        }

        return true;
    }
#else
    bool Pepe_MemCmp(u8 *s1, u8 *s2, u64 length) {
        for (u64 i = 0; i < length; i++) {
            if (s1[i] != s2[i]) {
                return false;
            }
        }
        return true;
    }
#endif

bool
Pepe_SliceCmp(Pepe_Slice s1, Pepe_Slice s2)
{
  if (s1.len != s2.len) {
    return false;
  }


}


#endif
