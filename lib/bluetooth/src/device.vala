/**
 * Object representing a [[https://github.com/luetzel/bluez/blob/master/doc/device-api.txt|device]].
 */
public class AstalBluetooth.Device : Object {
    private IDevice proxy;
    private Battery battery;

    internal ObjectPath object_path { owned get; private set; }

    internal Device(IDevice proxy) {
        this.proxy = proxy;
        this.object_path = (ObjectPath)proxy.g_object_path;
        proxy.g_properties_changed.connect((props) => {
            var map = (HashTable<string, Variant>)props;
            foreach (var key in map.get_keys()) {
                var prop = kebab_case(key);
                if (get_class().find_property(prop) != null) {
                    notify_property(prop);
                }

                if (prop == "icon") notify_property("icon-name");
            }
        });
    }

    private ulong battery_handler = 0;

    internal void set_battery(Battery? battery) {
        if ((battery_handler > 0) && (this.battery != null)) {
            this.battery.disconnect(battery_handler);
            battery_handler = 0;
        }

        this.battery = battery;

        if (battery != null) {
            battery_handler = battery.notify["percentage"].connect(() => {
                notify_property("battery_percentage");
            });
        }

        notify_property("battery_percentage");
    }

    /**
     * List of 128-bit UUIDs that represents the available remote services.
     */
    public string[] uuids { owned get { return proxy.uuids; } }

    /**
     * Indicates if the remote device is currently connected.
     */
    public bool connected { get { return proxy.connected; } }

    /**
     * `true` if the device only supports the pre-2.1 pairing mechanism.
     */
    public bool legacy_pairing { get { return proxy.legacy_pairing; } }

    /**
     * Indicates if the remote device is paired.
     */
    public bool paired { get { return proxy.paired; } }

    /**
     * Received Signal Strength Indicator of the remote device (inquiry or advertising).
     */
    public int16 rssi { get { return proxy.rssi; } }

    /**
     * The object path of the adapter the device belongs to.
     */
    public ObjectPath adapter { owned get { return proxy.adapter; } }

    /**
     * The Bluetooth device address of the remote device.
     */
    public string address { owned get { return proxy.address; } }

    /**
     * Proposed icon name.
     */
    public string icon { owned get { return proxy.icon; } }

    /**
     * Remote Device ID information in modalias format used by the kernel and udev.
     */
    public string modalias { owned get { return proxy.modalias; } }

    /**
     * The Bluetooth remote name.
     *
     * It is always better to use [property@AstalBluetooth.Device:alias].
     */
    public string name { owned get { return proxy.name; } }

    /**
     * External appearance of device, as found on GAP service.
     */
    public uint16 appearance { get { return proxy.appearance; } }

    /**
     * The Bluetooth class of device of the remote device.
     */
    public uint32 class { get { return proxy.class; } }

    /**
     * Indicates if this device is currently trying to be connected.
     */
    public bool connecting { get; private set; }

    /**
     * Symbolic icon name for this device, based on
     * [property@AstalBluetooth.Device:icon].
     */
    public string icon_name {
        owned get {
            var name = proxy.icon;
            if (name == null) return "bluetooth-symbolic";

            return name + "-symbolic";
        }
    }

    /**
     * If set to `true` any incoming connections from the device will be immediately rejected.
     */
    public bool blocked {
        get { return proxy.blocked; }
        set { proxy.blocked = value; }
    }

    /**
     * Indicates if the remote is seen as trusted.
     */
    public bool trusted {
        get { return proxy.trusted; }
        set { proxy.trusted = value; }
    }

    /**
     * The percentage of battery left on the device if it has one, else -1.
     */
    public double battery_percentage {
        get {
            if (battery != null) {
                return battery.percentage * 0.01;
            } else {
                return -1;
            }
        }
    }

    /**
     * The name alias for the remote device.
     *
     * In case no alias is set, it will return the remote device [property@AstalBluetooth.Device:name].
     */
    public string alias {
        owned get { return proxy.alias; }
        set { proxy.alias = value; }
    }

    /**
     * This is a generic method to connect any profiles
     * the remote device supports that can be connected to.
     *
     * Possible errors: `NotReady`, `Failed`, `InProgress`, `AlreadyConnected`.
     */
    public async void connect_device() throws Error {
        try {
            connecting = true;
            yield proxy.connect();
        } finally {
            connecting = false;
        }
    }

    /**
     * This method gracefully disconnects all connected profiles.
     *
     * Possible errors: `NotConnected`.
     */
    public async void disconnect_device() throws Error {
        yield proxy.disconnect();
    }

    /**
     * This method connects a specific profile of this device.
     * The UUID provided is the remote service UUID for the profile.
     *
     * Possible errors: `Failed`, `InProgress`, `InvalidArguments`, `NotAvailable`, `NotReady`.
     *
     * @param uuid the remote service UUID.
     */
    public async void connect_profile(string uuid) throws Error {
        yield proxy.connect_profile(uuid);
    }

    /**
     * This method disconnects a specific profile of this device.
     *
     * Possible errors: `Failed`, `InProgress`, `InvalidArguments`, `NotSupported`.
     *
     * @param uuid the remote service UUID.
     */
    public async void disconnect_profile(string uuid) throws Error {
        yield proxy.disconnect_profile(uuid);
    }

    /**
     * This method will connect to the remote device and initiate pairing.
     *
     * Possible errors: `InvalidArguments`, `Failed`, `AlreadyExists`,
     * `AuthenticationCanceled`, `AuthenticationFailed`, `AuthenticationRejected`,
     * `AuthenticationTimeout`, `ConnectionAttemptFailed`.
     */
    public async void pair() throws Error {
        yield proxy.pair();
    }

    /**
     * This method can be used to cancel a pairing operation
     * initiated by [method@AstalBluetooth.Device.pair].
     *
     * Possible errors: `DoesNotExist`, `Failed`.
     */
    public async void cancel_pairing() throws Error {
        yield proxy.cancel_pairing();
    }
}
