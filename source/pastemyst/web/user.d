module pastemyst.web.user;

import vibe.d;
import vibe.web.auth;
import pastemyst.data;
import pastemyst.web;

/++
 + web interface for the /user endpoint
 +/
@path("/user")
@requiresAuth
public class UserWeb
{
    mixin Auth;

    /++
     + GET /user/profile
     +
     + user profile page
     +/
    @path("profile")
    @anyAuth
    public void getProfile(HTTPServerRequest req, string search="")
    {
        import pastemyst.db : find;
        import std.algorithm : canFind;
        import std.uni : toLower;

        UserSession session = req.session.get!UserSession("user");    
        const title = session.user.username ~ " - profile";

        auto pastesRes = find!Paste(["ownerId": session.user.id]);
        Paste[] pastes;
        foreach (paste; pastesRes)
        {
            if (search == "" || paste.title.toLower().canFind(search.toLower()))
            {
                pastes ~= paste;
            }
        }

        render!("profile.dt", pastes, search, session, title);
    }

    /++
     + GET /user/settings
     +
     + user settings page
     +/
    @path("settings")
    @anyAuth
    public void getSettings(HTTPServerRequest req)
    {
        import pastemyst.db : findOneById;

        UserSession session = req.session.get!UserSession("user");    
        User user = findOneById!User(session.user.id).get();

        const title = session.user.username ~ " - settings";
        render!("settings.dt", user, session, title);
    }

    /++
     + POST /user/settings/save
     +
     + save user settings
     +/
    @path("settings/save")
    @anyAuth
    public void postSettingsSave(HTTPServerRequest req, string username, bool publicProfile, string language)
    {
        import std.conv : to;
        import pastemyst.db : uploadAvatar, update, findOneById;
        import std.path : chainPath, baseName;
        import std.array : array, split;
        import pastemyst.data : config, doesLanguageExist;
        import std.file : remove, exists;
        import std.algorithm : startsWith;

        UserSession session = req.session.get!UserSession("user");

        User user = findOneById!User(session.user.id).get();

        if ("avatar" in req.files)
        {
            auto avatar = "avatar" in req.files;

            string avatarPath = uploadAvatar(avatar.tempPath.toString(), avatar.filename.name);

            string avatarUrl = chainPath(config.hostname, "static/assets/avatars/", avatarPath).array;

            if (user.avatarUrl.startsWith(config.hostname))
            {
                // delete old avatar
                remove("./public/assets/avatars/" ~ baseName(user.avatarUrl));
            }

            update!User(["_id": session.user.id], ["$set": ["avatarUrl": avatarUrl]]);

            session.user.avatarUrl = avatarUrl;
        }

        if (session.user.username != username)
        {
            session.user.username = username;
            update!User(["_id": session.user.id], ["$set": ["username": username]]);
        }

        if (user.publicProfile != publicProfile)
        {
            update!User(["_id": session.user.id], ["$set": ["publicProfile": publicProfile]]);
        }

        if (user.defaultLang != language)
        {
            string lang = language.split(",")[0];
            enforceHTTP(doesLanguageExist(lang), HTTPStatus.badRequest, "invalid language");
            update!User(["_id": session.user.id], ["$set": ["defaultLang": lang]]);
        }

        req.session.set("user", session);

        redirect("/user/settings");
    }

    /++
     + GET /user/delete
     +
     + confirmation prompt for deleting the users account
     +/
    @path("/delete")
    @anyAuth
    public void getDelete(HTTPServerRequest req)
    {
        UserSession session = req.session.get!UserSession("user");

        const string msg = "are you sure you want to completely delete your account? this action cannot be undone.";
        const string confirmLink = "/user/delete/confirm";
        const string cancelLink = "/user/settings";

        render!("confirm.dt", msg, confirmLink, cancelLink, session);
    }

    @path("/delete/confirm")
    @anyAuth
    public void getDeleteConfirm(HTTPServerRequest req)
    {
        import pastemyst.db : remove, findOneById;
        import std.algorithm : startsWith;
        import std.path : baseName;
        import file = std.file : remove;

        UserSession session = req.session.get!UserSession("user");

        User user = findOneById!User(session.user.id).get();

        if (user.avatarUrl.startsWith(config.hostname))
        {
            file.remove("./public/assets/avatars/" ~ baseName(user.avatarUrl));
        }

        remove!Paste(["ownerId": session.user.id]);
        remove!User(["_id": session.user.id]);

        terminateSession();

        redirect("/");
    }
}
