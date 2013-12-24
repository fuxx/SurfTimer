Welcome to my Surf Timer for CS:S!
=========================

My source timer is based on Alongub's timer which I modified a lot. I don't think much left of the original code.
The timer works only with MySQL and you should prefer a local instance as the timer is interacting a lot with MySQL. 

The Zone editing is Alongub's way, except a second edit mode which could be activated via "+use" (e key).

You will find 2 MySQL dumps from my own SurfTimer server you could use. One is the data structure only.
For being a admin you will need the admin flag. 

I wont support the plugin in no way. This plugin could be used to copy/paste stuff out of it. For learning purpose e.g. to know how you can make efficient MySQL queries for live stats calculations.

Again, you can ask me developer questions but I won't help you to get the plugin running. Its pretty straight forward for developers. Take a look into the "Makefile". Change the variables according to your source server setup. Import one of the sql dumps to your database. Configure source mod with your database credentials. 

In the paste we made a document of which maps are ready with zones and which are not ready. We also added some infos about jails. 

If i find the anti jail stuff, which i made with Stripper:Source, I will publish them too.

Known bugs?
=

There are some left, but the plugin was that stable that we could surf without issues for day's. Some of the stats menu's are maybe a bit wrong, but there was no major bug left.

Features?
=
Well, 

!start !stop, world records, zone reccords, recent records, zone editing, stats reset and other stuff. 

The zones are using triggers instead of that > x && < y && blah > stuff. It's more accurate and is not wasting additional calculation power. 
The timer also includes a simple anti-bhop which triggers after 3 jumps (within 1 second? I don't remember).

I also started on a ghost recorder, but i removed the source as i found no quick way to get the replay in sync with the rest of the world. It worked, but the recording played to fast.

There are tons of statistic menus and also i made a hook where the KSF timer was my inspiration. I really like a minimal UI. Greetings to KSF, really inspiring work you did over there ;)

Take a look into the source code and you will find a lot of stuff i don't remember right now.

Map status document
=
Here you go <https://docs.google.com/spreadsheet/ccc?key=0Av2VXnsHFp8OdHRobkwxdUx0VVpxak1LeW9sR21CZmc&usp=drive_web#gid=0>

Questions?
=

Email me at <mail@stefanpopp.de>

How to install?
=
Again, I wont support you except for development questions. Take a look into the Makefile and you will find what ever you need.

License?
=
Public domain, do what ever you want. Not sure if Alongub's license where public domain too, but if not, his license applies for his parts only.
