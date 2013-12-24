/*******************************************************************************

  Advanced Rules Menu

  Version: 1.2
  Author: haN
  
  Description : Display Rules to clients on connection and by typing !rules 
                Rules can be added from rules/cfg located at configs folder .
                
  Cvar's:        
        - sm_rules_descmode : Change Rules description mode : Set 0 to show description on a menu / Set 1 to print description to chat.
        - sm_rules_noconnect : Changes if Rules menu will be displayed on connection or not : Set 0 To display on player connection / Set 1 to NOT display on player connection .       
        
  Commands:
        - sm_rules: Type !rules to display rules menu .
        - sm_showrules: (ADMINS) Type !showrules to send rules menu to players on server .             
                
ENJOY !                

*******************************************************************************/

/////////////////////////////////////////////////////////
///////////////  INCLUDES / DEFINES
/////////////////////////////////////////////////////////

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#define VERSION "1.3"

new Handle:g_CvarShowOnConnect = INVALID_HANDLE;
new Item = 0;

new String:rulespath[PLATFORM_MAX_PATH];


/////////////////////////////////////////////////////////
///////////////  PLUGIN INFO
/////////////////////////////////////////////////////////

public Plugin:myinfo = 
{
    name = "Rules Plugin",
    author = "haN",
    description = "A detailed Rules plugin",
    version = VERSION,
    url = "www.sourcemod.net"
};

/////////////////////////////////////////////////////////
///////////////  ESSENTIAL FUNCTIONS
/////////////////////////////////////////////////////////

public OnPluginStart()
{
      //Build SM Path 
    BuildPath(Path_SM, rulespath, sizeof(rulespath), "configs/rules.cfg"); 
     // Register Client / Admins Commands
    RegConsoleCmd("sm_rules", RulesMenu_Func);
    RegConsoleCmd("sm_commands", RulesMenu_Func);
    RegConsoleCmd("sm_infomenu", RulesMenu_Func);
    RegConsoleCmd("sm_chatrank", RulesMenu_Func);
    RegConsoleCmd("sm_chatranks", RulesMenu_Func);
    RegConsoleCmd("sm_info", RulesMenu_Func);
    RegAdminCmd("sm_showinfo", ShowRules, ADMFLAG_GENERIC);
    
    g_CvarShowOnConnect = CreateConVar("sm_rules_noconnect", "0", "Set to 1 If you dont want menu to show on players connection .");
    
}

/////////////////////////////////////////////////////////
///////////////  ON CLIENT CONNECTING TO SERVER SEND RULES
/////////////////////////////////////////////////////////

public OnClientPostAdminCheck(client)
{
    if (!GetConVarInt(g_CvarShowOnConnect) && !IsFakeClient(client))
    {
         CreateRulesMenu(client, 0);
    }
}

/////////////////////////////////////////////////////////
///////////////  CMD HANDLERs
//////////////////////////////////////////////////////////

public Action:RulesMenu_Func(client, args)
{
     // Function To Create the menu and send it to client
    CreateRulesMenu(client, 0);
    return Plugin_Handled;
}

public Action:ShowRules(client, args)
{
     // Send admins a list of players to send the Rules menu
    new Handle:PlayersMenu = CreateMenu(ShowRulesHandler);
    SetMenuTitle(PlayersMenu, "Send infos to player");
    SetMenuExitButton(PlayersMenu, true);
    AddTargetsToMenu2(PlayersMenu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);
    DisplayMenu(PlayersMenu, client, 15);
    return Plugin_Handled;
}

/////////////////////////////////////////////////////////
///////////////  MENUs / MENUs HANDLERs
/////////////////////////////////////////////////////////

public Action:CreateRulesMenu(client, item)
{
    new Handle:RulesMenu = CreateMenu(RulesMenuHandler);
    SetMenuTitle(RulesMenu, "Server commands");
    
    new Handle:kv = CreateKeyValues("Rules");
    FileToKeyValues(kv, rulespath);
    
    if (!KvGotoFirstSubKey(kv))
	{
		return Plugin_Continue;
	}
	  
    decl String:RuleNumber[64];
    decl String:RuleName[255];
	  
    do
	{
    	KvGetSectionName(kv, RuleNumber, sizeof(RuleNumber));    
        KvGetString(kv, "name", RuleName, sizeof(RuleName));
         // Add Each Rule to the menu 
        AddMenuItem(RulesMenu, RuleNumber, RuleName);    
    }while (KvGotoNextKey(kv));
    CloseHandle(kv);  
     // Send Menu to client
    DisplayMenuAtItem(RulesMenu, client, item, 15);
    
    return Plugin_Handled;  
}

public HandlerBackToMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select) {
        CreateRulesMenu(param1, Item);
    } else if (action == MenuAction_Cancel) {
		
	} else if (action == MenuAction_End) {
	   CloseHandle(menu);
	}
}


public RulesMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {             
        new Handle:kv = CreateKeyValues("Rules");   
        FileToKeyValues(kv, rulespath);
        
        if (!KvGotoFirstSubKey(kv))
	    {
		        CloseHandle(menu);
	    }        

        decl String:buffer[255];
        decl String:choice[255];
        GetMenuItem(menu, param2, choice, sizeof(choice));     
        
        do
        {   
            KvGetSectionName(kv, buffer, sizeof(buffer));
            if (StrEqual(buffer, choice))
            {
                decl String:ruleName[255];
                decl String:ruleDescription[4096];
                KvGetString(kv, "name", ruleName, sizeof(ruleName));
                KvGetString(kv, "description", ruleDescription, sizeof(ruleDescription));

          
                decl String:Rule[255];
                decl String:Desc[4096];
                Format(Rule, sizeof(Rule), "%s", ruleName);
                Format(Desc, sizeof(Desc), "%s", ruleDescription); 

                new String:Descriptions[10][255];
                ExplodeString(ruleDescription, "|", Descriptions, 10, 255);

                Item = GetMenuSelectionPosition();               
                new Handle:DescriptionPanel = CreatePanel(); 
                SetPanelTitle(DescriptionPanel, Rule);
                DrawPanelText(DescriptionPanel, " ");

                for (new i = 0; i < 10; i++) {
                    DrawPanelText(DescriptionPanel, Descriptions[i]);
                }

                DrawPanelText(DescriptionPanel, " ");
                DrawPanelItem(DescriptionPanel, "Back");                   
                SendPanelToClient(DescriptionPanel, param1, HandlerBackToMenu, 15);                


            }
        } while (KvGotoNextKey(kv));
        CloseHandle(kv);           
    }
    else if (action == MenuAction_Cancel)
	  {
		    PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
	  }

    else if (action == MenuAction_End)
	  {
		    CloseHandle(menu);
	  }
}

public ShowRulesHandler(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        decl String:UserId[64];
        GetMenuItem(menu, param2, UserId, sizeof(UserId));
        new i_UserId = StringToInt(UserId);
        new client = GetClientOfUserId(i_UserId);
        CreateRulesMenu(client, 1);
    }

    else if (action == MenuAction_Cancel)
	  {
		    PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
	  }

    else if (action == MenuAction_End)
	  {
		    CloseHandle(menu);
	  }   
}
