/*
* Copyright (c) 2019-2020 Alecaddd (https://alecaddd.com)
*
* This file is part of Akira.
*
* Akira is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.

* Akira is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.

* You should have received a copy of the GNU General Public License
* along with Akira. If not, see <https://www.gnu.org/licenses/>.
*
* Authored by: Giacomo Alberini <giacomoalbe@gmail.com>
* Authored by: Alessandro "Alecaddd" Castellani <castellani.ale@gmail.com>
*/

public enum Akira.Lib.Models.CanvasItemType {
    RECT,
    ELLIPSE,
    TEXT,
    IMAGE,
    ARTBOARD
}

public interface Akira.Lib.Models.CanvasItem : Goo.CanvasItemSimple, Goo.CanvasItem {
    // Identifiers.
    public static int global_id = 0;
    public abstract Models.CanvasItemType item_type { get; set; }
    public abstract string id { get; set; }
    public abstract string name { get; set; }

    // Transform Panel attributes.
    public abstract double opacity { get; set; }
    public abstract double rotation { get; set; }

    // Fill Panel attributes.
    // If FALSE, don't add a FillItem to the ListModel
    public abstract bool has_fill { get; set; default = true; }
    public abstract int fill_alpha { get; set; }
    public abstract Gdk.RGBA color { get; set; }
    public abstract bool hidden_fill { get; set; default = false; }

    // Border Panel attributes.
    // If FALSE, don't add a BorderItem to the ListModel
    public abstract bool has_border { get; set; default = true; }
    public abstract int border_size { get; set; }
    public abstract Gdk.RGBA border_color { get; set; }
    public abstract int stroke_alpha { get; set; }
    public abstract bool hidden_border { get; set; default = false; }

    // Style Panel attributes.
    public abstract bool size_locked { get; set; default = false; }
    public abstract double size_ratio { get; set; default = 1.0; }
    public abstract bool flipped_h { get; set; default = false; }
    public abstract bool flipped_v { get; set; default = false; }
    public abstract bool show_border_radius_panel { get; set; default = false; }
    public abstract bool show_fill_panel { get; set; default = false; }
    public abstract bool show_border_panel { get; set; default = false; }

    // Layers panel attributes.
    public abstract bool selected { get; set; }
    public abstract bool locked { get; set; default = false; }
    public abstract string layer_icon { get; set; }
    public abstract int z_index { get; set; }

    public abstract Akira.Lib.Canvas canvas { get; set; }
    public abstract Models.CanvasArtboard? artboard { get; set; }

    public abstract double relative_x { get; set; }
    public abstract double relative_y { get; set; }

    public abstract double initial_relative_x { get; set; }
    public abstract double initial_relative_y { get; set; }

    public double get_coords (string coord_id) {
        double _coord = 0.0;

        get (coord_id, out _coord);

        return _coord;
    }

    public virtual void set_visible (bool visible) {
        this.visibility = visible
            ? Goo.CanvasItemVisibility.VISIBLE
            : Goo.CanvasItemVisibility.INVISIBLE;
    }

    public void delete () {
        if (artboard != null) {
            artboard.remove_item (this);
            return;
        }

        remove ();
    }

    public static string create_item_id (Models.CanvasItem item) {
        string[] type_slug_tokens = item.item_type.to_string ().split ("_");
        string type_slug = type_slug_tokens[type_slug_tokens.length - 1];

        return "%s %d".printf (capitalize (type_slug.down ()), global_id++);
    }

    public static string capitalize (string s) {
        string back = s;
        if (s.get_char (0).islower ()) {
            back = s.get_char (0).toupper ().to_string () + s.substring (1);
        }

        return back;
    }

    public static void init_item (Goo.CanvasItem item) {
        item.set ("opacity", 100.0);
        item.set ("fill-alpha", 255);
        item.set ("stroke-alpha", 255);

        update_z_index (item);

        var canvas_item = item as Models.CanvasItem;

        // Populate the name with the item's id
        // to show it when added to the LayersPanel
        canvas_item.name = canvas_item.id;

        if (canvas_item.artboard != null) {
            canvas_item.notify.connect (() => {
                canvas_item.artboard.changed (true);
            });
        }
    }

    public static void update_z_index (Goo.CanvasItem item) {
        //var z_index = (item as Models.CanvasItem).canvas.get_root_item ().find_child (item);

        //item.set ("z-index", z_index);
    }

    public virtual void position_item (double _x, double _y) {
        if (artboard != null) {
            artboard.add_child (this, -1);

            double item_x_from_artboard = _x;
            double item_y_from_artboard = _y;

            canvas.convert_to_item_space (artboard, ref item_x_from_artboard, ref item_y_from_artboard);

            relative_x = item_x_from_artboard;
            relative_y = item_y_from_artboard;
        } else {
            parent.add_child (this, -1);


            // Keep the item always in the origin
            // move the entire coordinate system every time
            translate (_x, _y);
        }
    }

    public virtual void move (
        double delta_x, double delta_y,
        double delta_x_accumulator = 0.0, double delta_y_accumulator = 0.0) {

        if (artboard != null) {
            var transformed_delta_x = delta_x_accumulator;
            var transformed_delta_y = delta_y_accumulator;

            this.relative_x = this.initial_relative_x + transformed_delta_x;
            this.relative_y = this.initial_relative_y + transformed_delta_y;


            return;
        }

        this.translate (delta_x, delta_y);
    }

    public virtual Cairo.Matrix get_real_transform () {
        Cairo.Matrix transform = Cairo.Matrix.identity ();

        if (artboard == null) {
            get_transform (out transform);
        } else {
            artboard.get_transform (out transform);

            transform = compute_transform (transform);
        }

        return transform;
    }

    public virtual Cairo.Matrix compute_transform (Cairo.Matrix transform) {
        transform.translate (relative_x, relative_y);

        var width = get_coords ("width");
        var height = get_coords ("height");

        // Rotate around the center by the amount
        // in item.rotation
        transform.translate (width / 2, height / 2);
        transform.rotate (Utils.AffineTransform.deg_to_rad (rotation));
        transform.translate (- (width / 2), - (height / 2));

        return transform;
    }

    public virtual double get_real_coord (string coord_id) {
        var offset_x = artboard == null ? 0 : relative_x;
        var offset_y = artboard == null ? 0 : relative_y;

        var item_x = get_coords ("x") - offset_x;
        var item_y = get_coords ("y") - offset_y;

        switch (coord_id) {
            case "x":
                return item_x;
            case "y":
                return item_y;
            default:
                return 0.0;
        }
    }

    public virtual void store_relative_position () {
        this.initial_relative_x = this.relative_x;
        this.initial_relative_y = this.relative_y;
    }

    public virtual void reset_colors () {
        reset_fill ();
        reset_border ();
    }

    private void reset_fill () {
        if (hidden_fill || !has_fill) {
            set ("fill-color-rgba", null);
            return;
        }

        var rgba_fill = Gdk.RGBA ();
        rgba_fill = color;
        // debug (fill_alpha.to_string ());
        rgba_fill.alpha = ((double) fill_alpha) / 255 * opacity / 100;
        // debug (rgba_fill.alpha.to_string ());

        uint fill_color_rgba = Utils.Color.rgba_to_uint (rgba_fill);
        set ("fill-color-rgba", fill_color_rgba);
    }

    private void reset_border () {
        // Set a default border color in case no border is used
        // to avoid half pixel transparency during export.
        if (hidden_border || !has_border) {
            set ("stroke-color-rgba", fill_color_rgba);
            set ("line-width", 0.0);
            return;
        }

        var rgba_stroke = Gdk.RGBA ();
        rgba_stroke = border_color;
        rgba_stroke.alpha = ((double) stroke_alpha) / 255 * opacity / 100;

        uint stroke_color_rgba = Utils.Color.rgba_to_uint (rgba_stroke);
        set ("stroke-color-rgba", stroke_color_rgba);
        set ("line-width", (double) border_size);
    }

    public bool simple_is_item_at (double x, double y, Cairo.Context cr, bool is_pointer_event) {
        var width = get_coords ("width");
        var height = get_coords ("height");

        var item_x = relative_x;
        var item_y = relative_y;

        canvas.convert_from_item_space (
            artboard,
            ref item_x,
            ref item_y
            );

        if (
            x >= item_x
            && x <= item_x + width
            && y >= item_y
            && y <= item_y + height
           ) {
            return true;
        }

        return false;
    }
}
