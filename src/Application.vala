/*
* Copyright 2011-2021 elementary, Inc. (https://elementary.io)
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
* Authored by: Avi Romanoff <avi@romanoff.me>
*/

namespace Switchboard {
    public class SwitchboardApp : Gtk.Application {
        private string all_settings_label = N_("All Settings");

        private GLib.HashTable <Gtk.Widget, Switchboard.Plug> plug_widgets;
        private Gtk.Button navigation_button;
        private Adw.Leaflet leaflet;
        private Gtk.HeaderBar headerbar;
        private Gtk.Window main_window;
        private Switchboard.CategoryView category_view;
        private Gtk.Label title_label;

        private static bool opened_directly = false;
        private static string? link = null;
        private static string? open_window = null;
        private static string? plug_to_open = null;

        construct {
            application_id = "io.elementary.settings";
            flags |= ApplicationFlags.HANDLES_OPEN;

            Environment.set_variable ("GTK_USE_PORTAL", "1", true);
            GLib.Intl.setlocale (LocaleCategory.ALL, "");
            GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
            GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
            GLib.Intl.textdomain (GETTEXT_PACKAGE);

            if (GLib.AppInfo.get_default_for_uri_scheme ("settings") == null) {
                var appinfo = new GLib.DesktopAppInfo (application_id + ".desktop");
                try {
                    appinfo.set_as_default_for_type ("x-scheme-handler/settings");
                } catch (Error e) {
                    critical ("Unable to set default for the settings scheme: %s", e.message);
                }
            }
        }

        public override void open (File[] files, string hint) {
            var file = files[0];
            if (file == null) {
                return;
            }

            if (file.get_uri_scheme () == "settings") {
                link = file.get_uri ().replace ("settings://", "");
                if (link.has_suffix ("/")) {
                    link = link.substring (0, link.last_index_of_char ('/'));
                }
            } else {
                critical ("Calling Switchboard directly is unsupported, please use the settings:// scheme instead");
            }

            activate ();
        }

        public override void startup () {
            base.startup ();

            Granite.init ();

            var granite_settings = Granite.Settings.get_default ();
            var gtk_settings = Gtk.Settings.get_default ();

            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

            granite_settings.notify["prefers-color-scheme"].connect (() => {
                gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            });

            var back_action = new SimpleAction ("back", null);
            var quit_action = new SimpleAction ("quit", null);

            add_action (back_action);
            add_action (quit_action);

            set_accels_for_action ("app.back", {"<Alt>Left", "Back"});
            set_accels_for_action ("app.quit", {"<Control>q"});

            back_action.activate.connect (action_navigate_back);
            quit_action.activate.connect (quit);
        }

        public override void activate () {
            var plugsmanager = Switchboard.PlugsManager.get_default ();
            if (link != null) {
                bool plug_found = load_setting_path (link, plugsmanager);

                if (plug_found) {
                    link = null;

                    // If plug_to_open was set from the command line
                    opened_directly = true;
                } else {
                    warning (_("Specified link '%s' does not exist, going back to the main panel").printf (link));
                }
            } else if (plug_to_open != null) {
                foreach (var plug in plugsmanager.get_plugs ()) {
                    if (plug_to_open.has_suffix (plug.code_name)) {
                        load_plug (plug);
                        plug_to_open = null;

                        // If plug_to_open was set from the command line
                        opened_directly = true;
                        break;
                    }
                }
            }

            // If app is already running, present the current window.
            if (get_windows ().length () > 0) {
                get_windows ().data.present ();
                return;
            }

            plug_widgets = new GLib.HashTable <Gtk.Widget, Switchboard.Plug> (null, null);

            navigation_button = new Gtk.Button.with_label (_(all_settings_label));
            navigation_button.action_name = "app.back";
            navigation_button.set_tooltip_markup (
                Granite.markup_accel_tooltip (get_accels_for_action (navigation_button.action_name))
            );
            navigation_button.get_style_context ().add_class ("back-button");

            title_label = new Gtk.Label ("");
            title_label.add_css_class (Granite.STYLE_CLASS_TITLE_LABEL);

            headerbar = new Gtk.HeaderBar () {
                show_title_buttons = true,
                title_widget = title_label
            };
            headerbar.pack_start (navigation_button);

            category_view = new Switchboard.CategoryView (plug_to_open);

            leaflet = new Adw.Leaflet () {
                can_navigate_back = true,
                can_navigate_forward = true,
                can_unfold = false
            };
            leaflet.append (category_view);

            main_window = new Gtk.Window () {
                application = this,
                child = leaflet,
                icon_name = application_id,
                title = _("System Settings"),
                titlebar = headerbar
            };
            add_window (main_window);
            main_window.present ();

            navigation_button.hide ();

            /*
            * This is very finicky. Bind size after present else set_titlebar gives us bad sizes
            * Set maximize after height/width else window is min size on unmaximize
            * Bind maximize as SET else get get bad sizes
            */
            var settings = new Settings ("io.elementary.settings");
            settings.bind ("window-height", main_window, "default-height", SettingsBindFlags.DEFAULT);
            settings.bind ("window-width", main_window, "default-width", SettingsBindFlags.DEFAULT);

            if (settings.get_boolean ("window-maximized")) {
                main_window.maximize ();
            }

            settings.bind ("window-maximized", main_window, "maximized", SettingsBindFlags.SET);

            main_window.bind_property ("title", title_label, "label");

            shutdown.connect (() => {
                if (plug_widgets[leaflet.visible_child] != null && plug_widgets[leaflet.visible_child] is Switchboard.Plug) {
                    plug_widgets[leaflet.visible_child].hidden ();
                }
            });

            leaflet.notify["visible-child"].connect (() => {
                update_navigation ();
            });

            leaflet.notify["child-transition-running"].connect (() => {
                update_navigation ();
            });
        }

        private void update_navigation () {
            if (!leaflet.child_transition_running) {
                if (plug_widgets[leaflet.get_adjacent_child (Adw.NavigationDirection.FORWARD)] != null) {
                    plug_widgets[leaflet.get_adjacent_child (Adw.NavigationDirection.FORWARD)].hidden ();
                }

                var previous_child = plug_widgets[leaflet.get_adjacent_child (Adw.NavigationDirection.BACK)];
                if (previous_child != null && previous_child is Switchboard.Plug) {
                    previous_child.hidden ();
                }

                var visible_widget = leaflet.visible_child;
                if (visible_widget is Switchboard.CategoryView) {
                    main_window.title = _("System Settings");

                    navigation_button.hide ();
                } else {
                    var plug = plug_widgets[visible_widget];
                    if (plug != null) {
                        plug.shown ();
                        main_window.title = plug.display_name;
                    } else {
                        critical ("Visible child is not CategoryView nor is associated with a Plug.");
                    }


                    if (previous_child != null && previous_child is Switchboard.Plug) {
                        navigation_button.label = previous_child.display_name;
                    } else {
                        navigation_button.label = _(all_settings_label);
                    }

                    navigation_button.show ();
                }
            }
        }

        public void load_plug (Switchboard.Plug plug) {
            if (leaflet.child_transition_running) {
                return;
            }

            Idle.add (() => {
                while (leaflet.get_adjacent_child (Adw.NavigationDirection.FORWARD) != null) {
                    leaflet.remove (leaflet.get_adjacent_child (Adw.NavigationDirection.FORWARD));
                }

                var plug_widget = plug.get_widget ();
                if (plug_widget.parent == null) {
                    leaflet.append (plug_widget);
                }

                if (plug_widgets[plug_widget] == null) {
                    plug_widgets[plug_widget] = plug;
                }

                category_view.plug_search_result.foreach ((entry) => {
                    if (plug.display_name == entry.plug_name) {
                        if (entry.open_window == null) {
                            plug.search_callback (""); // open default in the switch
                        } else {
                            plug.search_callback (entry.open_window);
                        }
                        debug ("open section:%s of plug: %s", entry.open_window, plug.display_name);
                        return true;
                    }

                    return false;
                });

                // open window was set by command line argument
                if (open_window != null) {
                    plug.search_callback (open_window);
                    open_window = null;
                }

                if (opened_directly) {
                    leaflet.mode_transition_duration = 0;
                    opened_directly = false;
                } else if (leaflet.mode_transition_duration == 0) {
                    leaflet.mode_transition_duration = 200;
                }

                leaflet.visible_child = plug.get_widget ();

                return false;
            }, GLib.Priority.DEFAULT_IDLE);
        }

        // Handles clicking the navigation button
        private void action_navigate_back () {
            if (leaflet.get_adjacent_child (Adw.NavigationDirection.BACK) == category_view) {
                opened_directly = false;
                leaflet.mode_transition_duration = 200;
            }

            leaflet.navigate (Adw.NavigationDirection.BACK);
        }

        // Try to find a supported plug, fallback paths like "foo/bar" to "foo"
        public bool load_setting_path (string setting_path, Switchboard.PlugsManager plugsmanager) {
            foreach (var plug in plugsmanager.get_plugs ()) {
                var supported_settings = plug.supported_settings;
                if (supported_settings == null) {
                    continue;
                }

                if (supported_settings.has_key (setting_path)) {
                    load_plug (plug);
                    open_window = supported_settings.get (setting_path);
                    return true;
                }
            }

            // Fallback to subpath
            if ("/" in setting_path) {
                int last_index = setting_path.last_index_of_char ('/');
                return load_setting_path (setting_path.substring (0, last_index), plugsmanager);
            }

            return false;
        }

        public static int main (string[] args) {
            var app = new SwitchboardApp ();
            return app.run (args);
        }
    }
}
