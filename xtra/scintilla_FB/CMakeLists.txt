# for FireBreath library... this is:
# firebreath-dev/src/libs/scintilla/CMakeLists.txt
# (mkdir firebreath-dev/src/libs/scintilla)

#/**********************************************************\
#Original Author: Richard Bateman (taxilian)
#
#Created:    Nov 20, 2009
#License:    Dual license model; choose one of two:
#            New BSD License
#            http://www.opensource.org/licenses/bsd-license.php
#            - or -
#            GNU Lesser General Public License, version 2.1
#            http://www.gnu.org/licenses/lgpl-2.1.html
#
#Copyright 2009 PacketPass, Inc and the Firebreath development team
#\**********************************************************/

# sdaau 2011 - modded for scintilla
# only linux for now, no if (WIN32)
# tested on cmake version 2.8.3

# Written to work with cmake 2.6
cmake_minimum_required (VERSION 2.6)
set (CMAKE_BACKWARDS_COMPATIBILITY 2.6)
set (CMAKE_VERBOSE_MAKEFILE on)

# "with firebreath this target could get added mutliple times; protect against this"
project(scintilla)

get_target_property(library_target_exists scintilla TYPE)
if (library_target_exists)
    set(TARGET_ALREADY_EXISTS 1)
else()
    set(TARGET_ALREADY_EXISTS 0)
endif()


# message should be "src/libs/scintilla/" ..
# ${PROJECT_NAME} here is scintilla
# but NOTE: old cmake does NOT have CMAKE_CURRENT_LIST_DIR;
# so it needs to be manually set - to ABS. PATH!
# set(CMAKE_CURRENT_LIST_DIR ./src/libs/scintilla) # rel path no work for old cmake!
# abs path should work for old cmake:
#set(CMAKE_CURRENT_LIST_DIR /path/to/firebreath-dev/src/libs/scintilla) 

message("Scintilla: ${PROJECT_NAME} ${CMAKE_CURRENT_LIST_DIR}")
#~ include("${CMAKE_CURRENT_LIST_DIR}/FindScintilla") # no work, neither plain FindScintilla
include("${CMAKE_CURRENT_LIST_DIR}/FindScintilla.cmake")

# both variants are there:
message("Scintilla: ${SCINTILLA_LIBRARY} ${SCINTILLA_INCLUDE_DIR}")
message("Scintilla: ${SCINTILLA_LIBRARIES} ${SCINTILLA_INCLUDE_DIRS}")

if (SCINTILLA_FOUND)
    list(APPEND FBLIB_INCLUDE_DIRECTORIES
        ${SCINTILLA_INCLUDE_DIR}
        )
    list(APPEND FBLIB_LIBRARIES
        ${SCINTILLA_LIBRARIES}
        )
    if (WIN32)
    endif()
else()
    if (NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/scintilla)
        find_program(HG hg DOC "location of the hg executable")
        if (HG)
            message("Scintilla: running ${HG} ...")
            execute_process(
                COMMAND ${HG}
                clone http://scintilla.hg.sourceforge.net:8000/hgroot/scintilla/scintilla scintilla
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
        else()
            message("error ${HG} to get the scintilla libs. "
                "Please get them from http://scintilla.hg.sourceforge.net/hgweb/scintilla/scintilla "
                "and put them in ${CMAKE_CURRENT_SOURCE_DIR}/scintilla/" FATAL)
        endif()
    endif()
    if (NOT SCINTILLA_LIB_FOUND)
        # note - the finding of scintilla.a will only work if it is built beforehand
        # so to not let the first time fail, must set the variable explicitly here
        message("NOT SCINTILLA_LIB_FOUND !!!! Have to manually set varaible... ")
        SET(SCINTILLA_LIBRARY ${CMAKE_CURRENT_SOURCE_DIR}/scintilla/bin/scintilla.a)
    endif()
    # was lib/libcurl.lib:
    # use from FindScintilla:
    ## append_firebreath_link_library(${CMAKE_CURRENT_SOURCE_DIR}/scintilla/bin/scintilla.a)
    #~ append_firebreath_link_library(${SCINTILLA_LIBRARY})
    ## append_firebreath_include_dir(${CMAKE_CURRENT_SOURCE_DIR}/scintilla/include)
    #~ append_firebreath_include_dir(${SCINTILLA_INCLUDE_DIR})
#    add_firebreath_definition(-DSCINTILLA_STATICLIB)
else()
    message("Could not find Scintilla libraries!  Please install scintilla libraries and try again!" FATAL)
endif()

# as in jsoncpp/CMakeLists.txt? need to manually specify sources..
# try custom make
if (NOT TARGET_ALREADY_EXISTS)
    #~ add_library (scintilla STATIC ${SOURCES})
    # ADD_CUSTOM_TARGET - Add a target with no output so it will always be built.
    #~ ADD_CUSTOM_TARGET(
      #~ scintilla ALL
      #~ COMMAND ${CMAKE_MAKE_PROGRAM}
      #~ WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/scintilla/gtk
      #~ COMMENT "Original scintilla makefile target" )

    #~ ADD_CUSTOM_COMMAND(
      #~ OUTPUT scintilla.a
      #~ COMMAND ${CMAKE_MAKE_PROGRAM}
      #~ WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/scintilla/gtk
      #~ COMMENT "Original scintilla makefile target" )

    #~ ADD_CUSTOM_TARGET(scintilla STATIC DEPENDS scintilla.a) # Target "scintilla" of type UTILITY may not be linked into another target.
    #~ ADD_LIBRARY(scintilla STATIC DEPENDS scintilla.a) # Cannot find source file "DEPENDS".
    #~ ADD_LIBRARY(scintilla STATIC) # You have called ADD_LIBRARY for library scintilla without any source files.
    #~ ADD_DEPENDENCIES(scintilla scintilla.a) # Error: add_dependencies Adding dependency to non-existent target: scintilla
    #~ ADD_DEPENDENCIES(all scintilla.a) # non-existent target: all

    # just add_custom_target shows in firebreath-dev/Makefile after ./prepmake.sh
    # to build debug scintilla have to call `DEBUG=1 make`; note the possibility below;
    #  though its probably easier to do it manually..
    ADD_CUSTOM_TARGET(
      scintilla.a ALL
#      ${SCINTILLA_LIBRARY} ALL
      COMMAND ${CMAKE_MAKE_PROGRAM}
#      COMMAND DEBUG=1 ${CMAKE_MAKE_PROGRAM}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/scintilla/gtk
      COMMENT "Original scintilla makefile target"
#      VERBATIM
      )

    # ADD_CUSTOM_TARGET(${SCINTILLA_LIBRARY} : Error: Target names may not contain a slash.  Use ADD_CUSTOM_COMMAND to generate files.


    #~ set_target_properties(scintilla PROPERTIES FOLDER "Libraries")
endif()

if (FIREBREATH)
    # append_ as in jsoncpp/CMakeLists.txt:
    #~ append_firebreath_link_library(scintilla) # NO: /usr/bin/ld: cannot find -lscintilla
    append_firebreath_link_library(${SCINTILLA_LIBRARY})
    append_firebreath_include_dir(${SCINTILLA_INCLUDE_DIR})
    export_project_dependencies()
endif()
