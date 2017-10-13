/**********************************************************\

  Auto-generated SciMozFBAPI.h

\**********************************************************/

// sdaau, Oct 2011
// linux only - importing scintilla

#include <string>
#include <sstream>
//#include <boost/weak_ptr.hpp>
#include <boost/shared_ptr.hpp>
#include "JSAPIAuto.h"
#include "BrowserHost.h"
#include "JSObject.h"
#include "SciMozFB.h"
#include "MScintilla.h" //added


#include <iostream> // for cout
#include <stdio.h> // for printf

#ifndef H_SciMozFBAPI
#define H_SciMozFBAPI

#define BREAKPOINT() asm("   int $3");


//namespace FB { class PluginWindow; };
class MScintilla;

class SciMozFBAPI : public FB::JSAPIAuto
{
public:
    //SciMozFBAPI(const SciMozFBPtr& plugin, const FB::BrowserHostPtr& host);
    SciMozFBAPI(FB::BrowserHostPtr host);
    virtual ~SciMozFBAPI();

    SciMozFBPtr getPlugin();

    // Read/Write property ${PROPERTY.ident}
    std::string get_testString();
    void set_testString(const std::string& val);

    // Read-only property ${PROPERTY.ident}
    std::string get_version();

    // Method echo
    FB::variant echo(const FB::variant& msg);

    // Event helpers
    FB_JSAPI_EVENT(fired, 3, (const FB::variant&, bool, int));
    FB_JSAPI_EVENT(echo, 2, (const FB::variant&, const int));
    FB_JSAPI_EVENT(notify, 0, ());

    // Method test-event
    void testEvent(const FB::variant& s);

    // added
    void setWindow(FB::PluginWindow* win);

    // added - no interface? Not without registerMethod in .cpp!
    //~ void SciSendMessage(unsigned int iMessage, uptr_t wParam, sptr_t lParam);
    void SciSendMessageIS(const FB::variant& iMessage, const FB::variant& wParam, const FB::variant& lParam);
    void SciSendMessageII(const FB::variant& iMessage, const FB::variant& wParam, const FB::variant& lParam);
    int iSciSendMessage(const FB::variant& iMessage);
    std::string sSciSendMessageI(const FB::variant& iMessage, const FB::variant& wParam);

private:
    typedef boost::shared_ptr<MScintilla> MScintillaPtr;

    //SciMozFBWeakPtr m_plugin;
    FB::BrowserHostPtr m_host;
    MScintillaPtr m_scintilla;

    std::string m_testString;
};

#endif // H_SciMozFBAPI

