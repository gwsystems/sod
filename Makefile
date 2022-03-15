CC=clang
# It is unclear if CPU_FREQ was intentionally left off the wasm build or not
CFLAGS=-O3 -I. -DSOD_DISABLE_CNN -DLIBCOX_DISABLE_DISK_IO -DCPU_FREQ=3600 
LDFLAGS=-flto -lm

WASMCC=${WASI_SDK_PATH}/bin/clang --sysroot=${WASI_SDK_PATH}/share/wasi-sysroot/
WASMCFLAGS=${CFLAGS} -D_WASI_EMULATED_MMAN -DWASM

# See https://lld.llvm.org/WebAssembly.html
WASMLDFLAGS=-flto -lwasi-emulated-mman -Wl,-z,stack-size=524288,--allow-undefined,--threads=1

# Clang 12 WebAssembly Options
# See https://clang.llvm.org/docs/ClangCommandLineReference.html#webassembly
# Disable WebAssembly Proposals aWsm does not support
WASMCFLAGS+= -mno-atomics # https://github.com/WebAssembly/threads
WASMCFLAGS+= -mno-bulk-memory # https://github.com/WebAssembly/bulk-memory-operations
WASMCFLAGS+= -mno-exception-handling # https://github.com/WebAssembly/exception-handling
WASMCFLAGS+= -mno-multivalue # https://github.com/WebAssembly/multi-value
# Mutable globals still exist, but disables the ability to import mutable globals
WASMCFLAGS+= -mno-mutable-globals # https://github.com/WebAssembly/mutable-global
WASMCFLAGS+= -mno-nontrapping-fptoint # https://github.com/WebAssembly/nontrapping-float-to-int-conversions
WASMCFLAGS+= -mno-reference-types # https://github.com/WebAssembly/reference-types
WASMCFLAGS+= -mno-sign-ext # https://github.com/WebAssembly/sign-extension-ops
WASMCFLAGS+= -mno-tail-call # https://github.com/WebAssembly/tail-call
WASMCFLAGS+= -mno-simd128 # https://github.com/webassembly/simd

SAMPLES = resize_image license_plate_detection

.PHONY: samples
samples: ${SAMPLES}

.PHONY: samples.wasm
samples.wasm: ${SAMPLES:=.wasm}

%.out: sod.c samples/%.c
	@${CC} ${CFLAGS} ${LDFLAGS} $^ -o $@

%.wasm: sod.c samples/%.c
	@${WASMCC} ${WASMCFLAGS} ${WASMLDFLAGS} $^ -o $@

%.wat: %.wasm
	wasm2wat $< -o $@

%.cwasm: %.wasm
	wasmtime compile $< -o $@

# Writes the resized image to temp.jpg
.PHONY: resize_image.run_wasmtime_jit
resize_image.run_wasmtime_jit: resize_image.wasm
	wasmtime resize_image.wasm <samples/plate.jpg

.PHONY: resize_image.run_wasmtime_aot
resize_image.run_wasmtime_aot: resize_image.cwasm
	wasmtime run --allow-precompiled resize_image.cwasm <samples/plate.jpg

.PHONY: resize_image.run_wasm3
resize_image.run_wasm3: resize_image.wasm
	wasm3 resize_image.wasm <samples/plate.jpg

.PHONY: resize_image.run_native
resize_image.run_native: resize_image.out
	./resize_image.out <samples/plate.jpg

# Returns the coordinates of a bounding box where the license plate is located
.PHONY: license_plate_detection.run
license_plate_detection.run_wasmtime_jit: license_plate_detection.wasm
	@wasmtime license_plate_detection.wasm <samples/plate.jpg

.PHONY: license_plate_detection.run_wasmtime_aot
license_plate_detection.run_wasmtime_aot: license_plate_detection.cwasm
	@wasmtime run --allow-precompiled license_plate_detection.cwasm <samples/plate.jpg

.PHONY: license_plate_detection.run_wasm3
license_plate_detection.run_wasm3: license_plate_detection.wasm
	wasm3 license_plate_detection.wasm <samples/plate.jpg

.PHONY: license_plate_detection.run_native
license_plate_detection.run_native: license_plate_detection.out
	@./license_plate_detection.out <samples/plate.jpg

.PHONY: clean
clean:
	rm -f *.wasm 
	rm -f *.out 
	rm -f temp.jpg
	rm -f ${SAMPLES}
	@rm -f bench.csv

bench.csv: license_plate_detection.wasm license_plate_detection.cwasm license_plate_detection.out resize_image.wasm resize_image.cwasm resize_image.out
	hyperfine -w 10 \
	-n license_plate_detection_native './license_plate_detection.out <samples/plate.jpg' \
	-n license_plate_detection_wasmtime_jit 'wasmtime run license_plate_detection.wasm <samples/plate.jpg' \
	-n license_plate_detection_wasmtime_aot 'wasmtime run --allow-precompiled license_plate_detection.cwasm <samples/plate.jpg' \
	-n license_plate_detection_wasm3 'wasm3 license_plate_detection_wasm3.wasm <samples/plate.jpg' \
	-n resize_image_native './resize_image.out <samples/plate.jpg' \
	-n resize_image_wasmtime_jit 'wasmtime run resize_image.wasm <samples/plate.jpg' \
	-n resize_image_wasmtime_aot 'wasmtime run --allow-precompiled resize_image.cwasm <samples/plate.jpg' \
	-n resize_image_wasm3 'wasm3 resize_image_wasm3.wasm <samples/plate.jpg' \
	--export-csv bench.csv
