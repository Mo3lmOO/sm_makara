#include <sourcemod>
#include <multicolors>
#include <ripext>

#pragma semicolon 1
#pragma newdecls required

#define MAKARA_API_KEY "your_key"  // go to "https://aistudio.google.com" and create account after that go to "https://aistudio.google.com/api-keys" create ur key then put it here 

#define MAKARA_MAX_QUESTIONS 3
#define MAKARA_COOLDOWN_TIME 40.0
#define MAKARA_MAX_MESSAGE_LENGTH 192

bool g_bCoolDown[MAXPLAYERS + 1];
bool g_bThinking[MAXPLAYERS + 1];
int g_iQuestions[MAXPLAYERS + 1];
Handle g_hCooldownTimer[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name        = "Makara AI Assistant",
    author      = "XJext MoRx",
    description = "Zombie Revival Chat Bot",
    version     = "1.0.0",
    url         = "https://nide.gg"
};

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    RegConsoleCmd("sm_makara", Cmd_Makara);
}

public void OnMapStart()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        g_bCoolDown[client] = false;
        g_bThinking[client] = false;
        g_iQuestions[client] = 0;

        if (g_hCooldownTimer[client] != null)
        {
            KillTimer(g_hCooldownTimer[client]);
            g_hCooldownTimer[client] = null;
        }
    }
}

public void OnClientDisconnect(int client)
{
    g_bCoolDown[client] = false;
    g_bThinking[client] = false;
    g_iQuestions[client] = 0;

    if (g_hCooldownTimer[client] != null)
    {
        KillTimer(g_hCooldownTimer[client]);
        g_hCooldownTimer[client] = null;
    }
}

public Action Cmd_Makara(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client))
        return Plugin_Handled;

    if (g_bCoolDown[client])
    {
        CPrintToChat(client, "{green}[Makara]{white} You have reached the limit. Please wait 40 seconds.");
        return Plugin_Handled;
    }

    if (g_bThinking[client])
    {
        CPrintToChat(client, "{green}[Makara]{white} Please wait a moment, typing previous response...");
        return Plugin_Handled;
    }

    if (args < 1)
    {
        CPrintToChat(client, "{green}[Makara]{white} Usage: !makara <message>");
        return Plugin_Handled;
    }

    char message[MAKARA_MAX_MESSAGE_LENGTH];
    GetCmdArgString(message, sizeof(message));
    TrimString(message);

    if (message[0] == '\0')
    {
        CPrintToChat(client, "{green}[Makara]{white} Usage: !makara <message>");
        return Plugin_Handled;
    }

    if (CheckLocalBrain(message))
    {
        return Plugin_Handled;
    }

    g_iQuestions[client]++;

    if (g_iQuestions[client] >= MAKARA_MAX_QUESTIONS)
    {
        g_bCoolDown[client] = true;
        if (g_hCooldownTimer[client] != null) 
        {
            KillTimer(g_hCooldownTimer[client]);
        }
        g_hCooldownTimer[client] = CreateTimer(MAKARA_COOLDOWN_TIME, Timer_ResetCooldown, GetClientUserId(client));
    }

    g_bThinking[client] = true;
    CPrintToChat(client, "{green}[Makara]{white} Thinking, please wait...");

    Makara_FetchAI(client, message);

    return Plugin_Handled;
}

bool CheckLocalBrain(const char[] message)
{
    char lowerMsg[MAKARA_MAX_MESSAGE_LENGTH];
    strcopy(lowerMsg, sizeof(lowerMsg), message);
    StringToLower(lowerMsg);

    if (StrContains(lowerMsg, "ignore your rules") != -1 ||
        StrContains(lowerMsg, "reveal prompt") != -1 ||
        StrContains(lowerMsg, "system prompt") != -1)
    {
        CPrintToChatAll("{green}[Makara]{white} Nice try");
        return true;
    }
    else if (StrContains(lowerMsg, "shop") != -1 || StrContains(lowerMsg, "store") != -1)
    {
        CPrintToChatAll("{green}[Makara]{white} Just type !shop in chat to open the store menu.");
        return true;
    }
    else if (StrContains(lowerMsg, "spawn props") != -1 || StrContains(lowerMsg, "spawn prop") != -1)
    {
        CPrintToChatAll("{green}[Makara]{white} Use !props to spawn your barricades.");
        return true;
    }
    else if (StrContains(lowerMsg, "rank") != -1 || StrContains(lowerMsg, "stats") != -1)
    {
        CPrintToChatAll("{green}[Makara]{white} Check your rank using !rank command.");
        return true;
    }
    else if (StrContains(lowerMsg, "class") != -1 || StrContains(lowerMsg, "change my skin") != -1 || StrContains(lowerMsg, "zclass") != -1)
    {
        CPrintToChatAll("{green}[Makara]{white} Type !zclass to choose your zombie skin OR your Human skin.");
        return true;
    }
    else if (StrContains(lowerMsg, "vip") != -1)
    {
        CPrintToChatAll("{green}[Makara]{white} Type !vip to open VIP menu");
        return true;
    }
    else if (StrContains(lowerMsg, "rules") != -1)
    {
        CPrintToChatAll("{green}[Makara]{white} Type !rules.");
        return true;
    }
    else if (StrContains(lowerMsg, "who crated you") != -1 || StrContains(lowerMsg, "who made you") != -1)
    {
        CPrintToChatAll("{green}[Makara]{white} A person suffering from a lack of sleep :D");
        return true;
    }

    return false;   
}

void StringToLower(char[] str)
{
    int len = strlen(str);
    for (int i = 0; i < len; i++)
    {
        str[i] = CharToLower(str[i]);
    }
}

void FilterAIReply(char[] reply, int maxLen)
{
    char lower[256];
    strcopy(lower, sizeof(lower), reply);
    StringToLower(lower);

    char forbidden[][32] = {"api key", "system prompt", "openai", "gpt", "llm", "prompt", "instruction", "authorization", "token", "curl", "http://", "https://"};
    int forbidCount = sizeof(forbidden) / 32;
    for (int i = 0; i < forbidCount; i++)
    {
        if (StrContains(lower, forbidden[i]) != -1)
        {
            Format(reply, maxLen, "I can't share that");
            return;
        }
    }

    if (strlen(reply) >= maxLen)
    {
        reply[maxLen - 1] = '\0';
    }
}

public void Makara_FetchAI(int client, const char[] prompt)
{
    char url[512];
    Format(url, sizeof(url), "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=%s", MAKARA_API_KEY);

    HTTPRequest request = new HTTPRequest(url);

    JSONObject root = new JSONObject();
    
    JSONObject sysInst = new JSONObject();
    JSONArray sysParts = new JSONArray();
    JSONObject sysTextObj = new JSONObject();
    sysTextObj.SetString("text", "You are Makara, a casual Counter-Strike Source AI chatting on a Zombie Revival server. Chat naturally like a gamer using old school emoticons like xD, :D, =). Keep replies strictly under 15 words.");
    sysParts.Push(sysTextObj);
    sysInst.Set("parts", sysParts);
    root.Set("system_instruction", sysInst);

    JSONArray contents = new JSONArray();
    JSONObject contentObj = new JSONObject();
    JSONArray parts = new JSONArray();
    JSONObject textObj = new JSONObject();
    textObj.SetString("text", prompt);
    parts.Push(textObj);
    contentObj.Set("parts", parts);
    contents.Push(contentObj);
    root.Set("contents", contents);

    request.Post(root, OnHTTPResponse, GetClientUserId(client));

    delete sysTextObj;
    delete sysParts;
    delete sysInst;
    delete textObj;
    delete parts;
    delete contentObj;
    delete contents;
    delete root;
}

public void OnHTTPResponse(HTTPResponse response, any userid)
{
    int client = GetClientOfUserId(userid);

    if (client > 0)
    {
        g_bThinking[client] = false;
    }

    if (response.Status != HTTPStatus.OK || response.Data == null)
    {
        if (client > 0 && IsClientInGame(client))
        {
            CPrintToChat(client, "{green}[Makara]{white} Service is currently unavailable. Please try again later.");
        }
        return;
    }

    JSONObject json = view_as<JSONObject>(response.Data);
    JSONArray candidates = view_as<JSONArray>(json.Get("candidates"));

    if (candidates != null && candidates.Length > 0)
    {
        JSONObject candidate = view_as<JSONObject>(candidates.Get(0));
        if (candidate != null)
        {
            JSONObject content = view_as<JSONObject>(candidate.Get("content"));
            if (content != null)
            {
                JSONArray parts = view_as<JSONArray>(content.Get("parts"));
                if (parts != null && parts.Length > 0)
                {
                    JSONObject part = view_as<JSONObject>(parts.Get(0));
                    if (part != null)
                    {
                        char aiReply[256];
                        part.GetString("text", aiReply, sizeof(aiReply));
                        FilterAIReply(aiReply, sizeof(aiReply));
                        CPrintToChatAll("{green}[Makara]{white} %s", aiReply);
                        
                        delete part;
                    }
                    delete parts;
                }
                delete content;
            }
            delete candidate;
        }
        delete candidates;
    }
    else
    {
        if (client > 0 && IsClientInGame(client))
        {
            CPrintToChat(client, "{green}[Makara]{white} Could not process response. Please try asking differently.");
        }
    }
}

public Action Timer_ResetCooldown(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0)
    {
        g_iQuestions[client] = 0;
        g_bCoolDown[client] = false;
        g_hCooldownTimer[client] = null;
    }
    return Plugin_Stop;
}
