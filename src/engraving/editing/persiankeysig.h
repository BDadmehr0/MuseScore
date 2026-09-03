/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2026 MuseScore Limited and others
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma once

#include <functional>
#include <map>
#include <string>
#include <vector>

namespace mu::engraving {
class Note;
class Score;
class MasterScore;

// Defined in dom/key.h - forward declared here so that this header can be
// included from targets outside the engraving module (which do not have the
// engraving source directories on their include path). KeySigEvent is only
// used as a function parameter/return type below, which is allowed for an
// incomplete type; callers that construct or inspect one must include
// "engraving/dom/keysig.h" (or "engraving/dom/key.h") themselves.
class KeySigEvent;

//---------------------------------------------------------
//   Persian key signatures (charghah / چارگاه)
//
// A Persian key is a predefined pattern of accidental
// variants (flat / koron / sori / sharp) applied to note
// letters. Letters not present in the pattern are natural.
//
// Examples (from the Persian tuner project spec):
//   - "Do Koron": La koron + Re koron   (A koron, D koron)
//   - "Fa":       Si flat, Re koron, Sol koron
//---------------------------------------------------------

/// A single entry of a Persian key signature pattern.
struct PersianKeySigNote {
    std::string letter;  // "C" .. "B"
    std::string variant; // "flat" | "koron" | "sori" | "sharp" (never "natural")
};

/// A predefined Persian key signature (charghah).
struct PersianKeySig {
    std::string id;      // e.g. "do-koron"
    std::string nameFa;  // Persian name (UTF-8), e.g. "چارگاه دو کرن"
    std::string nameEn;  // Latin name, e.g. "Do Koron"
    std::vector<PersianKeySigNote> notes;
};

//! Predefined Persian key signatures.
const std::vector<PersianKeySig>& predefinedPersianKeySigs();

//! Look up a predefined Persian key signature by id (nullptr when unknown).
const PersianKeySig* persianKeySigById(const std::string& id);

//! True for patterns kept only to resolve ids saved by older versions
//! (they duplicate one of the canonical patterns and are hidden from the
//! palette and the panels).
bool isLegacyPersianKeySigId(const std::string& id);

//! True when \a variant is one of the known accidental variants
//! ("flat", "koron", "natural", "sori", "sharp").
bool isValidPersianVariant(const std::string& variant);

//! Default target cents (relative to the natural of the letter) for a variant:
//! flat -100, koron -50, natural 0, sori +50, sharp +100.
double defaultPersianVariantCents(const std::string& variant);

//! Build a custom KeySigEvent for an arbitrary letter->variant mapping so
//! that it can be used as a real (drag-and-drop) key signature on the staff.
//! The base key is C; only the altered letters get a CustDef entry
//! (natural letters stay implicit). Koron / sori / flat / sharp symbols are
//! used for the corresponding variants.
KeySigEvent persianKeySigToKeySigEvent(const std::vector<PersianKeySigNote>& mapping);

//! Convenience overload for the predefined patterns.
KeySigEvent persianKeySigToKeySigEvent(const PersianKeySig& keySig);

//! Build a mapping from a custom key signature (selected in the UI): letters
//! with variant "natural" (or absent) stay natural. Returns an empty vector
//! when \\a mapping is null.
std::vector<PersianKeySigNote> persianKeySigNotesFromMapping(const std::map<std::string, std::string>& mapping);

//! True when \\a event is a custom key signature whose symbols are all
//! Persian-compatible accidentals (flat, sharp, koron or sori) - i.e. a
//! Persian (quarter-tone) key, as opposed to an atonal / empty key.
bool isPersianKeySigEvent(const KeySigEvent& event);

//! Mapping (letter -> variant) of a custom Persian key signature event.
//! Returns an empty vector for non-Persian events.
std::vector<PersianKeySigNote> persianKeySigNotesFromEvent(const KeySigEvent& event);

//! Return the predefined Persian key signature whose custom KeySigEvent
//! matches \a event (by its CustDef list), or nullptr when \a event does not
//! correspond to any predefined Persian key.
const PersianKeySig* persianKeySigFromKeySigEvent(const KeySigEvent& event);

class EditPersianKeySig
{
public:
    /// Assign \a variant to a single note:
    ///  - ensures the note carries the matching accidental element
    ///    (FLAT / SHARP / SORI / KORON; an explicit NATURAL only when the
    ///    surrounding key/measure state is not natural),
    ///  - sets the note tuning (Pid::TUNING, cents) so that the note plays
    ///    at \a targetCents relative to the natural of its letter.
    ///
    /// Requires an open transaction.
    static void applyNoteVariant(Note* note, const std::string& variant, double targetCents);

    /// Apply a Persian key signature to the whole score: every note gets
    /// the variant of its letter from \a mapping; notes of letters not in
    /// \a mapping are reset to natural.
    ///
    /// \p centsFor returns the target cents for a letter/variant pair
    /// (may be null; then the default variant cents are used).
    /// Requires an open transaction.
    /// Returns the number of notes that were changed.
    static int applyScoreKeySig(Score* score, const std::vector<PersianKeySigNote>& mapping, const std::function<double(const std::string&,
                                                                                                                        const std::string&)>& centsFor = nullptr);

    /// Write \a mapping as the (custom Persian) key signature at the start of
    /// every staff of \a masterScore, then respell/retune the notes so the key
    /// also plays correctly. An empty mapping restores a plain C key signature
    /// (no signs) and resets the notes to natural.
    /// Requires an open transaction.
    /// Returns the number of notes that were changed by the retuning.
    static int applyKeySigToStaves(MasterScore* masterScore, const std::vector<PersianKeySigNote>& mapping,
                                   const std::function<double(const std::string&, const std::string&)>& centsFor = nullptr);
};
} // namespace mu::engraving
