namespace AstalHyprland {
public class Workspace : Object {
    public signal void removed();

    public List<weak Client> _clients = new List<weak Client>();

    public int id { get; private set; }
    public string name { get; private set; }
    public Monitor monitor { get; private set; }
    public List<weak Client> clients { owned get { return _clients.copy(); } }
    public bool has_fullscreen { get; private set; }
    public Client last_client { get; private set; }

    public Workspace.dummy(int id, Monitor ? monitor) {
        this.id = id;
        this.name = id.to_string();
        this.monitor = monitor;
    }

    internal List<weak Client> filter_clients() {
        var hyprland = Hyprland.get_default();
        var list = new List<weak Client>();
        foreach (var client in hyprland.clients) {
            if (client.workspace == this) {
                list.append(client);
            }
        }

        return list;
    }

    internal void sync(Json.Object obj) {
        var hyprland = Hyprland.get_default();

        id = (int)obj.get_int_member("id");
        name = obj.get_string_member("name");
        has_fullscreen = obj.get_boolean_member("hasfullscreen");

        monitor = hyprland.get_monitor((int)obj.get_int_member("monitorID"));
        last_client = hyprland.get_client(obj.get_string_member("lastwindow"));

        var list = filter_clients();
        if (_clients.length() != list.length()) {
            _clients = list.copy();
            notify_property("clients");
        }
    }

    public void focus() {
        if(Hyprland.get_default().config_provider == ConfigProvider.LUA) {
            Hyprland.get_default().dispatch("focus", "{workspace=" + id.to_string() + "}");
            return;
        }

        Hyprland.get_default().dispatch("workspace", id.to_string());
    }

    public void move_to(Monitor m) {
        if(Hyprland.get_default().config_provider == ConfigProvider.LUA) {
            Hyprland.get_default().dispatch("workspace.move", "{workspace=" + id.to_string() + ",monitor=" + m.id.to_string() + "}");
            return;
        }

        Hyprland.get_default().dispatch("moveworkspacetomonitor", id.to_string() + " " + m.id.to_string());
    }
}
}
