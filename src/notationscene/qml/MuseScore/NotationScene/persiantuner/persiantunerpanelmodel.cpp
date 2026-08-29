/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * Built-in Persian Tuner dock panel (Mixer-like), sign-oriented cents.
 */

#include "persiantunerpanelmodel.h"

#include <algorithm>
#include <cmath>

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include "engraving/dom/chord.h"
#include "engraving/dom/note.h"
#include "engraving/dom/property.h"
#include "engraving/dom/score.h"
#include "engraving/dom/segment.h"
#include "engraving/types/types.h"

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

    loadSettings();

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
    if (qFuzzyCompare(m_currentCents, cents)) {
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
            tuneNote(note, cents);
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
            tuneNote(note, cents);
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
        tuneNote(note, *mem);
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
    static const QMap<QString, QString> map {
        { QStringLiteral("C"), QStringLiteral("دو") },
        { QStringLiteral("D"), QStringLiteral("رِ") },
        { QStringLiteral("E"), QStringLiteral("می") },
        { QStringLiteral("F"), QStringLiteral("فا") },
        { QStringLiteral("G"), QStringLiteral("سل") },
        { QStringLiteral("A"), QStringLiteral("لا") },
        { QStringLiteral("B"), QStringLiteral("سی") },
    };
    return map.value(letter, letter);
}

QString PersianTunerPanelModel::variantFa(const QString& variant) const
{
    static const QMap<QString, QString> map {
        { QStringLiteral("flat"), QStringLiteral("بمل") },
        { QStringLiteral("koron"), QStringLiteral("کُرُن") },
        { QStringLiteral("natural"), QStringLiteral("بکار") },
        { QStringLiteral("sori"), QStringLiteral("سُری") },
        { QStringLiteral("sharp"), QStringLiteral("دیز") },
    };
    return map.value(variant, variant);
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
        emit selectionChanged();
        return;
    }
    n->interaction()->selectionChanged().onNotify(this, [this]() {
        refreshFromSelection();
    }, Asyncable::Mode::SetReplace);
    refreshFromSelection();
}

void PersianTunerPanelModel::refreshFromSelection()
{
    const auto notes = selectedNotes();
    if (!notes.empty()) {
        const NoteIdentity ident = identityOf(notes.front());
        m_selectedLetter = ident.letter;
        m_selectedVariant = ident.variant;
        m_selectedOctave = ident.octave;
        m_currentCents = effectiveTarget(notes.front());
        emit selectedLetterChanged();
        emit selectedVariantChanged();
        emit selectedOctaveChanged();
        emit currentCentsChanged();
        emit computedFreqChanged();
        emit variantRowsChanged();
    }
    emit selectionChanged();
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

    ident.tpc = 0;
    ident.letter = letterFromTpc(note->tpc());
    ident.octave = note->octave();
    ident.tick = note->tick().ticks();
    ident.staffIdx = static_cast<int>(note->staffIdx());

    const AccidentalType acc = note->accidentalType();
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
    default: {
        const int fifths = fifthsFromTpc(note->tpc());
        if (fifths < 0) {
            ident.variant = QStringLiteral("flat");
        } else if (fifths > 0) {
            ident.variant = QStringLiteral("sharp");
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
    const NoteIdentity ident = identityOf(note);
    const std::optional<double> mem = resolveMemory(scoreId(), memoryKey(ident), ident.tick);
    if (mem) {
        return *mem;
    }
    return tableCents(ident.letter, ident.variant);
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
        for (EngravingItem* e : seg->elist()) {
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

void PersianTunerPanelModel::tuneNote(Note* note, double targetCents)
{
    if (!note) {
        return;
    }
    const NoteIdentity ident = identityOf(note);
    const double required = round1(targetCents - ident.baseCents);
    note->undoChangeProperty(Pid::TUNING, required);
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
            tuneNote(note, targetCents);
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
}

double PersianTunerPanelModel::baseCentsForVariant(const QString& variant)
{
    if (variant == QLatin1String("flat")) {
        return -100.0;
    }
    if (variant == QLatin1String("koron")) {
        return -50.0;
    }
    if (variant == QLatin1String("sori")) {
        return 50.0;
    }
    if (variant == QLatin1String("sharp")) {
        return 100.0;
    }
    return 0.0;
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
