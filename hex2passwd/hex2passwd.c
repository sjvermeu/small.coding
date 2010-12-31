/*
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <ctype.h>

/**
 * maptohex - Change a string representation of a bytestream to the bytestream
 * @hex: string representation of the bytestream
 * @len: length of the bytestream
 * @debug: enable debugging output
 *
 * Description:
 *   The bytestream is converted by changing the strings '0' - '9' to the 
 *   real values 0 - 9, and the strings 'a' - 'f' to the real values 10 - 15.
 *   The conversion is done in the stream itself. 
 *   For instance, the hex pair '6f' codes to '01101111'. As a result, the 
 *   hexstream shrinks in half size-wise (otherwise its output would be
 *   0000011000001111).
 */
int maptohex(unsigned char * hex, int len, int debug) {
	unsigned char value  = 0;
	int ctr    = 0;
	int outctr = 0;

	while (ctr < len) {
		/* Higher bits */
		value = 0;
		if (debug) printf("DEBUG - Got character '%c' (%d)\n", hex[ctr], hex[ctr]);
		if ((hex[ctr] >= '0') && (hex[ctr] <= '9')) {
			hex[outctr] = ((hex[ctr] & 0x0F) << 4) & 0xF0;
		} else if ((hex[ctr] >= 'a') && (hex[ctr] <= 'f')) {
			hex[outctr] = (((hex[ctr] & 0x0F) + 9) << 4) & 0xF0;
		} else {
			if (debug) printf("DEBUG - Character '%c' (%d) is not within the range '%c' (%d) - '%c' (%d) or '%c' (%d) - '%c' (%d)\n", 
				          hex[ctr], hex[ctr], '0', '0', '9', '9', 'a', 'a', 'f', 'f');
			return 1;
		}
		ctr++;

		/* Lower bits */
		value = 0;
		if (debug) printf("DEBUG - Got character '%c' (%d)\n", hex[ctr], hex[ctr]);
		if ((hex[ctr] >= '0') && (hex[ctr] <= '9')) {
			hex[outctr] += (hex[ctr] & 0x0F);
		} else if ((hex[ctr] >= 'a') && (hex[ctr] <= 'f')) {
			hex[outctr] += ((hex[ctr] & 0x0F) + 9);
		} else {
			if (debug) printf("DEBUG - Character '%c' (%d) is not within the range '%c' (%d) - '%c' (%d) or '%c' (%d) - '%c' (%d)\n", 
				          hex[ctr], hex[ctr], '0', '0', '9', '9', 'a', 'a', 'f', 'f');
			return 1;
		}
		ctr++;
		outctr++;
	}

	return 0;
}

/**
 * hex2passwd - Convert a bytestream into the characters identified by the mapping
 * @hex: bytestream
 * @len: length of the bytestream
 * @mapping: mapping table
 * @mappinglength: length of the mapping table (multiple of 16)
 * @dflag: enable debugging
 *
 * Description:
 *   The algorithm uses a "sliding window" across the bits. 
 *   After identifying the number of bits needed to represent every item in the
 *   mapping table, this number of bits is taken from the stream one by one. The
 *   value from the stream is used as an index against the mapping table.
 *
 *   For instance, a bytestream of 000000001101101110000101 with a bit
 *   requirement of 6 (2^6 = 64 items in the mapping table) creates an index
 *   sequence of 000000 001101 101110 000101.
 */
unsigned char * hex2passwd(unsigned char * hex, int len, unsigned char * mapping, int mappinglength, int dflag) {
	int charpos = 0;
	int bitpos  = 0;
	int numbits = 4;
	int length  = mappinglength >> 4;
	unsigned char value   = 0;
	unsigned char othervalue = 0;
	int outpos  = 0;
	while ((length & 0x01) == 0x00) {
		length >>= 1;
		numbits++;
	}
	bitpos      = numbits;
	unsigned char * out  = calloc(len*8/numbits+1, sizeof(char));

	while (charpos < len) {
		if (bitpos >= numbits) {
			if (dflag) printf("DEBUG - Value is first %d bits of '%c' (%d)\n", numbits, hex[charpos], hex[charpos]);
			value = (hex[charpos] >> (8-numbits));
			value = (value << (8-numbits)) >> (8-numbits);
		} else {
			if (dflag) printf("DEBUG - Value is last %d bits of '%c' (%d) and first %d bits of '%c' (%d)\n", numbits - bitpos, hex[charpos-1], 
					  hex[charpos-1], bitpos, hex[charpos], hex[charpos]);
			value = (hex[charpos] >> (8-bitpos));
			value = (value << (8-numbits)) >> (8-numbits);
			if (dflag) printf("DEBUG - Intermediate value is %d\n", value);
			othervalue = hex[charpos-1] << (8 - (numbits - bitpos));
			othervalue = othervalue >> (8-numbits);
			if (dflag) printf("DEBUG - Intermediate othervalue is %d\n", othervalue);
			value = value + othervalue;
		}
		out[outpos] = mapping[value];
		if (dflag) printf("DEBUG - Value %d maps to character '%c' (%d)\n", value, out[outpos], out[outpos]);
		bitpos += numbits;
		if (bitpos >= 8) {
			charpos++;
			bitpos -= 8;
		}
		outpos++;
	};

	out[len*8/numbits] = 0x00;
	return out;
}

/**
 * switchcharsequence - Switch parts of the stream
 * @mapping: bytestream
 * @startpos: start position where switching begins
 * @endpos: end position where switching ends
 * @dflag: print out debugging information
 *
 * Description:
 *   The switching algorithm starts switching characters from @startpos
 *   with characters from the middle (in between @startpos and @endpos).
 *   So, a stream of 0123456789 and startpos/endpos of 2/5 would switch
 *   characters 2 with 4 and 3 with 5, resulting in 0145237890.
 */
void switchcharsequence(unsigned char * mapping, int startpos, int endpos, int dflag) {
	int midpos = startpos + (endpos - startpos) / 2 + 1;
	while (midpos <= endpos) {
		if (dflag) printf ("DEBUG - Switching character '%c' with '%c'\n", mapping[startpos], mapping[midpos]);
		mapping[startpos] ^= mapping[midpos];
		mapping[midpos] ^= mapping[startpos];
		mapping[startpos] ^= mapping[midpos];
		startpos++;
		midpos++;
	}
}

/**
 * switchcharacters - Switch bytes in the mapping based on the scrambling pattern
 * @mapping: bytestream to possibly swap bytes
 * @len: length of the bytestream
 * @scrambling: scrambling pattern using bitwise decisions
 * @slen: scrambling pattern length
 * @dflag: enable debugging
 *
 * Description:
 *   The scrambling pattern identified by @scrambling is read as a bit-stream.
 *   Each bit it encounters decides if swapping on the bytestream should occur
 *   or not. Every bit field uses a smaller granularity.
 *   1. the first bit decides if the first and second half of the stream needs to be switched.
 *   2. the second bit decides if the first and second quarter of the stream need to be 
 *      switched as well as third and fourth quarter
 *   3. the third bit decides if the 1st and 2nd 1/8th, 3rd and 4th 1/8th, ... need to be switched
 *   4. etc.
 *   ...
 *
 *   For instance, a scrambling pattern of 00000100 would mean that the 1/8ths
 *   parts of the stream need to be switched, so a stream of
 *    ABCDEFGHIJKLMNOPQRSTUVWX
 *   would be seen as
 *    ABC DEF GHI JKL MNO PQR STU VWX
 *   and result in switching ABC with DEF, GHI with JKL, ... resulting in
 *    DEF ABC JKL GHI PQR MNO VWX STU
 */
void switchcharacters(unsigned char * mapping, int len, unsigned char * scrambling, int slen, int dflag) {
	unsigned char scramblingchar = '0';
	unsigned char needswitch = '0';

	while (slen > 0) {
		scramblingchar = scrambling[slen-1];
		int i = 0;
		int buckets = 1;
		for (i = 0; i < 8; i++) {
			if (dflag) printf("DEBUG - Current scrambling character value is '%c' (%d), run %d\n", scramblingchar, scramblingchar, i);
			needswitch = scramblingchar & 0x01;
			if (needswitch == 0x01) {
				int startpos = 0;
				int endpos   = 0;
				int j        = 0;
				for (j = 0; j < buckets; j++) {
					startpos = j*(len/buckets);
					endpos   = (j+1)*(len/buckets) - 1;
					if (dflag) printf("DEBUG - Switching mapping with position sequence %d, %d\n", startpos, endpos);
					switchcharsequence(mapping, startpos, endpos, dflag);
				}
			}
			buckets <<= 1;
			scramblingchar >>= 1;
			if (buckets >= len) break;
		}
		slen--;
	}
	if (dflag) {
		unsigned char * debugout = calloc(len+1, sizeof(char));
		memcpy(debugout, mapping, len);
		debugout[len] = 0x00;
		printf("DEBUG - New mapping sequence is now %s (length is %d)\n", debugout, len);
		free(debugout);
	}
}

/**
 * failnonzero - Fail with the given message if the flag is non-zero
 */
void failnonzero(int flag, char * message) {
	if (flag != 0) {
		printf("%s\n", message);
		exit(1);
	};
}

int main(int argc, char** argv) {
	int hflag = 0;		// help
	int mselect = 0;	// specific mapping selection
	int dflag = 0;		// enable debugging
	int nchars = 0;
	unsigned char * mdefine = NULL;	// custom mapping
	unsigned char * scramble = NULL;	// scramble parameter

	int mlength       = 64;
	/*
	 * Default patterns, you can create your own with the -m option.
	 */
	unsigned char mdefault[64] = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.!";
	unsigned char maltern1[32] = "0123456789abcdefghijklmnoprstuvw";
	unsigned char maltern2[16] = "0123456789+-/*()";
	unsigned char * mapping    = mdefault;

	int c = 0;

	while ((c = getopt (argc, argv, "h12m:s:dn:")) != -1) {
		switch (c) {
			case 'h':
				hflag = 1;
				break;
			case '1':
				failnonzero(mselect, "You cannot select several mappings. Please decide before you start...");
				mselect = 1;
				mapping = maltern1;
				mlength = 32;
				break;
			case '2':
				failnonzero(mselect, "You cannot select several mappings. Please decide before you start...");
				mselect = 2;
				mapping = maltern2;
				mlength = 16;
				break;
			case 'm':
				failnonzero(mselect, "You cannot select several mappings. Please decide before you start...");
				mselect = 99;
				mlength = strlen(optarg);
				mdefine = (unsigned char *) optarg;
				if ((mlength != 16) && 
				    (mlength != 32) &&
				    (mlength != 64) &&
				    (mlength != 128)) {
					failnonzero (1, "The mapping length must be 16, 32, 64, 128 or 256 characters wide\n");
				};
				mapping = mdefine;
				break;
			case 's':
				scramble = (unsigned char *) optarg;
				break;
			case 'd':
				dflag = 1;
				break;
			case 'n':
				sscanf(optarg, "%d", &nchars);
				failnonzero (nchars > 512, "You aren't by any chance looking for an overflow are you?\n");

				break;
			case '?':
				hflag = 1;
				break;

		}
	}

	if (hflag) {
		printf("%s - A tool for creating passwords from hashes\n", argv[0]);
		printf("Copyright Sven Vermeulen, licensed under GPLv3\n");
		printf("Contact: sven.vermeulen@siphos.be\n\n");
		printf("%s usage:\n", argv[0]);
		printf("  -h            Show this help screen\n");
		printf("  -1            Select alternative mapping 1\n");
		printf("  -2            Select alternative mapping 2\n");
		printf("  -m <mapping>  Provide a custom mapping sequence\n");
		printf("  -s <scramble> Provide a scrambling sequence\n");
		printf("  -n <number>   Only show first <number> of characters\n");
		printf("  -d            Enable debugging\n");
		printf("\nAll arguments are optional\n");
		exit(0);
	};

	unsigned char * input = calloc(513, sizeof(char));
	scanf("%512s", input);
	int inputlength = strlen((char *) input);
	failnonzero ((inputlength % 2), "The input length must be an even number (as each character pair denotes a single character)\n");

	// Changes the string values 0-9 / [a-f] to the real numbers
	if (dflag) printf("DEBUG - Converting input to bytestream...\n");
	failnonzero(maptohex(input, inputlength, dflag), "The given string is no valid hex representation\nValid characters are [0-9] and [a-f]\n");
	inputlength >>= 1;


	// Scramble the chosen mapping
	if (scramble != NULL) {
		int scramblelength = strlen((char *) scramble);
		if (dflag) printf("DEBUG - Converting scramble string to bytestream...\n");
		failnonzero(maptohex(scramble, scramblelength, dflag), "The scramble string is no valid hex representation\nValid characters are [0-9] and [a-f]\n");
		scramblelength >>= 1;
		switchcharacters(mapping, mlength, scramble, scramblelength, dflag);
	}

	// Create output stream
	if (nchars == 0) nchars = inputlength*2;
	char * output = calloc(nchars+1, sizeof(char));
	unsigned char * retout = hex2passwd(input, inputlength, mapping, mlength, dflag);
	memcpy(output, retout, nchars);

	printf("%s\n", output);

	free(input);
	free(output);
	free(retout);

	return 0;
}
