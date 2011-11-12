import winsound

# Play Windows exit sound.
#winsound.PlaySound("SystemExit", winsound.SND_ALIAS)
# Probably play Windows default sound, if any is registered (because
# "*" probably isn't the registered name of any sound).
#winsound.PlaySound("*", winsound.SND_ALIAS)

print 'test'
##winsound.Beep(frequency, duration)
##winsound.Beep(32767,1000)
winsound.Beep(1000,1000 * 3)
