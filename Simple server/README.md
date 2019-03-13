# CMSC417 Project 2


## Due Date
Due October 11th 2017 11:00PM (https://submit.cs.umd.edu)


## Overview and Warnings
This project may seem deceptively simple. While the project is trivial in nature, there is a substantial amount of error handling to be implemented for non-conforming clients. The purpose of this assignment is to illustrate the complexity of handling clients which do not conform to a protocol. 


## Getting Started
Begin by reading the project description in the project2.pdf file. Read the description carefully several times. 



## Directory Structure
In order to simplify development, we have created a directory structure for you to develop the project. Please **DO NOT** modify this structure. 

### student
This is where you should write your code. We have already projected you with a server.c file. Use this file to write your code; we have already included all of the necessary libraries for you. Write all of your code in this file.

### build
Do not modify anything in this directory, it is used by the Makefile as a staging area. You will run your compiled code from this directory.

### public_tests
We have given you two public tests in the form of precompiled executables. The code was compiled in the CORE Guest OS so you need to run it in the same environment. 

#### Clients
* client1 is a conforming client
* client2 is a non-conforming client

#### Sample Usage
./client1 localhost 9090 cmsc417000 Andrew  
./client2 localhost 9091 cmsc417001 Andrew 

## Building
Use the provided Makefile with the following options:

* server: This will build the server
* clean: this removes executables and temporary files
* test: sets up the executables in the build environment 
* submit: packages the source code for submission to the submit server
