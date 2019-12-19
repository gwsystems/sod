# SOD does not generally require a Makefile to build. Just drop sod.c and its accompanying
# header files on your source tree and you are done.
CC = clang
CFLAGS = -lm -Ofast -march=native -Wall -std=c99

#sod: sod.c
#	$(CC) sod.c samples/cnn_face_detection.c -o sod_face_detect -I. $(CFLAGS)

EXT = out

SAMPLES = resize_image \
	  license_plate_detection

#SAMPLES = batch_img_loading \
#		blob_detection \
#		canny_edge_detection \
#		cnn_coco \
#		cnn_face_detection \
#		cnn_object_detection \
#		cnn_voc \
#		crop_image \
#		dilate_image \
#		erode_image \
#		grayscale_image \
#		hilditch_thin \
#		hough_lines_detection \
#		license_plate_detection \
#		minutiae \
#		otsu_image \
#		realnet_face_detection \
#		realnet_face_detection_embedded \
#		realnet_train_model \
#		resize_image \
#		rnn_text_gen \
#		rotate_image \
#		sobel_operator_img

SAMPLESOUT = $(SAMPLES:%=%.$(EXT))

all: clean dir copy samples

dir:
	mkdir -p bin/

copy:
	cp samples/*.png bin/
	cp samples/*.jpg bin/

samples: $(SAMPLESOUT)

%.$(EXT):
	$(CC) $(CFLAGS) -I. -lm sod.c samples/$(@:%.$(EXT)=%.c) -o bin/$@

clean:
	rm -f bin/*
