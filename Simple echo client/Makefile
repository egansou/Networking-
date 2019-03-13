TESTS:=$(wildcard public??)
PA1:=$(pa1.c)

all0:
	make clean
	make all
	@echo done.

all: pa1 chmod

pa1: $(PA1)
	gcc pa1.c -o pa1

chmod:
	chmod a+x pa1 $(TESTS)

clean:
	(rm *~ *.out pa1 compare_file; echo clean)


