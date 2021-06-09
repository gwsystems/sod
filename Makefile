BASE_DIR=../../../

AWSM_CC=awsm

NATIVE_CC=clang
NATIVE_CFLAGS = -I. -DCPU_FREQ=3600 -O3 -lm -DSOD_DISABLE_CNN -DLIBCOX_DISABLE_DISK_IO

OPTFLAGS=-O3 -flto

WASM_CC=wasm32-unknown-unknown-wasm-clang
WASM_LDFLAGS=-Wl,-z,stack-size=524288,--allow-undefined,--no-threads,--stack-first,--no-entry,--export-all,--export=main,--export=dummy
WASM_CFLAGS=${WASM_LDFLAGS} -nostartfiles -DWASM -I. -DSOD_DISABLE_CNN -lm -DLIBCOX_DISABLE_DISK_IO

MEMC_64=64bit_nix.c

# for aWsm compiler
# Currently only uses wasmception backing
AWSM_DIR=${BASE_DIR}/awsm/
AWSM_RT_DIR=${AWSM_DIR}/runtime/
AWSM_RT_MEM=${AWSM_RT_DIR}/memory/
AWSM_RT_LIBC=${AWSM_RT_DIR}/libc/wasmception_backing.c
AWSM_RT_ENV=${AWSM_RT_DIR}/libc/env.c
AWSM_RT_RT=${AWSM_RT_DIR}/runtime.c
AWSM_RT_MEMC=${AWSM_RT_MEM}/${MEMC_64}
DUMMY=${AWSM_DIR}/code_benches/dummy.c

# for SLEdge serverless runtime
SLEDGE_RT_DIR=${BASE_DIR}/runtime/
SLEDGE_RT_INC=${SLEDGE_RT_DIR}/include/
SLEDGE_MEMC=${SLEDGE_RT_DIR}/compiletime/memory/${MEMC_64}

SLEDGE_BIN_DIR=${SLEDGE_RT_DIR}/bin/
WASMISA=${SLEDGE_RT_DIR}/compiletime/instr.c

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

all: dir copy

dir:
	@mkdir -p bin/

copy:
	cp samples/*.png bin/
	cp samples/*.jpg bin/

.PHONY: samples
samples:  resize_image #license_plate_detection

.PHONY: samples.wasm
samples.wasm: resize_image.wasm license_plate_detection.wasm

.PHONY: samples.so
samples.so: resize_image.so license_plate_detection.so

.PHONY: samples.out
samples.out: resize_image.out license_plate_detection.out

%: samples/%.c
	$(NATIVE_CC) $(NATIVE_CFLAGS) sod.c samples/$(@:%=%.c) -o bin/$@

%.wasm: samples/%.c
	@$(WASM_CC) $(WASM_CFLAGS) $(OPTFLAGS) sod.c $< $(DUMMY) -o bin/$@

%.out: %.wasm
	@$(AWSM_CC) $< -o $(<:.wasm=.bc)
	@$(NATIVE_CC) ${CFLAGS} ${EXTRA_CFLAGS} $(OPTFLAGS) -DUSE_MEM_VM bin/$(<:.wasm=.bc) $(AWSM_RT_LIBC) $(AWSM_RT_RT) $(AWSM_RT_ENV) $(AWSM_RT_MEMC) -o $@

%.so: %.wasm
	@$(AWSM_CC) --inline-constant-globals --runtime-globals bin/$< -o bin/$(@:.so=.bc)
	@$(NATIVE_CC) --shared -fPIC ${CFLAGS} ${EXTRA_CFLAGS} $(OPTFLAGS) -DUSE_MEM_VM -I${SLEDGE_RT_INC} bin/$(@:.so=.bc) $(WASMISA) ${SLEDGE_MEMC} -o bin/$@

.PHONY: clean
clean:
	rm -f bin/*
	rm -f *.wasm
	rm -f *.bc
	rm -f *.so
	rm -f *.out
