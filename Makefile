WASMCC=${WASI_SDK_PATH}/bin/clang --sysroot=${WASI_SDK_PATH}/share/wasi-sysroot/
CC=clang
OPTFLAGS=-O3 -flto

WASMLINKFLAGS=-Wl,-z,stack-size=524288,--allow-undefined,--threads=1
WASMCFLAGS=${WASMLINKFLAGS} -D_WASI_EMULATED_MMAN -lwasi-emulated-mman -DWASM
CFLAGS=-I. -DSOD_DISABLE_CNN -lm -DLIBCOX_DISABLE_DISK_IO 

SAMPLES = resize_image license_plate_detection

.PHONY: samples
samples: ${SAMPLES}

.PHONY: samples.wasm
samples.wasm: ${SAMPLES:=.wasm}

# It is unclear if CPU_FREQ was intentionally left off the wasm build or not
%: samples/%.c
	@${CC} -DCPU_FREQ=3600 ${CFLAGS} ${OPTFLAGS} sod.c $^ -o $@

%.wasm: samples/%.c
	@${WASMCC} ${WASMLINKFLAGS} ${CFLAGS} ${OPTFLAGS} ${WASMCFLAGS} sod.c $^ -o $@

# Writes the resized image to temp.jpg
.PHONY: resize_image.run
resize_image.run: resize_image.wasm
	wasmtime resize_image.wasm <samples/plate.jpg > temp.jpg

.PHONY: resize_image.run_native
resize_image.run_native: resize_image
	./resize_image <samples/plate.jpg > temp.jpg

# Returns the coordinates of a bounding box where the license plate is located
.PHONY: license_plate_detection.run
license_plate_detection.run: license_plate_detection.wasm
	@wasmtime license_plate_detection.wasm <samples/plate.jpg

.PHONY: license_plate_detection.run_native
license_plate_detection.run_native: license_plate_detection
	@./license_plate_detection <samples/plate.jpg

.PHONY: clean
clean:
	rm -f *.wasm 
	rm -f temp.jpg
	rm -f ${SAMPLES}
