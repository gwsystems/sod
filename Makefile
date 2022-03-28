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

RESIZE_IMAGE_HYPERFINE_ARGS = -w 10
RESIZE_IMAGE_PRE =
RESIZE_IMAGE_POST = <$(abspath ./samples/plate.jpg)
LICENSE_PLATE_DETECTION_HYPERFINE_ARGS = -w 10
LICENSE_PLATE_DETECTION_PRE =
LICENSE_PLATE_DETECTION_POST = <$(abspath ./samples/plate.jpg) 

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
	${RESIZE_IMAGE_PRE} wasmtime resize_image.wasm ${RESIZE_IMAGE_POST}

.PHONY: resize_image.run_wasmtime_aot
resize_image.run_wasmtime_aot: resize_image.cwasm
	${RESIZE_IMAGE_PRE} wasmtime run --allow-precompiled resize_image.cwasm ${RESIZE_IMAGE_POST}

.PHONY: resize_image.run_wasm3
resize_image.run_wasm3: resize_image.wasm
	${RESIZE_IMAGE_PRE} wasm3 resize_image.wasm ${RESIZE_IMAGE_POST}

.PHONY: resize_image.run_wamr_int
resize_image.run_wamr_int: resize_image.wasm
	${RESIZE_IMAGE_PRE} iwasm resize_image.wasm ${RESIZE_IMAGE_POST}

.PHONY: resize_image.run_wamr_aot
resize_image.run_wamr_aot: resize_image.aot
	${RESIZE_IMAGE_PRE} iwasm resize_image.aot ${RESIZE_IMAGE_POST}

.PHONY: resize_image.run_native
resize_image.run_native: resize_image.out
	${RESIZE_IMAGE_PRE} ./resize_image.out ${RESIZE_IMAGE_POST}

# Returns the coordinates of a bounding box where the license plate is located
.PHONY: license_plate_detection.run
license_plate_detection.run_wasmtime_jit: license_plate_detection.wasm
	@${LICENSE_PLATE_DETECTION_PRE} wasmtime license_plate_detection.wasm ${LICENSE_PLATE_DETECTION_POST}

.PHONY: license_plate_detection.run_wasmtime_aot
license_plate_detection.run_wasmtime_aot: license_plate_detection.cwasm
	@${LICENSE_PLATE_DETECTION_PRE} wasmtime run --allow-precompiled license_plate_detection.cwasm ${LICENSE_PLATE_DETECTION_POST}

# Error: [trap] stack overflow
# .PHONY: license_plate_detection.run_wasm3
# license_plate_detection.run_wasm3: license_plate_detection.wasm
# 	${LICENSE_PLATE_DETECTION_PRE} wasm3 license_plate_detection.wasm ${LICENSE_PLATE_DETECTION_POST}

# Exception: wasm operand stack overflow
# .PHONY: license_plate_detection.run_wamr_int
# license_plate_detection.run_wamr_int: license_plate_detection.wasm
# 	${LICENSE_PLATE_DETECTION_PRE} iwasm license_plate_detection.wasm ${LICENSE_PLATE_DETECTION_POST}

.PHONY: license_plate_detection.run_wamr_aot
license_plate_detection.run_wamr_aot: license_plate_detection.aot
	${LICENSE_PLATE_DETECTION_PRE} iwasm license_plate_detection.aot ${LICENSE_PLATE_DETECTION_POST}

.PHONY: license_plate_detection.run_native
license_plate_detection.run_native: license_plate_detection.out
	@${LICENSE_PLATE_DETECTION_PRE} ./license_plate_detection.out ${LICENSE_PLATE_DETECTION_POST}

.PHONY: clean
clean:
	rm -f *.wasm 
	rm -f *.out 
	rm -f temp.jpg
	rm -f ${SAMPLES}
	rm -f *bench.csv

license_plate_detection.bench.csv: license_plate_detection.wasm license_plate_detection.cwasm license_plate_detection.out license_plate_detection.aot 
	hyperfine ${LINCENSE_PLATE_DETECTION_HYPERFINE_ARGS} --export-csv $@ \
		-n license_plate_detection_native       '${LICENSE_PLATE_DETECTION_PRE} ./license_plate_detection.out ${LICENSE_PLATE_DETECTION_POST}' \
		-n license_plate_detection_wasmtime_jit '${LICENSE_PLATE_DETECTION_PRE} wasmtime run license_plate_detection.wasm ${LICENSE_PLATE_DETECTION_POST}' \
		-n license_plate_detection_wasmtime_aot '${LICENSE_PLATE_DETECTION_PRE} wasmtime run --allow-precompiled license_plate_detection.cwasm ${LICENSE_PLATE_DETECTION_POST}' \
		-n license_plate_detection_wamr_aot     '${LICENSE_PLATE_DETECTION_PRE} iwasm license_plate_detection.aot ${LICENSE_PLATE_DETECTION_POST}'
		
# -n license_plate_detection_wasm3        '${LICENSE_PLATE_DETECTION_PRE} wasm3 license_plate_detection_wasm3.wasm ${LICENSE_PLATE_DETECTION_POST}'
# -n license_plate_detection_wamr_int     '${LICENSE_PLATE_DETECTION_PRE} iwasm license_plate_detection.wasm ${LICENSE_PLATE_DETECTION_POST}'

resize_image.bench.csv: resize_image.wasm resize_image.cwasm resize_image.out resize_image.aot
	hyperfine ${RESIZE_IMAGE_HYPERFINE_ARGS} --export-csv $@ \
		-n resize_image_native                  '${RESIZE_IMAGE_PRE} ./resize_image.out ${RESIZE_IMAGE_POST}' \
		-n resize_image_wasmtime_jit            '${RESIZE_IMAGE_PRE} wasmtime run resize_image.wasm ${RESIZE_IMAGE_POST}' \
		-n resize_image_wasmtime_aot            '${RESIZE_IMAGE_PRE} wasmtime run --allow-precompiled resize_image.cwasm ${RESIZE_IMAGE_POST}' \
		-n resize_image_wamr_int                '${RESIZE_IMAGE_PRE} iwasm resize_image.wasm ${RESIZE_IMAGE_POST}' \
		-n resize_image_wamr_aot                '${RESIZE_IMAGE_PRE} iwasm resize_image.aot ${RESIZE_IMAGE_POST}' \
		-n resize_image_wasm3                   '${RESIZE_IMAGE_PRE} wasm3 resize_image.wasm ${RESIZE_IMAGE_POST}'
