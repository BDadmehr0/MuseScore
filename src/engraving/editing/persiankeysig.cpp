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

#include "realfn.h"

#include "dom/accidental.h"
#include "dom/chord.h"
#include "dom/factory.h"
#include "dom/key.h"
#include "dom/keysig.h"
#include "dom/masterscore.h"
#include "dom/measure.h"
#include "dom/note.h"
#include "dom/pitchspelling.h"
#include "dom/score.h"
#include "dom/segment.h"
#include "dom/staff.h"

#include "editkeysig.h"
#include "editnote.h"
#include "transaction/transaction.h"

#include "log.h"

namespace mu::engraving {
namespace {
//---------------------------------------------------------
//   letterDegree
///    Note letter ("C" .. "B") to a C-major scale degree (0..6).
///    Returns -1 for unknown letters.
//---------------------------------------------------------

int letterDegree(const std::string& letter)
{
    static const std::map<std::string, int> kDegrees = {
        { "C", 0 }, { "D", 1 }, { "E", 2 }, { "F", 3 }, { "G", 4 }, { "A", 5 }, { "B", 6 }
    };
    auto it = kDegrees.find(letter);
    return it == kDegrees.end() ? -1 : it->second;
}

//---------------------------------------------------------
//   variantSymId
///    Persian variant to the accidental symbol used in a custom
///    key signature. Natural letters stay implicit (noSym).
//---------------------------------------------------------

SymId variantSymId(const std::string& variant)
{
    if (variant == "flat") {
        return SymId::accidentalFlat;
    }
    if (variant == "sharp") {
        return SymId::accidentalSharp;
    }
    if (variant == "sori") {
        return SymId::accidentalSori;
    }
    if (variant == "koron") {
        return SymId::accidentalKoron;
    }
    return SymId::noSym;
}

//---------------------------------------------------------
//   variantForSym
///    Inverse of variantSymId for the custom-key symbols that
///    can appear in a Persian key signature. Empty string for
///    everything else.
//---------------------------------------------------------

std::string variantForSym(SymId sym)
{
    switch (sym) {
    case SymId::accidentalFlat: return "flat";
    case SymId::accidentalSharp: return "sharp";
    case SymId::accidentalKoron: return "koron";
    case SymId::accidentalSori: return "sori";
    default: return std::string();
    }
}

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
//   variantSignCents
///    Microtonal cents carried by the sign of \a variant
///    itself (koron -67, sori +33, 0 for the others).
//---------------------------------------------------------

double variantSignCents(const std::string& variant)
{
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
///    element, creating or replacing it when needed.
//---------------------------------------------------------

void ensureAccidentalElement(Score* score, Note* note, AccidentalType type)
{
    Accidental* acc = note->accidental();
    if (acc && acc->accidentalType() == type) {
        return;
    }
    if (acc) {
        Accidental* a = acc->clone();
        a->setParent(note);
        a->setAccidentalType(type);
        a->setRole(AccidentalRole::USER);
        score->undoChangeElement(acc, a);
        return;
    }
    Accidental* acc1 = Factory::createAccidental(note);
    acc1->setParent(note);
    acc1->setAccidentalType(type);
    acc1->setRole(AccidentalRole::USER);
    score->undoAddElement(acc1);
}

//---------------------------------------------------------
//   noteNeedsSign
///    True when \a note, spelled as \a variant, needs an
///    explicit sign in front of it: the state of its line
///    (key signature + earlier accidentals of the measure,
///    including a koron / sori of a Persian key) differs from
///    the variant. A note that just follows the key signature
///    gets no sign - the key signature is the default.
//---------------------------------------------------------

bool noteNeedsSign(const Note* note, const std::string& variant)
{
    const AccidentalVal targetVal = Accidental::subtype2value(variantAccidentalType(variant));
    const double targetCents = variantSignCents(variant);
    if (tpc2alter(note->tpc()) != targetVal) {
        return true;
    }
    const Measure* m = note->findMeasure();
    if (!m) {
        return false;
    }
    if (m->findAccidental(note) != targetVal) {
        return true;
    }
    return !muse::RealIsEqual(m->findCentOffset(note), targetCents);
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
    // no sign of its own: a koron / sori may be inherited from the key
    // signature (or from an earlier sign in the measure)
    if (const Measure* m = note->findMeasure()) {
        const double cents = m->findCentOffset(note);
        if (muse::RealIsEqual(cents, Accidental::subtype2centOffset(AccidentalType::KORON))) {
            return "koron";
        }
        if (muse::RealIsEqual(cents, Accidental::subtype2centOffset(AccidentalType::SORI))) {
            return "sori";
        }
    }
    return "natural";
}
} // namespace

const std::vector<PersianKeySig>& predefinedPersianKeySigs()
{
    // Persian tunings, taken one-to-one from LilyPond's persian.ly
    // (Kees van den Doel / Werner Lemberg), all given on Do (C):
    //
    //   shur          : Re koron, Mi bemol, La bemol, Si bemol
    //   shurk         : shur with a koron 5th degree (Sol koron)
    //   esfahan       : Mi bemol, La koron
    //   mokhalefsegah : Mi bemol, La koron, Si koron
    //   chahargah     : Re koron, La koron
    //   mahur         : no accidentals
    //   delkashMahur  : La koron, Si bemol
    //
    // Dashti, Abu'ata, Bayat-e Tork and Nava use \shur; Afshari and Segah
    // use \shurk; Homayun is \esfahan (a fifth apart); Rast-Panjgah is
    // \mahur. The key signature only lists the altered letters - letters
    // that are not listed stay natural.
    //
    // The signs of the key signature are the default for the notes: a note
    // on an altered line inherits the koron / sori / flat of the key (in
    // playback too) and is written without its own sign. Cents: flat -100,
    // koron -50, sori +50, sharp +100 by default; persian.ly tunes koron
    // to -60 and sori to +40 cents - both are adjustable per letter/sign
    // in the Persian tuner.
    static const std::vector<PersianKeySig> kKeySigs = {
        {
            "shur", "شور (دشتی، ابوعطا، بیات ترک، نوا)", "Shur",
            { { "D", "koron" }, { "E", "flat" }, { "A", "flat" }, { "B", "flat" } }
        },
        {
            "shurk", "شور با سل کرن (افشاری، سه‌گاه)", "Shur-k (Afshari, Segah)",
            { { "D", "koron" }, { "E", "flat" }, { "G", "koron" }, { "A", "flat" }, { "B", "flat" } }
        },
        {
            "esfahan", "اصفهان (همایون)", "Esfahan (Homayun)",
            { { "E", "flat" }, { "A", "koron" } }
        },
        {
            "mokhalefsegah", "مخالف سه‌گاه", "Mokhalef-e Segah",
            { { "E", "flat" }, { "A", "koron" }, { "B", "koron" } }
        },
        {
            "chahargah", "چهارگاه", "Chahargah",
            { { "D", "koron" }, { "A", "koron" } }
        },
        {
            "mahur", "ماهور / راست پنج‌گاه", "Mahur (Rast-Panjgah)",
            {}
        },
        {
            "delkash-mahur", "دلکش ماهور", "Delkash Mahur",
            { { "A", "koron" }, { "B", "flat" } }
        },
        // ---- Legacy ids kept only to resolve settings saved by earlier
        //      versions (hidden from the palette and the panels) ----
        { "rast", "راست پنج‌گاه", "Rast-Panjgah", {} },
        { "nava", "نوا", "Nava", { { "D", "koron" }, { "E", "flat" }, { "A", "flat" }, { "B", "flat" } } },
        { "dashti", "دشتی", "Dashti", { { "D", "koron" }, { "E", "flat" }, { "A", "flat" }, { "B", "flat" } } },
        { "abuata", "ابوعطا", "Abu'ata", { { "D", "koron" }, { "E", "flat" }, { "A", "flat" }, { "B", "flat" } } },
        { "bayate-tork", "بیات ترک", "Bayat-e Tork", { { "D", "koron" }, { "E", "flat" }, { "A", "flat" }, { "B", "flat" } } },
        { "bayate-kord", "بیات کرد", "Bayat-e Kord", { { "D", "koron" }, { "E", "flat" }, { "A", "flat" }, { "B", "flat" } } },
        { "afshari", "افشاری", "Afshari",
          { { "D", "koron" }, { "E", "flat" }, { "G", "koron" }, { "A", "flat" }, { "B", "flat" } } },
        { "segah", "سه‌گاه", "Segah",
          { { "D", "koron" }, { "E", "flat" }, { "G", "koron" }, { "A", "flat" }, { "B", "flat" } } },
        { "homayun", "همایون", "Homayun", { { "E", "flat" }, { "A", "koron" } } },
        { "do-koron", "چهارگاه (دو کرن)", "Do Koron (Chahargah)", { { "D", "koron" }, { "A", "koron" } } },
        { "fa", "فا (شور)", "Fa (Shur)", { { "B", "flat" }, { "E", "flat" }, { "A", "koron" } } },
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

bool isLegacyPersianKeySigId(const std::string& id)
{
    static const char* kLegacy[] = {
        "rast", "nava", "dashti", "abuata", "bayate-tork", "bayate-kord", "afshari", "segah", "homayun", "do-koron", "fa"
    };
    for (const char* legacy : kLegacy) {
        if (id == legacy) {
            return true;
        }
    }
    return false;
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

//---------------------------------------------------------
//   persianKeySigToKeySigEvent
//---------------------------------------------------------

KeySigEvent persianKeySigToKeySigEvent(const std::vector<PersianKeySigNote>& mapping)
{
    KeySigEvent e;
    e.setConcertKey(Key::C);
    e.setCustom(true);

    // Order the symbols like a traditional Persian key signature:
    // flats first, then korons, then soris/sharps; within a group the
    // western circle-of-fifths order (B, E, A, D, G, C, F).
    static const std::vector<std::string> kOrder
        = { "B", "E", "A", "D", "G", "C", "F" };
    auto rank = [](const std::string& variant) -> int {
        if (variant == "flat") {
            return 0;
        }
        if (variant == "koron") {
            return 1;
        }
        if (variant == "sharp") {
            return 2;
        }
        if (variant == "sori") {
            return 3;
        }
        return 4;
    };

    std::vector<PersianKeySigNote> notes;
    for (const PersianKeySigNote& n : mapping) {
        if (letterDegree(n.letter) < 0 || !isValidPersianVariant(n.variant)) {
            continue;
        }
        if (n.variant == "natural") {
            continue; // natural letters are implicit in a key signature
        }
        notes.push_back(n);
    }
    std::sort(notes.begin(), notes.end(), [&](const PersianKeySigNote& a, const PersianKeySigNote& b) {
        const int ra = rank(a.variant);
        const int rb = rank(b.variant);
        if (ra != rb) {
            return ra < rb;
        }
        const auto ia = std::find(kOrder.begin(), kOrder.end(), a.letter);
        const auto ib = std::find(kOrder.begin(), kOrder.end(), b.letter);
        return ia < ib;
    });

    for (const PersianKeySigNote& n : notes) {
        const SymId sym = variantSymId(n.variant);
        if (sym == SymId::noSym) {
            continue;
        }
        CustDef c;
        c.degree = letterDegree(n.letter);
        c.sym = sym;
        e.customKeyDefs().push_back(c);
    }
    return e;
}

KeySigEvent persianKeySigToKeySigEvent(const PersianKeySig& keySig)
{
    return persianKeySigToKeySigEvent(keySig.notes);
}

std::vector<PersianKeySigNote> persianKeySigNotesFromMapping(const std::map<std::string, std::string>& mapping)
{
    std::vector<PersianKeySigNote> notes;
    for (const auto& p : mapping) {
        if (letterDegree(p.first) < 0 || !isValidPersianVariant(p.second)) {
            continue;
        }
        if (p.second == "natural") {
            continue;
        }
        notes.push_back({ p.first, p.second });
    }
    return notes;
}

bool isPersianKeySigEvent(const KeySigEvent& event)
{
    if (!event.custom() || event.isAtonal()) {
        return false;
    }
    for (const CustDef& c : event.customKeyDefs()) {
        if (variantForSym(c.sym).empty()) {
            return false;
        }
    }
    return !event.customKeyDefs().empty();
}

std::vector<PersianKeySigNote> persianKeySigNotesFromEvent(const KeySigEvent& event)
{
    std::vector<PersianKeySigNote> notes;
    if (!event.custom()) {
        return notes;
    }
    static const char* kLetters[] = { "C", "D", "E", "F", "G", "A", "B" };
    for (const CustDef& c : event.customKeyDefs()) {
        if (c.degree < 0 || c.degree > 6) {
            continue;
        }
        const std::string variant = variantForSym(c.sym);
        if (!variant.empty()) {
            notes.push_back({ kLetters[c.degree], variant });
        }
    }
    return notes;
}

//---------------------------------------------------------
//   persianKeySigFromKeySigEvent
//---------------------------------------------------------

const PersianKeySig* persianKeySigFromKeySigEvent(const KeySigEvent& event)
{
    if (!event.custom() || event.isAtonal()) {
        return nullptr;
    }
    for (const PersianKeySig& keySig : predefinedPersianKeySigs()) {
        const KeySigEvent candidate = persianKeySigToKeySigEvent(keySig);
        if (candidate == event) {
            return &keySig;
        }
    }
    return nullptr;
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
    const AccidentalType target = variantAccidentalType(variant);
    const AccidentalVal targetVal = Accidental::subtype2value(target);

    // 1. Pitch / spelling: make the note sound and be spelled as the
    //    variant (changeAccidental() also takes care of linked notes).
    const Accidental* acc = note->accidental();
    const AccidentalType current = acc ? acc->accidentalType() : AccidentalType::NONE;
    const bool currentIsMicrotonal = acc && Accidental::isMicrotonal(current);
    if (tpc2alter(note->tpc()) != targetVal || currentIsMicrotonal != Accidental::isMicrotonal(target)
        || (currentIsMicrotonal && current != target)) {
        EditNote::changeAccidental(score, note, target);
    }

    // 2. Sign: only when the key signature (or an earlier accidental of
    //    the measure) does not already provide the variant on this line.
    //    With a Persian key signature the koron / sori / flat of the key
    //    is the default - the notes must not repeat it.
    //    Evaluate the state *without* the note's own sign, since an
    //    explicit sign always matches the target by construction.
    const bool needSign = noteNeedsSign(note, variant);
    Accidental* own = note->accidental();
    if (needSign) {
        ensureAccidentalElement(score, note, target);
    } else if (own) {
        score->undoRemoveElement(own);
    }

    // 3. Playback: the sign (explicit or inherited from the key) already
    //    contributes variantContribution(variant) cents; the note tuning
    //    completes the target.
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
                if (upToDate) {
                    // the sign must be present exactly when the key
                    // signature / earlier accidentals do not already give
                    // the variant (no doubled koron / flat signs)
                    upToDate = (note->accidental() != nullptr) == noteNeedsSign(note, variant);
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

//---------------------------------------------------------
//   EditPersianKeySig::applyKeySigToStaves
//    Writes the Persian key signature (flat/koron/sori/sharp signs)
//    at the beginning of every staff and retunes the notes. The same
//    path is used by the palette drop, the Properties panel and the
//    Persian tuner panel, so what you see on the staff always matches
//    what you hear.
//---------------------------------------------------------

int EditPersianKeySig::applyKeySigToStaves(MasterScore* masterScore, const std::vector<PersianKeySigNote>& mapping,
                                           const std::function<double(const std::string&, const std::string&)>& centsFor)
{
    if (!masterScore) {
        return 0;
    }

    // 1. Write the key signature event at tick 0 of every staff.
    const KeySigEvent keyEvent = mapping.empty() ? [] {
        // a plain (all-natural) key signature restores C major
        KeySigEvent e;
        e.setConcertKey(Key::C);
        return e;
    }() : persianKeySigToKeySigEvent(mapping);

    if (Measure* firstMeasure = masterScore->tick2measure(Fraction(0, 1))) {
        Transaction& tx = masterScore->transactionManager()->currentOrDummyTransaction();
        for (Staff* staff : masterScore->staves()) {
            if (staff) {
                EditKeySig::undoChangeKeySig(tx, masterScore, staff, firstMeasure->tick(), keyEvent);
            }
        }
    }

    // 2. Respell and retune the notes so that koron/sori/flat/sharp
    //    signs actually sound.
    return applyScoreKeySig(masterScore, mapping, centsFor);
}
} // namespace mu::engraving
