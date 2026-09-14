namespace AstalHyprland {
public Hyprland get_default() {
    return Hyprland.get_default();
}

public class Hyprland : Object {
    private static string HIS = GLib.Environment.get_variable("HYPRLAND_INSTANCE_SIGNATURE");
    private static string RUN_DIR = GLib.Environment.get_user_runtime_dir();

    private static Hyprland _instance;
    public static Hyprland? get_default() {
        if (_instance != null) return _instance;

        var HIS = GLib.Environment.get_variable("HYPRLAND_INSTANCE_SIGNATURE");
        if (HIS == null) {
            critical("Hyprland is not running");
            return null;
        }

        var h = new Hyprland();
        _instance = h;

        h.socket2 = h.connection("socket2");
        h.watch_socket(new DataInputStream(h.socket2.input_stream));
        try {
            h.init();
        } catch (Error err) {
            critical("could not initialize: %s", err.message);
            return null;
        }

        return _instance;
    }

    // monitors, workspaces, clients
    private HashTable<int, Monitor> _monitors =
        new HashTable<int, Monitor>((i) => i, ((a, b) => a == b));

    private HashTable<int, Workspace> _workspaces =
        new HashTable<int, Workspace>((i) => i, ((a, b) => a == b));

    private HashTable<string, Client> _clients =
        new HashTable<string, Client>(str_hash, str_equal);

    public List<weak Monitor> monitors { owned get { return _monitors.get_values(); } }
    public List<weak Workspace> workspaces { owned get { return _workspaces.get_values(); } }
    public List<weak Client> clients { owned get { return _clients.get_values(); } }
    public ConfigProvider config_provider { get; private set; default = ConfigProvider.HYPRLANG; }

    public Monitor get_monitor(int id) {
        return _monitors.get(id);
    }
    public Workspace get_workspace(int id) {
        return _workspaces.get(id);
    }
    public Client? get_client(string address) {
        if ((address == "") || (address == null)) return null;

        if (address.substring(0, 2) == "0x") return _clients.get(address.substring(2, -1));

        return _clients.get(address);
    }

    public Monitor? get_monitor_by_name(string name) {
        foreach (var mon in monitors) {
            if (mon.name == name) return mon;
        }
        return null;
    }

    public Workspace? get_workspace_by_name(string name) {
        foreach (var ws in workspaces) {
            if (ws.name == name) return ws;
        }
        return null;
    }

    public Workspace focused_workspace { get; private set; }
    public Monitor focused_monitor { get; private set; }
    public Client focused_client { get; private set; }

    // other props
    public List<Bind> binds {
        owned get {
            var list = new List<Bind>();
            try {
                var arr = Json.from_string(message("j/binds")).get_array();
                foreach (var b in arr.get_elements()) {
                    list.append(new Bind.from_json(b.get_object()));
                }
            } catch (Error err) {
                critical(err.message);
            }
            return list;
        }
    }

    public Position cursor_position {
        owned get {
            return new Position.cursorpos(message("cursorpos"));
        }
    }

    // signals
    public signal void event(string event, string args);

    // TODO: nag vaxry for fullscreenv2
    // public signal void fullscreen (bool fullscreen);
    public signal void minimize(Client client, bool minimize);
    public signal void floating(Client client, bool floating);
    public signal void urgent(Client client);
    public signal void client_moved(Client client, Workspace ws);

    public signal void submap(string name);
    public signal void keyboard_layout(string keyboard, string layout);
    public signal void config_reloaded();

    // state
    public signal void client_added(Client client);
    public signal void client_removed(string address);
    public signal void workspace_added(Workspace workspace);
    public signal void workspace_removed(int id);
    public signal void monitor_added(Monitor monitor);
    public signal void monitor_removed(int id);

    private SocketConnection socket2;

    private SocketConnection? connection(string socket) {
        var path = RUN_DIR + "/hypr/" + HIS + "/." + socket + ".sock";
        try {
            return new SocketClient().connect(new UnixSocketAddress(path), null);
        } catch (Error err) {
            critical(err.message);
            return null;
        }
    }

    private void watch_socket(DataInputStream stream) {
        stream.read_line_async.begin(Priority.DEFAULT, null, (_, res) => {
                try {
                    var line = stream.read_line_async.end(res);
                    handle_event.begin(line, (_, res) => {
                        try {
                            handle_event.end(res);
                        } catch (Error err) {
                            critical(err.message);
                        }
                    });
                    watch_socket(stream);
                } catch (Error err) {
                    critical(err.message);
                }
            });
    }

    private void write_socket(
        string message,
        out SocketConnection conn,
        out DataInputStream stream
    ) throws Error {
        conn = connection("socket");
        if (conn != null) {
            conn.output_stream.write(message.data, null);
            stream = new DataInputStream(conn.input_stream);
        } else {
            stream = null;
            critical("could not write to the Hyprland socket");
        }
    }

    public string message(string message) {
        SocketConnection? conn;
        DataInputStream? stream;
        try {
            write_socket(message, out conn, out stream);
            if ((stream != null) && (conn != null)) {
                var res = stream.read_upto("\x04", -1, null, null);
                conn.close(null);
                return res;
            }
        } catch (Error err) {
            critical(err.message);
        }
        return "";
    }

    public async string message_async(string message) {
        SocketConnection? conn;
        DataInputStream? stream;
        try {
            write_socket(message, out conn, out stream);
            if ((stream != null) && (conn != null)) {
                var res = yield stream.read_upto_async("\x04", -1, Priority.DEFAULT, null, null);
                conn.close(null);
                return res;
            }
        } catch (Error err) {
            critical(err.message);
        }
        return "";
    }

    /**
      * Send inline lua to Hyprland. (with `LUA` config provider only)
      */
    public void eval(string lua) {
        var msg = "eval " + lua;
        message_async.begin(msg, (_, res) => {
                var err = message_async.end(res);
                if (err != "ok") critical("eval error: %s", err);
            });
    }

    /**
      * Call a dispatcher in the Hyprland socket (without the `hl.dsp` prefix) 
      * Please keep in mind that arguments are in the lua syntax, 
      * you might need to add string quotes when needed
      */
    public void dispatch(string dispatcher, string args) {
        var msg = "dispatch ";
        if(this.config_provider == ConfigProvider.LUA) {
            msg = msg + "hl.dsp." + dispatcher + "(" + args + ")";
        } else {
            msg = msg + dispatcher + " " + args;
        }
        message_async.begin(msg, (_, res) => {
                var err = message_async.end(res);
                if (err != "ok") critical("dispatch error: %s", err);
            });
    }

    /**
      * Call a dispatcher in the Hyprland socket (without the `hl.dsp` prefix) 
      * Please keep in mind that arguments are in the lua syntax, 
      * you might need to add string quotes when needed
      */
    public void dispatch_argv(string dispatcher, string[] args) {
        var msg = "dispatch hl.dsp." + dispatcher + "(" + string.joinv(",", args) + ")";
        message_async.begin(msg, (_, res) => {
                var err = message_async.end(res);
                if (err != "ok") critical("dispatch error: %s", err);
            });
    }

    public void move_cursor(int x, int y) {
        if(this.config_provider == ConfigProvider.LUA) {
            dispatch("cursor.move", "{x=" + x.to_string() + ",y=" + y.to_string() + "}");
            return;
        }

       dispatch("movecursor", x.to_string() + " " + y.to_string()); 
    }

    // TODO: nag vaxry to make socket events and hyprctl more consistent
    private void init() throws Error {
        var mons = Json.from_string(message("j/monitors")).get_array();
        var wrkspcs = Json.from_string(message("j/workspaces")).get_array();
        var clnts = Json.from_string(message("j/clients")).get_array();
        
        try {
            var prov = Json.from_string(message("j/status")).get_object().get_member("configProvider").get_string();
            if (prov == "lua") {
                this.config_provider = ConfigProvider.LUA;
            }
        } catch (Error _) {}

        // create
        foreach (var mon in mons.get_elements()) {
            var id = (int)mon.get_object().get_member("id").get_int();
            var m = new Monitor();
            _monitors.insert(id, m);

            if (mon.get_object().get_member("focused").get_boolean()) focused_monitor = m;
        }
        foreach (var wrkpsc in wrkspcs.get_elements()) {
            var id = (int)wrkpsc.get_object().get_member("id").get_int();
            _workspaces.set(id, new Workspace());
        }
        foreach (var clnt in clnts.get_elements()) {
            var addr = clnt.get_object().get_member("address").get_string();
            _clients.set(addr.replace("0x", ""), new Client());
        }

        // init
        foreach (var c in clnts.get_elements()) {
            var addr = c.get_object().get_member("address").get_string();
            get_client(addr).sync(c.get_object());
        }
        foreach (var ws in wrkspcs.get_elements()) {
            var id = (int)ws.get_object().get_member("id").get_int();
            get_workspace(id).sync(ws.get_object());
        }
        foreach (var mon in mons.get_elements()) {
            var id = (int)mon.get_object().get_member("id").get_int();
            get_monitor(id).sync(mon.get_object());
        }

        // focused
        focused_workspace = get_workspace((int)Json.from_string(message("j/activeworkspace"))
                .get_object().get_member("id").get_int());

        focused_client = get_client(Json.from_string(message("j/activewindow"))
                .get_object().get_member("address").get_string());
    }

    ~Hyprland() {
        if (socket2 != null) {
            try {
                socket2.close(null);
            } catch (Error err) {
                critical(err.message);
            }
        }
    }

    public async void sync_monitors() throws Error {
        var str = yield message_async("j/monitors");
        var arr = Json.from_string(str).get_array();
        foreach (var obj in arr.get_elements()) {
            var id = (int)obj.get_object().get_int_member("id");
            var m = get_monitor(id);
            if (m != null) m.sync(obj.get_object());
        }
    }

    public async void sync_workspaces() throws Error {
        var str = yield message_async("j/workspaces");
        var arr = Json.from_string(str).get_array();
        foreach (var obj in arr.get_elements()) {
            var id = (int)obj.get_object().get_int_member("id");
            var ws = get_workspace(id);
            if (ws != null) ws.sync(obj.get_object());
        }
    }

    public async void sync_clients() throws Error {
        var str = yield message_async("j/clients");
        var arr = Json.from_string(str).get_array();
        foreach (var obj in arr.get_elements()) {
            var addr = obj.get_object().get_string_member("address");
            var c = get_client(addr);
            if (c != null) c.sync(obj.get_object());
        }
    }

    private async bool try_add_client(string addr) throws Error {
        if ((addr == "") || (get_client(addr) != null)) {
            return true;
        }

        var client = new Client();
        _clients.insert(addr, client);
        yield sync_clients();
        yield sync_workspaces();
        client_added(client);
        notify_property("clients");
        return false;
    }

    private async void handle_event(string line) throws Error {
        var args = line.split(">>");

        switch (args[0]) {
            case "workspacev2": {
                yield sync_workspaces();
                yield sync_monitors();
                focused_workspace = get_workspace(int.parse(args[1]));
                break;
            }
            case "focusedmon": {
                var argv = args[1].split(",", 2);
                yield sync_monitors();
                focused_monitor = get_monitor_by_name(argv[0]);
                focused_workspace = get_workspace_by_name(argv[1]);
                break;
            }
            case "fullscreen": {
                yield sync_clients();
                break;
            }
            case "monitorremoved": {
                var id = get_monitor_by_name(args[1]).id;
                _monitors.get(id).removed();
                _monitors.remove(id);
                monitor_removed(id);
                notify_property("monitors");
                break;
            }
            case "monitoraddedv2": {
                var id = int.parse(args[1].split(",", 2)[0]);
                var mon = new Monitor();
                _monitors.insert(id, mon);
                yield sync_monitors();
                monitor_added(mon);
                notify_property("monitors");
                break;
            }
            case "createworkspacev2": {
                var id = int.parse(args[1].split(",", 2)[0]);
                var ws = new Workspace();
                _workspaces.insert(id, ws);
                yield sync_workspaces();
                workspace_added(ws);
                notify_property("workspaces");
                break;
            }
            case "destroyworkspacev2": {
                var id = int.parse(args[1].split(",", 2)[0]);
                _workspaces.get(id).removed();
                _workspaces.remove(id);
                workspace_removed(id);
                notify_property("workspaces");
                break;
            }
            case "moveworkspacev2": {
                yield sync_workspaces();
                yield sync_monitors();
                focused_workspace = get_workspace(int.parse(args[1]));
                notify_property("workspaces");
                break;
            }
            case "renameworkspace": {
                yield sync_workspaces();
                break;
            }
            case "activespecial": {
                yield sync_monitors();
                yield sync_workspaces();
                break;
            }
            case "activelayout": {
                var argv = args[1].split(",");
                keyboard_layout(argv[0], argv[1]);
                break;
            }
            // first event that signals a new client when it opens as an active window
            case "activewindowv2": {
                yield try_add_client(args[1]);
                focused_client = get_client(args[1]);
                break;
            }
            case "openwindow": {
                var addr = args[1].split(",")[0];
                if (yield try_add_client(addr)) {
                    yield sync_clients();
                    yield sync_workspaces();
                }
                break;
            }
            case "closewindow": {
                _clients.get(args[1]).removed();
                _clients.remove(args[1]);
                yield sync_workspaces();
                client_removed(args[1]);
                notify_property("clients");
                break;
            }
            case "movewindowv2": {
                yield sync_clients();
                yield sync_workspaces();
                var argv = args[1].split(",");
                client_moved(get_client(argv[0]), get_workspace(int.parse(argv[1])));
                get_client(argv[0]).moved_to(get_workspace(int.parse(argv[1])));
                break;
            }
            case "submap": {
                submap(args[1]);
                break;
            }
            case "changefloatingmode": {
                var argv = args[1].split(",");
                yield sync_clients();
                floating(get_client(argv[0]), argv[1] == "0");
                break;
            }
            case "urgent": {
                urgent(get_client(args[1]));
                break;
            }
            case "minimize": {
                var argv = args[1].split(",");
                yield sync_clients();
                minimize(get_client(argv[0]), argv[1] == "0");
                break;
            }
            case "windowtitlev2": {
                yield sync_clients();
                break;
            }
            // TODO:
            case "togglegroup":
            case "moveintogroup":
            case "moveoutofgroup":
            case "ignoregrouplock":
            case "lockgroups": {
                break;
            }
            case "configreloaded": {
                config_reloaded();
                break;
            }
            default: break;
        }

        event(args[0], args[1]);
    }
}
}
