import { register, type BaseProps, type Widget } from './widget.js';
import Gtk from 'gi://Gtk?version=4.0';
import Gdk from 'gi://Gdk?version=4.0';
import Cairo from 'gi://cairo?version=1.0';
// @ts-expect-error missing types FIXME:
import { default as LayerShell } from 'gi://Gtk4LayerShell';

const ANCHOR = {
    'left': LayerShell.Edge.LEFT,
    'right': LayerShell.Edge.RIGHT,
    'top': LayerShell.Edge.TOP,
    'bottom': LayerShell.Edge.BOTTOM,
} as const;

const LAYER = {
    'background': LayerShell.Layer.BACKGROUND,
    'bottom': LayerShell.Layer.BOTTOM,
    'top': LayerShell.Layer.TOP,
    'overlay': LayerShell.Layer.OVERLAY,
} as const;

const KEYMODE = {
    'on-demand': LayerShell.KeyboardMode.ON_DEMAND,
    'exclusive': LayerShell.KeyboardMode.EXCLUSIVE,
    'none': LayerShell.KeyboardMode.NONE,
} as const;

type Layer = keyof typeof LAYER;
type Anchor = keyof typeof ANCHOR;
type Exclusivity = 'normal' | 'ignore' | 'exclusive';
type Keymode = keyof typeof KEYMODE;

export type WindowProps<
    Child extends Gtk.Widget = Gtk.Widget,
    Attr = unknown,
    Self = Window<Child, Attr>,
> = BaseProps<Self, Gtk.Window.ConstructorProperties & {
    child?: Child
    anchor?: Anchor[]
    exclusivity?: Exclusivity
    layer?: Layer
    margins?: number[]
    monitor?: number
    gdkmonitor?: Gdk.Monitor
    visible?: boolean
    keymode?: Keymode
    transparent?: boolean
}, Attr>

export function newWindow<
    Child extends Gtk.Widget = Gtk.Widget,
    Attr = unknown
>(...props: ConstructorParameters<typeof Window<Child, Attr>>) {
    return new Window(...props);
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export interface Window<Child, Attr> extends Widget<Attr> { }
export class Window<Child extends Gtk.Widget, Attr> extends Gtk.Window {
    static {
        register(this, {
            properties: {
                'anchor': ['jsobject', 'rw'],
                'exclusive': ['boolean', 'rw'],
                'exclusivity': ['string', 'rw'],
                'focusable': ['boolean', 'rw'],
                'layer': ['string', 'rw'],
                'margins': ['jsobject', 'rw'],
                'monitor': ['int', 'rw'],
                'gdkmonitor': ['jsobject', 'rw'],
                'popup': ['boolean', 'rw'],
                'keymode': ['string', 'rw'],
                'transparent': ['boolean', 'r'],
            },
        });
    }

    // the window has to be set as a layer,
    // so we can't rely on gobject constructor
    constructor({
        anchor = [],
        exclusivity = 'normal',
        focusable = false,
        keymode = 'none',
        layer = 'top',
        margins = [],
        monitor = -1,
        gdkmonitor,
        visible = true,
        transparent = false,
        ...params
    }: WindowProps<Child, Attr> = {}, child?: Child) {
        if (child)
            params.child = child;

        super(params as Gtk.Window.ConstructorProperties);
        LayerShell.init_for_window(this);
        LayerShell.set_namespace(this, this.name);

        this._handleParamProp('anchor', anchor);
        this._handleParamProp('exclusivity', exclusivity);
        this._handleParamProp('focusable', focusable);
        this._handleParamProp('layer', layer);
        this._handleParamProp('margins', margins);
        this._handleParamProp('monitor', monitor);
        this._handleParamProp('gdkmonitor', gdkmonitor);
        this._handleParamProp('keymode', keymode);
        this._handleParamProp('visible', visible);

        if (transparent)
            Utils.idle(() => this.get_surface().set_input_region(new Cairo.Region));
    }

    get transparent() { return !!this._get('transparent'); }

    get child() { return super.child as Child; }
    set child(child: Child) { super.child = child; }

    get gdkmonitor(): Gdk.Monitor | null { return this._get('gdkmonitor') || null; }
    set gdkmonitor(monitor: Gdk.Monitor | null) {
        this._set('gdkmonitor', monitor);
        LayerShell.set_monitor(this, monitor);
        this.notify('gdkmonitor');
    }

    get monitor(): number { return this._get('monitor'); }
    set monitor(monitor: number) {
        if (monitor < 0)
            return;

        const m = Gdk.Display.get_default()?.get_monitors().get_item(monitor);
        if (m) {
            this.gdkmonitor = m as Gdk.Monitor;
            this._set('monitor', monitor);
            return;
        }

        console.error(`Could not find monitor with id: ${monitor}`);
    }

    get exclusivity(): Exclusivity {
        if (LayerShell.auto_exclusive_zone_is_enabled(this))
            return 'exclusive';

        if (LayerShell.get_exclusive_zone(this) === -1)
            return 'ignore';

        return 'normal';
    }

    set exclusivity(exclusivity: Exclusivity) {
        if (this.exclusivity === exclusivity)
            return;

        switch (exclusivity) {
            case 'normal':
                LayerShell.set_exclusive_zone(this, 0);
                break;

            case 'ignore':
                LayerShell.set_exclusive_zone(this, -1);
                break;

            case 'exclusive':
                LayerShell.auto_exclusive_zone_enable(this);
                break;

            default:
                console.error(Error('wrong value for exclusivity'));
                break;
        }

        this.notify('exclusivity');
    }

    get layer() {
        return Object.keys(LAYER).find(layer => {
            return LAYER[layer as Layer] === LayerShell.get_layer(this);
        }) as Layer;
    }

    set layer(layer: Layer) {
        if (this.layer === layer)
            return;

        if (!Object.keys(LAYER).includes(layer)) {
            console.error('wrong layer value for Window');
            return;
        }

        LayerShell.set_layer(this, LAYER[layer]);
        this.notify('layer');
    }

    get anchor() {
        return Object.keys(ANCHOR).filter(key => {
            return LayerShell.get_anchor(this, ANCHOR[key as Anchor]);
        }) as Anchor[];
    }

    set anchor(anchor: Anchor[]) {
        if (this.anchor.length === anchor.length &&
            this.anchor.every(a => anchor.includes(a)))
            return;

        // reset
        Object.values(ANCHOR).forEach(side => LayerShell.set_anchor(this, side, false));

        anchor.forEach(side => {
            if (!Object.keys(ANCHOR).includes(side))
                return console.error(`${side} is not a valid anchor`);

            LayerShell.set_anchor(this, ANCHOR[side], true);
        });

        this.notify('anchor');
    }

    get margins() {
        return ['TOP', 'RIGHT', 'BOTTOM', 'LEFT'].map(edge =>
            LayerShell.get_margin(this, LayerShell.Edge[edge]),
        );
    }

    set margins(margin: number[]) {
        let margins: [side: string, index: number][] = [];
        switch (margin.length) {
            case 1:
                margins = [['TOP', 0], ['RIGHT', 0], ['BOTTOM', 0], ['LEFT', 0]];
                break;
            case 2:
                margins = [['TOP', 0], ['RIGHT', 1], ['BOTTOM', 0], ['LEFT', 1]];
                break;
            case 3:
                margins = [['TOP', 0], ['RIGHT', 1], ['BOTTOM', 2], ['LEFT', 1]];
                break;
            case 4:
                margins = [['TOP', 0], ['RIGHT', 1], ['BOTTOM', 2], ['LEFT', 3]];
                break;
            default:
                break;
        }

        margins.forEach(([side, i]) =>
            LayerShell.set_margin(this,
                LayerShell.Edge[side], (margin as number[])[i]),
        );

        this.notify('margins');
    }

    get keymode() {
        return Object.keys(KEYMODE).find(layer => {
            return KEYMODE[layer as Keymode] === LayerShell.get_keyboard_mode(this);
        }) as Keymode;
    }

    set keymode(mode: Keymode) {
        if (this.keymode === mode)
            return;

        LayerShell.set_keyboard_mode(this, KEYMODE[mode]);
        this.notify('keymode');
    }
}
