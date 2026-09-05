/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * Built-in Persian Tuner dock panel (Mixer-like), sign-oriented cents.
 */

#include "persiantunerpanelmodel.h"

#include <algorithm>
#include <cmath>
#include <set>

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include "engraving/dom/accidental.h"
#include "engraving/dom/chord.h"
#include "engraving/dom/masterscore.h"
#include "engraving/dom/note.h"
#include "engraving/dom/property.h"
#include "engraving/dom/score.h"
#include "engraving/dom/segment.h"
#include "engraving/editing/persiankeysig.h"
#include "engraving/types/types.h"

#include "realfn.h"

#include "notation/inotation.h"
#include "notation/inotationelements.h"
#include "notation/inotationinteraction.h"
#include "notation/inotationselection.h"
#include "notation/inotationundostack.h"

#include "project/inotationproject.h"

#include "settings.h"
#include "translation.h"
#include "types/translatablestring.h"

#include "log.h"

using namespace mu::notation;
using namespace mu::engraving;
using namespace muse;

static const QStringList kLetters { QStringLiteral("C"), QStringLiteral("D"), QStringLiteral("E"),
                                    QStringLiteral("F"), QStringLiteral("G"), QStringLiteral("A"),
                                    QStringLiteral("B") };
static const QStringList kVariants { QStringLiteral("natural"), QStringLiteral("flat"), QStringLiteral("sori"),
                                     QStringLiteral("koron"), QStringLiteral("sharp") };

static const std::string kModule("persianTuner");
static const Settings::Key kAutoMemory(kModule, "autoMemory");
static const Settings::Key kRefFreq(kModule, "refFreq");
static const Settings::Key kTuningTable(kModule, "tuningTable");
static const Settings::Key kMemory(kModule, "memory");
static const Settings::Key kKeySigByScore(kModule, "keySigByScore");

PersianTunerPanelModel::PersianTunerPanelModel(QObject* parent)
    : QObject(parent), muse::Contextable(muse::iocCtxForQmlObject(this))
{
    for (const QString& letter : kLetters) {
        for (const QString& variant : { QStringLiteral("flat"), QStringLiteral("koron"), QStringLiteral("natural"),
                                        QStringLiteral("sori"), QStringLiteral("sharp") }) {
            m_tuningTable[letter][variant] = baseCentsForVariant(variant);
        }
    }
}

void PersianTunerPanelModel::init()
{
    settings()->setDefaultValue(kAutoMemory, Val(true));
    settings()->setDefaultValue(kRefFreq, Val(440.0));
    settings()->setDefaultValue(kTuningTable, Val(QString()));
    settings()->setDefaultValue(kMemory, Val(QString()));
    settings()->setDefaultValue(kKeySigByScore, Val(QString()));

    loadSettings();

    emit keySigPatternsChanged();

    onCurrentNotationChanged();
    globalContext()->currentNotationChanged().onNotify(this, [this]() {
        onCurrentNotationChanged();
    });
}

int PersianTunerPanelModel::letterIndex() const
{
    const int idx = kLetters.indexOf(m_selectedLetter);
    return idx >= 0 ? idx : 5;
}

int PersianTunerPanelModel::variantIndex() const
{
    const int idx = kVariants.indexOf(m_selectedVariant);
    return idx >= 0 ? idx : 2;
}

int PersianTunerPanelModel::octaveIndex() const
{
    return std::clamp(m_selectedOctave - 3, 0, 3);
}

double PersianTunerPanelModel::computedFreq() const
{
    static const QMap<QString, int> kSemitone {
        { QStringLiteral("C"), 0 }, { QStringLiteral("D"), 2 }, { QStringLiteral("E"), 4 },
        { QStringLiteral("F"), 5 }, { QStringLiteral("G"), 7 }, { QStringLiteral("A"), 9 },
        { QStringLiteral("B"), 11 }
    };
    const int naturalMidi = (m_selectedOctave + 1) * 12 + kSemitone.value(m_selectedLetter, 0);
    const double targetMidi = naturalMidi + m_currentCents / 100.0;
    return m_refFreq * std::pow(2.0, (targetMidi - 69.0) / 12.0);
}

bool PersianTunerPanelModel::hasSelection() const
{
    return !selectedNotes().empty();
}

QString PersianTunerPanelModel::selectionSummary() const
{
    const auto notes = selectedNotes();
    if (notes.empty()) {
        return muse::qtrc("notation/persiantuner", "Select a note in the score");
    }
    const NoteIdentity ident = identityOf(notes.front());
    return ident.letter + QStringLiteral(" ") + variantFa(ident.variant)
           + QStringLiteral(" — ") + QString::number(effectiveTarget(notes.front()), 'f', 1) + QStringLiteral("¢");
}

QString PersianTunerPanelModel::currentLabel() const
{
    return letterFa(m_selectedLetter) + QStringLiteral(" ") + variantFa(m_selectedVariant);
}

QString PersianTunerPanelModel::hintText() const
{
    if (m_selectedVariant == QLatin1String("sori")) {
        return muse::qtrc("notation/persiantuner", "Typical sori is about +50 cents — this is only a starting point");
    }
    if (m_selectedVariant == QLatin1String("koron")) {
        return muse::qtrc("notation/persiantuner", "Typical koron is about -50 cents");
    }
    if (m_selectedVariant == QLatin1String("flat")) {
        return muse::qtrc("notation/persiantuner", "Flat is usually -100 cents relative to natural");
    }
    if (m_selectedVariant == QLatin1String("sharp")) {
        return muse::qtrc("notation/persiantuner", "Sharp is usually +100 cents");
    }
    return muse::qtrc("notation/persiantuner", "Natural is the reference: 0 cents");
}

QString PersianTunerPanelModel::centsLabel() const
{
    const double v = round1(m_currentCents);
    return (v > 0 ? QStringLiteral("+") : QString()) + QString::number(v);
}

QString PersianTunerPanelModel::refNoteLabel() const
{
    return muse::qtrc("notation/persiantuner", "Cents relative to %1 natural").arg(letterFa(m_selectedLetter));
}

QVariantList PersianTunerPanelModel::variantRows() const
{
    QVariantList rows;
    for (const QString& variant : { QStringLiteral("flat"), QStringLiteral("koron"), QStringLiteral("natural"),
                                    QStringLiteral("sori"), QStringLiteral("sharp") }) {
        QVariantMap row;
        row.insert(QStringLiteral("id"), variant);
        row.insert(QStringLiteral("label"), variantFa(variant));
        row.insert(QStringLiteral("cents"), tableCents(m_selectedLetter, variant));
        rows << row;
    }
    return rows;
}

QVariantList PersianTunerPanelModel::selectedNotesInfo() const
{
    QVariantList rows;
    const auto notes = selectedNotes();
    for (const Note* note : notes) {
        const NoteIdentity ident = identityOf(note);
        QVariantMap row;
        row.insert(QStringLiteral("label"), ident.letter + QStringLiteral(" ") + variantFa(ident.variant)
                   + QStringLiteral(" ") + QString::number(ident.octave));
        row.insert(QStringLiteral("cents"), effectiveTarget(note));
        rows << row;
    }
    return rows;
}

QVariantList PersianTunerPanelModel::keySigPatterns() const
{
    QVariantList rows;
    for (const PersianKeySig& keySig : predefinedPersianKeySigs()) {
        if (isLegacyPersianKeySigId(keySig.id)) {
            continue;
        }
        QVariantMap row;
        row.insert(QStringLiteral("id"), QString::fromStdString(keySig.id));
        row.insert(QStringLiteral("nameFa"), QString::fromStdString(keySig.nameFa));
        row.insert(QStringLiteral("nameEn"), QString::fromStdString(keySig.nameEn));

        QStringList parts;
        for (const PersianKeySigNote& n : keySig.notes) {
            parts << letterFa(QString::fromStdString(n.letter)) + " " + variantFa(QString::fromStdString(n.variant));
        }
        const QString description = parts.isEmpty()
                                    ? muse::qtrc("notation/persiantuner", "All notes natural")
                                    : parts.join(QStringLiteral(", "));
        row.insert(QStringLiteral("description"), description);
        rows << row;
    }
    return rows;
}

static std::vector<const PersianKeySig*> visiblePersianKeyPatterns()
{
    std::vector<const PersianKeySig*> result;
    for (const PersianKeySig& keySig : predefinedPersianKeySigs()) {
        if (!isLegacyPersianKeySigId(keySig.id)) {
            result.push_back(&keySig);
        }
    }
    return result;
}

int PersianTunerPanelModel::keySigPatternIndex() const
{
    if (m_currentKeySigPattern.isEmpty()) {
        return -1;
    }
    const auto patterns = visiblePersianKeyPatterns();
    const auto it = std::find_if(patterns.begin(), patterns.end(),
                                 [id = m_currentKeySigPattern.toStdString()] (const PersianKeySig* keySig) {
        return keySig->id == id;
    });
    return it == patterns.end() ? -1 : static_cast<int>(it - patterns.begin());
}

QString PersianTunerPanelModel::keySigPattern() const
{
    return m_currentKeySigPattern;
}

QString PersianTunerPanelModel::keySigPatternDescription() const
{
    const PersianKeySig* pattern = m_currentKeySigPattern.isEmpty()
                                   ? nullptr : persianKeySigById(m_currentKeySigPattern.toStdString());
    if (!pattern) {
        return QString();
    }
    QStringList parts;
    for (const PersianKeySigNote& n : pattern->notes) {
        parts << letterFa(QString::fromStdString(n.letter)) + " " + variantFa(QString::fromStdString(n.variant));
    }
    return parts.isEmpty()
           ? muse::qtrc("notation/persiantuner", "All notes natural")
           : parts.join(QStringLiteral(", "));
}

void PersianTunerPanelModel::setSelectedLetter(const QString& letter)
{
    if (!kLetters.contains(letter) || m_selectedLetter == letter) {
        return;
    }
    m_selectedLetter = letter;
    m_currentCents = tableCents(m_selectedLetter, m_selectedVariant);
    emit selectedLetterChanged();
    emit currentCentsChanged();
    emit computedFreqChanged();
    emit variantRowsChanged();
    emit selectionChanged();
}

void PersianTunerPanelModel::setSelectedVariant(const QString& variant)
{
    if (m_selectedVariant == variant) {
        return;
    }
    m_selectedVariant = variant;
    m_currentCents = tableCents(m_selectedLetter, m_selectedVariant);
    emit selectedVariantChanged();
    emit currentCentsChanged();
    emit computedFreqChanged();
    emit selectionChanged();
}

void PersianTunerPanelModel::setSelectedOctave(int octave)
{
    octave = std::clamp(octave, 0, 8);
    if (m_selectedOctave == octave) {
        return;
    }
    m_selectedOctave = octave;
    emit selectedOctaveChanged();
    emit computedFreqChanged();
}

void PersianTunerPanelModel::setLetterIndex(int index)
{
    if (index >= 0 && index < kLetters.size()) {
        setSelectedLetter(kLetters.at(index));
    }
}

void PersianTunerPanelModel::setVariantIndex(int index)
{
    if (index >= 0 && index < kVariants.size()) {
        setSelectedVariant(kVariants.at(index));
    }
}

void PersianTunerPanelModel::setOctaveIndex(int index)
{
    setSelectedOctave(3 + std::clamp(index, 0, 3));
}

void PersianTunerPanelModel::setCurrentCents(double cents)
{
    cents = std::clamp(round1(cents), -100.0, 100.0);
    if (qFuzzyCompare(m_currentCents, cents) || (m_currentCents == 0.0 && cents == 0.0)) {
        return;
    }
    m_currentCents = cents;
    emit currentCentsChanged();
    emit computedFreqChanged();
}

void PersianTunerPanelModel::setRefFreq(double freq)
{
    if (freq <= 0.0) {
        return;
    }
    if (qFuzzyCompare(m_refFreq, freq)) {
        return;
    }
    m_refFreq = freq;
    saveSettings();
    emit refFreqChanged();
    emit computedFreqChanged();
}

void PersianTunerPanelModel::setAutoMemory(bool on)
{
    if (m_autoMemory == on) {
        return;
    }
    m_autoMemory = on;
    saveSettings();
    emit autoMemoryChanged();
}

void PersianTunerPanelModel::applyCents(double cents)
{
    cents = std::clamp(round1(cents), -100.0, 100.0);
    setCurrentCents(cents);

    INotationPtr n = notation();
    if (!n) {
        m_tuningTable[m_selectedLetter][m_selectedVariant] = cents;
        saveSettings();
        emit variantRowsChanged();
        return;
    }

    auto notes = selectedNotes();
    if (!n->undoStack()) {
        return;
    }
    n->undoStack()->prepareChanges(TranslatableString("undoableAction", "Tune notes"));

    m_tuningTable[m_selectedLetter][m_selectedVariant] = cents;

    int applied = 0;
    if (notes.empty()) {
        saveSettings();
    } else {
        for (Note* note : notes) {
            tuneNote(note, m_selectedVariant, cents);
            ++applied;
        }
        if (m_autoMemory) {
            applied = rememberAndPropagate(notes, cents);
        } else {
            const QString id = scoreId();
            for (Note* note : notes) {
                const NoteIdentity ident = identityOf(note);
                setMemoryChange(id, memoryKey(ident), ident.tick, cents);
            }
        }
        saveSettings();
    }

    n->undoStack()->commitChanges();
    n->notationChanged().send(muse::RectF());

    emit variantRowsChanged();
    emit selectionChanged();
    if (notes.empty()) {
        setStatus(m_selectedLetter + QStringLiteral(" ") + variantFa(m_selectedVariant)
                  + QStringLiteral(" = ") + QString::number(cents) + QStringLiteral("¢"));
    } else {
        setStatus(muse::qtrc("notation/persiantuner", "%1 notes tuned").arg(applied));
    }
}

void PersianTunerPanelModel::setTableCents(const QString& letter, const QString& variant, double cents)
{
    cents = std::clamp(round1(cents), -100.0, 100.0);
    m_tuningTable[letter][variant] = cents;
    if (letter == m_selectedLetter && variant == m_selectedVariant) {
        setCurrentCents(cents);
    }

    INotationPtr n = notation();
    const QString id = scoreId();
    const QString key = letter + QLatin1Char('/') + variant;
    setMemoryChange(id, key, 0, cents);
    saveSettings();

    if (n && n->undoStack() && score()) {
        n->undoStack()->prepareChanges(TranslatableString("undoableAction", "Update tuning table"));
        const std::optional<int> toTick = nextChangeTick(id, key, 0);
        for (Note* note : collectScoreNotes()) {
            const NoteIdentity ident = identityOf(note);
            if (memoryKey(ident) != key) {
                continue;
            }
            if (toTick && ident.tick >= *toTick) {
                continue;
            }
            tuneNote(note, variant, cents);
        }
        n->undoStack()->commitChanges();
        n->notationChanged().send(muse::RectF());
    }

    emit variantRowsChanged();
    emit selectionChanged();
    setStatus(letter + QStringLiteral(" ") + variantFa(variant) + QStringLiteral(" = ")
              + QString::number(cents) + QStringLiteral("¢"));
}

void PersianTunerPanelModel::playCurrent()
{
    if (!playbackController()) {
        return;
    }
    const auto notes = selectedNotes();
    if (notes.empty()) {
        setStatus(muse::qtrc("notation/persiantuner", "Select a note to play"));
        return;
    }
    std::vector<const EngravingItem*> elems;
    elems.reserve(notes.size());
    for (Note* note : notes) {
        elems.push_back(note);
    }
    playbackController()->playElements(elems);
}

void PersianTunerPanelModel::reapplyMemory()
{
    INotationPtr n = notation();
    if (!n) {
        return;
    }
    const QString id = scoreId();
    n->undoStack()->prepareChanges(TranslatableString("undoableAction", "Re-apply Persian tuning"));
    int applied = 0;
    for (Note* note : collectScoreNotes()) {
        const NoteIdentity ident = identityOf(note);
        const std::optional<double> mem = resolveMemory(id, memoryKey(ident), ident.tick);
        if (!mem) {
            continue;
        }
        tuneNote(note, ident.variant, *mem);
        ++applied;
    }
    n->undoStack()->commitChanges();
    n->notationChanged().send(muse::RectF());
    emit selectionChanged();
    setStatus(muse::qtrc("notation/persiantuner", "Re-applied %1 notes").arg(applied));
}

void PersianTunerPanelModel::clearMemory()
{
    m_memory.remove(scoreId());
    saveSettings();
    setStatus(muse::qtrc("notation/persiantuner", "Memory cleared"));
}

QString PersianTunerPanelModel::letterFa(const QString& letter) const
{
    // Solfège names used as translatable source (English). The Persian names
    // ("دو", "رِ", ...) are provided as translations in the locale files.
    static const QMap<QString, QString> map {
        { QStringLiteral("C"), QStringLiteral("Do") },
        { QStringLiteral("D"), QStringLiteral("Re") },
        { QStringLiteral("E"), QStringLiteral("Mi") },
        { QStringLiteral("F"), QStringLiteral("Fa") },
        { QStringLiteral("G"), QStringLiteral("Sol") },
        { QStringLiteral("A"), QStringLiteral("La") },
        { QStringLiteral("B"), QStringLiteral("Si") },
    };
    const QString source = map.value(letter, letter);
    return muse::qtrc("notation/persiantuner", muse::String(source));
}

QString PersianTunerPanelModel::variantFa(const QString& variant) const
{
    static const QMap<QString, QString> map {
        { QStringLiteral("flat"), QStringLiteral("Flat") },
        { QStringLiteral("koron"), QStringLiteral("Koron") },
        { QStringLiteral("natural"), QStringLiteral("Natural") },
        { QStringLiteral("sori"), QStringLiteral("Sori") },
        { QStringLiteral("sharp"), QStringLiteral("Sharp") },
    };
    const QString source = map.value(variant, variant);
    return muse::qtrc("notation/persiantuner", muse::String(source));
}

INotationPtr PersianTunerPanelModel::notation() const
{
    return globalContext()->currentNotation();
}

Score* PersianTunerPanelModel::score() const
{
    INotationPtr n = notation();
    return n && n->elements() ? n->elements()->msScore() : nullptr;
}

QString PersianTunerPanelModel::scoreId() const
{
    auto project = globalContext()->currentProject();
    if (!project) {
        return QStringLiteral("score");
    }
    const QString name = project->displayName();
    return name.isEmpty() ? QStringLiteral("score") : name;
}

void PersianTunerPanelModel::onCurrentNotationChanged()
{
    INotationPtr n = notation();
    if (!n) {
        m_currentKeySigPattern.clear();
        emit selectionChanged();
        emit keySigPatternIndexChanged();
        return;
    }
    n->interaction()->selectionChanged().onNotify(this, [this]() {
        refreshFromSelection();
    }, Asyncable::Mode::SetReplace);
    // Keep the panel in sync with changes made in MuseScore itself
    // (top symbols row, keyboard, properties panel, ...): any score
    // change re-reads the selected note's accidental and cents.
    n->notationChanged().onReceive(this, [this](const muse::RectF&) {
        refreshFromSelection();
    }, Asyncable::Mode::SetReplace);

    refreshFromSelection();
    refreshKeySigPattern();
}

void PersianTunerPanelModel::refreshFromSelection()
{
    const auto notes = selectedNotes();
    if (!notes.empty()) {
        const NoteIdentity ident = identityOf(notes.front());
        if (m_selectedLetter != ident.letter) {
            m_selectedLetter = ident.letter;
            emit selectedLetterChanged();
        }
        if (m_selectedVariant != ident.variant) {
            m_selectedVariant = ident.variant;
            emit selectedVariantChanged();
        }
        if (m_selectedOctave != ident.octave) {
            m_selectedOctave = ident.octave;
            emit selectedOctaveChanged();
        }
        const double cents = round1(effectiveTarget(notes.front()));
        if (!(m_currentCents == 0.0 && cents == 0.0) && !qFuzzyCompare(m_currentCents, cents)) {
            m_currentCents = cents;
            emit currentCentsChanged();
            emit computedFreqChanged();
        }
        emit variantRowsChanged();
    }
    emit selectionChanged();
}

void PersianTunerPanelModel::refreshKeySigPattern()
{
    const QString id = m_keySigByScore.value(scoreId());
    if (m_currentKeySigPattern == id) {
        return;
    }
    m_currentKeySigPattern = id;
    emit keySigPatternIndexChanged();
}

void PersianTunerPanelModel::setStatus(const QString& msg)
{
    m_statusMessage = msg;
    emit statusMessageChanged();
}

PersianTunerPanelModel::NoteIdentity PersianTunerPanelModel::identityOf(const Note* note) const
{
    NoteIdentity ident;
    if (!note) {
        return ident;
    }

    ident.letter = letterFromTpc(note->tpc());
    ident.octave = note->octave();
    ident.tick = note->tick().ticks();
    ident.staffIdx = static_cast<int>(note->staffIdx());

    const AccidentalType acc = note->accidental() ? note->accidental()->accidentalType() : AccidentalType::NONE;
    switch (acc) {
    case AccidentalType::FLAT:
    case AccidentalType::FLAT2:
        ident.variant = QStringLiteral("flat");
        break;
    case AccidentalType::KORON:
        ident.variant = QStringLiteral("koron");
        break;
    case AccidentalType::SORI:
        ident.variant = QStringLiteral("sori");
        break;
    case AccidentalType::SHARP:
    case AccidentalType::SHARP2:
        ident.variant = QStringLiteral("sharp");
        break;
    case AccidentalType::NATURAL:
        ident.variant = QStringLiteral("natural");
        break;
    default: {
        const int fifths = fifthsFromTpc(note->tpc());
        if (fifths < 0) {
            ident.variant = QStringLiteral("flat");
        } else if (fifths > 0) {
            ident.variant = QStringLiteral("sharp");
        } else if (note->centOffsetInherited()
                   && muse::RealIsEqual(note->centOffset(), Accidental::subtype2centOffset(AccidentalType::KORON))) {
            // koron given by the key signature (no sign in front of the note)
            ident.variant = QStringLiteral("koron");
        } else if (note->centOffsetInherited()
                   && muse::RealIsEqual(note->centOffset(), Accidental::subtype2centOffset(AccidentalType::SORI))) {
            ident.variant = QStringLiteral("sori");
        } else {
            ident.variant = QStringLiteral("natural");
        }
        break;
    }
    }

    ident.baseCents = baseCentsForVariant(ident.variant);
    return ident;
}

QString PersianTunerPanelModel::memoryKey(const NoteIdentity& ident) const
{
    return ident.letter + QLatin1Char('/') + ident.variant;
}

double PersianTunerPanelModel::tableCents(const QString& letter, const QString& variant) const
{
    if (m_tuningTable.contains(letter) && m_tuningTable[letter].contains(variant)) {
        return m_tuningTable[letter][variant];
    }
    return baseCentsForVariant(variant);
}

double PersianTunerPanelModel::effectiveTarget(const Note* note) const
{
    if (!note) {
        return 0.0;
    }
    // The actual cents of the note relative to the natural of its letter:
    // the semitone + microtonal contribution of the accidental the note
    // carries (set in MuseScore itself, e.g. from the top symbols row)
    // plus the fine tuning stored on the note.
    const NoteIdentity ident = identityOf(note);
    double contribution = 0.0;
    if (const Accidental* acc = note->accidental()) {
        contribution = double(Accidental::subtype2value(acc->accidentalType())) * 100.0
                       + Accidental::subtype2centOffset(acc->accidentalType());
    } else {
        if (ident.variant == QLatin1String("flat")) {
            contribution = -100.0;
        } else if (ident.variant == QLatin1String("sharp")) {
            contribution = 100.0;
        } else if (note->centOffsetInherited()) {
            // koron / sori inherited from the key signature
            contribution = note->centOffset();
        }
    }
    return round1(contribution + note->tuning());
}

std::vector<Note*> PersianTunerPanelModel::selectedNotes() const
{
    std::vector<Note*> result;
    INotationPtr n = notation();
    if (!n || !n->interaction() || !n->interaction()->selection()) {
        return result;
    }
    return n->interaction()->selection()->notes();
}

std::vector<Note*> PersianTunerPanelModel::collectScoreNotes() const
{
    std::vector<Note*> result;
    Score* sc = score();
    if (!sc) {
        return result;
    }
    for (Segment* seg = sc->firstSegment(SegmentType::ChordRest); seg; seg = seg->next1(SegmentType::ChordRest)) {
        for (EngravingObject* e : seg->elist()) {
            if (!e || !e->isChord()) {
                continue;
            }
            for (Note* note : toChord(e)->notes()) {
                result.push_back(note);
            }
        }
    }
    return result;
}

void PersianTunerPanelModel::tuneNote(Note* note, const QString& variant, double targetCents)
{
    if (!note || !score()) {
        return;
    }
    EditPersianKeySig::applyNoteVariant(note, variant.toStdString(), targetCents);
}

int PersianTunerPanelModel::rememberAndPropagate(const std::vector<Note*>& notes, double targetCents)
{
    if (notes.empty()) {
        return 0;
    }
    const QString id = scoreId();
    QMap<QString, int> startTicks;
    QStringList keyOrder;
    for (Note* note : notes) {
        const NoteIdentity ident = identityOf(note);
        const QString key = memoryKey(ident);
        if (!startTicks.contains(key)) {
            startTicks.insert(key, ident.tick);
            keyOrder << key;
        } else if (ident.tick < startTicks[key]) {
            startTicks[key] = ident.tick;
        }
    }

    int applied = 0;
    const auto allNotes = collectScoreNotes();
    for (const QString& key : keyOrder) {
        const int from = startTicks[key];
        setMemoryChange(id, key, from, targetCents);
        const std::optional<int> to = nextChangeTick(id, key, from);
        const QStringList keyParts = key.split(QLatin1Char('/'));
        const QString letter = keyParts.value(0);
        const QString variant = keyParts.value(1);
        for (Note* note : allNotes) {
            const NoteIdentity ident = identityOf(note);
            if (memoryKey(ident) != key) {
                continue;
            }
            if (ident.tick < from) {
                continue;
            }
            if (to && ident.tick >= *to) {
                continue;
            }
            tuneNote(note, variant, targetCents);
            ++applied;
        }
    }
    return applied;
}

void PersianTunerPanelModel::setMemoryChange(const QString& id, const QString& key, int tick, double cents)
{
    auto& list = m_memory[id][key];
    bool replaced = false;
    for (MemoryChange& change : list) {
        if (change.tick == tick) {
            change.cents = cents;
            replaced = true;
            break;
        }
    }
    if (!replaced) {
        list.append({ tick, cents });
    }
    std::sort(list.begin(), list.end(), [](const MemoryChange& a, const MemoryChange& b) {
        return a.tick < b.tick;
    });
}

std::optional<double> PersianTunerPanelModel::resolveMemory(const QString& id, const QString& key, int tick) const
{
    const auto scoreIt = m_memory.constFind(id);
    if (scoreIt == m_memory.cend()) {
        return std::nullopt;
    }
    const auto keyIt = scoreIt.value().constFind(key);
    if (keyIt == scoreIt.value().cend()) {
        return std::nullopt;
    }
    std::optional<double> cents;
    for (const MemoryChange& change : keyIt.value()) {
        if (change.tick <= tick) {
            cents = change.cents;
        } else {
            break;
        }
    }
    return cents;
}

std::optional<int> PersianTunerPanelModel::nextChangeTick(const QString& id, const QString& key, int fromTick) const
{
    const auto scoreIt = m_memory.constFind(id);
    if (scoreIt == m_memory.cend()) {
        return std::nullopt;
    }
    const auto keyIt = scoreIt.value().constFind(key);
    if (keyIt == scoreIt.value().cend()) {
        return std::nullopt;
    }
    for (const MemoryChange& change : keyIt.value()) {
        if (change.tick > fromTick) {
            return change.tick;
        }
    }
    return std::nullopt;
}

void PersianTunerPanelModel::setKeySigPatternIndex(int index)
{
    const auto keySigs = visiblePersianKeyPatterns();
    if (index < 0 || index >= (int)keySigs.size()) {
        return;
    }
    const QString id = QString::fromStdString(keySigs[index]->id);
    if (m_currentKeySigPattern == id) {
        return;
    }
    m_currentKeySigPattern = id;
    emit keySigPatternIndexChanged();
}

void PersianTunerPanelModel::applyKeySigPattern()
{
    applyPersianKeySig(m_currentKeySigPattern);
}

void PersianTunerPanelModel::clearKeySigPattern()
{
    applyPersianKeySig(QString());
}

void PersianTunerPanelModel::playKeySigPattern()
{
    INotationPtr n = notation();
    if (!n || !n->interaction() || !playbackController()) {
        return;
    }
    const std::string id = m_currentKeySigPattern.toStdString();
    const PersianKeySig* pattern = id.empty() ? nullptr : persianKeySigById(id);

    // Collect the notes that carry the key's character (the letters of
    // the pattern; all notes when no pattern is active), earliest first
    std::set<std::string> letters;
    if (pattern) {
        for (const PersianKeySigNote& n2 : pattern->notes) {
            letters.insert(n2.letter);
        }
    }
    std::vector<Note*> notes;
    for (Note* note : collectScoreNotes()) {
        if (!letters.empty() && !letters.count(letterFromTpc(note->tpc()).toStdString())) {
            continue;
        }
        notes.push_back(note);
    }
    if (notes.empty()) {
        notes = collectScoreNotes();
    }
    if (notes.empty()) {
        setStatus(muse::qtrc("notation/persiantuner", "Add notes to the score to play the key"));
        return;
    }
    std::sort(notes.begin(), notes.end(), [](const Note* a, const Note* b) {
        return a->tick() < b->tick();
    });
    if (notes.size() > 32) {
        notes.resize(32);
    }

    std::vector<EngravingItem*> elems;
    elems.reserve(notes.size());
    std::vector<const EngravingItem*> playElems;
    playElems.reserve(notes.size());
    for (Note* note : notes) {
        elems.push_back(note);
        playElems.push_back(note);
    }
    n->interaction()->select(elems);
    playbackController()->playElements(playElems);
    setStatus(muse::qtrc("notation/persiantuner", "Playing %1 notes of the key").arg(playElems.size()));
}

void PersianTunerPanelModel::applyPersianKeySig(const QString& patternId)
{
    INotationPtr n = notation();
    Score* sc = score();
    if (!n || !sc || !n->undoStack()) {
        return;
    }

    const PersianKeySig* pattern = patternId.isEmpty() ? nullptr : persianKeySigById(patternId.toStdString());

    std::vector<PersianKeySigNote> mapping;
    if (pattern) {
        mapping = pattern->notes;
    }

    n->undoStack()->prepareChanges(
        pattern ? TranslatableString("undoableAction", "Apply Persian key signature %1").arg(
            muse::String(QString::fromStdString(pattern->nameEn)))
        : TranslatableString("undoableAction", "Clear Persian key signature"));

    auto centsFor = [this](const std::string& letter, const std::string& variant) -> double {
        return tableCents(QString::fromStdString(letter), QString::fromStdString(variant));
    };
    // Write the signs into the key signature on the staves AND respell /
    // retune the notes (what you see is what you hear).
    const int changed = EditPersianKeySig::applyKeySigToStaves(sc->masterScore(), mapping, centsFor);

    // Remember the key in the tuning memory so "Re-apply memory"
    // reproduces it
    const QString id = scoreId();
    if (pattern) {
        for (const PersianKeySigNote& n2 : pattern->notes) {
            setMemoryChange(id, QString::fromStdString(n2.letter) + QLatin1Char('/') + QString::fromStdString(n2.variant),
                            0, centsFor(n2.letter, n2.variant));
        }
    }
    for (const QString& letter : kLetters) {
        const bool inPattern = pattern && std::any_of(pattern->notes.begin(), pattern->notes.end(),
                                                      [letter](const PersianKeySigNote& n2) {
            return n2.letter == letter.toStdString();
        });
        if (!inPattern) {
            setMemoryChange(id, letter + QLatin1Char('/') + QStringLiteral("natural"), 0, 0.0);
        }
    }

    saveCurrentKeySigPattern(patternId);

    n->undoStack()->commitChanges();
    n->notationChanged().send(muse::RectF());

    emit keySigPatternIndexChanged();
    emit selectionChanged();
    if (pattern) {
        setStatus(muse::qtrc("notation/persiantuner", "Key %1 applied (%2 notes changed)")
                  .arg(QString::fromStdString(pattern->nameEn), QString::number(changed)));
    } else {
        setStatus(muse::qtrc("notation/persiantuner", "Persian key cleared (%1 notes changed)").arg(changed));
    }
}

void PersianTunerPanelModel::saveCurrentKeySigPattern(const QString& patternId)
{
    m_currentKeySigPattern = patternId;
    if (patternId.isEmpty()) {
        m_keySigByScore.remove(scoreId());
    } else {
        m_keySigByScore[scoreId()] = patternId;
    }
    saveSettings();
}

void PersianTunerPanelModel::loadSettings()
{
    m_autoMemory = settings()->value(kAutoMemory).toBool();
    const double freq = settings()->value(kRefFreq).toDouble();
    if (freq > 0.0) {
        m_refFreq = freq;
    }

    const QString tableJson = settings()->value(kTuningTable).toQString();
    const QJsonObject tableObj = QJsonDocument::fromJson(tableJson.toUtf8()).object();
    for (auto it = tableObj.begin(); it != tableObj.end(); ++it) {
        const QJsonObject variants = it.value().toObject();
        for (auto vit = variants.begin(); vit != variants.end(); ++vit) {
            m_tuningTable[it.key()][vit.key()] = round1(vit.value().toDouble());
        }
    }

    const QString memJson = settings()->value(kMemory).toQString();
    const QJsonObject memObj = QJsonDocument::fromJson(memJson.toUtf8()).object();
    const QJsonObject scores = memObj.value(QStringLiteral("scores")).toObject();
    for (auto sit = scores.begin(); sit != scores.end(); ++sit) {
        const QJsonObject keys = sit.value().toObject().value(QStringLiteral("keys")).toObject();
        for (auto kit = keys.begin(); kit != keys.end(); ++kit) {
            QList<MemoryChange> list;
            const QJsonArray arr = kit.value().toArray();
            for (const QJsonValue& v : arr) {
                const QJsonObject o = v.toObject();
                list.append({ o.value(QStringLiteral("t")).toInt(), o.value(QStringLiteral("c")).toDouble() });
            }
            m_memory[sit.key()][kit.key()] = list;
        }
    }

    const QString keySigJson = settings()->value(kKeySigByScore).toQString();
    const QJsonObject keySigObj = QJsonDocument::fromJson(keySigJson.toUtf8()).object();
    for (auto it = keySigObj.begin(); it != keySigObj.end(); ++it) {
        m_keySigByScore[it.key()] = it.value().toString();
    }

    m_currentCents = tableCents(m_selectedLetter, m_selectedVariant);
}

void PersianTunerPanelModel::saveSettings()
{
    settings()->setSharedValue(kAutoMemory, Val(m_autoMemory));
    settings()->setSharedValue(kRefFreq, Val(m_refFreq));

    QJsonObject tableObj;
    for (auto it = m_tuningTable.begin(); it != m_tuningTable.end(); ++it) {
        QJsonObject variants;
        for (auto vit = it.value().begin(); vit != it.value().end(); ++vit) {
            variants.insert(vit.key(), vit.value());
        }
        tableObj.insert(it.key(), variants);
    }
    settings()->setSharedValue(kTuningTable, Val(QString::fromUtf8(QJsonDocument(tableObj).toJson(QJsonDocument::Compact))));

    QJsonObject scores;
    for (auto sit = m_memory.begin(); sit != m_memory.end(); ++sit) {
        QJsonObject keys;
        for (auto kit = sit.value().begin(); kit != sit.value().end(); ++kit) {
            QJsonArray arr;
            for (const MemoryChange& change : kit.value()) {
                QJsonObject o;
                o.insert(QStringLiteral("t"), change.tick);
                o.insert(QStringLiteral("c"), change.cents);
                arr.append(o);
            }
            keys.insert(kit.key(), arr);
        }
        QJsonObject scoreObj;
        scoreObj.insert(QStringLiteral("keys"), keys);
        scores.insert(sit.key(), scoreObj);
    }
    QJsonObject root;
    root.insert(QStringLiteral("scores"), scores);
    settings()->setSharedValue(kMemory, Val(QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Compact))));

    QJsonObject keySigObj;
    for (auto it = m_keySigByScore.begin(); it != m_keySigByScore.end(); ++it) {
        keySigObj.insert(it.key(), it.value());
    }
    settings()->setSharedValue(kKeySigByScore, Val(QString::fromUtf8(QJsonDocument(keySigObj).toJson(QJsonDocument::Compact))));
}

double PersianTunerPanelModel::baseCentsForVariant(const QString& variant)
{
    return defaultPersianVariantCents(variant.toStdString());
}

QString PersianTunerPanelModel::letterFromTpc(int tpc)
{
    static const char* letters[] = { "F", "C", "G", "D", "A", "E", "B" };
    const int delta = tpc - 13;
    const int index = ((delta % 7) + 7) % 7;
    return QString::fromLatin1(letters[index]);
}

int PersianTunerPanelModel::fifthsFromTpc(int tpc)
{
    return static_cast<int>(std::floor((tpc - 13) / 7.0));
}

double PersianTunerPanelModel::round1(double v)
{
    return std::round(v * 10.0) / 10.0;
}
