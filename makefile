DMD ?= dmd
GCC ?= gcc
ARCHFLAG ?= -m64
DFLAGS = $(ARCHFLAG) -w -debug -gc -unittest
# DFLAGS = $(ARCHFLAG) -w -O -release

LLVM_CONFIG ?= llvm-config
LLVM_LIB = `$(LLVM_CONFIG) --ldflags` `$(LLVM_CONFIG) --libs`
LIBD_LIB = -Llib -ld-llvm -ld

LDFLAGS ?=
ifdef LD_PATH
	LDFLAGS += $(addprefix -L, $(LD_PATH))
endif

LDFLAGS += -lphobos2 $(LIBD_LIB) $(LLVM_LIB)

PLATFORM = $(shell uname -s)
ifeq ($(PLATFORM),Linux)
	LDFLAGS += -lstdc++ -export-dynamic -ldl -lffi -lpthread -lm -lncurses
endif
ifeq ($(PLATFORM),Darwin)
	LDFLAGS += -lc++ -lncurses
endif

IMPORTS = $(LIBD_LLVM_IMPORTS) -I$(LIBD_LLVM_ROOT)/src
SOURCE = src/sdc/*.d src/util/*.d

SDC = bin/sdc

LIBD_ROOT = libd
LIBD_LLVM_ROOT = libd-llvm
LIBSDRT_ROOT = libsdrt
LIBSDRT_EXTRA_DEPS = $(SDC) bin/sdc.conf

ALL_TARGET = $(LIBSDRT)

include libd-llvm/makefile.common
include libsdrt/makefile.common

$(SDC): obj/sdc.o $(LIBD) $(LIBD_LLVM)
	@mkdir -p bin
	gcc -o $(SDC) obj/sdc.o $(ARCHFLAG) $(LDFLAGS)

obj/sdc.o: $(SOURCE)
	@mkdir -p lib obj
	$(DMD) -c -ofobj/sdc.o $(SOURCE) $(DFLAGS) $(IMPORTS)

bin/sdc.conf:
	@mkdir -p bin
	printf "{\n\t\"includePath\": [\"$(PWD)/libs\", \".\"],\n\t\"libPath\": [\"$(PWD)/lib\"],\n}\n" > $@

clean:
	rm -rf obj lib $(SDC)

doc:
	$(DMD) -o- -op -c -Dddoc index.dd $(SOURCE) $(DFLAGS)

.PHONY: clean run debug doc
