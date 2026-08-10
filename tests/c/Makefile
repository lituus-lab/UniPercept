# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Shell-free: `pwd` and `rm` are unavailable under mingw32-make on Windows.
ifeq ($(origin CC),default)
  ifeq ($(OS),Windows_NT)
    CC := gcc
  else
    CC := cc
  endif
endif

ROOT   := $(CURDIR)/../..
CFLAGS := -I$(ROOT)/include -O2 -Wall -Wextra -std=c11
LIB    := $(ROOT)/libUniPercept.a
# libUniPercept.a references uncompress/compress2 (UniImage PNG/DEFLATE codecs
# via libz FFI); a C consumer must supply libz itself, even when only decoding
# PPM — the archive pulls in the full UniImage codec set reachable from decode.
ifeq ($(OS),Windows_NT)
  LIBS := -lz
else
  LIBS := -lz
endif

ifeq ($(OS),Windows_NT)
  BIN  := test_unipercept.exe
  RUN  := $(BIN)
  RM_F := del /q
else
  BIN  := test_unipercept
  RUN  := ./$(BIN)
  RM_F := rm -f
endif

.PHONY: all run clean
all: run
run: $(BIN)
	$(RUN)
$(BIN): test_unipercept.c $(ROOT)/include/UniPercept.h $(LIB)
	$(CC) $(CFLAGS) -o $(BIN) test_unipercept.c $(LIB) $(LIBS)
# File target, not phony: `nimble ctest` already built the lib, don't redo it.
$(LIB):
	cd $(ROOT) && nimble clibStatic
clean:
	$(RM_F) $(BIN)
