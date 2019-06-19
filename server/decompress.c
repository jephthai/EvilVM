//
// Microsoft's compress API has oddball compression algorithms that aren't
// so friendly to the normal Linux ecosystem.  This program uses libwim
// to decompress LZMS-compressed buffers.  In the future, I intend to make
// this a ruby wrapper so there's nothing external to the server, but this
// is a pragmatic solution for now.
//
// Make sure you have libwim:
//
//    # apt install libwim-dev
//  
// Compile this with:
//
//    # gcc -o decompress decompress.c -lwim
//

#include <wimlib.h>

#include <errno.h>
#include <error.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	uint32_t block_size;
	struct wimlib_decompressor *decompressor;
	char x;
	unsigned int total_size;
	int bogus;
	int offset = 0;

	read(0, &total_size, 4);
	read(0, &total_size, 4);
	read(0, &total_size, 4);

	read(0, &block_size, 4);
	read(0, &block_size, 4);

	read(0, &bogus, 4);

	char *source = (void*)malloc(block_size);
	char *dest = (void*)malloc(total_size);

	if(wimlib_create_decompressor(WIMLIB_COMPRESSION_TYPE_LZMS, block_size, &decompressor)) {
	  printf("Error creating decompressor!\n");
	  return 1;
	}

	while(offset < total_size) {
	  int amount = offset + block_size > total_size ? total_size - offset : block_size;

	  read(0, &bogus, 4);
	  read(0, source, bogus);

	  if (wimlib_decompress(source, bogus, dest + offset, amount,
				decompressor)) {
	    return 1;
	  }
	  offset += amount;
	}

	write(1, dest, total_size);
	
	wimlib_free_decompressor(decompressor);

	return 0;
}
