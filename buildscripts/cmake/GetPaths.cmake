# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-Studio-CLA-applies
#
# MuseScore Studio
# Music Composition & Notation
#
# Copyright (C) 2026 MuseScore Limited and others
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# WORKAROUND / OVERRIDE of muse/buildscripts/cmake/GetPaths.cmake
#
# This file shadows the muse_framework module of the same name: the MuseScore
# top-level CMakeLists.txt puts "<repo>/buildscripts/cmake" before
# "<muse>/buildscripts/cmake" in CMAKE_MODULE_PATH, so every `include(GetPaths)`
# performed anywhere in the build tree (including inside the muse_framework
# sources, e.g. muse/framework/diagnostics/CMakeLists.txt) resolves to this file.
#
# Why it exists:
# The pinned muse_framework submodule defines INSTALL_BIN_DIR as an ABSOLUTE path
# (${CMAKE_INSTALL_PREFIX}/${INSTALL_SUBDIR}) and installs the crashpad handler to
# it. CPack (WIX, Windows packaging) refuses absolute install destinations:
#   CMake Error at .../muse/framework/diagnostics/cmake_install.cmake:47 (message):
#     ABSOLUTE path INSTALL DESTINATION forbidden (by caller):
#     .../build.install/bin/crashpad_handler.exe
# Upstream muse_framework fixed this by installing to a relative destination.
#
# Setting INSTALL_BIN_DIR in the top-level CMakeLists.txt is NOT enough, because
# muse/framework/diagnostics/CMakeLists.txt calls `include(GetPaths)` itself right
# before the install() command, which re-set the variable back to the absolute
# path. Overriding the module itself is therefore the only reliable fix without
# bumping/patching the submodule.
#
# Variables provided:
#   INSTALL_SUBDIR      - install dir relative to CMAKE_INSTALL_PREFIX (unchanged)
#   INSTALL_BIN_DIR     - destination to be used in install() commands.
#                         Relative (== INSTALL_SUBDIR) so CPack accepts it.
#   INSTALL_BIN_DIR_ABS - absolute path, for consumers that need a real filesystem
#                         path (e.g. passing a binary path to tests).

include(GetPlatformInfo)

if (OS_IS_MAC)
    set(INSTALL_SUBDIR mscore.app/Contents/MacOS/)
else()
    set(INSTALL_SUBDIR bin)
endif()

set(INSTALL_BIN_DIR_ABS ${CMAKE_INSTALL_PREFIX}/${INSTALL_SUBDIR})

# Use a relative destination everywhere: install() interprets it relative to
# CMAKE_INSTALL_PREFIX (same result as before), and CPack no longer errors out.
set(INSTALL_BIN_DIR ${INSTALL_SUBDIR})
