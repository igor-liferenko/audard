/**********************************************************\

  Auto-generated SciMozFBAPI.cpp

\**********************************************************/

// sdaau, Oct 2011
// linux only - importing scintilla

#include "JSObject.h"
#include <boost/assign.hpp> // added
#include "SciMozFBAPI.h" //moved up
//~ #include "MScintilla.h" //added - moved to .h, due scintilla typedefs
#include "DOM/Window.h" //added
#include "variant_list.h"
#include "DOM/Document.h"
#include "global/config.h"



///////////////////////////////////////////////////////////////////////////////
/// @fn SciMozFBAPI::SciMozFBAPI(const SciMozFBPtr& plugin, const FB::BrowserHostPtr host)
///
/// @brief  Constructor for your JSAPI object.  You should register your methods, properties, and events
///         that should be accessible to Javascript from here.
///
/// @see FB::JSAPIAuto::registerMethod
/// @see FB::JSAPIAuto::registerProperty
/// @see FB::JSAPIAuto::registerEvent
///////////////////////////////////////////////////////////////////////////////
//SciMozFBAPI::SciMozFBAPI(const SciMozFBPtr& plugin, const FB::BrowserHostPtr& host) : m_plugin(plugin), m_host(host)
SciMozFBAPI::SciMozFBAPI(FB::BrowserHostPtr host)
  : m_host(host)
  , m_scintilla()
{
    //~ using FB::make_method;   // copied from orig src, no need?
    //~ using FB::make_property; // copied, no need?

    registerMethod("echo",      make_method(this, &SciMozFBAPI::echo));
    registerMethod("testEvent", make_method(this, &SciMozFBAPI::testEvent));
    registerMethod("SciSendMessageIS", make_method(this, &SciMozFBAPI::SciSendMessageIS));
    registerMethod("SciSendMessageII", make_method(this, &SciMozFBAPI::SciSendMessageII));
    registerMethod("iSciSendMessage", make_method(this, &SciMozFBAPI::iSciSendMessage));
    registerMethod("sSciSendMessageI", make_method(this, &SciMozFBAPI::sSciSendMessageI));

    // Read-write property
    registerProperty("testString",
                     make_property(this,
                        &SciMozFBAPI::get_testString,
                        &SciMozFBAPI::set_testString));

    // Read-only property
    registerProperty("version",
                     make_property(this,
                        &SciMozFBAPI::get_version));

    try
    {
        m_scintilla  = MScintillaPtr(new MScintilla);

    }
    catch(const MScintilla::InitializationException&)
    {
        m_host->htmlLog("failed to initialize m_scintilla");
    }
    std::cout << "SciMozFBAPI::SciMozFBAPI: m_host " << m_host << " m_scintilla " << m_scintilla << " host " << host << std::endl;
}

///////////////////////////////////////////////////////////////////////////////
/// @fn SciMozFBAPI::~SciMozFBAPI()
///
/// @brief  Destructor.  Remember that this object will not be released until
///         the browser is done with it; this will almost definitely be after
///         the plugin is released.
///////////////////////////////////////////////////////////////////////////////
SciMozFBAPI::~SciMozFBAPI()
{
    // m_scintilla.reset();
}

///////////////////////////////////////////////////////////////////////////////
/// @fn SciMozFBPtr SciMozFBAPI::getPlugin()
///
/// @brief  Gets a reference to the plugin that was passed in when the object
///         was created.  If the plugin has already been released then this
///         will throw a FB::script_error that will be translated into a
///         javascript exception in the page.
///////////////////////////////////////////////////////////////////////////////
SciMozFBPtr SciMozFBAPI::getPlugin()
{
    //SciMozFBPtr plugin(m_plugin.lock());
    //if (!plugin) {
    //    throw FB::script_error("The plugin is invalid");
    //}
    //return plugin;
}



// Read/Write property testString
std::string SciMozFBAPI::get_testString()
{
    return m_testString;
}
void SciMozFBAPI::set_testString(const std::string& val)
{
    m_testString = val;
}

// Read-only property version
std::string SciMozFBAPI::get_version()
{
    return FBSTRING_PLUGIN_VERSION;
}

// Method echo
FB::variant SciMozFBAPI::echo(const FB::variant& msg)
{
    static int n(0);
    fire_echo(msg, n++);
    return msg;
}

void SciMozFBAPI::testEvent(const FB::variant& var)
{
    fire_fired(var, true, 1);
}

// added
void SciMozFBAPI::setWindow(FB::PluginWindow* win)
{
    m_scintilla->setWindow(win); // was m_player in orig src
    std::cout << "SciMozFBAPI::setWindow: m_scintilla " << m_scintilla << " win " << win << std::endl;
}

// added
//~ void SciMozFBAPI::SciSendMessageIS(unsigned int iMessage, uptr_t wParam, sptr_t lParam)
// DONT FORGET FOR JS INTERFACE - registerMethod!!:
void SciMozFBAPI::SciSendMessageIS(const FB::variant& iMessage, const FB::variant& wParam, const FB::variant& lParam)
{

    //~ m_scintilla->SciSendMessageIS(iMessage, wParam, lParam); // was m_player in orig src
    // apparently, sending 0 as number from js is not good?
    // note for problem below:
    //  http://www.firebreath.org/display/documentation/class+FB+variant+convert_cast
    //  "Supported destination types include" .. so cannot just cast to anything..

    //unsigned int iM = iMessage.cast<unsigned int>(); // js: Error: uncaught exception: Could not convert from i to j
    unsigned int iM = (unsigned int)iMessage.cast<int>(); //OK !
    uptr_t wP = wParam.convert_cast<uptr_t>();
    //~ sptr_t lP = lParam.cast<sptr_t>(); // js: Error: uncaught exception: Could not convert from Ss to l
    //~ sptr_t lP = (sptr_t)lParam.cast<std::string>(); //error: invalid cast from type ‘const std::basic_string<char>’ to type ‘sptr_t’
    std::string lPss = lParam.cast<std::string>(); // has correct letters
    //~ sptr_t lP = reinterpret_cast<sptr_t>(lPss); // error: invalid cast from type ‘std::string’ to type ‘sptr_t’
    //~ sptr_t lP = reinterpret_cast<sptr_t>(&lPss); // works - but gives wrong letters
    std::string* lPssp = &lPss; // no need for this anymore, actually, but leave it.
    //~ sptr_t lPssp_t = (sptr_t)lPssp; // wrong letters (same as above anyway)
    sptr_t lPssp_t = (sptr_t)lPss.c_str(); // YESSSSSSS!!! this is it!

    m_scintilla->MSciSendMessage(iM, wP, lPssp_t); // was m_player in orig src

    // note: the compiler barfs at " iMessage " << iMessage ; for const FB::variant& iMessage
    std::cout << "SciMozFBAPI::SciSendMessageIS: m_scintilla " << m_scintilla ; //<< " iMessage " << iMessage << std::endl;
    printf(" lP %s\n", lPss.c_str()); // note, this printf can NOT print addressof m_scintilla (only cout)!!?
}

//added
void SciMozFBAPI::SciSendMessageII(const FB::variant& iMessage, const FB::variant& wParam, const FB::variant& lParam)
{
    unsigned int iM = (unsigned int)iMessage.cast<int>(); //OK !
    //~ uptr_t wP = wParam.convert_cast<uptr_t>();
    //~ sptr_t lP = lParam.convert_cast<sptr_t>();
    // overloaded?
    int wP = wParam.cast<int>();
    int lP = lParam.cast<int>();

    m_scintilla->MSciSendMessage(iM, wP, lP);
    // no need to dump output here..
}

//added - for SCI_GETLENGTH: just send message ID, and accept int return, and give it back
int SciMozFBAPI::iSciSendMessage(const FB::variant& iMessage)
{
  unsigned int iM = (unsigned int)iMessage.cast<int>();
  int ret;
  ret = m_scintilla->MSciSendMessage(iM); // should overload
  return ret;
}

//added - for SCI_GETTEXT:
// writing in argument from js: lplugin.SciSendMessageIS(SCI_GETTEXT, textlen+1, textcontent); apparently cannot work
// so get string from api via argument, and then return it for javascript
// sSciSendMessageI Too many arguments, expected 1. ???
std::string SciMozFBAPI::sSciSendMessageI(const FB::variant& iMessage, const FB::variant& wParam)
{
  unsigned int iM = (unsigned int)iMessage.cast<int>();
  //BREAKPOINT();
  int wPi = wParam.cast<int>();
  uptr_t wP = wParam.convert_cast<uptr_t>();
  // std::string lPss = lParam.cast<std::string>();
  //~ std::string *lPssp = new std::string;
  //~ std::string lPss = *lPssp;
  //~ std::string lPss = new std::string; //error: conversion from ‘std::string*’ to non-scalar type ‘std::string’ requested
  //~ std::string lPss;

  //~ std::string *lPssp = new std::string;
  //~ std::string lPss = lPssp.cast<std::string>(); //error: request for member ‘cast’ in ‘lPssp’, which is of non-class type ‘std::string*’
  //~ sptr_t lPssp_t = (sptr_t)lPss.c_str();
  char* buffer = 0;
  buffer = new char[wPi + 1];
  //sptr_t lPssp_t = buffer.cast<sptr_t>(); // (sptr_t)buffer; // error: invalid conversion from ‘sptr_t’ to ‘const char*’

  m_scintilla->MSciSendMessage(iM, wP, (sptr_t)buffer); // should overload

  std::string lPss(buffer); // constructor - convert char* to std::string

  printf("SciMozFBAPI::sSciSendMessageI lP %s\n", lPss.c_str());

  return lPss;
}
