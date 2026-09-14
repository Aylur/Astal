/**
 * Object representing an [[https://github.com/RadiusNetworks/bluez/blob/master/doc/adapter-api.txt|adapter]].
 */
public class AstalBluetooth.Adapter : Object {
    /**
     * Seconds to wait for a power change to take effect before giving up
     * on the transition. Toggling an adapter goes through rfkill, which on
     * some systems takes a noticeable while, and can fail without a reply.
     */
    private const uint STATE_TIMEOUT = 30;

    private IAdapter proxy;
    private uint state_timeout = 0;

    internal string object_path { owned get; private set; }

    /**
     * State of this adapter, including the transitions between on and off.
     */
    public AdapterState state { get; private set; default = AdapterState.OFF; }

    internal Adapter(IAdapter proxy) {
        this.proxy = proxy;
        this.object_path = proxy.g_object_path;
        proxy.g_properties_changed.connect((props) => {
            var map = (HashTable<string, Variant>)props;
            foreach (var key in map.get_keys()) {
                var prop = kebab_case(key);
                if (get_class().find_property(prop) != null) {
                    notify_property(prop);
                }

                if (prop == "powered") settle_state();
            }
        });

        settle_state();
    }

    ~Adapter() {
        if (state_timeout > 0) Source.remove(state_timeout);
    }

    private void settle_state() {
        if (state_timeout > 0) {
            Source.remove(state_timeout);
            state_timeout = 0;
        }

        state = proxy.powered ? AdapterState.ON : AdapterState.OFF;
    }

    /**
     * List of 128-bit UUIDs that represents the available local services.
     */
    public string[] uuids { owned get { return proxy.uuids; } }

    /**
     * Indicates that a device discovery procedure is active.
     */
    public bool discovering { get { return proxy.discovering; } }

    /**
     * Local Device ID information in modalias format used by the kernel and udev.
     */
    public string modalias { owned get { return proxy.modalias; } }

    /**
     * The Bluetooth system name (pretty hostname).
     */
    public string name { owned get { return proxy.name; } }

    /**
     * The Bluetooth class of device.
     */
    public uint class { get { return proxy.class; } }

    /**
     * The Bluetooth device address.
     */
    public string address { owned get { return proxy.address; } }

    /**
     * Switch an adapter to discoverable or non-discoverable
     * to either make it visible or hide it.
     */
    public bool discoverable {
        get { return proxy.discoverable; }
        set { proxy.discoverable = value; }
    }

    /**
     * Switch an adapter to pairable or non-pairable.
     */
    public bool pairable {
        get { return proxy.pairable; }
        set { proxy.pairable = value; }
    }

    /**
     * Switch an adapter on or off.
     */
    public bool powered {
        get { return proxy.powered; }
        set {
            if (value == proxy.powered) return;

            state = value ? AdapterState.TURNING_ON : AdapterState.TURNING_OFF;

            // the transition has to end even if the adapter never reports back
            if (state_timeout > 0) Source.remove(state_timeout);
            state_timeout = Timeout.add_seconds(STATE_TIMEOUT, () => {
                state_timeout = 0;
                state = proxy.powered ? AdapterState.ON : AdapterState.OFF;
                return Source.REMOVE;
            });

            proxy.powered = value;
        }
    }

    /**
     * The Bluetooth friendly name.
     *
     * In case no alias is set, it will return [property@AstalBluetooth.Adapter:name].
     */
    public string alias {
        owned get { return proxy.alias; }
        set { proxy.alias = value; }
    }

    /**
     * The discoverable timeout in seconds.
     * A value of zero means that the timeout is disabled
     * and it will stay in discoverable/limited mode forever
     * until [method@AstalBluetooth.Adapter.stop_discovery] is invoked.
     * The default value for the discoverable timeout should be `180`.
     */
    public uint discoverable_timeout {
        get { return proxy.discoverable_timeout; }
        set { proxy.discoverable_timeout = value; }
    }

    /**
     * The pairable timeout in seconds.
     *
     * A value of zero means that the timeout is disabled and it will stay in pairable mode forever.
     * The default value for pairable timeout should be disabled `0`.
     */
    public uint pairable_timeout {
        get { return proxy.pairable_timeout; }
        set { proxy.pairable_timeout = value; }
    }

    /**
     * This removes the remote device and the pairing information.
     *
     * Possible errors: `InvalidArguments`, `Failed`.
     */
    public async void remove_device(Device device) throws Error {
        yield proxy.remove_device(device.object_path);
    }

    /**
     * This method starts the device discovery procedure.
     *
     * Possible errors: `NotReady`, `Failed`.
     */
    public async void start_discovery() throws Error {
        yield proxy.start_discovery();
    }

    /**
     * This method will cancel any previous [method@AstalBluetooth.Adapter.start_discovery] procedure.
     *
     * Possible errors: `NotReady`, `Failed`, `NotAuthorized`.
     */
    public async void stop_discovery() throws Error {
        yield proxy.stop_discovery();
    }
}

/**
 * State of an [class@AstalBluetooth.Adapter].
 */
public enum AstalBluetooth.AdapterState {
    /** No adapter is present. */
    ABSENT,
    /** The adapter is not powered. */
    OFF,
    /** The adapter is powered. */
    ON,
    /** The adapter is powering on. */
    TURNING_ON,
    /** The adapter is powering off. */
    TURNING_OFF;

    public string to_string() {
        switch (this) {
            case OFF: return "off";
            case ON: return "on";
            case TURNING_ON: return "turning_on";
            case TURNING_OFF: return "turning_off";
            default: return "absent";
        }
    }
}
