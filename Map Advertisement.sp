#include <sourcemod>
#include <sdktools>

Database g_dDatabase = null;

bool painter[MAXPLAYERS+1];

int decals;
int g_idecals = 0;

Handle adt_decal_position	= INVALID_HANDLE;

enum decalSettings
{
	decalName = 0, 
	decalModel,
}
public Plugin myinfo =
{
	name = "Map Advertisement",
	author = "Forked from Neko",
	description = "Advertisement plugin",
	version = "0.1"
};

char szMap[128];

char g_szSkins[137][decalSettings][PLATFORM_MAX_PATH + 1];
char Decal[137][PLATFORM_MAX_PATH];

char DecalInUse[MAXPLAYERS+1][PLATFORM_MAX_PATH];


public OnPluginStart()
{	
	adt_decal_position = CreateArray(3);
	RegAdminCmd("sm_listdecal",Command_listDecal,ADMFLAG_KICK);
	RegAdminCmd("sm_decal", Command_Decal, ADMFLAG_KICK);
	RegAdminCmd("sm_del", Command_DecalDel, ADMFLAG_KICK);
    //HookEvent("bullet_impact",Decal_BulletImpact);
	SQL_MakeConnection();
}

public Action Command_Decal(int client,int args)
{
	Menus_SkinsMain(client);
}

public Action Command_DecalDel(int client,int args)
{
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `decals` WHERE `map` = '%s'",szMap);
	g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	PrintToChat(client,"已从数据库中删除所有当前地图Decals落点");
}

public Action Command_listDecal(int client,int args)
{
	PrintToChatAll("%i",decals);
	float position[3];
	for (new i=0; i<decals; ++i) {
		GetArrayArray(adt_decal_position, i, _:position);
		PrintToChatAll("%f,%f,%f",position[0],position[1],position[2]);
		PrintToChatAll("%s",Decal[i]);
	}
}

public void OnMapStart()
{
	decals = 0;
	ClearArray(adt_decal_position);
	GetCurrentMap(szMap, 128);
	GetDecal();
	LoadDecal();
}

LoadDecal()
{
	char Buffer[PLATFORM_MAX_PATH];
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath,PLATFORM_MAX_PATH, "configs/decal.cfg");
	if (!FileExists(szPath))
		SetFailState("找不到这个文件: %s", szPath);
	
	KeyValues kConfig = new KeyValues("");
	kConfig.ImportFromFile(szPath);
	kConfig.JumpToKey("decal");
	kConfig.GotoFirstSubKey();
	
	do {
	
		kConfig.GetString("name", g_szSkins[g_idecals][decalName], 64);
		kConfig.GetString("index", g_szSkins[g_idecals][decalModel], PLATFORM_MAX_PATH);
		Format(Buffer,sizeof(Buffer),"materials/%s.vmt",g_szSkins[g_idecals][decalModel]);
		AddFileToDownloadsTable(Buffer);
		Format(Buffer,sizeof(Buffer),"materials/%s.vtf",g_szSkins[g_idecals][decalModel]);
		AddFileToDownloadsTable(Buffer);
		g_idecals++;
	} while (kConfig.GotoNextKey())
}

public OnMapEnd() {
	ClearArray(adt_decal_position);
}

/**
public Action Decal_BulletImpact(Handle:event,const String:name[],bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(painter[client])
	{
		decl Float:m_fImpact[3];
		char posx[32],posy[32],posz[32];

		m_fImpact[0] = GetEventFloat(event, "x");
		FloatToString(m_fImpact[0],posx,sizeof(posx));
		
		m_fImpact[1] = GetEventFloat(event, "y");
		FloatToString(m_fImpact[1],posy,sizeof(posy));
		
		m_fImpact[2] = GetEventFloat(event, "z");
		FloatToString(m_fImpact[2],posz,sizeof(posz));
		
		TE_Start("BSP Decal");
		TE_WriteVector("m_vecOrigin", pos);
		TE_WriteNum("m_nEntity",0);
		TE_WriteNum("m_nIndex",PrecacheDecal("decals/custom/example/neko.vmt", true));
		TE_SendToAll();
		char szQuery[512];
		FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `decals` (`map`,`x`,`y`,`z`) VALUES ('%s','%s','%s','%s')",szMap,posx,posy,posz);
		g_dDatabase.Query(SQL_CheckForErrors, szQuery);
		UpdateRow();
		painter[client]=false;
		PrintToChat(client,"贴图落点已上传");
	}
}

**/
public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon) 
{
	if (iButtons & IN_USE && painter[client])
	{
		paint(client);
	}
}

void paint(int client)
{
	char Buffer[PLATFORM_MAX_PATH];
	float vAngles[3], vOrigin[3],pos[3];
	char posx[32],posy[32],posz[32];
	GetClientEyePosition( client, vOrigin );
	GetClientEyeAngles( client, vAngles );
	TR_TraceRayFilter( vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer );
	if( TR_DidHit() )
		TR_GetEndPosition( pos );
	FloatToString(pos[0],posx,sizeof(posx));	
	FloatToString(pos[1],posy,sizeof(posy));
	FloatToString(pos[2],posz,sizeof(posz));
	PushArrayArray(adt_decal_position,_:pos);
	
	TE_Start("BSP Decal");
	TE_WriteVector("m_vecOrigin", pos);
	TE_WriteNum("m_nEntity",0);
	Format(Buffer,sizeof(Buffer),"%s.vmt",DecalInUse[client]);
	//PrintToChatAll(Buffer);
	TE_WriteNum("m_nIndex",PrecacheDecal(Buffer, true));
	TE_SendToAll();
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `decals` (`map`,`x`,`y`,`z`,`decal`) VALUES ('%s','%s','%s','%s','%s')",szMap,posx,posy,posz,DecalInUse[client]);
	g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	painter[client]=false;
	PrintToChat(client,"贴图落点已上传");
	decals++;
}

void SQL_MakeConnection()
{
	if (g_dDatabase != null)
		delete g_dDatabase;
	char szError[512];
	g_dDatabase = SQL_Connect("xs_mapad", true, szError, sizeof(szError));
	if (g_dDatabase == null)
	{
		SetFailState("Cannot connect to datbase error: %s", szError);
	}
	
}


void GetDecal()
{
	char buffer[128];
	Format( buffer, sizeof(buffer), "SELECT * FROM `decals` WHERE `map` = '%s'",szMap);
	g_dDatabase.Query( LoadDecalsCallback, buffer, _, DBPrio_High );
	
}

public void LoadDecalsCallback( Database db, DBResultSet results, const char[] error, any data )
{
	float position[3];
	char pos[12];
	while(results.FetchRow())
	{
		results.FetchString(1, pos, sizeof(pos));
		position[0]=StringToFloat(pos);
		results.FetchString(2, pos, sizeof(pos));
		position[1]=StringToFloat(pos);
		results.FetchString(3, pos, sizeof(pos));
		position[2]=StringToFloat(pos);
		results.FetchString(4, Decal[decals], sizeof(Decal));
		PushArrayArray(adt_decal_position,_:position);
		decals++;
	}
}

/**
public void HowManyRow(Database db, DBResultSet results, const char[] error, any data)
{
	if(results.FetchRow())
	{
		decals = results.FetchInt(0);
	}
}
**/

void Menus_SkinsMain(int client)
{
	
	Menu menu = new Menu(Handler_SkinsSelection);
	menu.SetTitle("选择一个自定义贴图\n");
	char szBuffer[128];
	for (int i = 0; i < g_idecals; i++)
	{
		Format(szBuffer, sizeof(szBuffer), g_szSkins[i][decalName]);
		menu.AddItem(g_szSkins[i][decalModel], szBuffer);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_SkinsSelection(Menu menu, MenuAction action, int client, int itemNum)
{
	
	if (action == MenuAction_Select) {
	char szInfo[PLATFORM_MAX_PATH], szName[64];
	menu.GetItem(itemNum, szInfo, PLATFORM_MAX_PATH, _, szName, sizeof(szName));
	DecalInUse[client]=szInfo;
	painter[client]=true;
	PrintToChat(client,"瞄准后按E贴图");
	Menus_SkinsMain(client);
	}
}

public OnClientPostAdminCheck(client) {
	painter[client]=false;
	float position[3];
	char Buffer[PLATFORM_MAX_PATH];
	for (new i=0; i<decals; ++i) {
		GetArrayArray(adt_decal_position, i, _:position);
		TE_Start("BSP Decal");
		TE_WriteVector("m_vecOrigin", position);
		TE_WriteNum("m_nEntity",0);
		Format(Buffer,sizeof(Buffer),"%s.vmt",Decal[i]);
		TE_WriteNum("m_nIndex",PrecacheDecal(Buffer, true));
		TE_SendToClient(client);
	}
}

public void SQL_CheckForErrors(Database db, DBResultSet results, const char[] error, any data)
{	
	//UpdateRow();
	if (!StrEqual(error, ""))
	{
		LogError("Databse error, %s", error);
		return;
	}
}

public bool TraceEntityFilterPlayer( int entity, int contentsMask )
{
	return ( entity > MaxClients || !entity );
}