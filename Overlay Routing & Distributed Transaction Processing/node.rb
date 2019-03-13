require 'socket'
require 'thread'
require 'set'

Thread.abort_on_exception = true

$port = nil #port for self node
$hostname = nil #hostname for self node
$clock = 0
$updateInterval = nil
$maxPayload = nil
$pingTimeout = nil
$nextMessageID = 1


$inf = Float::INFINITY

$listener = nil

$socketList = [] #list of all sockets for receiver thread

$nameToNode = {} #Hashmap to look up an Node object from its hostname
$socketToNode = {} #Hashmap to look up Node object from its socket - may have several sockets for one node, shouldnt matter

$edges = {} #Hashmap to store the routing table 


$adjacencyMatrix = nil #distance matrix for Djikstra's, infinity means unreachable for now
$adjacencyKey = nil #sorted list of Node names, indexing is same as rows/columns of adjacency matrix


$lock = Mutex.new #lock for everything 
$pinglock = Mutex.new #lock for ping

$listener_T = nil #thread ID for listener thread
$receiver_T = nil #thread ID for receiver thread
#$command_T = nil #original thread is command thread, may change later
$clock_T = nil #thread ID for clock thread
$linkUpdate_T = nil #thread ID for link broadcast and djikstra's thread


class Node
	#attr_accessors allow getting and setting of Node instance variables
	attr_accessor :hostname
	attr_accessor :IP
	attr_accessor :port 
	attr_accessor :socket
	attr_accessor :nextHop
	attr_accessor :cost
	def initialize(hostname, port)
		@hostname = hostname #set during setup
		@IP = nil #set during edgeB
		@port = port #set during setup
		@socket = nil #socket to/from this node
		@nextHop = nil #don't know how to reach before edgeB
		@cost = nil #no cost/distance before edgeB
	end

	def to_s()
		return "#{@hostname}, #{@port}" #for debugging purposes, add other Node instance vars  if we need
	end
end


def lsp()
	message = "LINKSTATE|"
	$edges.each do |key, value|
		key_str = key.join("=")
		message += "#{key_str}=#{value} "
	end


	message +="|" 
	# send message out in each socket we know to be our neighbors
	$socketList.each{|socket|
		#STDOUT.puts("#{socket}")
		socket.puts(message)
		socket.flush
		sleep(1)
	}	
	#STDOUT.puts("lsp")
end

def prepareDjikstra()

	keys = Set.new

	# First get all the keys
	$edges.each do |key, value|
		if (value != -1)
			keys.add(key[0])
			keys.add(key[1])
		end
	end
	
	$adjacencyKey = keys.to_a
	$adjacencyKey.sort!	

	count = $adjacencyKey.length - 1

	$adjacencyMatrix = [] 
	for i in 0..count do 
		entry = [] 
		for j in 0..count do 
			if i == j 
				entry.push(0) 
			else  
				entry.push($inf) 
			end 
		end 
		$adjacencyMatrix.push(entry) 
	end 

	$edges.each do |key, value|
		if (value != -1)
			$adjacencyMatrix[djikstraIndex(key[0])][djikstraIndex(key[1])] = value
		end
	end
end

def runDjikstra()
	costList = []
	predList = []
	unvisited = []

	$adjacencyKey.each {|node|
		if (node.eql? $hostname)
			costList.push(0)
		else
			costList.push($inf)
		end
		predList.push(nil)
		unvisited.push(node)
	}

	while unvisited.length != 0

		currIndex = minDistance(costList, unvisited)
		currNode = $adjacencyKey[currIndex]
		unvisited.delete(currNode)
		nb_idx = 0

		$adjacencyMatrix[currIndex].each {|dist|
			
			nb_name = $adjacencyKey[nb_idx]

			# The neighbor must not have been visitied, the distance is not zero or infinity
			if ((unvisited.include?(nb_name)) && (dist != 0) && (dist != $inf))
					
				alt = costList[currIndex] + dist 
				if (alt < costList[nb_idx])
					costList[nb_idx] = alt
					predList[nb_idx] = currNode
				end
			end

			nb_idx = nb_idx + 1
		}

	end


	$adjacencyKey.each{ |nodeName|
		if ( !(nodeName.eql? $hostname) )

			nexthop = getNextHop(nodeName, predList)
			
			node = $nameToNode[nodeName]
			nextNode = $nameToNode[nexthop]
			node.socket = nextNode.socket #save socket in node obj
			node.nextHop = nexthop
			cost = costList[djikstraIndex(nodeName)]
			node.cost = cost
		end
	}
end

def minDistance(costList, unvisited)            
    min = $inf
    min_index = -1
  
    unvisited.each{ |nodeName|
    	idx = djikstraIndex(nodeName)

    	if (costList[idx] <= min)
    		min = costList[idx]
    		min_index = idx 
    	end
    }
    return min_index 
end

# Passing the node name and retrieves its index 
def djikstraIndex(name)
	return $adjacencyKey.index(name)
end

def getNextHop(nodeName, predList)
	

	idx = djikstraIndex(nodeName)

	pred = predList[idx]
	
	if (pred.eql? $hostname)
		return nodeName
	else 
		getNextHop(pred, predList)
	end
end



# --------------------- Part 1 --------------------- # 

def dumptable(cmd)

	table = []	
	$nameToNode.each_value{ |node|
		if (node.nextHop != nil) #only put nodes we have a path to
			table.push("#{$hostname},#{node.hostname},#{node.nextHop},#{node.cost}")
		end
	}
	

	table.sort! #routing table must be sorted

	outfile = File.open(cmd[0], "w") { |io|  #write routing table to specified file
		io.puts table
	}
end

def shutdown(cmd)

	
	Thread.kill($listener_T)
	Thread.kill($receiver_T)
	Thread.kill($clock_T)
	Thread.kill($linkUpdate_T)
	
	$socketList.each { |socket|
		socket.close #close all connections
	}

	$listener.close
	STDOUT.flush
	STDERR.flush
	exit(0)
end

def edgeb(cmd)
	srcIP = cmd[0]
	dstIP = cmd[1]
	dstName = cmd[2]
	dstPort = nil
	node = nil
	
	node = $nameToNode[dstName]
		
	dstPort = node.port
		
	socket = TCPSocket.new(dstIP, dstPort)

	socket.puts("EDGEB|#{dstName}|#{srcIP}|#{$hostname}|")
	socket.flush

	node.IP = dstIP
	node.nextHop = dstName
	node.socket = socket
	node.cost = 1

	$socketToNode[socket] = dstName
	$socketList.push(socket)	
	
	# Store the specific edges
	$edges[[$hostname,dstName]] = 1
	$edges[[dstName, $hostname]] = 1
	
end

# --------------------- Part 2 --------------------- # 

def edgeu(cmd)

	dstName = cmd[0]
	newCost = cmd[1]

	node = $nameToNode[dstName]

	node.cost = newCost #update the weight of the edge to the specified node
	node.nextHop = dstName
	$edges[[$hostname,dstName]] = newCost.to_i

end

def edged(cmd)

	dstName = cmd[0]
	node = $nameToNode[dstName]

	socket = node.socket 
	socket.close 

	node.socket = nil
	node.nextHop = nil 
	node.cost = nil

	$socketToNode.delete(socket) 
	$socketList.delete(socket) 

	$edges[[$hostname,dstName]] = -1 # or infinity ?
	
end


def status()

	neighbors = []
	$nameToNode.each_value{ |node|
		if node.nextHop.eql? node.hostname #neighbors are 1 hop away
			neighbors.push(node.hostname)
		end
	}

	neighbors.sort!
	neighbors_str = neighbors.join(",")
	STDOUT.puts "Name: #{$hostname}"
	STDOUT.puts "Port: #{$port}"
	STDOUT.puts "Neighbors: #{neighbors_str}"
end


# --------------------- Part 3 --------------------- # 
def sendmsg(cmd)
	dstName =  cmd[0]
	msg = cmd[1..-1].join(' ')

	dstNode = $nameToNode[dstName]

	nexthop = dstNode.nextHop
	socket = dstNode.socket 

	if (nexthop == nil)
		STDOUT.puts("SENDMSG ERROR: HOST UNREACHABLE")
	else
		socket.puts("SENDMSG|#{$hostname}|#{dstName}|#{msg}|") 
	end	
end

def ping(cmd)
	dstName =  cmd[0]
	numPings = cmd[1].to_i
	delay = cmd[2].to_i

	dstNode = $nameToNode[dstName]

	nexthop = dstNode.nextHop
	socket = dstNode.socket 

	count = numPings - 1 

	$pinglock.synchronize {
		for i in 0..count do 
			if (nexthop != nil)
				time = Time.now.to_i
				interval = 0
				socket.puts("PINGREQ|#{$hostname}|#{dstName}|#{i}|#{time}|#{interval}|") 
			end
			sleep(delay)
		end
	}
end

def traceroute(cmd)
	dstName =  cmd[0]

	dstNode = $nameToNode[dstName]

	nexthop = dstNode.nextHop
	socket = dstNode.socket 

	if (nexthop != nil)	
		interval = 0
		time = Time.now.to_i
		hopcount = 0
		msg = "#{hopcount},#{$hostname},#{interval} "
		socket.puts("TRACEREQ|#{$hostname}|#{dstName}|#{time}|#{interval}|#{hopcount}|#{msg}|")
	end
end

# --------------------- Part 4 --------------------- # 


def ftp(cmd)
	STDOUT.puts "FTP: not implemented"
end

def circuit(cmd)
	STDOUT.puts "CIRCUIT: not implemented"
end




# do main loop here.... 
def main()

	while(line = STDIN.gets())
		line = line.strip()
		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]
		case cmd
		when "EDGEB"; edgeb(args)
		when "EDGED"; edged(args)
		when "EDGEU"; edgeu(args)
		when "DUMPTABLE"; dumptable(args)
		when "SHUTDOWN"; shutdown(args)
		when "STATUS"; status()
		when "SENDMSG"; sendmsg(args)
		when "PING"; ping(args)
		when "TRACEROUTE"; traceroute(args)
		when "FTP"; ftp(args);
		when "CIRCUIT"; circuit(args);
		else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end
	end
end

def setup(hostname, port, nodes, config)
	$hostname = hostname
	$port = port
	$nameToNode = {}

	File.foreach(nodes) { |line|
		fields = line.split(",")
		nodeName = fields[0]
		nodePort = fields[1].to_i

		if (nodeName.eql? $hostname)
			#don't save self node
		else 
			newNode = Node.new(nodeName, nodePort)
			$nameToNode[nodeName] = newNode
		end	
	}

	File.foreach(config) { |line|  
		fields = line.split("=")
		if (fields[0].eql? "updateInterval")
			$updateInterval = fields[1].to_i
		elsif (fields[0].eql? "maxPayload")
			$maxPayload = fields[1].to_i
		elsif (fields[0].eql? "pingTimeout")
			$pingTimeout = fields[1].to_i
		end
	}



	$clock = Time.now.to_i #set clock before threads so no torn reads/writes possible

	$clock_T = Thread.new{
		loop{
			$clock += 1
			sleep 1
		}
	}

	$listener_T = Thread.new{
		$listener = TCPServer.new($port)

		loop{
			newSocket = $listener.accept
			packet = newSocket.gets
			
			fields = packet.split("|")


			if (fields[0].eql? "EDGEB") && (fields[1].eql? $hostname)
				otherName = fields[3]
				#fields[2] is $hostname
				otherIP = fields[2]

				
				node = $nameToNode[otherName]
				node.IP = otherIP
				node.socket = newSocket
				node.nextHop = otherName
				node.cost = 1 #all edges start as 1	
				$socketList.push(newSocket)
				$socketToNode[newSocket] = node

				$edges[[$hostname, otherName]] = 1
				$edges[[otherName, $hostname]] = 1
				
			end
		}
	}


	$receiver_T = Thread.new{
		loop{
			if ($socketList.length != 0)
				readSocket = IO.select($socketList) #check which sockets can be read from
				if read = readSocket[0] #not sure what this does, from TA example
					socket = read[0]
					
					message = socket.gets
					if message != nil

						fields = message.split('|')
						if fields[0].eql? "SENDMSG"
							srcName = fields[1]
							dstName = fields[2]
							msg = fields[3] 
							if (dstName.eql?$hostname)
								STDOUT.puts "SENDMSG: #{srcName} --> #{msg}"
							else 
								
								dstNode = $nameToNode[dstName]
								
				
								nexthop = dstNode.nextHop
								socket = dstNode.socket 

								if nexthop != nil
									socket.puts("SENDMSG|#{srcName}|#{dstName}|#{msg}|") 
								end
					
							end
						elsif fields[0].eql? "PINGREQ"
							new_time = Time.now.to_i
							srcName = fields[1]
							dstName = fields[2]
							id = fields[3]
							old_time = fields[4].to_i
							interval = fields[5].to_i 
							interval += new_time - old_time 

							if (interval > $pingTimeout)
								srcNode = $nameToNode[srcName]
								nexthop = srcNode.nextHop
								socket = srcNode.socket 

								if nexthop != nil
									socket.puts("PINGFAIL|#{srcName}|")
								end
							else
								if(dstName.eql?$hostname)
									srcNode = $nameToNode[srcName]
									nexthop = srcNode.nextHop
									socket = srcNode.socket 

									if nexthop != nil
										socket.puts("PINGRES|#{dstName}|#{srcName}|#{id}|#{new_time}|#{interval}|")
									end

								else
									dstNode = $nameToNode[dstName]
								
									nexthop = dstNode.nextHop
									socket = dstNode.socket 
									if nexthop != nil
										socket.puts("PINGREQ|#{srcName}|#{dstName}|#{id}|#{new_time}|#{interval}|")
									end
								end
							end

						elsif fields[0].eql? "PINGRES"
							new_time = Time.now.to_i
							srcName = fields[1]
							dstName = fields[2]
							id = fields[3]
							old_time = fields[4].to_i
							interval = fields[5].to_i 
							interval += new_time - old_time 

							if (interval > $pingTimeout)
								dstNode = $nameToNode[dstName]
								nexthop = dstNode.nextHop
								socket = dstNode.socket 

								if nexthop != nil
									socket.puts("PINGFAIL|#{dstName}|")
								end
							else

								if(dstName.eql?$hostname)
								#0 n4 0
									STDOUT.puts("#{id} #{srcName} #{interval}")
								else
									dstNode = $nameToNode[dstName]
								
									nexthop = dstNode.nextHop
									socket = dstNode.socket 
									if nexthop != nil
										socket.puts("PINGRES|#{srcName}|#{dstName}|#{id}|#{new_time}|#{interval}|")
									end
								end 
							end

						elsif fields[0].eql? "PINGFAIL"
							dstName = fields[1]

							if(dstName.eql?$hostname)
								#0 n4 0
								STDOUT.puts("PING ERROR: HOST UNREACHABLE")
							else
								dstNode = $nameToNode[dstName]
								nexthop = dstNode.nextHop
								socket = dstNode.socket 
								if nexthop != nil
									socket.puts("PINGFAIL|#{dstName}|")
								end
							end 

							
						elsif fields[0].eql? "TRACEREQ"
							new_time = Time.now.to_i
							srcName = fields[1]
							dstName = fields[2]
							old_time = fields[3].to_i
							interval = fields[4].to_i
							interval += new_time - old_time 
							hopcount = fields[5].to_i
							hopcount += 1
							msg = fields[6]
							#STDOUT.puts("Here")


							#if (interval < $pingTimeout)
								#later
							#else 
								if(dstName.eql?$hostname)
									srcNode = $nameToNode[srcName]
									nexthop = srcNode.nextHop
									socket = srcNode.socket 

									if nexthop != nil
										#STDOUT.puts("#{hopcount}")
										msg += "#{hopcount},#{$hostname},#{interval} "
										socket.puts("TRACERES|#{srcName}|#{msg}|")
									end
								else 
									dstNode = $nameToNode[dstName]
									nexthop = dstNode.nextHop
									socket = dstNode.socket 
									if(nexthop != nil)
										#STDOUT.puts("#{hopcount}")
										msg += "#{hopcount},#{$hostname},#{interval} "
										socket.puts("TRACEREQ|#{srcName}|#{dstName}|#{new_time}|#{interval}|#{hopcount}|#{msg}|")
									end
								end
							#end

						elsif fields[0].eql? "TRACERES"
							dstName = fields[1]
							msg = fields[2]
							#STDOUT.puts("Here")

							#if (interval > $pingTimeout)
								# Later
							#else

								if(dstName.eql?$hostname)
									msgs = msg.split(" ")

									msgs.each { |msg_part|
										msg_parts = msg_part.split(",")

										STDOUT.puts("#{msg_parts[0]} #{msg_parts[1]} #{msg_parts[2]}")
									}
								
								else
									dstNode = $nameToNode[dstName]
								
									nexthop = dstNode.nextHop
									socket = dstNode.socket 
									if nexthop != nil
										socket.puts("TRACERES|#{dstName}|#{msg}|")
									end
								end 
							#end

						elsif fields[0].eql? "TRACEFAIL"
							#Later
				
						elsif fields[0].eql? "LINKSTATE"
							$lock.synchronize {
								updates = fields[1].split(" ")

								updates.each do |update|
									fields = update.split("=")
									$edges[[fields[0], fields[1]]] = fields[2].to_i	
								end

								# After we update our edges, we must run djikstra
								prepareDjikstra()
								runDjikstra()
							}
						end
					end
				end
			end
		}
	}



	$linkUpdate_T = Thread.new{
		loop{
			lsp()	
			sleep($updateInterval/2)
		}
	}

	#initial thread is command listener thread
	sleep(1)
	main()
end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])