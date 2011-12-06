#coding:utf-8
import string, urllib
from sgmllib import SGMLParser
import threading
import time
import urllib2
import StringIO
import gzip
import string
import os
 
def parserPage(url):	 
	##m = urllib.urlopen(url).read()
	print url
	parser = Basegeturls()
	opener = urllib2.build_opener() 
	request = urllib2.Request(url)
	request.add_header('Accept-encoding', 'gzip') 
	try:
		page = opener.open(request)
		if page.code == 200:	
			predata = page.read()
			pdata = StringIO.StringIO(predata) 
			gzipper = gzip.GzipFile(fileobj = pdata)
			try:
				data = gzipper.read()
			except(IOError):
				print 'unused gzip'
				data = predata 
			try:
				parser.feed(data) 
			except:
				print 'I am here' 
			for item in parser.url:
				print item
			
		page.close() 
	except:
		print 'sfd'
class Basegeturls(SGMLParser):
	def reset(self):
		self.url = []
		SGMLParser.reset(self)
	def start_img(self, attrs):
		href = [v for k, v in attrs if k == 'src']
		width = [v for k, v in attrs if k == 'width']
		height = [v for k, v in attrs if k == 'height']  
		if width == '175' and height == '175' and href:	
			self.url.extend(href)
 
bdurl = 'http://itunes.apple.com/us/app/ibooks/id364709193?mt=8'
#µ÷ÓÃ
parserPage(bdurl)

##http://a5.mzstatic.com/us/r1000/087/Purple/6d/76/81/mzl.fzaigvmu.175x175-75.jpg

{
id
cmd
code
reason
}