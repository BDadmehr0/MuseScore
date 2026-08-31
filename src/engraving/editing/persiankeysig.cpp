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

#include "persiankeysig.h"

#include <algorithm>
#include <cmath>

#include "dom/accidental.h"
#include "dom/chord.h"
#include "dom/factory.h"
#include "dom/measure.h"
#include "dom/note.h"
#include "dom/pitchspelling.h"
#include "dom/score.h"
#include "dom/segment.h"
#include "dom/staff.h"

#include "editnote.h"

#include "log.h"

namespace mu::engraving {
namespace {
//---------------------------------------------------------
//   variantAccidentalType
//---------------------------------------------------------

AccidentalType variantAccidentalType(const std::string& variant)
{
    if (variant == "flat") {
        return AccidentalType::FLAT;
    }
    if (variant == "sharp") {
        return AccidentalType::SHARP;
    }
    if (variant == "sori") {
        return AccidentalType::SORI;
    }
    if (variant == "koron") {
        return AccidentalType::KORON;
    }
    return AccidentalType::NATURAL;
}

//---------------------------------------------------------
//   variantContribution
///    Cents (relative to the natural of the letter) that the
///    accidental element of \a variant contributes by itself
///    during playback: semitone value of the accidental plus
///    the microtonal cent offset stored in the symbol table
///    (sori +33, koron -67).
//---------------------------------------------------------

double variantContribution(const std::string& variant)
{
    if (variant == "flat") {
        return -100.0;
    }
    if (variant == "sharp") {
        return 100.0;
    }
    if (variant == "sori") {
        return Accidental::subtype2centOffset(AccidentalType::SORI);
    }
    if (variant == "koron") {
        return Accidental::subtype2centOffset(AccidentalType::KORON);
    }
    return 0.0;
}

//---------------------------------------------------------
//   ensureAccidentalElement
///    Make sure \a note carries an explicit \a type accidental
///    element, creating it when missing.
//---------------------------------------------------------

void ensureAccidentalElement(Score* score, Note* note, AccidentalType type)
{
    Accidental* acc = note->accidental();
    if (acc && acc->accidentalType() == type) {
        return;
    }
    if (acc) {
        return; // changeAccidental() has already handled the replacement
    }
    Accidental* acc1 = Factory::createAccidental(note);
    acc1->setParent(note);
    acc1->setAccidentalType(type);
    acc1->setRole(AccidentalRole::USER);
    score->undoAddElement(acc1);
}

//---------------------------------------------------------
//   noteNeedsNaturalSign
///    True when a natural sounding \a note still needs an
///    explicit natural sign to be correct on the page (the
///    key signature or earlier accidentals of the measure
///    alter its line).
//---------------------------------------------------------

bool noteNeedsNaturalSign(const Note* note)
{
    if (tpc2alter(note->tpc()) != AccidentalVal::NATURAL) {
        return true;
    }
    if (const Measure* m = note->findMeasure()) {
        return m->findAccidental(note) != AccidentalVal::NATURAL;
    }
    return false;
}

//---------------------------------------------------------
//   noteLetter
///    Note letter ("C" .. "B") from its TPC.
//---------------------------------------------------------

std::string noteLetter(int tpc)
{
    static const char* letters[] = { "F", "C", "G", "D", "A", "E", "B" };
    const int delta = tpc - 13;
    const int index = ((delta % 7) + 7) % 7;
    return letters[index];
}

//---------------------------------------------------------
//   noteVariant
///    Current accidental variant of \a note, as a Persian
///    variant id: from its explicit accidental element, or
///    from the TPC fifths (key signature) when it has none.
//---------------------------------------------------------

std::string noteVariant(const Note* note)
{
    const Accidental* acc = note->accidental();
    if (acc) {
        switch (acc->accidentalType()) {
        case AccidentalType::FLAT:
        case AccidentalType::FLAT2:
            return "flat";
        case AccidentalType::SHARP:
        case AccidentalType::SHARP2:
            return "sharp";
        case AccidentalType::SORI:
            return "sori";
        case AccidentalType::KORON:
            return "koron";
        case AccidentalType::NATURAL:
            return "natural";
        default:
            break;
        }
    }
    const int fifths = static_cast<int>(std::floor((note->tpc() - 13) / 7.0));
    if (fifths < 0) {
        return "flat";
    }
    if (fifths > 0) {
        return "sharp";
    }
    return "natural";
}
} // namespace

const std::vector<PersianKeySig>& predefinedPersianKeySigs()
{
    static const std::vector<PersianKeySig> kKeySigs = {
        // Rast: no accidentals (all notes natural)
        {
            "rast", "راست", "Rast",
            {}
        },
        // Do Koron: La koron + Re koron
        {
            "do-koron", "چارگاه دو کرن", "Do Koron",
            { { "A", "koron" }, { "D", "koron" } }
        },
        // Fa: Si flat, Re koron, Sol koron
        {
            "fa", "چارگاه فا", "Fa",
            { { "B", "flat" }, { "D", "koron" }, { "G", "koron" } }
        },
        // Segah: Re koron + Sol koron
        {
            "segah", "چارگاه سگاه", "Segah",
            { { "D", "koron" }, { "G", "koron" } }
        },
        // Homayun: La koron, Re koron, Sol koron
        {
            "homayun", "چارگاه همایون", "Homayun",
            { { "A", "koron" }, { "D", "koron" }, { "G", "koron" } }
        },
    };
    return kKeySigs;
}

const PersianKeySig* persianKeySigById(const std::string& id)
{
    const auto& keySigs = predefinedPersianKeySigs();
    for (const PersianKeySig& keySig : keySigs) {
        if (keySig.id == id) {
            return &keySig;
        }
    }
    return nullptr;
}

bool isValidPersianVariant(const std::string& variant)
{
    return variant == "flat" || variant == "koron" || variant == "natural" || variant == "sori" || variant == "sharp";
}

double defaultPersianVariantCents(const std::string& variant)
{
    if (variant == "flat") {
        return -100.0;
    }
    if (variant == "koron") {
        return -50.0;
    }
    if (variant == "sori") {
        return 50.0;
    }
    if (variant == "sharp") {
        return 100.0;
    }
    return 0.0;
}

void EditPersianKeySig::applyNoteVariant(Note* note, const std::string& variant, double targetCents)
{
    if (!note || !note->score()) {
        return;
    }
    if (!isValidPersianVariant(variant)) {
        LOGW() << "EditPersianKeySig: unknown variant: " << variant;
        return;
    }

    Score* score = note->score();
    Accidental* acc = note->accidental();
    const AccidentalType current = acc ? acc->accidentalType() : AccidentalType::NONE;

    if (variant == "natural") {
        // Restore the natural pitch when the note is altered
        if (tpc2alter(note->tpc()) != AccidentalVal::NATURAL) {
            EditNote::changeAccidental(score, note, AccidentalType::NATURAL);
        }
        // changeAccidental() keeps a leftover non-natural element when it
        // cannot prove the sign is needed (e.g. Bb with an explicit flat
        // in Bb major) - drop it, we want a natural note here
        Accidental* leftover = note->accidental();
        if (leftover && leftover->accidentalType() != AccidentalType::NATURAL) {
            score->undoRemoveElement(leftover);
        }
        // An explicit natural sign is only needed while the surrounding
        // state (key signature / earlier accidentals) is not natural
        const bool needSign = noteNeedsNaturalSign(note);
        acc = note->accidental();
        if (acc && !needSign) {
            score->undoRemoveElement(acc);
        } else if (!acc && needSign) {
            ensureAccidentalElement(score, note, AccidentalType::NATURAL);
        }
    } else {
        const AccidentalType target = variantAccidentalType(variant);
        if (current != target) {
            EditNote::changeAccidental(score, note, target);
        }
        ensureAccidentalElement(score, note, target);
    }

    // The accidental element contributes variantContribution(variant)
    // cents by itself; the note tuning completes the target.
    const double required = targetCents - variantContribution(variant);
    note->undoChangeProperty(Pid::TUNING, required);
}

int EditPersianKeySig::applyScoreKeySig(Score* score, const std::vector<PersianKeySigNote>& mapping,
                                        const std::function<double(const std::string&, const std::string&)>& centsFor)
{
    if (!score) {
        return 0;
    }

    std::map<std::string, std::string> letterVariant;
    for (const PersianKeySigNote& n : mapping) {
        if (!isValidPersianVariant(n.variant)) {
            continue;
        }
        letterVariant[n.letter] = n.variant;
    }

    auto targetCents = [&](const std::string& letter, const std::string& variant) -> double {
        return centsFor ? centsFor(letter, variant) : defaultPersianVariantCents(variant);
    };

    int changed = 0;
    for (Segment* seg = score->firstSegment(SegmentType::ChordRest); seg; seg = seg->next1(SegmentType::ChordRest)) {
        for (EngravingObject* e : seg->elist()) {
            if (!e || !e->isChord()) {
                continue;
            }
            for (Note* note : toChord(e)->notes()) {
                const std::string letter = noteLetter(note->tpc());
                const std::string variant = letterVariant.count(letter) ? letterVariant.at(letter) : std::string("natural");
                const double requiredTuning = targetCents(letter, variant) - variantContribution(variant);
                bool upToDate = (noteVariant(note) == variant) && (std::abs(note->tuning() - requiredTuning) < 0.05);
                if (upToDate && variant == "natural") {
                    // a natural note may still require an explicit
                    // natural sign (key signature / earlier accidentals)
                    upToDate = (note->accidental() != nullptr) == noteNeedsNaturalSign(note);
                }
                if (upToDate) {
                    continue;
                }
                applyNoteVariant(note, variant, targetCents(letter, variant));
                ++changed;
            }
        }
    }

    return changed;
}
} // namespace mu::engraving
