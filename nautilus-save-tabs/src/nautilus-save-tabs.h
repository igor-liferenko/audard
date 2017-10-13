/*
 *  nautilus-save-tabs.h
 * 
 *  Copyright (C) 2004, 2005 Free Software Foundation, Inc.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public
 *  License along with this library; if not, write to the Free
 *  Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 *  Author: Christian Neumair <chris@gnome-de.org>
 * 
 */

#ifndef NAUTILUS_SAVE_TABS_H
#define NAUTILUS_SAVE_TABS_H

#include <glib-object.h>

G_BEGIN_DECLS

/* Declarations for the open terminal extension object.  This object will be
 * instantiated by nautilus.  It implements the GInterfaces 
 * exported by libnautilus. */


#define NAUTILUS_TYPE_SAVE_TABS	  (nautilus_save_tabs_get_type ())
#define NAUTILUS_SAVE_TABS(o)	  (G_TYPE_CHECK_INSTANCE_CAST ((o), NAUTILUS_TYPE_SAVE_TABS, NautilusSaveTabs))
#define NAUTILUS_IS_SAVE_TABS(o)	  (G_TYPE_CHECK_INSTANCE_TYPE ((o), NAUTILUS_TYPE_SAVE_TABS))
typedef struct _NautilusSaveTabs      NautilusSaveTabs;
typedef struct _NautilusSaveTabsClass NautilusSaveTabsClass;

struct _NautilusSaveTabs {
	GObject parent_slot;
};

struct _NautilusSaveTabsClass {
	GObjectClass parent_slot;
};

GType nautilus_save_tabs_get_type      (void);
void  nautilus_save_tabs_register_type (GTypeModule *module);

G_END_DECLS

#endif
