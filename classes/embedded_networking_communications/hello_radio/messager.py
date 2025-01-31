#   messager.py
#  
#  Script to handle interaction with hello_radio board.  Sends and receives
#  messages on serial line.  Set the serial port with the first argument, e.g.:
#
#   python messager.py /dev/ttyUSB0
#
#  Defaults to /dev/ttyUSB0
#
#  by Charlie DeTar (2008)
#
import sys
import cmd
import readline
import threading

import serial

port = "/dev/ttyUSB0"
baud = 9600
if len(sys.argv) > 1:
    port = sys.argv[1]

ser = serial.Serial(port, baud, timeout = 0.1)
ser.setDTR()
msg_length = 160

class SerialManager(threading.Thread):
    """A class to manage communication to and from serial.  Runs in its own
    thread, and listens for a serial byte.  If it doesn't find one after a
    timeout, checks for any messages in the queue (to_send) and sends them.
    """
    to_send = []
    running = True
    def run(self):
        global ser
        while self.running:
            msg = ser.read(160).strip()
            if msg:
                out = "\n"
                for c in msg:
                    o = ord(c) 
                    if o <= 126 and o >= 32:
                        out += c
                print out
            if len(self.to_send) > 0:
                msg = self.to_send.pop(0)
                for c in msg:
                    ser.write(c)

class Messager(cmd.Cmd):
    """Class to handle user interaction.  Straight-forward implementation of
    python's Cmd.
    """
    def __init__(self):
        cmd.Cmd.__init__(self)

        self.prompt = "=> "
        self.intro = "Welcome to messager.  Type your message."
        self.ser_mgr = SerialManager()
        self.ser_mgr.start()

    def emptyline(self):
        pass

    def do_EOF(self, args):
        self.ser_mgr.running = False
        return -1

    def default(self, line):
        """Main action (and only, besides exiting): send a message."""
        if line:
            msg = (line + " " * msg_length)[:msg_length]
            self.ser_mgr.to_send.append(msg)

if __name__ == '__main__':
    console = Messager()
    try:
        console.cmdloop()
    except KeyboardInterrupt:
        sys.exit(0)
