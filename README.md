# Makara AI Assistant

A SourceMod plugin designed for CS:S Zombie Revival servers that provides an interactive AI chat assistant powered by the Google AI Studio (Gemini) API using `ripext`

### Features
* **AI Integration:** Uses REST in Pawn (`ripext`) for async HTTPS and native JSON parsing with Google Gemini API.
* **Local Brain:** Handles common server commands (`!shop`, `!props`, `!zclass`, etc.) instantly without wasting API queries.
* **VIP Cooldown:** Built-in rate limiting (3 questions followed by a 40-second cooldown) to prevent chat spam.
* **Response Filtering:** Includes safety filters to prevent prompt injection and leak of sensitive instructions or system keys.

### Requirements
* [REST in Pawn (ripext)](https://github.com/ErikMinekus/sm-ripext)
* [MultiColors (`multicolors.inc`)](https://github.com/Bara/Multi-Colors/tree/master/addons/sourcemod/scripting/include/multicolors)
