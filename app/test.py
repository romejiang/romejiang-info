print 'test'
while True:
	msg = raw_input("Please input send message:")
	if msg == "q":
		print "exit program."
		break
	print "send to %s " %( msg )
 
