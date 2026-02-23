# Makefile for Assembly Echo Server
# Supports both x86_64 and ARM64

# Detect architecture
UNAME_M := $(shell uname -m)
UNAME_S := $(shell uname -s)

# x86_64 settings
ASM_X86 = nasm
ASMFLAGS_X86 = -f elf64 -g -F dwarf
SRC_X86 = echoserver.asm
OBJ_X86 = echoserver_x86.o
BIN_X86 = echoserver_x86

# ARM64 settings (override for cross-compile: make arm64 ARM_AS=aarch64-linux-gnu-as ARM_LD=aarch64-linux-gnu-ld)
ASM_ARM ?= as
ARM_LD ?= ld
SRC_ARM = echoserver_arm64.asm
OBJ_ARM = echoserver_arm64.o
BIN_ARM = echoserver_arm64

# Default binary name
BIN = echoserver

# Detect and build for current architecture
ifeq ($(UNAME_M),x86_64)
    DEFAULT_TARGET = x86_64
else ifeq ($(UNAME_M),aarch64)
    DEFAULT_TARGET = arm64
else ifeq ($(UNAME_M),arm64)
    DEFAULT_TARGET = arm64
else
    DEFAULT_TARGET = x86_64
endif

# Default target - build for current architecture
all: $(DEFAULT_TARGET)
	@echo "Built for $(DEFAULT_TARGET)"

# x86_64 target (Linux only)
x86_64: $(BIN_X86)
	ln -sf $(BIN_X86) $(BIN)

$(OBJ_X86): $(SRC_X86)
	$(ASM_X86) $(ASMFLAGS_X86) $(SRC_X86) -o $(OBJ_X86)

$(BIN_X86): $(OBJ_X86)
	ld $(OBJ_X86) -o $(BIN_X86)

# ARM64 target (Linux)
arm64: $(BIN_ARM)
	ln -sf $(BIN_ARM) $(BIN)

$(OBJ_ARM): $(SRC_ARM)
	$(ASM_ARM) -o $(OBJ_ARM) $(SRC_ARM)

$(BIN_ARM): $(OBJ_ARM)
	$(ARM_LD) -o $(BIN_ARM) $(OBJ_ARM)

# Build both architectures (for CI/CD)
both: x86_64 arm64

# Clean
clean:
	rm -f $(OBJ_X86) $(BIN_X86) $(OBJ_ARM) $(BIN_ARM) $(BIN)

# Run with default port
run: all
	./$(BIN) 8080

# Help
help:
	@echo "Assembly Echo Server Build System"
	@echo ""
	@echo "Detected: $(UNAME_M) on $(UNAME_S)"
	@echo ""
	@echo "Targets:"
	@echo "  all       - Build for current architecture (default)"
	@echo "  x86_64    - Build x86_64 version (requires NASM, Linux)"
	@echo "  arm64     - Build ARM64 version (requires GNU as, Linux)"
	@echo "  both      - Build both architectures"
	@echo "  clean     - Remove build artifacts"
	@echo "  run       - Build and run on port 8080"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Usage:"
	@echo "  make              # Build for current arch"
	@echo "  make x86_64       # Build x86_64 version"
	@echo "  make arm64        # Build ARM64 version"
	@echo "  ./echoserver [port]"

.PHONY: all x86_64 arm64 both clean run help
