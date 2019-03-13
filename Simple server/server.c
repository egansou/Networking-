/*NAME: Enock Gansou*/

#include <stdio.h>  /* printf() and fprintf()  */
#include <string.h>	/* for using strtok, strcmp, etc */
#include <unistd.h> /* for close() */
#include <sys/types.h>
#include <stdlib.h> /* for atoi() */
#include <sys/socket.h> /* for socket(), bind(), and connect */
#include <netinet/in.h>
#include <arpa/inet.h> /* sockaddr_in and inet_ntoa() */
#include <netdb.h>

#include "common.h"

/* Error message and closing socket*/
void fatal(int clntSocket, char *ip, int port){
	printf("**Error** from %s:%d\n", ip, port);
	fflush(stdout);
	close(clntSocket);
}


/* This function allows to compute the cookie value and adds it to a string */
void getcookie(char *c, char *ip){

	char cookie[10];
	char copy[30];

	char *token;
	int total;

	memset(cookie, 0, 10); 
	memset(copy, 0, 30); 

	strcpy(copy, ip);

	

	/* get the first token */
	token = strtok(copy, ".");

	/* walk through other tokens */
	while( token != NULL ) {
		total += atoi(token);
		token = strtok(NULL, ".");
	}

	total *= 13;
	total %= 1111;

	sprintf(cookie, "%d", total);

	strcpy(c, cookie);
}

/* This function allows us to determine if the message received from the client is valid or not.
Returns 0 if it is invalid, 1 otherwise. */
int check(char *msg, int id, char *cookie, char *login, char *name ){

	char copy[MAX_STR_SIZE + 1];
	char *fields[5] = { NULL };

	size_t n;

	char delimit[]=" \t\r\n\v\f";
	int i = 0;

	/* copy the message */
	memcpy (copy, msg, MAX_STR_SIZE + 1);

	/* Getting at most 5 strings from the meaage */ 
	fields[i]=strtok(copy ,delimit);    
    while(i < 4 && fields[i]!=NULL)                    
    {
      i++;
      fields[i]=strtok(NULL,delimit);
    }

    /* Make sure we point to the last valid we obtained */
    if(fields[i] == NULL) i--;

    /* Handling HELLO defined by id equals to 1 */
    if( id == 1){
    	/* Make sure we just obtained 4 srtings */
    	if( i != 3){
    		return 0;
    	}

    	if( (strcmp(fields[0], MAGIC_STRING) != 0) || (strcmp(fields[1], "HELLO") != 0) ){
    		return 0;
    	}

    	strcpy(login, fields[2]);
    	strcpy(name, fields[3]);

    }

    /* Handling CLIENT_BYE defined by id equals to 2 */
    if( id == 2){

    	/* Make sure we just obtained 3 srtings */
    	if( i != 2){
    		return 0;
    	}

    	if( (strcmp(fields[0], MAGIC_STRING) != 0) || (strcmp(fields[1], "CLIENT_BYE") != 0) || (strcmp(fields[2], cookie) != 0) ){
    		return 0;
    	}

    }
   
   return 1;
    
}


/* This function ensures the required communication between the client and the server */
void HandleTCPClient(int clntSocket, char *ip, int port){

	char echoBuffer[MAX_STR_SIZE + 1]; /* Buffer for echo string - include the null character */
	int recvMsgSize; /* Size of received message */
	char cookie[10];
	char login[MAX_STR_SIZE + 1];
	char name[MAX_STR_SIZE + 1];


	memset(echoBuffer, 0, MAX_STR_SIZE + 1); 


	/* Receive message from client */
	if ((recvMsgSize = recv(clntSocket, echoBuffer, MAX_STR_SIZE, 0)) < 0 || recvMsgSize > MAX_STR_SIZE){
		   fatal(clntSocket, ip, port); 
	} 

	else {

		memset(login, 0, MAX_STR_SIZE + 1); 
		memset(name, 0, MAX_STR_SIZE + 1);

		/* check the validity of the first message sent by the client */
		if(check(echoBuffer, 1, NULL, login, name) == 0) {
			fatal(clntSocket, ip, port);
		} 

		else {
			memset(echoBuffer, 0, MAX_STR_SIZE + 1);

			/* Getting cookie */
			memset(cookie, 0, 10); 
			getcookie(cookie, ip);

			/* Design the message STATUS sent by the server */
			sprintf(echoBuffer, "%s STATUS %s %s:%d", MAGIC_STRING, cookie, ip, port); 

			recvMsgSize = strlen(echoBuffer);

			/* send message STATUS to client */
			send(clntSocket, echoBuffer, recvMsgSize, 0);
			
			/* reset the buffer */
			memset(echoBuffer, 0, MAX_STR_SIZE + 1); 

			/* See if there is more data to receive */
			if ((recvMsgSize = recv(clntSocket, echoBuffer, MAX_STR_SIZE, 0)) < 0 || recvMsgSize > MAX_STR_SIZE ){
				fatal(clntSocket, ip, port);
			}

			else {

				/* check the validity of the second message sent by the client */
				if (check(echoBuffer, 2, cookie, NULL, NULL) == 0) {
					fatal(clntSocket, ip, port);
				} 
				else {
					memset(echoBuffer, 0, MAX_STR_SIZE + 1); 

					sprintf(echoBuffer, "%s SERVER_BYE", MAGIC_STRING); 

					recvMsgSize = strlen(echoBuffer);

					/* send message SERVER_BYE to client */
					send(clntSocket, echoBuffer, recvMsgSize, 0); 
				
					/* reset the buffer */
					memset(echoBuffer, 0, MAX_STR_SIZE + 1); 

					/* Make sure the communication ends there */
					if ((recvMsgSize = recv(clntSocket, echoBuffer, MAX_STR_SIZE, 0)) == 0){
						printf("%s %s %s from %s:%d\n", cookie, login, name, ip, port);
						fflush(stdout);
					}
					else {
						fatal(clntSocket, ip, port);
					}

					close(clntSocket); /* Close client socket */
				}
			} 
		}
	}
}
    

int main(int argc, char *argv[]) {

	int servSock; /* Socket descriptor for server */
	int clntSock; /* Socket descriptor for client */ 
	struct sockaddr_in echoServAddr; /* Local address */
	struct sockaddr_in echoClntAddr; /* Client address */
	unsigned short echoServPort; /* Server port */
	unsigned int clntLen; /* Length of client address data structure */

	if (argc == 1) {
		echoServPort = SERVER_PORT; /* default port */
	}
	else if (argc == 2) {
		echoServPort = atoi(argv[1]);
	}
	/* In our case, we will assume the correct usage. Please, disregard this. */
	else {
		printf("usage: ./server [<port>]\n");
		fflush(stdout);
		exit(1);
	}
	
	/* Create socket for incoming connections */
	servSock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
	
	/* Construct local address structure */
	memset(&echoServAddr, 0, sizeof(echoServAddr)); /* Zero out structure */
	echoServAddr.sin_family = AF_INET; /* Internet address family */
	echoServAddr.sin_addr.s_addr = htonl(INADDR_ANY);  
	echoServAddr.sin_port = htons(echoServPort); /* Local port */

	/* Bind to the local address */
	bind(servSock, (struct sockaddr *)&echoServAddr, sizeof(echoServAddr));
		
	/* Mark the socket so it will listen for incoming connections */
	listen(servSock, MAXPENDING);

	for (;;) { /* Run forever */

		/* Set the size of the in-out parameter */
		clntLen = sizeof(echoClntAddr);

		/* Wait for a client to connect */
		if ((clntSock = accept(servSock, (struct sockaddr *) &echoClntAddr, &clntLen)) >= 0) {

			/* We pass in the client ip address and its port */
			HandleTCPClient (clntSock, inet_ntoa(echoClntAddr.sin_addr), ntohs(echoClntAddr.sin_port)) ;
		}	
	}
	
	/* NOT REACHED */

	return 0;
}








