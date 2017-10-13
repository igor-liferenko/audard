/**********************************************************\

  Auto-generated SciMozFB.cpp

  This file contains the auto-generated main plugin object
  implementation for the Scintilla/Scite Mozilla FireBreath Plugin project

\**********************************************************/

// sdaau, Oct 2011
// linux only - importing scintilla

//#include <iostream> // for cout , moved to SciMozFBAPI.h
#include "SciMozFBAPI.h"
#include "SciMozFB.h"

// to trigger a breakpoint in gdb from the source file!
// (note, it can interrupt normal program run too!)
//~ #define BREAKPOINT() asm("   int $3"); // moved to API.h


// no need for this ?! //#include "X11/..." was commented?!
// actually, MUST be included, else: "error: ‘GtkWidget’ was not declared in this scope"
// but that is moved to MScintillaX11 now..
//~ #ifdef FB_X11
//~ #include "X11/PluginWindowX11.h"
//~ #endif
// but also, it included printf, used below - so manually adding stdio.h in SciMozFBAPI.h

// note: to check if these #include "Scintilla.h" are included correctly, check
// firebreath-dev/build/projects/SciMozFB/CMakeFiles/SciMozFB.dir/depend.internal
// should refer to:  ../src/libs/scintilla/scintilla/include/SciLexer.h
//#include "Scintilla.h"
//#include "SciLexer.h"
//~ #define PLAT_GTK 1
// for ScintillaWidget:
// 1) MUST define GTK here manually; else nothing from Widget is included !! (else: SCINTILLA was not declared in this scope)
// 2) MUST be placed after the "X11/PluginWindowX11.h" (else even if GTK defined: ‘GtkWidget’ does not name a type)
//#define GTK
//#include "ScintillaWidget.h"

/*
* Should follow the organization of BasicMediaPlayer example:
* there are auto-defaults:
BasicMediaPlayerPlugin.cpp  -> SciMozFB.cpp      (//#include "X11/PluginWindowX11.h")
BasicMediaPlayerPlugin.h    -> SciMozFB.h
BasicMediaPlayer.cpp        -> SciMozFBAPI.cpp
BasicMediaPlayer.h          -> SciMozFBAPI.h
*
* then, there is
MediaPlayer.h                     -> MScintilla.h (avoid naming conflicts)
* which interfaces further to platform-specific
Win/MediaPlayerWin.cpp            -> Win/MScintillaWin.cpp
Win/error_mapping.cpp
Win/error_mapping.h
Mac/BasicMediaPlayerPluginMac.h
Mac/BasicMediaPlayerPluginMac.mm
Mac/MediaPlayerMac.cpp            -> X11/MScintillaX11.cpp
* Win/MediaPlayerWin.cpp ; Mac/MediaPlayerMac.cpp #include "../MediaPlayer.h" "Win/PluginWindowWin.h"
* but apart from that, seems respective Win/Mac/projectDef.cmake build all files, simply
*/


///////////////////////////////////////////////////////////////////////////////
/// @fn SciMozFB::StaticInitialize()
///
/// @brief  Called from PluginFactory::globalPluginInitialize()
///
/// @see FB::FactoryBase::globalPluginInitialize
///////////////////////////////////////////////////////////////////////////////
void SciMozFB::StaticInitialize()
{
    // Place one-time initialization stuff here; As of FireBreath 1.4 this should only
    // be called once per process
}

///////////////////////////////////////////////////////////////////////////////
/// @fn SciMozFB::StaticInitialize()
///
/// @brief  Called from PluginFactory::globalPluginDeinitialize()
///
/// @see FB::FactoryBase::globalPluginDeinitialize
///////////////////////////////////////////////////////////////////////////////
void SciMozFB::StaticDeinitialize()
{
    // Place one-time deinitialization stuff here. As of FireBreath 1.4 this should
    // always be called just before the plugin library is unloaded
}

///////////////////////////////////////////////////////////////////////////////
/// @brief  SciMozFB constructor.  Note that your API is not available
///         at this point, nor the window.  For best results wait to use
///         the JSAPI object until the onPluginReady method is called
///////////////////////////////////////////////////////////////////////////////
SciMozFB::SciMozFB()
  : m_smfbapi()
  , m_window(0)
{
}

///////////////////////////////////////////////////////////////////////////////
/// @brief  SciMozFB destructor.
///////////////////////////////////////////////////////////////////////////////
SciMozFB::~SciMozFB()
{
    // This is optional, but if you reset m_api (the shared_ptr to your JSAPI
    // root object) and tell the host to free the retained JSAPI objects then
    // unless you are holding another shared_ptr reference to your JSAPI object
    // they will be released here.
    releaseRootJSAPI();
    m_host->freeRetainedObjects();
}

void SciMozFB::onPluginReady()
{
    // When this is called, the BrowserHost is attached, the JSAPI object is
    // created, and we are ready to interact with the page and such.  The
    // PluginWindow may or may not have already fire the AttachedEvent at
    // this point.

    // init scintilla
    //GtkWidget *editor;
    //ScintillaObject *sci;
    //FB::PluginWindowX11* wnd = reinterpret_cast<FB::PluginWindowX11*>(m_window);

    //editor = scintilla_new();
    //sci = SCINTILLA(editor);
    //gtk_container_add(GTK_CONTAINER(m_window), editor); // builds fine, but Gtk-CRITICAL **: IA__gtk_container_add: assertion `GTK_IS_CONTAINER (container)' failed
    /// gtk_container_add(m_window, editor); // error: cannot convert ‘FB::PluginWindow*’ to ‘GtkContainer*’
    // see firebreath-dev/src/PluginAuto/X11/PluginWindowX11.h for FB::PluginWindow*
    /// gtk_container_add(GTK_CONTAINER(m_window->getWindow()), editor); //  ‘class FB::PluginWindow’ has no member named ‘getWindow’
    /// gtk_container_add(GTK_CONTAINER(wnd->getWindow()), editor); // segfault
    //scintilla_set_id(sci, 0);
}

void SciMozFB::shutdown()
{
    // This will be called when it is time for the plugin to shut down;
    // any threads or anything else that may hold a shared_ptr to this
    // object should be released here so that this object can be safely
    // destroyed. This is the last point that shared_from_this and weak_ptr
    // references to this object will be valid
}

///////////////////////////////////////////////////////////////////////////////
/// @brief  Creates an instance of the JSAPI object that provides your main
///         Javascript interface.
///
/// Note that m_host is your BrowserHost and shared_ptr returns a
/// FB::PluginCorePtr, which can be used to provide a
/// boost::weak_ptr<SciMozFB> for your JSAPI class.
///
/// Be very careful where you hold a shared_ptr to your plugin class from,
/// as it could prevent your plugin class from getting destroyed properly.
///////////////////////////////////////////////////////////////////////////////
FB::JSAPIPtr SciMozFB::createJSAPI()
{
    // m_host is the BrowserHost
    // return boost::make_shared<SciMozFBAPI>(FB::ptr_cast<SciMozFB>(shared_from_this()), m_host);
    m_smfbapi = SciMozFBAPIPtr(new SciMozFBAPI(m_host));
    m_smfbapi->setWindow(m_window);
    // all these in the printf are pointers already, drop the & - also unsigned int
    // for %X:
    //  but (unsigned int)m_smfbapi - invalid cast from type ‘SciMozFB::SciMozFBAPIPtr’ to type ‘unsigned int’
    //  same for reinterpret_cast<unsigned int>(m_smfbapi)
    // so use %p - nope, still (void*)m_smfbapi invalid cast
    //~ printf("SciMozFB::createJSAPI: m_smfbapi %p, m_window %p, m_host %p", (void*)m_smfbapi, m_window, (void*)m_host);
    // `std::cout << m_smfbapi` should output address .. http://stackoverflow.com/questions/482757
    std::cout << "SciMozFB::createJSAPI: m_smfbapi " << m_smfbapi << " m_window " << m_window << " m_host " << m_host << std::endl;
    return m_smfbapi;
}

bool SciMozFB::onMouseDown(FB::MouseDownEvent *evt, FB::PluginWindow *)
{
    printf("Mouse down at: %d, %d\n", evt->m_x, evt->m_y);
    return false;
}

bool SciMozFB::onMouseUp(FB::MouseUpEvent *evt, FB::PluginWindow *)
{
    printf("Mouse up at: %d, %d\n", evt->m_x, evt->m_y);
    return false;
}

bool SciMozFB::onMouseMove(FB::MouseMoveEvent *evt, FB::PluginWindow *)
{
    //printf("Mouse move at: %d, %d\n", evt->m_x, evt->m_y);
    return false;
}

//add win as argument here manually!
bool SciMozFB::onWindowAttached(FB::AttachedEvent *evt, FB::PluginWindow *win)
{
    // The window is attached; act appropriately
    m_window = win;
    if(m_smfbapi)
        m_smfbapi->setWindow(win);
    std::cout << "SciMozFB::onWindowAttached: m_smfbapi " << m_smfbapi << " m_window " << m_window << std::endl;
    // NOTE: keep BREAKPOINT commented, unless you want to debug with gdb!
    // otherwise, it will break normal runs too (w "Program received signal SIGTRAP, Trace/breakpoint trap")
    //BREAKPOINT();
    return true; // default false;
}

//add win as argument here manually!
bool SciMozFB::onWindowDetached(FB::DetachedEvent *evt, FB::PluginWindow *win)
{
    // The window is about to be detached; act appropriately
    m_smfbapi->setWindow(NULL);
    std::cout << "SciMozFB::onWindowDetached: m_smfbapi " << m_smfbapi << std::endl;
    return true; // default false;
}

