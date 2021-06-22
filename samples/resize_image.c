/*
 * Programming introduction with the SOD Embedded Image Processing API.
 * Copyright (C) PixLab | Symisc Systems, https://sod.pixlab.io
 */
/*
* Compile this file together with the SOD embedded source code to generate
* the executable. For example:
*
*  gcc sod.c resize_image.c -lm -Ofast -march=native -Wall -std=c99 -o sod_img_proc
*  
* Under Microsoft Visual Studio (>= 2015), just drop `sod.c` and its accompanying
* header files on your source tree and you're done. If you have any trouble
* integrating SOD in your project, please submit a support request at:
* https://sod.pixlab.io/support.html
*/
/*
* This simple program is a quick introduction on how to embed and start
* experimenting with SOD without having to do a lot of tedious
* reading and configuration.
*
* Make sure you have the latest release of SOD from:
*  https://pixlab.io/downloads
* The SOD Embedded C/C++ documentation is available at:
*  https://sod.pixlab.io/api.html
*/
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include "sod.h"
#include "get_time.h"
#define MAX_IMG_SZ (1024*1024) //1MB
/*
* Resize an image (Minify) to half its original size.
*/
int main(int argc, char *argv[])
{
//	struct stat stbf;
	size_t imgSz = 0;
	unsigned char *zInpbuf = NULL;
	// unsigned long long s = get_time(), e;

	zInpbuf = malloc(MAX_IMG_SZ);
	if (!zInpbuf) return -1;

	imgSz = read(0, zInpbuf, MAX_IMG_SZ);
	if (imgSz <= 0) return -1;
	
	sod_img imgIn = sod_img_load_from_mem(zInpbuf, imgSz, SOD_IMG_COLOR /* full color channels */);
	if (imgIn.data == 0) {
		/* Invalid path, unsupported format, memory failure, etc. */
		printf("Error loading input\n");
		free(zInpbuf);
		return -1;
	}
	/* Resize to half its original size  */
	int newWidth  = imgIn.w / 2;
	int newHeight = imgIn.h / 2;
	
	sod_img rz = sod_resize_image(imgIn, newWidth, newHeight);
	/* Save the resized image to the specified path */
	// sod_img_save_as_png(rz, NULL);
	sod_img_save_as_jpeg(rz, NULL, 0);
	/* Cleanup */
	sod_free_image(imgIn);
	sod_free_image(rz);
	free(zInpbuf);
	// e = get_time();
	// print_time(s, e);
	return 0;
}
