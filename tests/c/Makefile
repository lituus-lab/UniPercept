# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Avoids $(shell pwd) and selects the delete command per platform.
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
# The archive uses floating-point math; UniImage compression is pure Nim.
LIBS := -lm

ifeq ($(OS),Windows_NT)
  BIN  := test_unipercept.exe
  RUN  := $(BIN)
  RM_F := del /q
else
  BIN  := test_unipercept
  RUN  := ./$(BIN)
  RM_F := rm -f
  LIBS += -pthread
endif

.PHONY: all test run clean
all: run
test: run
run: $(BIN)
	$(RUN)
$(BIN): test_unipercept.c $(ROOT)/include/UniPercept.h $(LIB)
	$(CC) $(CFLAGS) -o $(BIN) test_unipercept.c $(LIB) $(LIBS)
# File target, not phony: `nimble ctest` already built the lib, don't redo it.
$(LIB):
	cd $(ROOT) && nimble clibStatic
clean:
	$(RM_F) $(BIN)
