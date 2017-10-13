/**********************************************************\
Original Author: Richard Bateman and Georg Fritzsche

Created:    December 3, 2009
License:    Dual license model; choose one of two:
            New BSD License
            http://www.opensource.org/licenses/bsd-license.php
            - or -
            GNU Lesser General Public License, version 2.1
            http://www.gnu.org/licenses/lgpl-2.1.html

Copyright 2009 Georg Fritzsche,
               Firebreath development team
\**********************************************************/

// sdaau, Oct 2011
// linux only - importing scintilla

#ifndef H_MSCINTILLA
#define H_MSCINTILLA

#include <boost/shared_ptr.hpp>
#include <stdexcept>
#include <string>
#include <iostream> // for cout; the one in SciMozFBAPI.h doesn't propagate to MScintillaX11.cpp!

// these copied from Scintilla.h
#ifdef MAXULONG_PTR
typedef ULONG_PTR uptr_t;
typedef LONG_PTR sptr_t;
#else
typedef unsigned long uptr_t;
typedef long sptr_t;
#endif


namespace FB { class PluginWindow; };
struct ScintillaContext; // originally: PlayerContext
typedef boost::shared_ptr<ScintillaContext> ScintillaContextPtr;

class MScintilla
{
public:
    struct InitializationException : std::runtime_error {
        InitializationException(const char* const what) : std::runtime_error(what) {}
    };

    MScintilla();
    ~MScintilla();

    const std::string& version() const;
    const std::string& type() const;
    const std::string& lastError() const;

    //bool play(const std::string& file);
    //bool stop();

    void setWindow(FB::PluginWindow*);
    void MSciSendMessage(unsigned int iMessage, uptr_t wParam, sptr_t lParam);
    void MSciSendMessage(unsigned int iMessage, int wParam, int lParam);
    int MSciSendMessage(unsigned int iMessage);

private:
    boost::shared_ptr<ScintillaContext> m_context;
    std::string m_version;
    const std::string m_type;
};

#endif

