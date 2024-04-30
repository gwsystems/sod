/*
 * Programming introduction with the SOD Embedded Convolutional/Recurrent Neural Networks (CNN/RNN) API.
 * Copyright (C) PixLab | Symisc Systems, https://sod.pixlab.io
 */
/*
* Compile this file together with the SOD embedded source code to generate
* the executable. For example:
*
*  gcc sod.c cnn_face_detection.c -lm -Ofast -march=native -Wall -std=c99 -o sod_cnn_intro
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
#include <unistd.h>
#include <stdlib.h>
#include "sod.h"

#define MAX_IMG_SIZE (1024*1024)

/* Real-Time multi-scale face detection using SOD CNN */
int main(int argc, char *argv[])
{
	size_t zImgSz = 0;
	unsigned char *zInpbuf = NULL;
	// unsigned long long s = get_time(), e;

	zInpbuf = malloc(MAX_IMG_SIZE);
	if (!zInpbuf) return -1;

	ssize_t bytes_read;
	while ((bytes_read = read(STDIN_FILENO, zInpbuf + zImgSz, MAX_IMG_SIZE - zImgSz)) > 0) {
		zImgSz += bytes_read;
		if (zImgSz >= MAX_IMG_SIZE) return -1;
	}
	if (zImgSz <= 0) return -1;

	/* Load the input image in the grayscale colorspace */
	sod_img imgIn = sod_img_load_from_mem(zInpbuf, zImgSz, SOD_IMG_COLOR);
	if (imgIn.data == 0) {
		/* Invalid path, unsupported format, memory failure, etc. */
		puts("Cannot load input image..exiting");
		return 0;
	}

	/* The CNN handle that should perform the detection process */
	sod_cnn *pNet;

	int rc;
	const char *zErr; /* Error log if any */
	/*
	 * Create our CNN handle using the built-in `face`
	 * architecture trained to detect frontal, partial, 
	 * tiny & large faces at Real-time.
	 */
	rc = sod_cnn_create(&pNet, ":face", "./face_cnn.sod", &zErr);
	/*
	 * ":face" is the magic word for the built-in face (single class) 
	 * architecture. The list of built-in Magic words (pre-ready to use 
	 * configurations and their associated models) are documented here:
	 * https://sod.pixlab.io/c_api/sod_cnn_create.html.
	 *
	 * "face_cnn.sod" is the pre-trained model associated with the ":face" architecture 
	 *  and is available to download from https://pixlab.io/downloads
	 */
	if (rc != SOD_OK) {
		/* Display the error message and exit */
		puts(zErr);
		return 0;
	}
	/*
	 * A sod_box instance always store the coordinates for each detected object
	 * returned by the CNN via sod_cnn_predict() as we'll see later.
	 */
	sod_box *box;
	int i, nbox;
	/* Prepare our input image for the detection process which 
	 * is resized to the network dimension (This op is always very fast)
	 */
	float * blob = sod_cnn_prepare_image(pNet, imgIn);
	if (!blob) {
		/* Very unlikely this happen: Invalid architecture, out-of-memory */
		puts("Something went wrong while preparing image..");
		return 0;
	}

	/* Detect.. */
	sod_cnn_predict(pNet, blob, &box, &nbox);
	/* Report the detection result. */
	printf("%d face(s) were detected..\n",nbox);
	for (i = 0; i < nbox; i++) {
		/* Report the coordinates and score of the current detected face */
		printf("(%s) X:%d Y:%d Width:%d Height:%d score:%f%%\n", box[i].zName, box[i].x, box[i].y, box[i].w, box[i].h, box[i].score * 100);
		if( box[i].score < 0.3) continue;   /* Discard low score detection, remove if you want to report all objects */
	}
	/* Finally save our output image with the boxes drawn on it */
	/* Cleanup */
	sod_free_image(imgIn);
	free(zInpbuf);
	/* Release all resources allocated to the CNN handle */
	sod_cnn_destroy(pNet);
	return 0;
}