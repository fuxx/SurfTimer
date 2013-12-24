#!/bin/bash
cp build/*.smx /home/gameserver/srcds/SurfServerOne/cstrike/addons/sourcemod/plugins/
cp build/*.smx /home/gameserver/srcds/SurfServerDev/cstrike/addons/sourcemod/plugins/
cp build/*.smx /home/gameserver/srcds/SurfServerDevTwo/cstrike/addons/sourcemod/plugins/

cp -R /home/gameserver/srcds/SurfServerTest/cstrike/addons/stripper/maps/* /home/gameserver/srcds/SurfServerDev/cstrike/addons/stripper/maps
cp -R /home/gameserver/srcds/SurfServerTest/cstrike/addons/stripper/maps/* /home/gameserver/srcds/SurfServerDevTwo/cstrike/addons/stripper/maps
cp -R /home/gameserver/srcds/SurfServerTest/cstrike/addons/stripper/maps/* /home/gameserver/srcds/SurfServerOne/cstrike/addons/stripper/maps
