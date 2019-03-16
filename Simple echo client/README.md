# Simple Echo client
Writing a client program which will communicate with an echo server using socket in C. 

Steps:
1. Connect using TCP to argv[1] with port argv[2].
2. Read stdin and write that stuﬀ to the TCP socket until stdin ends (end of ﬁle).
3. Shutdown the socket for writing. See shutdown(2). (i.e., man shutdown)
4. Read what the TCP socket has and write that stuﬀ to stdout until the socket ends (end of ﬁle because the other side closed). 
5. Exit. 

