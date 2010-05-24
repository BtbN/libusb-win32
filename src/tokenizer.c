/* LIBUSB-WIN32, Generic Windows USB Library
 * Copyright (c) 2010 Travis Robinson <libusbdotnet@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
#include "tokenizer.h"

// If the dst buffer is to small it grows to what is needed+GROW_SIZE
#define GetDestSize(RequiredSize) RequiredSize+8192

// copies text into the destination buffer; growing the buffer as needed.
#define StrCpyWithGrow(DstPtr, DstPtrOrig, DstPos, DstAllocSize,  \
	                    ReplaceString, ReplaceLength)             \
{                                                                 \
	if (DstPos+(ReplaceLength) >= DstAllocSize+1)                 \
	{                                                             \
		DstAllocSize = GetDestSize(DstPos + ReplaceLength);       \
		DstPtr = realloc(DstPtr,DstAllocSize);                    \
	}                                                             \
	if (!DstPtr)                                                  \
	{                                                             \
		free(DstPtrOrig);                                         \
		return -ERROR_NOT_ENOUGH_MEMORY;                          \
	}                                                             \
	DstPtrOrig = DstPtr;                                          \
	safe_strncpy(&DstPtr[DstPos],ReplaceString,ReplaceLength);    \
	DstPos += ReplaceLength;                                      \
}

// replaces tokens in text.
// Returns: less than 0 on error, 0 if src is empty,
//          number of chars written to dst on success.
// NOTE: On success dst must be freed by the calling function.
long tokenize_string(const char* src, // text to bo tokenized
				   long src_count, // length of src
				   char** dst, // destination buffer (must be freed)
				   const token_entity_t* token_entities, // match/replace token list
				   const char* tok_prefix, // the token prefix exmpl:"$("
				   const char* tok_suffix, // the token suffix exmpl:")"
				   int recursive) // allows tokenzing tokens in tokens
{
	const token_entity_t* next_match;
	long match_replace_pos;
	const char* match_start;
	long tok_prefix_size;
	long tok_suffix_size;
	int match_found;
	long match_length;
	long replace_length;
	long dst_pos;
	long dst_alloc_size;
	char* pDst;
	long match_count;

	if (!src || !dst || !token_entities || !src_count || !tok_prefix || !tok_suffix)
		return -ERROR_BAD_ARGUMENTS;

	tok_prefix_size = strlen(tok_prefix);
	tok_suffix_size = strlen(tok_suffix);

	// token prefix and suffix markers is required
	if (!tok_prefix_size || !tok_suffix_size)
		return -ERROR_BAD_ARGUMENTS;

	// if the src buffer count <= 0 assume it is null terminated
	if (src_count < 0) src_count = strlen(src);
	
	// nothing to do
	if (src_count == 0) return 0;

	// allocate twice the size of the src buffer to start things off
	// the destination buffer will grow as needed.
	dst_alloc_size=src_count*2;
	*dst = pDst = malloc(dst_alloc_size);
	if (!pDst) 
		return -ERROR_NOT_ENOUGH_MEMORY;
	dst_pos=0;

	match_count=0;

	// search for a token prefix
	while((match_start=strstr(src,tok_prefix)))
	{
		// found a token prefix
		match_replace_pos=0;
		match_found=0;
		match_length = match_start-src;

		StrCpyWithGrow(pDst,*dst, dst_pos,dst_alloc_size,src,match_length);

		src+=match_length+tok_prefix_size;
		src_count-=(match_length+tok_prefix_size);
		if (src_count <= 0)
			break;

		// iterate through the match/replace tokens
		while ((next_match=&token_entities[match_replace_pos++]))
		{
			// the match and replace fields must both be set
			if (!next_match->match || !next_match->replace)
			{
				free(pDst);
				return -ERROR_BAD_ARGUMENTS;
			}
			match_length=strlen(next_match->match);

			// if this token will be longer than what's left in src buffer, skip it.
			if (src_count < (match_length+tok_suffix_size))
				continue; // not found

			// check for a match suffix
			if (strncmp(src+match_length,tok_suffix,tok_suffix_size)!=0)
				continue; // not found

			if (strncmp(src,next_match->match,match_length)==0)
			{
				// found a valid token match
				replace_length=strlen(next_match->replace);
				StrCpyWithGrow(pDst, *dst, dst_pos, dst_alloc_size,
					next_match->replace,replace_length);

				src+=match_length+tok_suffix_size;
				src_count-=(match_length+tok_suffix_size);
				match_found=1;
				match_count++;
				break;
			}
		}

		if (!match_found)
		{
			// No matches were found; leave it as-is. 
			StrCpyWithGrow(pDst, *dst, dst_pos, dst_alloc_size,
				tok_prefix, tok_prefix_size);
		}
	}

	match_length=src_count;
	if (src_count)
		StrCpyWithGrow(pDst, *dst, dst_pos, dst_alloc_size, src, match_length);

	// StrCpyWithGrow is aware an extra char is always needed for null.
	pDst[dst_pos]='\0';

	if (recursive && match_count)
	{
		// if recursive mode is true, keep re-tokenizing until no matches are found
		*dst = NULL;
		dst_pos = tokenize_string(pDst,dst_pos,dst,
			token_entities,tok_prefix,tok_suffix,recursive);

		// free the old dst buffer
		free(pDst);
	}
	// return the new size (excluding null)
	return dst_pos;
}

// tokenizes a resource stored in the current module.
long tokenize_resource(LPCSTR resource_name, 
					 LPCSTR resource_type,
					 char** dst,
					 const token_entity_t* token_entities,
					 const char* tok_prefix,
					 const char* tok_suffix,
					 int recursive)
{
	const char* src;
	long src_count;
	HGLOBAL res_data;

	HRSRC hSrc = FindResourceA(NULL, resource_name, resource_type);

	if (!hSrc)
		return -ERROR_RESOURCE_DATA_NOT_FOUND;

	src_count = SizeofResource(NULL, hSrc);

	res_data = LoadResource(NULL,hSrc);
	
	if (!res_data)
		return -ERROR_RESOURCE_DATA_NOT_FOUND;

	src = (char*) LockResource(res_data);

	if (!src)
		return -ERROR_RESOURCE_DATA_NOT_FOUND;

	return tokenize_string(src, src_count, dst, 
		token_entities, tok_prefix, tok_suffix, recursive);

}
