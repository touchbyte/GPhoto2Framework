/*
 * Small jpeg decoder library (Internal header)
 *
 * *** NOTE: This is a modified version to deal with the ax203 "JPEG" fmt
 * *** This version can not decompress regular JPEG files, see
 * *** README.ax203-compression for details
 * 
 * Copyright (c) 2006, Luc Saillard <luc@saillard.org>
 *
 * ax203 modifications:
 * Copyright (c) 2010, Hans de Goede <hdegoede@redhat.com>
 *
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *  this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright notice,
 *  this list of conditions and the following disclaimer in the documentation
 *  and/or other materials provided with the distribution.
 *
 * - Neither the name of the author nor the names of its contributors may be
 *  used to endorse or promote products derived from this software without
 *  specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 */


#ifndef __TINYJPEG_INTERNAL_H_
#define __TINYJPEG_INTERNAL_H_

#include <setjmp.h>

#define SANITY_CHECK 1

struct jdec_private;

#define HUFFMAN_HASH_NBITS 9
#define HUFFMAN_HASH_SIZE  (1UL<<HUFFMAN_HASH_NBITS)
#define HUFFMAN_HASH_MASK  (HUFFMAN_HASH_SIZE-1)

#define HUFFMAN_TABLES	   4
#define COMPONENTS	   3
#define JPEG_MAX_WIDTH	   2048
#define JPEG_MAX_HEIGHT	   2048

struct huffman_table
{
  /* Fast look up table, using HUFFMAN_HASH_NBITS bits we can have directly the symbol,
   * if the symbol is <0, then we need to look into the tree table */
  short int lookup[HUFFMAN_HASH_SIZE];
  /* code size: give the number of bits of a symbol is encoded */
  unsigned char code_size[HUFFMAN_HASH_SIZE];
  /* some place to store value that is not encoded in the lookup table
   * IMPROVEME: Calculate if 256 value is enough to store all values
   */
  uint16_t slowtable[16-HUFFMAN_HASH_NBITS][256];
};

struct component
{
  unsigned int Hfactor;
  unsigned int Vfactor;
  float *Q_table;		/* Pointer to the quantisation table to use */
  struct huffman_table *AC_table;
  struct huffman_table *DC_table;
  short int previous_DC;	/* Previous DC coefficient */
  short int DCT[64];		/* DCT coef */
#if SANITY_CHECK
  unsigned int cid;
#endif
};


typedef void (*decode_MCU_fct) (struct jdec_private *priv, int block_nr);
typedef void (*convert_colorspace_fct) (struct jdec_private *priv);

struct jdec_private
{
  /* Public variables */
  uint8_t *components[COMPONENTS];
  unsigned int width, height;	/* Size of the image */

  /* Private variables */
  const unsigned char *stream_end;
  const unsigned char *stream;	/* Pointer to the current stream */
  unsigned int reservoir, nbits_in_reservoir;

  struct component component_infos[COMPONENTS];
  float Q_tables[COMPONENTS][64];		/* quantization tables */
  struct huffman_table HTDC[HUFFMAN_TABLES];	/* DC huffman tables   */
  struct huffman_table HTAC[HUFFMAN_TABLES];	/* AC huffman tables   */
  int default_huffman_table_initialized;

  /* Temp space used after the IDCT to store each components */
  uint8_t Y[64*4], Cr[64], Cb[64];

  jmp_buf jump_state;
  /* Internal Pointer use for colorspace conversion, do not modify it !!! */
  uint8_t *plane[COMPONENTS];

  char error_string[256];
};

#define IDCT tinyjpeg_idct_float
void tinyjpeg_idct_float (struct component *compptr, uint8_t *output_buf, int stride);

#endif
