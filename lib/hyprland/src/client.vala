namespace AstalHyprland {
public class Client : Object {
    public signal void removed();
    public signal void moved_to(Workspace workspace);

    public string address { get; private set; }
    public bool mapped { get; private set; }
    public bool hidden { get; private set; }
    public int x { get; private set; }
    public int y { get; private set; }
    public int width { get; private set; }
    public int height { get; private set; }
    public Workspace workspace { get; private set; }
    public bool floating { get; private set; }
    public Monitor monitor { get; private set; }
    public string class { get; private set; }
    public string title { get; private set; }
    public string initial_class { get; private set; }
    public string initial_title { get; private set; }
    public uint pid { get; private set; }
    public bool xwayland { get; private set; }
    public bool pinned { get; private set; }
    public Fullscreen fullscreen { get; private set; }
    public Fullscreen fullscreen_client { get; private set; }

    // TODO: public Group[] grouped { get; private set; }
    // TODO: public Tag[] tags { get; private set; }
    public string swallowing { get; private set; }
    public int focus_history_id { get; private set; }

    internal void sync(Json.Object obj) {
        var hyprland = Hyprland.get_default();

        address = obj.get_string_member("address").replace("0x", "");
        mapped = obj.get_boolean_member("mapped");
        hidden = obj.get_boolean_member("hidden");
        floating = obj.get_boolean_member("floating");
        class = obj.get_string_member("class");
        title = obj.get_string_member("title");
        initial_title = obj.get_string_member("initialTitle");
        initial_class = obj.get_string_member("initialClass");
        pid = (uint)obj.get_int_member("pid");
        xwayland = obj.get_boolean_member("xwayland");
        pinned = obj.get_boolean_member("pinned");
        swallowing = obj.get_string_member("swallowing");
        focus_history_id = (int)obj.get_int_member("focusHistoryID");
        x = (int)obj.get_array_member("at").get_int_element(0);
        y = (int)obj.get_array_member("at").get_int_element(1);
        width = (int)obj.get_array_member("size").get_int_element(0);
        height = (int)obj.get_array_member("size").get_int_element(1);
        fullscreen = (Fullscreen)obj.get_int_member("fullscreen");
        fullscreen_client = (Fullscreen)obj.get_int_member("fullscreenClient");

        workspace = hyprland.get_workspace((int)obj.get_object_member("workspace").get_int_member("id"));
        monitor = hyprland.get_monitor((int)obj.get_int_member("monitor"));
    }

    public void kill() {
        if(Hyprland.get_default().config_provider == ConfigProvider.LUA) {
            Hyprland.get_default().dispatch("window.close", @"\"address:0x$address\"");
            return;
        }

        Hyprland.get_default().dispatch("closewindow", @"address:0x$address");
    }

    public void focus() {
        if(Hyprland.get_default().config_provider == ConfigProvider.LUA) {
            Hyprland.get_default().dispatch("focus", @"{window=\"address:0x$address\"}");
            return;
        }

        Hyprland.get_default().dispatch("focuswindow", @"address:0x$address");
    }

    public void move_to(Workspace ws) {
        var id = ws.id.to_string();
        if(Hyprland.get_default().config_provider == ConfigProvider.LUA) {
            Hyprland.get_default().dispatch("window.move", @"{window=\"address:0x$address\",workspace=$id,follow=false}");
            return;
        }

        Hyprland.get_default().dispatch("movetoworkspacesilent", @"$id,address:0x$address"); 
    }

    public void toggle_floating() {
        if(Hyprland.get_default().config_provider == ConfigProvider.LUA) {
            Hyprland.get_default().dispatch("window.float", @"{window=\"address:0x$address\"}");
            return;
        }

        Hyprland.get_default().dispatch("togglefloating", @"address:0x$address");
    }
}

[Flags]
public enum Fullscreen {
    CURRENT = -1,
    NONE = 0,
    MAXIMIZED = 1,
    FULLSCREEN = 2,
}
}
