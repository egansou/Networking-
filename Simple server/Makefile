CC=gcc -lpthread

all: clean server chmod test submit

chmod:
	-chmod a+x server ./public_tests/*

server: 
	-(cd student && gcc server.c -o server && mv server ..)


clean:
	-(rm -f server submit.zip; rm -f ./student/*~; rm -f *~; rm -f ./build/*)

test:
	-(cp server ./build; cp public_tests/* ./build)

submit:
	-(rm -f submit.zip; cd ./student && zip ../submit.zip server.c common.h)
