/*NAME: Enock Gansou */

/* Part of my code is used from the required textbooks for this class */
/*
* This page contains a client program that can request a file from the server program
* on the next page. The server responds by sending the whole file.
*/
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#define BUF_SIZE 4096 /* block transfer size */
#define RCVBUFSIZE 32 

/* This function allows us to dynamically allocate space according to standard input */
char *inputString(FILE* fp, size_t size){
//The size is extended by the input with the value of the provisional
    char *str;
    int ch;
    size_t len = 0;
    str = realloc(NULL, sizeof(char)*size);//size is start size
    if(!str)return str;
    while(EOF!=(ch=fgetc(fp))){
        str[len++]=ch;
        if(len==size){
            str = realloc(str, sizeof(char)*(size+=16));
            if(!str)return str;
        }
    }
    str[len++]='\0';

    return realloc(str, sizeof(char)*len);
}

int main(int argc, char **argv){

	int c, s, bytes, in_len, len, totalBytesRcvd, bytesRcvd;
	char *in; /* buffer for incoming file */
	char *out;
	struct hostent *h; /* info about server */
	struct sockaddr_in channel; /* holds IP address */
	if (argc != 3) fatal("Usage: client server-name port");
	h = gethostbyname(argv[1]); /* look up host’s IP address */
	if (!h) fatal("gethostbyname failed");
	s = socket(PF_INET, SOCK_STREAM, 0);
	if (s < 0) fatal("socket");

	memset(&channel, 0, sizeof(channel));
	channel.sin_family= AF_INET;
	memcpy(&channel.sin_addr.s_addr, h->h_addr, h->h_length);
	channel.sin_port= htons(atoi(argv[2]));

	/* Establish the connection to the echo server */
	c = connect(s, (struct sockaddr *) &channel, sizeof(channel));
	if (c < 0) fatal("connect failed");

	/*memset(in, 0, BUF_SIZE);
	memset(out, 0, BUF_SIZE); 
	fgets(in, BUF_SIZE, stdin); */

	/* get the string from standard input */
	in = inputString(stdin, 10);
	in_len = strlen(in);

	/* Send the string to the server */ 
	if (send(s, in, in_len, 0) != in_len) fatal("send() sent a different number of bytes than expected"); 


	out = malloc(in_len + 1000);
	memset(out, 0, in_len + 1000); 

	/* Receive the same string back from the server */ 
	totalBytesRcvd = 0;
	while (totalBytesRcvd < in_len) {
		/* Receive up to the buffer size (minus 1 to leave space for
		a null terminator) bytes from the sender */
		if ((bytesRcvd = recv(s, out, RCVBUFSIZE - 1, 0)) <= 0) fatal("recv() failed or connection closed prematurely");
			totalBytesRcvd += bytesRcvd; /* Keep tally of total bytes */
			out[bytesRcvd] = '\0'; /* Terminate the string! */
			printf("%s", out); /* Print the echo buffer */
	}

	free(in);
	free(out);

	close(s);
  	exit(0);
  
}
  

void fatal(char *string){
	printf("%s\n", string);
	exit(1);
}
