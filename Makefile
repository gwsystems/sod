CC=clang
CFLAGS=-O3 -I. -Wall
LDFLAGS=-flto

WASMCC=${WASI_SDK_PATH}/bin/clang --sysroot=${WASI_SDK_PATH}/share/wasi-sysroot/
WASMCFLAGS=${CFLAGS}

# See https://lld.llvm.org/WebAssembly.html
WASMLDFLAGS=${LDFLAGS} -Wl,--allow-undefined,-z,stack-size=32768,--threads=1

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

# Disassemble WebAssembly binary
%.wat: %.wasm
	wasm2wat $< -o $@

# wasmtime AOT
%.cwasm: %.wasm
	wasmtime compile $< -o $@

# wamr AOT
%.aot: %.wasm
	wamrc -o $@ $<

# wasm2c WIP
# %.wasm.c: %.wasm
# 	wasm2c $< -o $@


WASMLDFLAGS+= -Wl,-z,stack-size=64000 -Wl,--export=malloc -Wl,--export=free
# WASMLDFLAGS+=-Wl,-z,stack-size=64000

# It is unclear if CPU_FREQ was intentionally left off the wasm build or not
CFLAGS+= -DSOD_DISABLE_CNN -DLIBCOX_DISABLE_DISK_IO -DCPU_FREQ=3600 
LDFLAGS+= -lm

WASMCFLAGS+= -D_WASI_EMULATED_MMAN -DWASM -DSOD_DISABLE_CNN -DLIBCOX_DISABLE_DISK_IO -DCPU_FREQ=3600 
WASMLDFLAGS+= -lwasi-emulated-mman

SAMPLES = resize_image license_plate_detection

.PHONY: all
all: \
	resize_image.out \
	resize_image.wasm \
	resize_image.cwasm \
	resize_image.aot \
	license_plate_detection.out \
	license_plate_detection.wasm \
	license_plate_detection.cwasm \
	license_plate_detection.aot

.PHONY: samples
samples: ${SAMPLES}

.PHONY: samples.wasm
samples.wasm: ${SAMPLES:=.wasm}

%.out: sod.c samples/%.c
	@${CC} ${CFLAGS} ${LDFLAGS} $^ -o $@

%.wasm: sod.c samples/%.c
	@${WASMCC} ${WASMCFLAGS} ${WASMLDFLAGS} $^ -o $@

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

.PHONY: resize_image.run_wamr_int
resize_image.run_wamr_int: resize_image.wasm
	iwasm resize_image.wasm <samples/plate.jpg

.PHONY: resize_image.run_wamr_aot
resize_image.run_wamr_aot: resize_image.aot
	iwasm resize_image.aot <samples/plate.jpg

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

# Error: [trap] stack overflow
# .PHONY: license_plate_detection.run_wasm3
# license_plate_detection.run_wasm3: license_plate_detection.wasm
# 	wasm3 license_plate_detection.wasm <samples/plate.jpg

# Exception: wasm operand stack overflow
# .PHONY: license_plate_detection.run_wamr_int
# license_plate_detection.run_wamr_int: license_plate_detection.wasm
# 	iwasm license_plate_detection.wasm <samples/plate.jpg

.PHONY: license_plate_detection.run_wamr_aot
license_plate_detection.run_wamr_aot: license_plate_detection.aot
	iwasm license_plate_detection.aot <samples/plate.jpg

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

bench.csv: license_plate_detection.wasm license_plate_detection.cwasm license_plate_detection.out license_plate_detection.aot resize_image.wasm resize_image.cwasm resize_image.out resize_image.aot
	hyperfine -w 10 --export-csv bench.csv \
		-n license_plate_detection_native       './license_plate_detection.out <samples/plate.jpg' \
		-n license_plate_detection_wasmtime_jit 'wasmtime run license_plate_detection.wasm <samples/plate.jpg' \
		-n license_plate_detection_wasmtime_aot 'wasmtime run --allow-precompiled license_plate_detection.cwasm <samples/plate.jpg' \
		-n license_plate_detection_wamr_aot     'iwasm license_plate_detection.aot <samples/plate.jpg' \
		-n resize_image_native                  './resize_image.out <samples/plate.jpg' \
		-n resize_image_wasmtime_jit            'wasmtime run resize_image.wasm <samples/plate.jpg' \
		-n resize_image_wasmtime_aot            'wasmtime run --allow-precompiled resize_image.cwasm <samples/plate.jpg' \
		-n resize_image_wamr_int                'iwasm resize_image.wasm <samples/plate.jpg' \
		-n resize_image_wamr_aot                'iwasm resize_image.aot <samples/plate.jpg' \
		-n resize_image_wasm3                   'wasm3 resize_image.wasm <samples/plate.jpg'

# -n license_plate_detection_wasm3        'wasm3 license_plate_detection_wasm3.wasm <samples/plate.jpg' \
# -n license_plate_detection_wamr_int     'iwasm license_plate_detection.wasm' \