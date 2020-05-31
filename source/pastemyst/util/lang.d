module pastemyst.util.lang;

/++
 + detects the language of the code using enry
 + it returns the mime of the language
 +/
public string autodetectLang(string pasteId, string pastyId, string code) @safe
{
    import vibe.data.json : parseJsonString, Json;
    import std.process : execute;
    import std.file : write, mkdir, remove, exists;

    if (!exists("tmp/"))
    {
        mkdir("tmp");
    }

    write("tmp/" ~ pasteId ~ "-" ~ pastyId ~ "-code", code);

    Json res = execute(["enry", "-json", "tmp/" ~ pasteId ~ "-" ~ pastyId ~ "-code"]).output.parseJsonString();

    remove("tmp/" ~ pasteId ~ "-" ~ pastyId ~ "-code");

    return res["mime"].get!string();
}

/++
 + returns the language name from the mime type
 +/
public string getLangFromMime(string mime) @safe
{
    import pastemyst.data : languages;
    import std.algorithm : canFind;
    import vibe.data.json : Json;

    foreach (language; languages.byValue())
    {
        if (language["name"].get!string() == "Autodetect")
        {
            continue;
        }

        if (language["mimes"].get!(Json[])().canFind!((j) => j.get!string() == mime))
        {
            return language["name"].get!string();
        }
    }

    return "Plain Text";
}