# CharsMiditoRobloxPianoPlayer
WINDOWS ONLY!!!

Welcome! This program I made uses AutoHotkey Version 1.1 and Python 3 in order to work. But how?

Autohotkey handles the key presses and the gui, while python handles converting your midi files into CSV files. To do this, however, you must have pip, which usually comes with Python 3. then, you'd want to press Win+R then type cmd to open command prompt. Once you do that type "pip install mido python-rtmidi". Those are midi libraries that are the reason projects like this work in the first place. BTW, to check if you have pip installed do pip --version in cmd prompt.

While still in your command prompt, however, to convert your midi files (some converted versions of midis are already in the "converted midis" folder), you have to type cd C:/Users/youruser/Downloads/CharsMidiPlayer. once you are in that directory, to convert any other midi files you put in the program's directory, all you have to do is type python midi_to_csv.py MIDIFILENAME.mid/midi EXAMPLEFILENAME.csv.

Once you can do that you can put the csv file in the "converted midis" folder. to actually use them, though, open the autoplayer with ahk then press load csv. find the directory and open whichever csv file you desire. once you do that, press insert to start/pause, and delete to unload it. it can handle any midi your pc can. Thanks for downloading.

P.S. if you have any questions my discord is liam_theclown
