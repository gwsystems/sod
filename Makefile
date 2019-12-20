BASE_DIR=../
include Makefile.wasm.inc

# SOD does not generally require a Makefile to build. Just drop sod.c and its accompanying
# header files on your source tree and you are done.
NCC = clang
NCFLAGS = -I. -DCPU_FREQ=3600 -O3 -lm -DSOD_DISABLE_CNN -DLIBCOX_DISABLE_DISK_IO
WCFLAGS = -DWASM -I. -DSOD_DISABLE_CNN -lm -DLIBCOX_DISABLE_DISK_IO

#sod: sod.c
#	$(CC) sod.c samples/cnn_face_detection.c -o sod_face_detect -I. $(CFLAGS)

EXT = out
WEXT = wout

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
SAMPLESWOUT = $(SAMPLES:%=%.$(WEXT))

all: clean dir copy

native: samples
wasm: samples.wasm
#	samples.wasm
#      	samples

dir:
	mkdir -p bin/

copy:
	cp samples/*.png bin/
	cp samples/*.jpg bin/

samples: $(SAMPLESOUT)

samples.wasm: $(SAMPLESWOUT)

%.$(EXT):
	$(NCC) $(NCFLAGS) sod.c samples/$(@:%.$(EXT)=%.c) -o bin/$@

%.$(WEXT):
	$(WASMCC) $(WCFLAGS) $(WASMCFLAGS) $(OPTFLAGS) sod.c samples/$(@:%.$(WEXT)=%.c) $(DUMMY) -o bin/$(@:%.$(WEXT)=%.wasm)
	$(SFCC) bin/$(@:%.$(WEXT)=%.wasm) -o bin/$(@:%.$(WEXT)=%.bc)
	$(CC) ${CFLAGS} ${EXTRA_CFLAGS} $(OPTFLAGS) -D$(USE_MEM) bin/$(@:%.$(WEXT)=%.bc) $(RT_LIBC) $(RT_RT) ${MEMC} -o bin/$@

clean:
	rm -f bin/*
