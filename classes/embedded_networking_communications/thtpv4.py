#!/usr/bin/env python
#
# thtpv4.py
#
# i0 user-space SLIP, virtual node, and TCP<->UDP THTP bridge
# IPv4 version
# command line syntax: thtp serial_port serial_speed THTP_port
# URL syntax: http://computer_address:THTP_port/i0_node_address:node_port
#
# Neil Gershenfeld
# CBA MIT 11/22/09
#
# (c) Massachusetts Institute of Technology 2009
# Permission granted for experimental and personal use;
# license for commercial use available from MIT.
#
# todo:
#    address filter translation
#    flow control
#

from Tkinter import *
from string import *
from socket import *
from select import *
import serial, time, signal

TIMEOUT = 10
END = 192
ESC = 219
ESC_END = 220
ESC_ESC = 221

def handler(signum, frame):
   #
   # timeout handler
   #
   raise IOError, "i0 timeout"

def high(number):
   #
   # return high byte
   #
   return (number >> 8)

def low(number):
   #
   # return low byte
   #
   return (number & 255)

def idle(parent):
   #
   # idle routine
   #
   [read_ready, write_ready, error_ready] = select([server_socket],[],[],0)
   if (read_ready != []):
      #
      # Web server data waiting, read packet
      #
      get_Web_packet()
   elif (ser.inWaiting() != 0):
      #
      # i0 serial data waiting, read packet
      #
      # set timout alarm
      #
      signal.signal(signal.SIGALRM, handler)
      signal.alarm(TIMEOUT)
      #
      # try to read packet, otherwise set error message
      #
      try:
         get_i0_packet()
      except:
         sindata.set("i0 timeout")
      #
      # turn off alarm
      #
      signal.alarm(0)
   #
   # sleep to reduce OS load
   #
   time.sleep(0.001)
   parent.after_idle(idle,parent)

def output(byte):
   #
   # output a byte
   #
   ser.write(chr(byte))
   #time.sleep(.001) # byte spacing (if needed)

def get_Web_packet():
   #
   # read and display an incoming Web request
   #
   (client_socket, client_address) = server_socket.accept()
   data = client_socket.recv(1000)
   #
   # set source address, port, and data
   #
   dot1 = find(client_address[0],".")
   sinsource1.set(client_address[0][:dot1])
   dot2 = find(client_address[0],".",(dot1+1))
   sinsource2.set(client_address[0][(dot1+1):dot2])
   dot3 = find(client_address[0],".",(dot2+1))
   sinsource3.set(client_address[0][(dot2+1):dot3])
   sinsource4.set(client_address[0][(dot3+1):])
   sinsourceport.set(THTP_port)
   #sindata.set(data)
   #
   # check for THTP address in request path
   #
   start = find(data,"GET /")
   end = find(data,"HTTP")
   if (count(data,".",start,end) == 3):
      #
      # found address; parse destination address and port in incoming packet
      #
      start = find(data,"GET /")
      dot1 = find(data,".",start)
      sindest1.set(data[(start+5):dot1])
      dot2 = find(data,".",(dot1+1))
      sindest2.set(data[(dot1+1):dot2])
      dot3 = find(data,".",(dot2+1))
      sindest3.set(data[(dot2+1):dot3])
      colon = find(data,":",(dot3+1))
      if (colon != -1):
         sindest4.set(data[(dot3+1):colon])
         space = find(data," ",(colon+1))
         port = data[colon+1:space]
         sindestport.set(port)
      else:
         sindest4.set(data[(dot3+1):colon])
         sindestport.set("80")
      #
      # set and send outgoing i0 packet
      #
      soutsource1.set(sinsource1.get())
      soutsource2.set(sinsource2.get())
      soutsource3.set(sinsource3.get())
      soutsource4.set(sinsource4.get())
      soutdest1.set(sindest1.get())
      soutdest2.set(sindest2.get())
      soutdest3.set(sindest3.get())
      soutdest4.set(sindest4.get())
      soutdestport.set(sindestport.get())
      put_i0_packet()
      #
      # get Web response if port 80
      #
      if (port == "80"):
         #
         # set timout alarm
         #
         signal.signal(signal.SIGALRM, handler)
         signal.alarm(TIMEOUT)
         #
         # try to read Web page, otherwise set error message
         #
         try:
            get_i0_packet()
         except:
            sindata.set("i0 timeout")
         #
         # turn off alarm
         #
         signal.alarm(0)
         #
         # send Web page
         #
         client_socket.send(sindata.get())
      else:
         client_socket.send("HTTP/1.1 200 OK\nContent-Type: text/html\n\n")
      client_socket.close()
   else:
      #
      # no i0 address; close socket
      #
      client_socket.send("HTTP/1.1 200 OK\nContent-Type: text/html\n\n")
      client_socket.close()

def put_i0_packet():
   #
   # send i0 packet
   #
   ip_header_size = 20
   udp_header_size = 8
   outgoing_data_size = 10
   # ip_header_size_before_checksum = 10
   # ip_header_size_after_checksum = 8
   # outgoing_packet_size = ip_header_size + udp_header_size + outgoing_data_size
   # outgoing_start = RAMSTART
   # outgoing_source_address = outgoing_start + 12
   # outgoing_destination_address = outgoing_start + 16
   # outgoing_data = outgoing_start + ip_header_size + udp_header_size
   #
   # IP
   #
   packet = []
   packet.append(0x45) # version = 4 (4 bits), header length = 5 32-bit words (4 bits)
   packet.append(0) # type of service
   packet.append(high(ip_header_size + udp_header_size + outgoing_data_size)) # packet length
   packet.append(low(ip_header_size + udp_header_size + outgoing_data_size)) # packet length
   packet.append(0) # identification (high byte)
   packet.append(0) # identification (low byte)
   packet.append(0) # flag (3 bits), fragment offset (13 bits) (high byte)
   packet.append(0) # flag (3 bits), fragment offset (13 bits) (low byte)
   packet.append(255) # time to live
   packet.append(17) # protocol = 17 for UDP
   packet.append(0) # header checksum (to be calculated)
   packet.append(0) # header checksum (to be calculated)
   packet.append(int(soutsource1.get())) # source address byte 1
   packet.append(int(soutsource2.get())) # source address byte 2
   packet.append(int(soutsource3.get())) # source address byte 3
   packet.append(int(soutsource4.get())) # source address byte 4
   packet.append(int(soutdest1.get())) # destination address byte 1
   packet.append(int(soutdest2.get())) # destination address byte 2
   packet.append(int(soutdest3.get())) # destination address byte 3
   packet.append(int(soutdest4.get())) # destination address byte 4
   #
   # UDP
   #
   packet.append(high(int(soutsourceport.get()))) # source port
   packet.append(low(int(soutsourceport.get()))) # source port
   packet.append(high(int(soutdestport.get()))) # destination port
   packet.append(low(int(soutdestport.get()))) # destination port
   packet.append(high(udp_header_size + outgoing_data_size)) # payload length
   packet.append(low(udp_header_size + outgoing_data_size)) # payload length
   packet.append(0) # payload checksum (not used)
   packet.append(0) # payload checksum (not used)
   #
   # remove THTP prefix from addresses
   #
   data = soutdata.get()
   address = sindest1.get()+"."+sindest2.get()+"."+sindest3.get()+"."+sindest4.get()
   data = data.replace(address,"")
   soutdata.set(data)
   #print "\nput i0 packet:\n"
   #print data
   #
   # data
   #
   for i in range(len(data)):
      packet.append(ord(data[i]))
   #
   # send the packet with SLIP mapping and framing
   #
   output(END)
   for byte in range(len(packet)):
      if (packet[byte] == END):
         output(ESC)
         output(ESC_END)
      elif (packet[byte] == ESC):
         output(ESC)
         output(ESC_ESC)
      else:
         output(packet[byte])
   output(END)
   #
   # pause for bridge after sending packet
   #
   time.sleep(.002)

def get_i0_packet():
   #
   # read and display an i0 packet
   #
   sindata.set("reading ...")
   root.update()
   packet_length_offset = 2
   source_address_offset = 12
   destination_address_offset = 16
   source_port_offset = 20
   destination_port_offset = 22
   data_offset = 28
   #
   # find starting END
   #
   while 1:
      byte = ord(ser.read())
      if (byte == END):
         #
         # check whether beginning or end of packet
         #
         bute = ord(ser.read())
         if (byte == END):
            #
            # was end of packet, read next char
            #
            byte = ord(ser.read())
         break
   #
   # read until closing END
   #
   packet = []
   while 1:
      #
      # do SLIP mapping and save byte
      #
      if (byte == ESC):
         byte = ord(ser.read())
         if (byte == ESC_END):
            byte = END
         elif (byte == ESC_ESC):
            byte = ESC
         else:
            print "error: unknown ESC"
            break
      packet.append(byte)
      #
      # get next byte
      #
      byte = ord(ser.read())
      if (byte == END):
         sinsource1.set(str(packet[source_address_offset+0-1]))
         sinsource2.set(str(packet[source_address_offset+1-1]))
         sinsource3.set(str(packet[source_address_offset+2-1]))
         sinsource4.set(str(packet[source_address_offset+3-1]))
         sindest1.set(str(packet[destination_address_offset+0-1]))
         sindest2.set(str(packet[destination_address_offset+1-1]))
         sindest3.set(str(packet[destination_address_offset+2-1]))
         sindest4.set(str(packet[destination_address_offset+3-1]))
         sinsourceport.set(str(256*packet[source_port_offset+0-1]+packet[source_port_offset+1-1]))
         sindestport.set(str(256*packet[destination_port_offset+0-1]+packet[destination_port_offset+1-1]))
         packet_length = 256*packet[packet_length_offset+0-1]+packet[packet_length_offset+1-1]
         data = join(map(chr,packet[(data_offset-1):(data_offset+packet_length)]),sep="")
         #
         # add THTP prefix to addresses
         #
         data = data.replace("http://",thtp_prefix)
         #print "\nget i0 packet:\n"
         #print data
         sindata.set(data)
         return

def quit():
   #
   # clean up and quit
   #
   server_socket.close()
   sys.exit()

#
# get command line arguments
#
if (len(sys.argv) != 4):
   print "command line syntax: thtp serial_port serial_speed THTP_port"
   sys.exit()
serial_port = sys.argv[1]
serial_speed = int(sys.argv[2])
THTP_port = sys.argv[3]
#
# set up GUI
#
root = Tk()
root.title('thtpv4.py')
#
incomingframe = Frame(root)
Label(incomingframe,text="incoming packet: ").pack(side="left")
incomingframe.pack()
#
insourceframe = Frame(root)
Label(insourceframe,text="source address: ").pack(side="left")
sinsource1 = StringVar()
winsource1 = Entry(insourceframe, width=3, textvariable=sinsource1)
winsource1.pack(side="left")
Label(insourceframe,text=".").pack(side="left")
sinsource2 = StringVar()
winsource2 = Entry(insourceframe, width=3, textvariable=sinsource2)
winsource2.pack(side="left")
Label(insourceframe,text=".").pack(side="left")
sinsource3 = StringVar()
winsource3 = Entry(insourceframe, width=3, textvariable=sinsource3)
winsource3.pack(side="left")
Label(insourceframe,text=".").pack(side="left")
sinsource4 = StringVar()
winsource4 = Entry(insourceframe, width=3, textvariable=sinsource4)
winsource4.pack(side="left")
insourceframe.pack()
#
indestframe = Frame(root)
Label(indestframe,text="destination address: ").pack(side="left")
sindest1 = StringVar()
windest1 = Entry(indestframe, width=3, textvariable=sindest1)
windest1.pack(side="left")
Label(indestframe,text=".").pack(side="left")
sindest2 = StringVar()
windest2 = Entry(indestframe, width=3, textvariable=sindest2)
windest2.pack(side="left")
Label(indestframe,text=".").pack(side="left")
sindest3 = StringVar()
windest3 = Entry(indestframe, width=3, textvariable=sindest3)
windest3.pack(side="left")
Label(indestframe,text=".").pack(side="left")
sindest4 = StringVar()
windest4 = Entry(indestframe, width=3, textvariable=sindest4)
windest4.pack(side="left")
indestframe.pack()
#
inportframe = Frame(root)
Label(inportframe,text="source port: ").pack(side="left")
sinsourceport = StringVar()
winsourceport = Entry(inportframe, width=4, textvariable=sinsourceport)
winsourceport.pack(side="left")
Label(inportframe,text="  destination port: ").pack(side="left")
sindestport = StringVar()
windestport = Entry(inportframe, width=4, textvariable=sindestport)
windestport.pack(side="left")
inportframe.pack()
#
indataframe = Frame(root)
Label(indataframe,text="data: ").pack(side="left")
sindata = StringVar()
windata = Entry(indataframe, width=30, textvariable=sindata)
windata.pack(side="left")
indataframe.pack()
#
webframe = Frame(root)
Label(webframe,text="Web server port: "+THTP_port).pack(side="left")
webframe.pack()
#
outgoingframe = Frame(root)
Label(outgoingframe,text="\noutgoing packet: ").pack(side="left")
outgoingframe.pack()
#
outsourceframe = Frame(root)
Label(outsourceframe,text="source address: ").pack(side="left")
soutsource1 = StringVar()
soutsource1.set("10")
woutsource1 = Entry(outsourceframe, width=3, textvariable=soutsource1)
woutsource1.pack(side="left")
Label(outsourceframe,text=".").pack(side="left")
soutsource2 = StringVar()
soutsource2.set("0")
woutsource2 = Entry(outsourceframe, width=3, textvariable=soutsource2)
woutsource2.pack(side="left")
Label(outsourceframe,text=".").pack(side="left")
soutsource3 = StringVar()
soutsource3.set("0")
woutsource3 = Entry(outsourceframe, width=3, textvariable=soutsource3)
woutsource3.pack(side="left")
Label(outsourceframe,text=".").pack(side="left")
soutsource4 = StringVar()
soutsource4.set("1")
woutsource4 = Entry(outsourceframe, width=3, textvariable=soutsource4)
woutsource4.pack(side="left")
outsourceframe.pack()
#
outdestframe = Frame(root)
Label(outdestframe,text="destination address: ").pack(side="left")
soutdest1 = StringVar()
soutdest1.set("10")
woutdest1 = Entry(outdestframe, width=3, textvariable=soutdest1)
woutdest1.pack(side="left")
Label(outdestframe,text=".").pack(side="left")
soutdest2 = StringVar()
soutdest2.set("0")
woutdest2 = Entry(outdestframe, width=3, textvariable=soutdest2)
woutdest2.pack(side="left")
Label(outdestframe,text=".").pack(side="left")
soutdest3 = StringVar()
soutdest3.set("0")
woutdest3 = Entry(outdestframe, width=3, textvariable=soutdest3)
woutdest3.pack(side="left")
Label(outdestframe,text=".").pack(side="left")
soutdest4 = StringVar()
soutdest4.set("2")
woutdest4 = Entry(outdestframe, width=3, textvariable=soutdest4)
woutdest4.pack(side="left")
outdestframe.pack()
#
outportframe = Frame(root)
Label(outportframe,text="source port: ").pack(side="left")
soutsourceport = StringVar()
soutsourceport.set("0")
woutsourceport = Entry(outportframe, width=4, textvariable=soutsourceport)
woutsourceport.pack(side="left")
Label(outportframe,text="  destination port: ").pack(side="left")
soutdestport = StringVar()
soutdestport.set("1002")
woutdestport = Entry(outportframe, width=4, textvariable=soutdestport)
woutdestport.pack(side="left")
outportframe.pack()
#
outdataframe = Frame(root)
Label(outdataframe,text="data: ").pack(side="left")
soutdata = StringVar()
woutdata = Entry(outdataframe, width=30, textvariable=soutdata)
woutdata.pack(side="left")
outdataframe.pack()
#
ioframe = Frame(root)
wbtn = Button(ioframe, text="send outgoing packet",command=put_i0_packet)
wbtn.pack(side="left")
ioframe.pack()
#
spaceframe = Frame(root)
Label(spaceframe,text=" ").pack(side="left")
spaceframe.pack()
#
quitframe = Frame(root)
wquit = Button(quitframe, text="quit",command=quit)
wquit.pack(side="left")
quitframe.pack()
#
# open serial port
#
ser = serial.Serial(port=serial_port, baudrate=serial_speed)
ser.flushInput()
#
# open Web server socket
#
server_socket = socket(AF_INET, SOCK_STREAM)
server_socket.bind(("0.0.0.0", int(THTP_port)))
server_socket.listen(1)
thtp_prefix = "http://" + gethostbyaddr(gethostname())[2][0]\
   + ':' + THTP_port + '/'
print "THTP prefix: "+thtp_prefix
#
# start mainloop
#
root.after(100,idle,root)
root.mainloop()
