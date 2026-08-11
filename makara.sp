#include <sourcemod>
#include <multicolors>
#include <SteamWorks>

#pragma semicolon 1
#pragma newdecls required

#define MAKARA_API_KEY ""   //go to https://aistudio.google.com and crate api key then put it here <---

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
        CPrintToChat(client, "{green}[Makara]{white} Dont spam please");
        return Plugin_Handled;
    }

    if (g_bThinking[client])
    {
        CPrintToChat(client, "{green}[Makara]{white} Wait a sec, typing previous reply...");
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

void EscapeJSONString(const char[] input, char[] output, int maxLen)
{
    int outPos = 0;
    int len = strlen(input);
    for (int i = 0; i < len && outPos < maxLen - 2; i++)
    {
        if (input[i] == '"' || input[i] == '\\')
        {
            output[outPos++] = '\\';
        }
        output[outPos++] = input[i];
    }
    output[outPos] = '\0';
}

void FilterAIReply(char[] reply, int maxLen)
{
    char lower[256];
    strcopy(lower, sizeof(lower), reply);
    StringToLower(lower);

    //black list words
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

    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
    if (request == null)
    {
        g_bThinking[client] = false;
        PrintToServer("[Makara Debug] SteamWorks_CreateHTTPRequest returned NULL!");
        return;
    }

    char escapedPrompt[384];
    EscapeJSONString(prompt, escapedPrompt, sizeof(escapedPrompt));

    char payload[1536];
    Format(payload, sizeof(payload), 
        "{\"system_instruction\":{\"parts\":[{\"text\":\"You are Makara, a casual Counter-Strike Source AI chatting on a Zombie Revival server. Chat naturally like a gamer using old school emoticons like xD, :D, =). Keep replies strictly under 15 words.\"}]},\"contents\":[{\"parts\":[{\"text\":\"%s\"}]}]}", 
        escapedPrompt);

    SteamWorks_SetHTTPRequestHeaderValue(request, "Content-Type", "application/json");
    SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", payload, strlen(payload));
    SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
    SteamWorks_SetHTTPCallbacks(request, OnSteamWorksHTTPComplete);

    if (!SteamWorks_SendHTTPRequest(request))
    {
        g_bThinking[client] = false;
        PrintToServer("[Makara Debug] SteamWorks_SendHTTPRequest failed to send!");
        delete request;
    }
}

public int OnSteamWorksHTTPComplete(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, any userid)
{
    int client = GetClientOfUserId(userid);

    if (client > 0)
    {
        g_bThinking[client] = false;
    }

    if (failure || !requestSuccessful || statusCode != k_EHTTPStatusCode200OK)
    {
        PrintToServer("[Makara AI Error] Http Code: %d, Failure: %d, Success: %d", statusCode, failure, requestSuccessful);
        delete request;
        return 0;
    }

    int bodySize = 0;
    SteamWorks_GetHTTPResponseBodySize(request, bodySize);

    if (bodySize <= 0)
    {
        delete request;
        return 0;
    }

    char[] response = new char[bodySize + 1];
    SteamWorks_GetHTTPResponseBodyData(request, response, bodySize);
    response[bodySize] = '\0';

    char aiReply[256];
    if (ExtractTextFromJSON(response, aiReply, sizeof(aiReply)))
    {
        FilterAIReply(aiReply, sizeof(aiReply));
        CPrintToChatAll("{green}[Makara]{white} %s", aiReply);
    }

    delete request;
    return 0;
}


bool ExtractTextFromJSON(const char[] json, char[] output, int maxLen)
{
    int textPos = StrContains(json, "\"text\":");
    if (textPos == -1) return false;

    int startQuote = -1;
    int len = strlen(json);
    
    for (int i = textPos + 7; i < len; i++)
    {
        if (json[i] == '"')
        {
            startQuote = i + 1;
            break;
        }
    }

    if (startQuote == -1) return false;

    int outPos = 0;
    for (int i = startQuote; i < len && outPos < maxLen - 1; i++)
    {
        if (json[i] == '"' && json[i - 1] != '\\')
            break;

        if (json[i] == '\\' && json[i + 1] == 'n')
        {
            output[outPos++] = ' ';
            i++;
            continue;
        }

        if (json[i] == '\\' && (json[i + 1] == '"' || json[i + 1] == '\\'))
        {
            i++;
        }

        output[outPos++] = json[i];
    }

    output[outPos] = '\0';
    TrimString(output);
    return (outPos > 0);
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