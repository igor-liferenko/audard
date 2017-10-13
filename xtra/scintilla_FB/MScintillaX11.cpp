/**********************************************************\
Original Author: Georg Fritzsche

Created:    September 20, 2010
License:    Dual license model; choose one of two:
            New BSD License
            http://www.opensource.org/licenses/bsd-license.php
            - or -
            GNU Lesser General Public License, version 2.1
            http://www.gnu.org/licenses/lgpl-2.1.html

Copyright 2010 Georg Fritzsche,
               Firebreath development team
\**********************************************************/

// sdaau, Oct 2011
// linux only - importing scintilla

#include <list>
#include <boost/assign/list_of.hpp>
#include "JSAPI.h"
//#include "Mac/PluginWindowMacCA.h"
#include "../MScintilla.h"

// now can do platform specific scintilla stuff?
//#ifdef FB_X11 // we should be here already...
#include "X11/PluginWindowX11.h"
//#endif
// actually, moving it to the MScintilla.h header (others may need it?);
// but since that is cross-platform.. aah, leave it

#include "Scintilla.h"
#include "SciLexer.h"
//~ #define PLAT_GTK 1
#define GTK
#include "ScintillaWidget.h"

// just a declaration? Naah.. #include "Editor.h"
//~ namespace Scintilla;
//~ #include "../src/Editor.h" // not a chance :)


struct ScintillaContext
{
    std::string error;

    // in mediaplayerwin, also: HWND hwnd;
    // CComPtr<IGraphBuilder> spGraph;

    ScintillaContext() {}
};

namespace
{
    ScintillaContextPtr make_context()
    {
        ScintillaContextPtr context(new ScintillaContext);
        // added from
        if(!context) throw MScintilla::InitializationException("failed to create context");
        // context->hwnd = hwnd; // context->spGraph.CoCreateInstance ..
        // ... context->spVideoWindow = spVideoWindow;

        std::cout << "MScintillaX11/make_context(): context " << context << std::endl;
        return context;
    }
}


// helper func, out of class
void printWidgetProps(GtkWidget *widget)
{
  GtkRequisition requisition;

      requisition = GtkRequisition(); // GTK3: gtk_requisition_new();
      gtk_widget_get_child_requisition(widget, &requisition); // segfault if requisition not instantiated!
      printf("widget get_child_requisition: w %d h %d\n", requisition.width, requisition.height); // default 0x0!
      gtk_widget_size_request(widget, &requisition);
      printf("widget size_request: w %d h %d\n", requisition.width, requisition.height); // default 1x1!

      printf("widget has_focus %d\n", gtk_widget_has_focus(widget));
      printf("widget get_app_paintable %d\n", gtk_widget_get_app_paintable(widget));
      printf("widget get_can_default %d\n", gtk_widget_get_can_default(widget));
      printf("widget get_can_focus %d\n", gtk_widget_get_can_focus(widget)); //1
      printf("widget get_double_buffered %d\n", gtk_widget_get_double_buffered(widget)); //1
      printf("widget has_default %d\n", gtk_widget_has_default(widget));
      printf("widget is_drawable %d\n", gtk_widget_is_drawable(widget));
      printf("widget has_focus %d\n", gtk_widget_has_focus(widget));
      printf("widget has_grab %d\n", gtk_widget_has_grab(widget));
      printf("widget get_mapped %d\n", gtk_widget_get_mapped(widget));
      printf("widget get_has_window %d\n", gtk_widget_get_has_window(widget)); //1
      printf("widget has_rc_style %d\n", gtk_widget_has_rc_style(widget));
      printf("widget get_realized %d\n", gtk_widget_get_realized(widget));
      printf("widget get_receives_default %d\n", gtk_widget_get_receives_default(widget));
      printf("widget get_sensitive %d\n", gtk_widget_get_sensitive(widget)); //1
      printf("widget is_sensitive %d\n", gtk_widget_is_sensitive(widget)); //1
      printf("widget is_toplevel %d\n", gtk_widget_is_toplevel(widget));
      printf("widget get_visible %d\n", gtk_widget_get_visible(widget));
}

MScintilla::MScintilla()
  : m_context()
  , m_version("")
  , m_type("X11")
{
    try
    {
        m_context = make_context();
    }
    catch(const InitializationException& e)
    {
        m_context = ScintillaContextPtr(new ScintillaContext);
        m_context->error = e.what();
        throw;
    }
    std::cout << "X11/MScintilla::MScintilla(): m_context " << m_context << std::endl;
}

MScintilla::~MScintilla()
{
    //stop(); // leftover from orig src
}

ScintillaObject *sci;

void MScintilla::setWindow(FB::PluginWindow* pluginWindow)
{
    // init scintilla
    GtkWidget *editor;
    //~ ScintillaObject *sci; // make "global", other funcs need it
    //FB::PluginWindowX11* wnd = reinterpret_cast<FB::PluginWindowX11*>(m_window);
    GtkWidget *m__container_w; // master is protected - local copy; (should be GtkContainer)
    GtkContainer *m__container; // for casting
    FB::PluginWindowX11* pwinx11; // for casting
    GtkWidget *childDrawAreaWidget; // for casting (should be GtkDrawingArea); note "cannot convert ‘GtkWidget*’ to ‘GtkDrawingArea*’ "
    GdkWindow *cdawWin; //for casting (should be GdkWindow)
    /* GtkWidget is the storage type for widgets */
    GtkWidget *fixed; //GtkFixed
    int32_t x, y;
    uint32_t w, h;
    GtkRequisition requisition;

    // NOTE: setWindow could kick in several times; sometimes it may be NULL! causing silent segfaults!!
    // so use these brackets all to the end..
    std::cout << "X11/MScintilla::setWindow(): pluginWindow " << pluginWindow << std::endl;
    if(pluginWindow) {

      pwinx11 = reinterpret_cast<FB::PluginWindowX11*>(pluginWindow);
      childDrawAreaWidget = pwinx11->getWidget(); //m_canvas
      // "The parent widget of this widget. Must be a gtk.Container widget."
      m__container_w = childDrawAreaWidget->parent;
      m__container = reinterpret_cast<GtkContainer*>(m__container_w);
      cdawWin = childDrawAreaWidget->window;

      editor = scintilla_new();
      sci = SCINTILLA(editor);

      // from bait.c: (replaced the define back)
      #define SSM(m, w, l) scintilla_send_message(sci, m, w, l)

      // the scintilla_send_messages *MUST* run at start to initialize;
      // else the widget is "empty" and it will continually segfault when shown!!
      scintilla_send_message(sci, SCI_STYLECLEARALL, 0, 0);

      scintilla_send_message(sci, SCI_SETWRAPMODE, SC_WRAP_WORD, 0);
      scintilla_send_message(sci, SCI_SETCODEPAGE, SC_CP_UTF8, 0); // start up in unicode...

      scintilla_send_message(sci, SCI_STYLESETFONT, STYLE_DEFAULT, (sptr_t)"monospace"); // monospace for default style
      scintilla_send_message(sci, SCI_STYLESETSIZE, STYLE_DEFAULT, 9); // X pt default style (bit too big ?!)
      scintilla_send_message(sci, SCI_STYLECLEARALL, 0, 0); // "Copies global style to all others"?
      scintilla_send_message(sci, SCI_SETMARGINTYPEN, 0, SC_MARGIN_NUMBER); // set margin 0 for line numbers (default)
      scintilla_send_message(sci, SCI_SETMARGINWIDTHN, 0, 40); // set margin 0 width (int margin, int pixelWidth)

      scintilla_send_message(sci, SCI_SETLEXER, SCLEX_CPP, 0);
      //~ scintilla_send_message(sci, SCI_SETKEYWORDS, 0, (sptr_t)"int char");
      scintilla_send_message(sci, SCI_STYLESETFORE, SCE_C_COMMENT, 0x008000);
      scintilla_send_message(sci, SCI_STYLESETFORE, SCE_C_COMMENTLINE, 0x008000);
      //~ scintilla_send_message(sci, SCI_STYLESETFORE, SCE_C_NUMBER, 0x808000);
      //~ scintilla_send_message(sci, SCI_STYLESETFORE, SCE_C_WORD, 0x800000);
      //~ scintilla_send_message(sci, SCI_STYLESETFORE, SCE_C_STRING, 0x800080);
      //~ scintilla_send_message(sci, SCI_STYLESETBOLD, SCE_C_OPERATOR, 1);

      scintilla_send_message(sci, SCI_INSERTTEXT, 0, (sptr_t)
      "int main(int argc, char **argv) {\n"
      "    // Start up the gnome\n"
      "    gnome_init(\"stest\", \"1.0\", argc, argv);\n}"
      );

      std::cout << "              ::setWindow(): pwinx11 " << pwinx11 << " childDrawAreaWidget " << childDrawAreaWidget << " m__container_w " << m__container_w << " m__container " << m__container << " cdawWin " << cdawWin << std::endl;

      pwinx11->getWindowPosition(x,y,w,h);
      printf("pwinx11 x %d, y %d, w %d, h %d\n", x, y, w, h); //ok

#if 0 // TRY1 - with fixed, etc
      // the PluginWindowX11 is setup as: m_container = gtk_plug_new; and its only child: m_canvas = gtk_drawing_area_new
      // m_container      --> m_canvas
      // plugGtkContainer --> GtkDrawingArea
      // http://stackoverflow.com/questions/4966623/add-and-locate-widgets-in-gtkdrawingarea
      // drawingarea cannot contain children, (there seems to be workaround with gtkFixed, but that's bad)
      // maybe instead: first create a new generic container, reparent childDrawAreaWidget to it, and reparent the new generic to m__container
      // but gtk.Container is base class; and others are HBox, Vbox for autolayout of widgets;
      // and here I'd like to put (overlay) scintilla on top of drawing area.. probably that's only possible with gtkfixed
      // [https://netfiles.uiuc.edu/rvmorale/www/gtk-faq-es/x639.html How do I reparent a widget?]
      // [http://www.gtk.org/tutorial1.2/gtk_tut-10.html GTK v1.2 Tutorial: Container Widgets]
      std::cout << "XX" << std::endl;
      fixed = gtk_fixed_new(); // silent segfault?
      ///gtk_container_add(GTK_CONTAINER(window), fixed);
      ///gtk_widget_show(fixed);
      std::cout << "a fixed " << fixed << std::endl;

      //* This packs the childDrawAreaWidget into the fixed containers window. * /
      //~ gtk_fixed_put (GTK_FIXED (fixed), childDrawAreaWidget, 0, 0); // maybe this messes up parenting?
      //* The final step is to display this (not) newly created widget. * /
      ///gtk_widget_show (childDrawAreaWidget);

      //gtk_widget_reparent (GtkWidget *widget, GtkWidget *new_parent)
      ///~ gtk_widget_reparent(childDrawAreaWidget, fixed); //Can't set a parent on widget which has a parent
      gtk_widget_ref(childDrawAreaWidget);

      gtk_container_remove(GTK_CONTAINER(m__container_w), childDrawAreaWidget);
      std::cout << "b" << std::endl;

      //~ gtk_container_add(GTK_CONTAINER(fixed), childDrawAreaWidget); //remove without add will segfault at end!
      gtk_fixed_put (GTK_FIXED (fixed), childDrawAreaWidget, 0, 0); // seems to be ok here?
      gtk_widget_unref(childDrawAreaWidget);
      std::cout << "              ::setWindow(): pwinx11 " << pwinx11 << " childDrawAreaWidget " << childDrawAreaWidget << " m__container_w " << m__container_w << " m__container " << m__container << " cdawWin " << cdawWin << std::endl;
      //
      //~ gtk_widget_reparent(fixed, m__container_w); //IA__gtk_widget_reparent: assertion `widget->parent != NULL' failed - if no parent, cannot reparent :)
      //~ gtk_container_add(m__container, fixed); // plain segfault

      //~ gtk_container_add(GTK_CONTAINER(m__container_w), fixed); // WAS: instance of invalid non-instantiatable type `(null)'; BUT gtk_fixed_put (instead of gtk_container_add *before* gtk_widget_unref helps)
      gtk_container_add(GTK_CONTAINER(m__container), fixed); // instance of invalid non-instantiatable
      //~ std::cout << "c" << std::endl;

      // try get size of editor
      printWidgetProps(editor);
      // got: widget get_child_requisition: w 0 h 0, widget size_request: w 1 h 1
      // try enforce a size:
      //~ gtk_widget_set_usize(editor, 500, 300); // works same as set_size_request
      gtk_widget_set_size_request(editor, 50, 50);
      gtk_widget_queue_draw_area(editor, 0,0, 50, 50);
      // try get size of editor again
      printWidgetProps(editor);
      // now both are 50x50



      ///~ gtk_fixed_put (GTK_FIXED (fixed), childDrawAreaWidget, 0, 0); //Can't set a parent on widget which has a parent - if container_add above! but if not: assertion `GTK_IS_WIDGET (widget)' failed .. NEEDS to be up, before the widget_unref!
      //~ std::cout << "d" << std::endl;
      gtk_fixed_put (GTK_FIXED (fixed), editor, 10, 10);
      //~ std::cout << "e" << std::endl;
      gtk_widget_show(GTK_WIDGET(fixed));
      gtk_widget_show(childDrawAreaWidget);
      //~ std::cout << "f" << std::endl;
      //~ std::cout << "g" << std::endl;
      //~ std::cout << "h" << std::endl;
      //~ gtk_widget_show(GTK_WIDGET(editor)); // when all up to here works, this causes a segfault on just editor :( but NOT on GTK_WIDGET(editor) if it is alone !!

      //~ gtk_widget_show_all(m__container_w); //segfault
      gtk_widget_grab_focus(GTK_WIDGET(editor));


      //~ gtk_container_add(GTK_CONTAINER( cdawWin ), editor); //invalid cast from `GdkWindow' to `GtkContainer'

      // so we must first remove the default draw area, to be able to add Scintilla instead
      /// m__container->remove(childDrawAreaWidget); //error: ‘struct GtkContainer’ has no member named ‘remove’
      //~ gtk_container_remove(GTK_CONTAINER( m__container ), childDrawAreaWidget); // passes
      //~ gtk_container_add(GTK_CONTAINER( m__container ), editor); // same as below; with gtk_container_remove raises no errors, however segfaults at end, and doesn't react on mouseclicks anymore
      /// gtk_container_add(GTK_CONTAINER( ((reinterpret_cast<FB::PluginWindowX11*>(pluginWindow))->getWidget())->parent ), editor); // builds fine, but Gtk-WARNING **: Attempting to add a widget with type Scintilla to a GtkPlug, but as a GtkBin subclass a GtkPlug can only contain one widget at a time; it already contains a widget of type GtkDrawingArea
      // "GtkPlug is a top level widget. This means that it may not be added as a child of another widget. Trying to do so will produce a Gtk-WARNING. As a subclass of GtkBin a window may only have one child. To add more widgets to a window first add a widget which can accept more than one child like a GtkHBox or a GtkVBox. Then add the other widgets to the child container. " http://gtk.php.net/manual/en/gtk.gtkwindow.php

      //~ gtk_container_add(GTK_CONTAINER((reinterpret_cast<FB::PluginWindowX11*>(pluginWindow))->m_container), editor); // error: ‘GtkWidget* FB::PluginWindowX11::m_container’ is protected
      //~ gtk_container_add(GTK_CONTAINER((reinterpret_cast<FB::PluginWindowX11*>(pluginWindow))->getWidget()), editor); // invalid cast from `GtkDrawingArea' to `GtkContainer'
      //~ gtk_container_add((reinterpret_cast<FB::PluginWindowX11*>(pluginWindow))->getWidget(), editor); // error: cannot convert ‘GtkWidget*’ to ‘GtkContainer*’
      //~ gtk_container_add(GTK_CONTAINER(pluginWindow->getWidget()), editor); //error: ‘class FB::PluginWindow’ has no member named ‘getWidget’
      //~ gtk_container_add(GTK_CONTAINER(reinterpret_cast<GtkContainer*>(pluginWindow)), editor); // builds fine, but same as below: GLib-GObject-WARNING **: invalid cast from `(null)' to `GtkContainer'
      //~ gtk_container_add(GTK_CONTAINER(pluginWindow), editor); // builds fine, but Gtk-CRITICAL **: IA__gtk_container_add: assertion `GTK_IS_CONTAINER (container)' failed
      /// gtk_container_add(m_window, editor); // error: cannot convert ‘FB::PluginWindow*’ to ‘GtkContainer*’
      // see firebreath-dev/src/PluginAuto/X11/PluginWindowX11.h for FB::PluginWindow*
      /// gtk_container_add(GTK_CONTAINER(m_window->getWindow()), editor); //  ‘class FB::PluginWindow’ has no member named ‘getWindow’
      /// gtk_container_add(GTK_CONTAINER(wnd->getWindow()), editor); // segfault

#endif


#if 1 // TRY2 - just scintilla replaces
      gtk_widget_set_size_request(editor, 50, 50);
      gtk_widget_queue_draw_area(editor, 0,0, 50, 50);

      gtk_container_remove(GTK_CONTAINER(m__container_w), childDrawAreaWidget);
      gtk_container_add(GTK_CONTAINER(m__container), editor);
      //~ editor->AllocateGraphics(); // GtkWidget’ has no member named ‘AllocateGraphics
      //~ (reinterpret_cast<Scintilla::Editor*>(editor))->AllocateGraphics(); // nope

      // for complains on childDrawAreaWidget: has no handler with id `251' (upon close)?
      // doesn't really work :(
        //~ gtk_signal_connect(GTK_OBJECT(m__container), "delete_event",
      //~ GTK_SIGNAL_FUNC(::~MScintilla()), 0); //was GTK_SIGNAL_FUNC(exit_app)

      gtk_widget_show(GTK_WIDGET(editor));
#endif
      scintilla_set_id(sci, 0);
      std::cout << "X11/MScintilla::setWindow() _____: editor " << editor << " sci " << sci << std::endl;
    } // end if pluginWindow null
}

const std::string& MScintilla::version() const
{
    return m_version;
}

const std::string& MScintilla::type() const
{
    return m_type;
}

const std::string& MScintilla::lastError() const
{
    return m_context->error;
}

void MScintilla::MSciSendMessage(unsigned int iMessage, uptr_t wParam, sptr_t lParam)
{
  scintilla_send_message(sci, iMessage, wParam, lParam);
}

// try overload
void MScintilla::MSciSendMessage(unsigned int iMessage, int wParam, int lParam)
{
  scintilla_send_message(sci, iMessage, wParam, lParam);
}

// try overload
int MScintilla::MSciSendMessage(unsigned int iMessage)
{
  return scintilla_send_message(sci, iMessage, 0, 0);
}


//~ bool MScintilla::play(const std::string& file_)
//~ {
    //~ return true;
//~ }

//~ bool MScintilla::stop()
//~ {
    //~ return true;
//~ }

