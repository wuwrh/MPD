// =============================================================================
//  Program : string.c
//  Author  : Chun-Jen Tsai
//  Date    : Dec/09/2019
// -----------------------------------------------------------------------------
//  Description:
//  This is the minimal string library for aquila.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
#include <stdio.h>
#include <string.h>

void *memcpy(void *d, void *s, size_t n)
{
    unsigned char *dst = (unsigned char *) d;
    unsigned char *src = (unsigned char *) s;

    for (int idx = 0; idx < n; idx++) *(dst++) = *(src++);
    return d;
}

void *memmove(void *d, void *s, size_t n)
{
    unsigned char *dst = (unsigned char *) d;
    unsigned char *src = (unsigned char *) s;

    if ((unsigned) d >= (unsigned) s &&
        (unsigned) d <= (unsigned) s + n)
    {
        for (int idx = n - 1; idx >= 0; idx--) dst[idx] = src[idx];
    }
    else
    {
        for (int idx = 0; idx < n; idx++) *(dst++) = *(src++);
    }

    return d;
}

void *memset(void *d, int v, size_t n)
{
    unsigned char *dst = (unsigned char *) d;

    for (int idx = 0; idx < n; idx++) *(dst++) = (unsigned char) v;
    return d;
}

long strlen(char *s)
{
    long n = 0;

    while (*s++) n++;
    return n;
}

/*char *strcpy(char *dst, char *src)
{
    char *tmp = dst;

    while (*src) *(tmp++) = *(src++);
    *tmp = 0;
    return dst;
}*/

char *strcpy(char *dst, char *src)
{
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    char *ret = dst;

    /* 先對齊到 4 的邊界可試著再加，但為了安全與簡潔先直接展開 */
    for (;;) {
        unsigned char c0 = *s++;  d[0] = c0; if (!c0) return ret;
        unsigned char c1 = *s++;  d[1] = c1; if (!c1) return ret;
        unsigned char c2 = *s++;  d[2] = c2; if (!c2) return ret;
        unsigned char c3 = *s++;  d[3] = c3; if (!c3) return ret;
        d += 4;
    }
}

char *strncpy(char *dst, char *src, size_t n)
{
    char *tmp = dst;

    while (*src && n) *(tmp++) = *(src++), n--;
    while (n--) *(tmp++) = 0;
    return dst;
}

char *strcat(char *dst, char *src)
{
    char *tmp = dst;

    while (*tmp) tmp++;
    while (*src) *(tmp++) = *(src++);
    *tmp = 0;
    return dst;
}

char *strncat(char *dst, char *src, size_t n)
{
    char *tmp = dst;

    while (*tmp) tmp++;
    while (*src && n) *(tmp++) = *(src++), n--;
    *tmp = 0;
    return dst;
}

/*int  strcmp(char *s1, char *s2)
{
    int value;
 
    s1--, s2--;
    do
    {
        s1++, s2++;
        if (*s1 == *s2)
        {
            value = 0;
        }
        else if (*s1 < *s2)
        {
            value = -1;
            break;
        }
        else
        {
            value = 1;
            break;
        }
    } while (*s1 != 0 && *s2 != 0);
    return value;
}*/

int strcmp(char *s1, char *s2)
{
    const unsigned char *a = (const unsigned char *)s1;
    const unsigned char *b = (const unsigned char *)s2;

    for (;;) {
        unsigned char x0 = *a++, y0 = *b++;
        if (x0 != y0) return (x0 < y0) ? -1 : 1;
        if (x0 == 0)  return 0;

        unsigned char x1 = *a++, y1 = *b++;
        if (x1 != y1) return (x1 < y1) ? -1 : 1;
        if (x1 == 0)  return 0;

        unsigned char x2 = *a++, y2 = *b++;
        if (x2 != y2) return (x2 < y2) ? -1 : 1;
        if (x2 == 0)  return 0;

        unsigned char x3 = *a++, y3 = *b++;
        if (x3 != y3) return (x3 < y3) ? -1 : 1;
        if (x3 == 0)  return 0;
    }
}

int  strncmp(char *s1, char *s2, size_t n)
{
    int value;

    s1--, s2--;
    do
    {
        s1++, s2++;
        if (*s1 == *s2)
        {
            value = 0;
        }
        else if (*s1 < *s2)
        {
            value = -1;
            break;
        }
        else
        {
            value = 1;
            break;
        }
    } while (--n && *s1 != 0 && *s2 != 0);
    return value;
}
