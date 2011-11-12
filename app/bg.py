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
import sys 
from HTMLParser import HTMLParser
import winsound

def parserPage(url , parser):	 
 
 
	opener = urllib2.build_opener() 
	request = urllib2.Request(url)
	request.add_header('Accept-encoding', 'gzip') 
	try:
		page = opener.open(request)
		print page.code
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
				##print 'start parser'
			except Exception,ex:
				print 'parser error' 
				print ex
		page.close() 
	except Exception,e: 
		print 'open error' 
		print e
	

class postparser(HTMLParser):
	selected = ('img')
	def __init__(self):
		HTMLParser.__init__(self)
		self.url = ''

	def handle_starttag(self, tag, attrs):
		if tag in postparser.selected:
			href = [v for k, v in attrs if k == 'src']
			width = [v for k, v in attrs if k == 'width']
			height = [v for k, v in attrs if k == 'height'] 
			if len(href) == 0 or len(width)==0 or len(height)==0: return 
			if width[0]  == '175' and height[0]  == '175' :	
				self.url = href[0]
	def reset(self):
		HTMLParser.reset(self)


class parserAppList(HTMLParser):
	selected = ('a')
	substr = 'http://itunes.apple.com/us/app/'
	def __init__(self):
		HTMLParser.__init__(self)
		self.url = []
		self.names = []
		self.flag = 0

	def handle_starttag(self, tag, attrs):
	 
		if tag in parserAppList.selected:
			href = [v for k, v in attrs if k == 'href'] 
			if len(href) == 0: return 
			if href[0].find(parserAppList.substr) > -1 :	
				self.url.extend(href)
				self.flag = 1
	def reset(self):
		HTMLParser.reset(self)
	def handle_data (self, data):
		if self.flag == 1:        
			self.names.append(data)
			self.flag = 0

def getName(str , p):
	str = str.replace(p , '')
	temp = str.split('/')
	if len(temp) > 1:
		return temp[0]
	else:
		return str.split('?')[0]
	
category = ['http://itunes.apple.com/us/genre/ios-books/id6018?mt=8',
'http://itunes.apple.com/us/genre/ios-business/id6000?mt=8',
'http://itunes.apple.com/us/genre/ios-education/id6017?mt=8',
'http://itunes.apple.com/us/genre/ios-entertainment/id6016?mt=8',
'http://itunes.apple.com/us/genre/ios-finance/id6015?mt=8',
'http://itunes.apple.com/us/genre/ios-games/id6014?mt=8',
'http://itunes.apple.com/us/genre/ios-health-fitness/id6013?mt=8',
'http://itunes.apple.com/us/genre/ios-lifestyle/id6012?mt=8',
'http://itunes.apple.com/us/genre/ios-medical/id6020?mt=8',
'http://itunes.apple.com/us/genre/ios-music/id6011?mt=8',
'http://itunes.apple.com/us/genre/ios-navigation/id6010?mt=8',
'http://itunes.apple.com/us/genre/ios-news/id6009?mt=8',
'http://itunes.apple.com/us/genre/ios-newsstand/id6021?mt=8',
'http://itunes.apple.com/us/genre/ios-photo-video/id6008?mt=8',
'http://itunes.apple.com/us/genre/ios-productivity/id6007?mt=8',
'http://itunes.apple.com/us/genre/ios-reference/id6006?mt=8',
'http://itunes.apple.com/us/genre/ios-social-networking/id6005?mt=8',
'http://itunes.apple.com/us/genre/ios-sports/id6004?mt=8',
'http://itunes.apple.com/us/genre/ios-travel/id6003?mt=8',
'http://itunes.apple.com/us/genre/ios-utilities/id6002?mt=8',
'http://itunes.apple.com/us/genre/ios-weather/id6001?mt=8']

app = 'http://itunes.apple.com/us/app/ibooks/id364709193?mt=8'
#µ÷ÓÃ
##parserPage(bdurl , 'ibooks')
#
#			for item in parser.url:
#				print item 
#				urllib.urlretrieve(item, (name +'.'+ item.split('.')[-1]))
	
index = 0
for cat in category:
	index = index+1
	dirname = getName(cat , 'http://itunes.apple.com/us/genre/ios-')
	if not os.path.exists(dirname): 
		os.makedirs(dirname)
	p = parserAppList()
	parserPage(cat, p)
	for x in range(0,len(p.url)):  
		print str(index) + "==" + p.names[x]
		filename = getName( p.url[x] , 'http://itunes.apple.com/us/app/')
		if os.path.exists( dirname + '/' + filename + '.jpg'): continue

		f = open( dirname + '/' + filename + '.txt' , 'w' )
		f.write(p.names[x] + '\n' + p.url[x])
		f.close()
		logo = postparser()
		parserPage(p.url[x] , logo)
		print logo.url
		if logo.url.strip() != '':
			urllib.urlretrieve(logo.url, ( dirname + '/' + filename +'.'+ logo.url.split('.')[-1]))

winsound.Beep(1000,1000 * 3)
#if __name__ == "__main__":
#	html_code = """
#	<img class="artwork" width="175" height="175" src="http://a5.mzstatic.com/us/r1000/087/Purple/6d/76/81/mzl.fzaigvmu.175x175-75.jpg" alt="iBooks">
#	<img src="www.google.comimg"> google.com 
#	<A Href="www.pythonclub.org"> PythonClub </a>
#	<A HREF = "www.sina.com.cn"> Sina </a>
#	"""
#	hp = postparser()
#	hp.feed(html_code)
#	hp.close()
#	print(hp.url)
##http://a5.mzstatic.com/us/r1000/087/Purple/6d/76/81/mzl.fzaigvmu.175x175-75.jpg