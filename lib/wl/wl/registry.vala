namespace AstalWl {
extern unowned Wl.Display get_wl_display();

/**
 * Describes a single Wayland global announced by `wl_registry`.
 */
public struct Global {
    /**
     * a unique numeric name
     */
    uint32 name;
    /**
     * the interface name
     */
    string interface;
    /** 
     * the supported version
     */
    uint32 version;
}

internal class SourceFuncWrapper {

    internal SourceFunc fun;

    internal SourceFuncWrapper(owned SourceFunc fun) {
        this.fun = (owned)fun;
    }
}

/**
 * Convenience wrapper for [func@AstalWl.Registry.get_default].
 *
 * Returns the singleton `Registry` instance that tracks all known
 * globals, outputs, and seats on the connected Wayland display.
 */
public Registry get_default() {
    return Registry.get_default();
}
/**
 * Wraps the Wayland `wl_registry` interface and
 * keeps track of all announced globals, outputs and seats.
 *
 * It exposes high-level collections and lookup helpers and emits
 * signals when globals, outputs or seats are added or removed.
 */
public class Registry : Object {

    private static Registry? instance;

    /**
     * Returns the singleton `Registry` instance.
     *
     * The first call connects to the Wayland display and sets up
     * the underlying `wl_registry` listener.
     */
    public static unowned Registry get_default() {
        if (instance == null) instance = new Registry();
        return instance;
    }

    private Source source;
    private Wl.Registry registry;
    private unowned Wl.Display display;
    private ZxdgOutputManagerV1 output_manager;

    private const Wl.RegistryListener registry_listener = {
        registry_handle_global_added,
        registry_handle_global_removed,
    };

    private const Wl.CallbackListener async_roundtrip_listener = {
        handle_async_roundtrip
    };

    /**
     * Hash table of all known Wayland globals keyed by their numeric ID.
     */
    public HashTable<uint32, Global?> globals;
    
    /**
     * Returns a list of all known globals.
     */
    public List<weak Global?> get_globals() {
        return this.globals.get_values();
    }
    
    /**
     * Emitted whenever a new global is announced by the compositor.
     */
    public signal void global_added(Global global);
    
    /**
     * Emitted whenever a new global is removed by the compositor.
     */
    public signal void global_removed(Global global);
    
    /**
     * Hash table of all currently bound outputs keyed by their global ID.
     */
    public HashTable<uint32, Output> outputs;

    /**
     * Returns a list of all known outputs.
     */
    public List<weak Output> get_outputs() {
        return this.outputs.get_values();
    }

    public ListModel output_list_model { get; private set; }

    /**
     * Emitted after a new [class@AstalWl.Output] has been created and bound, note that when this signal is emitted,
     * the output might not have received all events yet, so its properties might no have been set to the correct values yet.
     * If you are only interested ni outputs that have been fully initialized, use the ListModel api.
     */
    public signal void output_added(Output output);

    /**
     * Emitted just before an [class@AstalWl.Output] is removed from the List.
     */
    public signal void output_removed(Output output);

    /**
     * Hash table of all currently bound seats keyed by their global ID.
     */
    public HashTable<uint32, Seat> seats;

    /**
     * Returns a list of all known seats.
     */
    public List<weak Seat> get_seats() {
        return this.seats.get_values();
    }
    
    public ListModel seat_list_model { get; private set; }

    /**
     * Emitted after a new [class@AstalWl.Seat] has been created and bound.
     */
    public signal void seat_added(Seat seat);

    /**
     * Emitted just before a [class@AstalWl.Seat] is removed.
     */
    public signal void seat_removed(Seat seat);

    /**
     * Returns the underlying `wl_registry` object.
     */
    [GIR(visible = false)]
    public unowned Wl.Registry? get_registry() {
        return this.registry;
    }

    /**
     * Returns the underlying `wl_display` used by this registry.
     */
    [GIR(visible = false)]
    public unowned Wl.Display? get_display() {
        return this.display;
    }

    /**
     * Block until all pending requests have been handled by the compositor. Returns the number of dispatched events.
     */
    public int roundtrip() {
        return this.display.roundtrip();
    }

    private static void handle_async_roundtrip(owned SourceFuncWrapper func, Wl.Callback cb, uint32 data) {
        if(func != null && func.fun != null) {
            func.fun();
        }
    }

    /**
     * makes an asynchronous roundtrip invoking the callback when done without blocking in the main thread.
     */
    public async void roundtrip_async() {
        unowned Wl.Callback callback = this.display.sync();
        SourceFunc callback_func = this.roundtrip_async.callback;
        callback.add_listener(async_roundtrip_listener, new SourceFuncWrapper((owned) callback_func));
        yield;
    }

    private void registry_handle_global_added (Wl.Registry wl_registry, uint32 name, string @interface, uint32 version) {
        Global global = { name, @interface, version };
        this.globals.insert(name, global);

        if (@interface == "zxdg_output_manager_v1") {
            this.output_manager = this.registry.bind<ZxdgOutputManagerV1>(name, ref ZxdgOutputManagerV1.iface, uint.min(version, 4));
            HashTableIter<uint32, Output> iter = HashTableIter<uint32, Output>(this.outputs);
            unowned Output output;
            uint32 id;

            while (iter.next(out id, out output)) {
                output.init_xdg(this.output_manager, this.display);
            }
        } else if (@interface == "wl_output") {
            var output = new Output(global, this.registry, this.display, this.output_manager);
            ulong id = 0;
            id = output.changed.connect((o) => {
               (this.output_list_model as ListStore).append(o);
                output.disconnect(id);
            });
            this.outputs.insert(name, output);
            output_added(output);
        } else if (@interface == "wl_seat") {
            var seat = new Seat(global, this.registry, this.display);
            this.seats.insert(name, seat);
            (this.seat_list_model as ListStore).append(seat);
            seat_added(seat);
        }
        global_added(global);
    }

    private void registry_handle_global_removed(Wl.Registry wl_registry, uint32 name) {
        var global = this.globals.lookup(name);
        this.globals.remove(name);
        if (global.interface == "wl_output") {
            var output = this.outputs.lookup(name);
            this.outputs.remove(name);
            uint pos;
            (this.output_list_model as ListStore).find(output, out pos);
            (this.output_list_model as ListStore).remove(pos);
            output.invalidate();
            output_removed(output);
        } else if (global.interface == "wl_seat") {
            var seat = this.seats.lookup(name);
            this.seats.remove(name);
            uint pos;
            (this.seat_list_model as ListStore).find(seat, out pos);
            (this.seat_list_model as ListStore).remove(pos);
            seat_removed(seat);
        }
        global_removed(global);
    }

    /**
    * Returns a list of globals, optionally filtered by interface name.
    * If `null` is passed, all globals are returned.
    */
    public List<Global?>? find_globals(string? @interface = null) {
        List<Global?> list = new List<Global?>();

        HashTableIter<uint32, Global?> iter = HashTableIter<uint32, Global?>(this.globals);
        unowned Global? global;
        uint32 id;

        while (iter.next(out id, out global)) {
            if ((@interface == null) || (global.interface == @interface)) list.append(global);
        }
        return list;
    }

    /**
    * Looks up a global by its numeric Iid.
    */
    public Global? get_global_by_id(uint32 id) {
        return this.globals.lookup(id);
    }
    
    /**
    * Looks up an output by its global id.
    */
    public Output? get_output_by_id(uint32 id) {
        return this.outputs.lookup(id);
    }
   
   /**
    * Looks up an output by its compositor-assigned name.
    */
    public Output? get_output_by_name(string name) {
        HashTableIter<uint32, Output> iter = HashTableIter<uint32, Output>(this.outputs);
        unowned Output output;
        uint32 id;

        while (iter.next(out id, out output)) {
            if (output.name == name) return output;
        }
        return null;
    }
  
    /**
    * Looks up an `Output` by its underlying `wl_output`.
    */
    [GIR(visible = false)]
    public Output? get_output_by_wl_output(Wl.Output wl_output) {
        HashTableIter<uint32, Output> iter = HashTableIter<uint32, Output>(this.outputs);
        unowned Output output;
        uint32 id;

        while (iter.next(out id, out output)) {
            if (output.get_wl_output() == wl_output) return output;
        }
        return null;
    }

    /**
    * Looks up a seat by its global id.
    */
    public Seat? get_seat_by_id(uint32 id) {
        return this.seats.lookup(id);
    }

    /**
    * Looks up a seat by its compositor-assigned name.
    */
    public Seat? get_seat_by_name(string name) {
        HashTableIter<uint32, Seat> iter = HashTableIter<uint32, Seat?>(this.seats);
        unowned Seat seat;
        uint32 id;

        while (iter.next(out id, out seat)) {
            if (seat.name == name) return seat;
        }
        return null;
    }

    /**
    * Looks up a `Seat` by its underlying `wl_seat`.
    */
    [GIR(visible = false)]
    public Seat? get_seat_by_wl_seat(Wl.Seat wl_seat) {
        HashTableIter<uint32, Seat> iter = HashTableIter<uint32, Seat>(this.seats);
        unowned Seat seat;
        uint32 id;

        while (iter.next(out id, out seat)) {
            if (seat.get_wl_seat() == wl_seat) return seat;
        }
        return null;
    }

    construct {
        this.globals = new HashTable<uint32, Global?>(direct_hash, direct_equal);
        this.outputs = new HashTable<uint32, Output>(direct_hash, direct_equal);
        this.output_list_model = new ListStore(typeof(Output));
        this.seats = new HashTable<uint32, Seat>(direct_hash, direct_equal);
        this.seat_list_model = new ListStore(typeof(Seat));
        
        switch(GLib.Environment.get_variable("ASTAL_WL_DISPLAY")?.up()) {
            case "GDK":
            case "GTK":
                debug("forcing the use of gdk display");
                this.display = get_wl_display();
                break;
            case null:
                this.display = get_wl_display();
                if(this.display == null) {
                    debug("could not connect to gdk display, falling back to astal");
                    this.source = new Source();
                    this.display = this.source.display;
                }
                break;
            case "ASTAL":
            default:
                debug("forcing the use of astal display");
                this.source = new Source();
                this.display = this.source.display;
        }

        if (this.display == null) {
            critical("Could not connect to wayland.");
            return;
        }

        this.registry = this.display.get_registry();
        this.registry.add_listener(registry_listener, this);
        this.display.roundtrip();
    }
}
}
