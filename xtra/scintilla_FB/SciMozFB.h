/**********************************************************\

  Auto-generated SciMozFB.h

  This file contains the auto-generated main plugin object
  implementation for the Scintilla/Scite Mozilla FireBreath Plugin project

\**********************************************************/

// sdaau, Oct 2011
// linux only - importing scintilla

#ifndef H_SciMozFBPLUGIN
#define H_SciMozFBPLUGIN

#include "PluginWindow.h"
#include "PluginEvents/MouseEvents.h"
#include "PluginEvents/AttachedEvent.h"

#include "PluginCore.h"

class SciMozFBAPI;

FB_FORWARD_PTR(SciMozFB)
class SciMozFB : public FB::PluginCore
{
public:
    static void StaticInitialize();
    static void StaticDeinitialize();

public:
    SciMozFB();
    virtual ~SciMozFB();

public:
    void onPluginReady();
    void shutdown();
    virtual FB::JSAPIPtr createJSAPI();
    // If you want your plugin to always be windowless, set this to true
    // If you want your plugin to be optionally windowless based on the
    // value of the "windowless" param tag, remove this method or return
    // FB::PluginCore::isWindowless()
    virtual bool isWindowless() { return false; }

    BEGIN_PLUGIN_EVENT_MAP()
        EVENTTYPE_CASE(FB::MouseDownEvent, onMouseDown, FB::PluginWindow)
        EVENTTYPE_CASE(FB::MouseUpEvent, onMouseUp, FB::PluginWindow)
        EVENTTYPE_CASE(FB::MouseMoveEvent, onMouseMove, FB::PluginWindow)
        // EVENTTYPE_CASE(FB::MouseMoveEvent, onMouseMove, FB::PluginWindow) //duplicate from template?
        EVENTTYPE_CASE(FB::AttachedEvent, onWindowAttached, FB::PluginWindow)
        EVENTTYPE_CASE(FB::DetachedEvent, onWindowDetached, FB::PluginWindow)
    END_PLUGIN_EVENT_MAP()

    /** BEGIN EVENTDEF -- DON'T CHANGE THIS LINE **/
    virtual bool onMouseDown(FB::MouseDownEvent *evt, FB::PluginWindow *);
    virtual bool onMouseUp(FB::MouseUpEvent *evt, FB::PluginWindow *);
    virtual bool onMouseMove(FB::MouseMoveEvent *evt, FB::PluginWindow *);
    virtual bool onWindowAttached(FB::AttachedEvent *evt, FB::PluginWindow *);
    virtual bool onWindowDetached(FB::DetachedEvent *evt, FB::PluginWindow *);
    /** END EVENTDEF -- DON'T CHANGE THIS LINE **/

private:
    typedef boost::shared_ptr<SciMozFBAPI> SciMozFBAPIPtr;
    //return boost::make_shared<SciMozFBAPI>(FB::ptr_cast<SciMozFB>(shared_from_this()), m_host);

    SciMozFBAPIPtr m_smfbapi;
    FB::PluginWindow* m_window;
};


#endif

