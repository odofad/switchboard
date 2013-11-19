// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2012-2013 Switchboard Developers (http://launchpad.net/switchboard)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <tintou@mailoo.org>
 */

public abstract class Switchboard.Plug : GLib.Object {
    
    /**
     * The localised name of the plug.
     */
    public string SEP { public get; private set; default = "<sep>"; }
    /**
     * The category under which the plug will be stored.
     * 
     * Possible {@link Category} values are PERSONAL, HARDWARE, NETWORK or SYSTEM.
     */
    public Category category { get; construct; }
    /**
     * The unique name representing the plug.
     * 
     * It is also used to recognise it with the open-plug command.
     * for example "system-pantheon-info" for the official Info plug of the pantheon desktop.
     */
    public string code_name { get; construct; }
    /**
     * The localised name of the plug.
     */
    public string display_name { get; construct; }
    /**
     * A short description of the plug.
     */
    public string description { get; construct; }
    /**
     * The icon representing the plug.
     */
    public string icon { get; construct; }
    
    public enum Category {
        PERSONAL = 0,
        HARDWARE = 1,
        NETWORK = 2,
        SYSTEM = 3,
        OTHER = 4
    }
    
    /**
     * Returns the widget that contain the whole interface.
     *
     * @return a {@link Gtk.Widget} containing the interface.
     */
    public abstract Gtk.Widget get_widget ();
    /**
     * Called when the plug appears to the user.
     */
    public virtual void shown () {
        
    }
    /**
     * Called when the plug disappear to the user.
     * 
     * This is not called when the plug got destroyed or the window is closed, use ~Plug () instead.
     */
    public virtual void hidden () {
        
    }
    /**
     * This function should return the widget that contain the whole interface.
     * 
     * When the user click on an action, the second parameter is send to the {@link search_callback} method
     * 
     * @param search a {@link string} that represent the search.
     * @return a {@link Gee.TreeMap} containing two strings like {"Keyboard → Behavior → Duration", "keyboard<sep>behavior"}.
     */
    public virtual async Gee.TreeMap<string, string> search (string search) {
        return new Gee.TreeMap<string, string> (null, null);
    }
    /**
     * This function is used when the user click on a search result, it should show the selected setting (right tab…).
     * 
     * @param location a {@link string} that represents the setting to show.
     */
    public virtual void search_callback (string location) {
        
    }
} 
