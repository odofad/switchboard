/*
* Copyright (c) 2011-2017 elementary LLC (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA.
*
* Authored by: Avi Romanoff <aviromanoff@gmail.com>
*/

namespace Switchboard {

    public class CategoryView : Gtk.Box {
        private Gtk.SearchEntry search_box;

        public PlugsSearch plug_search { get; construct; }
        public Gee.ArrayList<SearchEntry?> plug_search_result { get; construct; }
        public Switchboard.Category personal_category { get; construct; }
        public Switchboard.Category hardware_category { get; construct; }
        public Switchboard.Category network_category { get; construct; }
        public Switchboard.Category system_category { get; construct; }

        public string? plug_to_open { get; construct set; default = null; }

        private Gtk.Stack stack;
        private Granite.Placeholder alert_view;

        construct {
            var search_box_eventcontrollerkey = new Gtk.EventControllerKey ();

            search_box = new Gtk.SearchEntry () {
                margin_top = 12,
                margin_end = 12,
                margin_bottom = 12,
                margin_start = 12,
                placeholder_text = _("Search Settings")
            };
            search_box.add_controller (search_box_eventcontrollerkey);

            var search_clamp = new Adw.Clamp () {
                child = search_box,
                maximum_size = 800,
                tightening_threshold = 800
            };

            var searchview = new SearchView (search_box);

            alert_view = new Granite.Placeholder ("");

            personal_category = new Switchboard.Category (Switchboard.Plug.Category.PERSONAL);
            hardware_category = new Switchboard.Category (Switchboard.Plug.Category.HARDWARE);
            network_category = new Switchboard.Category (Switchboard.Plug.Category.NETWORK);
            system_category = new Switchboard.Category (Switchboard.Plug.Category.SYSTEM);

            plug_search = new PlugsSearch ();
            plug_search_result = new Gee.ArrayList<SearchEntry?> ();

            var category_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24) {
                margin_top = 12,
                margin_end = 12,
                margin_bottom = 12,
                margin_start = 12,
                vexpand = true
            };
            category_box.append (personal_category);
            category_box.append (hardware_category);
            category_box.append (network_category);
            category_box.append (system_category);

            var category_scrolled = new Gtk.ScrolledWindow () {
                child = category_box,
                hscrollbar_policy = Gtk.PolicyType.NEVER
            };

            stack = new Gtk.Stack ();
            stack.add_child (alert_view);
            stack.add_named (category_scrolled, "category-grid");

            var clamp = new Adw.Clamp () {
                child = stack,
                maximum_size = 800,
                tightening_threshold = 800
            };

            var search_stack = new Gtk.Stack () {
                transition_type = CROSSFADE
            };
            search_stack.add_child (clamp);
            search_stack.add_child (searchview);

            orientation = VERTICAL;
            append (search_clamp);
            append (search_stack);

            if (Switchboard.PlugsManager.get_default ().has_plugs () == false) {
                show_alert (_("No Settings Found"), _("Install some and re-launch Switchboard."), "dialog-warning");
            } else {
                search_box.sensitive = true;
            }

            search_box.search_changed.connect (() => {
                if (search_box.text.length > 0) {
                    search_stack.visible_child = searchview;
                } else {
                    search_stack.visible_child = clamp;
                }
            });

            search_box.activate.connect (() => {
                searchview.activate_first_item ();
            });

            search_box_eventcontrollerkey.key_released.connect ((keyval, keycode, state) => {
                switch (keyval) {
                    case Gdk.Key.Down:
                        search_box.move_focus (Gtk.DirectionType.TAB_FORWARD);
                        break;
                    case Gdk.Key.Escape:
                        search_box.text = "";
                        break;
                    default:
                        break;
                }
            });

            var eventcontrollerkey = new Gtk.EventControllerKey ();
            eventcontrollerkey.key_pressed.connect (() => {
                eventcontrollerkey.forward (search_box.get_delegate ());
                return Gdk.EVENT_PROPAGATE;
            });

            add_controller (eventcontrollerkey);
        }

        public CategoryView (string? plug = null) {
            Object (plug_to_open: plug);
        }

        public void show_alert (string primary_text, string secondary_text, string icon_name) {
            alert_view.title = primary_text;
            alert_view.description = secondary_text;
            alert_view.icon = new ThemedIcon (icon_name);

            stack.visible_child = alert_view;
        }

        public async void load_default_plugs () {
            var plugsmanager = Switchboard.PlugsManager.get_default ();
            plugsmanager.plug_added.connect ((plug) => {
                add_plug (plug);
            });

            Idle.add (() => {
                foreach (var plug in plugsmanager.get_plugs ()) {
                    add_plug (plug);
                }

                return false;
            });
        }

        public void add_plug (Switchboard.Plug plug) {
            var icon = new Switchboard.CategoryIcon (plug);

            switch (plug.category) {
                case Switchboard.Plug.Category.PERSONAL:
                    personal_category.add (icon);
                    break;
                case Switchboard.Plug.Category.HARDWARE:
                    hardware_category.add (icon);
                    break;
                case Switchboard.Plug.Category.NETWORK:
                    network_category.add (icon);
                    break;
                case Switchboard.Plug.Category.SYSTEM:
                    system_category.add (icon);
                    break;
                default:
                    return;
            }

            var any_found = false;

            if (personal_category.has_child ()) {
                any_found = true;
            }

            if (hardware_category.has_child ()) {
                any_found = true;
            }

            if (network_category.has_child ()) {
                any_found = true;
            }

            if (system_category.has_child ()) {
                any_found = true;
            }

            if (any_found) {
                stack.visible_child_name = "category-grid";
            }

            if (plug_to_open != null && plug_to_open.has_suffix (plug.code_name)) {
                unowned var app = (SwitchboardApp) GLib.Application.get_default ();
                app.load_plug (plug);
                plug_to_open = null;
            }
        }

        public static string? get_category_name (Switchboard.Plug.Category category) {
            switch (category) {
                case Plug.Category.PERSONAL:
                    return _("Personal");
                case Plug.Category.HARDWARE:
                    return _("Hardware");
                case Plug.Category.NETWORK:
                    return _("Network & Wireless");
                case Plug.Category.SYSTEM:
                    return _("Administration");
            }

            return null;
        }
    }
}
