# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-Studio-CLA-applies
#
# ResolveDownloadTls.cmake - make CMake file(DOWNLOAD) work on Windows builds.
#
# CMake uses libcurl for file(DOWNLOAD). A CMake installation that was not built
# against the Windows certificate store (for example the MSYS2/MinGW cmake.exe
# that is commonly placed in C:\mingw64\bin) does not know where to load the CA
# certificates from. The first HTTPS dependency download then fails with:
#
#   SSL peer certificate or SSH remote key was not OK.  If this is due to https
#   certificate verification failure, one may set environment variable
#   CMAKE_TLS_VERIFY=0 to suppress it.
#
# This module resolves the same two variables that file(DOWNLOAD) consults:
#   CMAKE_TLS_VERIFY   - whether TLS certificates are verified
#   CMAKE_TLS_CAINFO   - path to a CA bundle that is used for verification
#
# Resolution order (first match wins):
#   1. CMAKE_TLS_CAINFO / CMAKE_TLS_VERIFY already defined (e.g. passed with -D)
#   2. the same names passed through the environment
#   3. an automatically detected CA bundle shipped with Git for Windows / MSYS2
#
# The environment names are kept exactly as CMake suggests in its error message,
# so a user can bypass the problem with:
#   set CMAKE_TLS_VERIFY=OFF
# or, preferably, point at a real bundle:
#   set CMAKE_TLS_CAINFO=C:\Program Files\Git\mingw64\etc\ssl\certs\ca-bundle.crt
#
# This helper must be included before any file(DOWNLOAD) call (before SoundFont
# / extdeps resolution) for it to affect the very first download.

# Env values are only consulted when CMake was not given an explicit -D value.
set(_muse_tls_verify_env "")
if(DEFINED ENV{CMAKE_TLS_VERIFY})
    set(_muse_tls_verify_env "$ENV{CMAKE_TLS_VERIFY}")
endif()
set(_muse_tls_cainfo_env "")
if(DEFINED ENV{CMAKE_TLS_CAINFO})
    set(_muse_tls_cainfo_env "$ENV{CMAKE_TLS_CAINFO}")
endif()

# If the user provided a CA bundle through -D, keep it. Else take the
# environment value, else auto-detect a bundle that usually exists when
# Git for Windows or MSYS2 is installed.
if(NOT DEFINED CMAKE_TLS_CAINFO OR NOT CMAKE_TLS_CAINFO)
    if(NOT _muse_tls_cainfo_env STREQUAL "")
        set(CMAKE_TLS_CAINFO "${_muse_tls_cainfo_env}")
    else()
        set(_muse_tls_cainfo_candidates
            "C:/Program Files/Git/mingw64/etc/ssl/certs/ca-bundle.crt"
            "C:/Program Files/Git/mingw64/ssl/certs/ca-bundle.crt"
            "C:/Program Files/Git/mingw64/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"
            "C:/Program Files/Git/usr/ssl/certs/ca-bundle.crt"
            "C:/Program Files/Git/etc/ssl/certs/ca-bundle.crt"
            "C:/Program Files (x86)/Git/mingw64/etc/ssl/certs/ca-bundle.crt"
            "C:/Program Files (x86)/Git/mingw64/ssl/certs/ca-bundle.crt"
            "C:/Program Files (x86)/Git/usr/ssl/certs/ca-bundle.crt"
            "$ENV{UserProfile}/.curl-ca-bundle.crt"
            "$ENV{USERPROFILE}/.curl-ca-bundle.crt"
            "C:/mingw64/etc/ssl/certs/ca-bundle.crt"
            "C:/mingw64/ssl/certs/ca-bundle.crt"
            "C:/msys64/mingw64/etc/ssl/certs/ca-bundle.crt"
            "C:/Windows/System32/curl-ca-bundle.crt"
            "C:/Windows/curl-ca-bundle.crt"
        )
        foreach(_muse_candidate IN LISTS _muse_tls_cainfo_candidates)
            if(_muse_candidate AND EXISTS "${_muse_candidate}")
                set(CMAKE_TLS_CAINFO "${_muse_candidate}")
                break()
            endif()
        endforeach()
    endif()
endif()

# TLS verification settings. file(DOWNLOAD) only checks these variables, so a
# normal top-level set() is enough (no CACHE needed).
if(NOT DEFINED CMAKE_TLS_VERIFY)
    if(NOT _muse_tls_verify_env STREQUAL "")
        set(CMAKE_TLS_VERIFY "${_muse_tls_verify_env}")
    else()
        set(CMAKE_TLS_VERIFY ON)
    endif()
endif()

# Report what was resolved, without a long warning on every normal build.
if(CMAKE_TLS_CAINFO)
    if(EXISTS "${CMAKE_TLS_CAINFO}")
        message(STATUS "[tls] CMake HTTPS downloads will use CA bundle: ${CMAKE_TLS_CAINFO}")
    else()
        message(WARNING "[tls] CMAKE_TLS_CAINFO does not exist: ${CMAKE_TLS_CAINFO}")
    endif()
else()
    message(STATUS "[tls] CMake HTTPS downloads: no explicit CA bundle (using CMake default)")
endif()

if(NOT CMAKE_TLS_VERIFY)
    message(WARNING "[tls] CMake HTTPS download certificate verification is DISABLED")
else()
    message(STATUS "[tls] CMake HTTPS download certificate verification: ${CMAKE_TLS_VERIFY}")
endif()
