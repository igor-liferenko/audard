# for FireBreath library... this is:
# firebreath-dev/src/libs/scintilla/FindScintilla.cmake
# (mkdir firebreath-dev/src/libs/scintilla)

# - Find curl
# Find the native SCINTILLA headers and libraries.
#
#  SCINTILLA_INCLUDE_DIRS - where to find curl/curl.h, etc.
#  SCINTILLA_LIBRARIES    - List of libraries when using curl.
#  SCINTILLA_FOUND        - True if curl found.

#=============================================================================
# Copyright 2006-2009 Kitware, Inc.
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================
# (To distribute this file outside of CMake, substitute the full
#  License text for the above reference.)

# sdaau 2011 - modded for scintilla

# Look for the header file.
# note - MUST add HINTS; else it doesn't look in CMAKE_CURRENT_LIST_DIR!
# also CMAKE_CURRENT_LIST_DIR:firebreath-dev/src/libs/scintilla; include: firebreath-dev/src/libs/scintilla/scintilla/include/Scintilla.h
# ALSO NOTE CACHING IN ./build/CMakeCache.txt;
#  should delete SCINTILLA_INCLUDE_DIR entry from there for update?
# -U <globbing_expr>          = Remove matching entries from CMake cache:
# -L[A][H]                    = List non-advanced cached variables.
# best simply to set it to SCINTILLA_INCLUDE_DIR-NOTFOUND
# cmake -LA # to see the advanced entries
# MUST BE IN THIS ORDER the cmdline options:
# (the command re-runs the build, but resets at first).
# cmake -D SCINTILLA_INCLUDE_DIR:PATH=SCINTILLA_INCLUDE_DIR-NOTFOUND ./build
# cmake -U SCINTILLA_INCLUDE_DIR ./build # works; starts from src/libs/scintilla though?! But needs ./prepmake.sh after
# And seemingly does not need 'PATH_SUFFIXES scintilla scintilla/include' if cache is reset?! (or maybe those are remembered somewhere..); but leave 'em
message("FindScintilla: ${CMAKE_CURRENT_LIST_DIR} ${SCINTILLA_INCLUDE_DIR}")
#~ FIND_PATH(SCINTILLA_INCLUDE_DIR NAMES scintilla/src/ScintillaBase.h HINTS ${CMAKE_CURRENT_LIST_DIR})
FIND_PATH(SCINTILLA_INCLUDE_DIR NAMES Scintilla.h PATHS ${CMAKE_CURRENT_LIST_DIR} PATH_SUFFIXES scintilla scintilla/include)
MARK_AS_ADVANCED(CLEAR SCINTILLA_INCLUDE_DIR)
message("FindScintilla: ${SCINTILLA_INCLUDE_DIR}")

message("FindScintilla L: ${SCINTILLA_LIBRARY}")
# Look for the library (libscintilla on linux? scintilla.a).
# NOTE: this works - but only if scintilla.a has been built in advance!
# so it will fail for very first time run... and so must set
#  explicitly the path to scintilla.a
#  leave this code - and upon fail, set in related CMakeLists.txt
FIND_LIBRARY(SCINTILLA_LIBRARY NAMES
  scintilla.a
  PATHS ${CMAKE_CURRENT_LIST_DIR}
  PATH_SUFFIXES scintilla scintilla/bin
)
MARK_AS_ADVANCED(SCINTILLA_LIBRARY)
message("FindScintilla L: ${SCINTILLA_LIBRARY}")


# handle the QUIETLY and REQUIRED arguments and set SCINTILLA_FOUND to TRUE if
# all listed variables are TRUE
# NOTE: 'tis in /usr/share/cmake-2.8/Modules/FindPackageHandleStandardArgs.cmake
#~ INCLUDE("${CMAKE_CURRENT_LIST_DIR}/FindPackageHandleStandardArgs.cmake")
# just INCLUDE(FindPackageHandleStandardArgs) works here:
# the _STANDARD_ARGS.. creates the SCINTILLA_FOUND var!
INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(SCINTILLA DEFAULT_MSG SCINTILLA_LIBRARY SCINTILLA_INCLUDE_DIR)
# create another variable only for lib_found
FIND_PACKAGE_HANDLE_STANDARD_ARGS(SCINTILLA_LIB DEFAULT_MSG SCINTILLA_LIBRARY)


IF(SCINTILLA_FOUND)
  SET(SCINTILLA_LIBRARIES ${SCINTILLA_LIBRARY})
  SET(SCINTILLA_INCLUDE_DIRS ${SCINTILLA_INCLUDE_DIR})
ENDIF(SCINTILLA_FOUND)
