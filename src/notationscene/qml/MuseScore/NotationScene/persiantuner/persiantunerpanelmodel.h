/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * Built-in Persian Tuner dock panel (Mixer-like), sign-oriented cents.
 *
 * Sync model:
 *  - the score accidentals (notes) are the source of truth for the panel:
 *    whatever accidental type a note carries in MuseScore itself (flat,
 *    natural, sharp, koron, sori - set from the top symbols row, the
 *    keyboard or the properties panel) is recognized and displayed here;
 *  - tuning a note in the panel assigns the matching accidental type to
 *    the note (so the koron / sori / flat ... sign shows up on the note)
 *    and sets the note tuning so the note plays at the chosen cents.
 *  - a Persian key signature (charghah) can be applied from predefined
 *    patterns; it is stored per score and drives both the score accidentals
 *    and the playback tuning.
 */

#pragma once

#include <functional>
#include <optional>
#include <vector>

#include <QList>
#include <QMap>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlintegration.h>

#include "async/asyncable.h"
#include "modularity/ioc.h"

#include "context/iglobalcontext.h"
#include "notation/inotation_fwd.h"
#include "playback/iplaybackcontroller.h"

namespace mu::engraving {
class Note;
class Score;
}

namespace mu::notation {
class PersianTunerPanelModel : public QObject, public muse::Contextable, public muse::async::Asyncable
{
    Q_OBJECT

    Q_PROPERTY(QString selectedLetter READ selectedLetter WRITE setSelectedLetter NOTIFY selectedLetterChanged)
    Q_PROPERTY(QString selectedVariant READ selectedVariant WRITE setSelectedVariant NOTIFY selectedVariantChanged)
    Q_PROPERTY(int selectedOctave READ selectedOctave WRITE setSelectedOctave NOTIFY selectedOctaveChanged)
    Q_PROPERTY(int letterIndex READ letterIndex WRITE setLetterIndex NOTIFY selectedLetterChanged)
    Q_PROPERTY(int variantIndex READ variantIndex WRITE setVariantIndex NOTIFY selectedVariantChanged)
    Q_PROPERTY(int octaveIndex READ octaveIndex WRITE setOctaveIndex NOTIFY selectedOctaveChanged)

    Q_PROPERTY(double currentCents READ currentCents WRITE setCurrentCents NOTIFY currentCentsChanged)
    Q_PROPERTY(double refFreq READ refFreq WRITE setRefFreq NOTIFY refFreqChanged)
    Q_PROPERTY(double computedFreq READ computedFreq NOTIFY computedFreqChanged)

    Q_PROPERTY(bool autoMemory READ autoMemory WRITE setAutoMemory NOTIFY autoMemoryChanged)
    Q_PROPERTY(bool hasSelection READ hasSelection NOTIFY selectionChanged)
    Q_PROPERTY(QString selectionSummary READ selectionSummary NOTIFY selectionChanged)
    Q_PROPERTY(QString currentLabel READ currentLabel NOTIFY selectionChanged)
    Q_PROPERTY(QString hintText READ hintText NOTIFY selectedVariantChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QString centsLabel READ centsLabel NOTIFY currentCentsChanged)
    Q_PROPERTY(QString refNoteLabel READ refNoteLabel NOTIFY selectedLetterChanged)

    Q_PROPERTY(QVariantList variantRows READ variantRows NOTIFY variantRowsChanged)
    Q_PROPERTY(QVariantList selectedNotesInfo READ selectedNotesInfo NOTIFY selectionChanged)

    // Persian key signatures (charghah)
    Q_PROPERTY(QVariantList keySigPatterns READ keySigPatterns NOTIFY keySigPatternsChanged)
    Q_PROPERTY(int keySigPatternIndex READ keySigPatternIndex WRITE setKeySigPatternIndex NOTIFY keySigPatternIndexChanged)
    Q_PROPERTY(QString keySigPattern READ keySigPattern NOTIFY keySigPatternIndexChanged)
    Q_PROPERTY(QString keySigPatternDescription READ keySigPatternDescription NOTIFY keySigPatternIndexChanged)

    QML_ELEMENT

    muse::ContextInject<mu::context::IGlobalContext> globalContext = { this };
    muse::ContextInject<mu::playback::IPlaybackController> playbackController = { this };

public:
    explicit PersianTunerPanelModel(QObject* parent = nullptr);

    QString selectedLetter() const { return m_selectedLetter; }
    QString selectedVariant() const { return m_selectedVariant; }
    int selectedOctave() const { return m_selectedOctave; }
    int letterIndex() const;
    int variantIndex() const;
    int octaveIndex() const;

    double currentCents() const { return m_currentCents; }
    double refFreq() const { return m_refFreq; }
    double computedFreq() const;

    bool autoMemory() const { return m_autoMemory; }
    bool hasSelection() const;
    QString selectionSummary() const;
    QString currentLabel() const;
    QString hintText() const;
    QString statusMessage() const { return m_statusMessage; }
    QString centsLabel() const;
    QString refNoteLabel() const;

    QVariantList variantRows() const;
    QVariantList selectedNotesInfo() const;

    // Persian key signatures (charghah)
    QVariantList keySigPatterns() const;
    int keySigPatternIndex() const;
    QString keySigPattern() const;
    QString keySigPatternDescription() const;

    Q_INVOKABLE void init();
    Q_INVOKABLE void setSelectedLetter(const QString& letter);
    Q_INVOKABLE void setSelectedVariant(const QString& variant);
    Q_INVOKABLE void setSelectedOctave(int octave);
    Q_INVOKABLE void setLetterIndex(int index);
    Q_INVOKABLE void setVariantIndex(int index);
    Q_INVOKABLE void setOctaveIndex(int index);
    Q_INVOKABLE void setCurrentCents(double cents);
    Q_INVOKABLE void setRefFreq(double freq);
    Q_INVOKABLE void setAutoMemory(bool on);

    Q_INVOKABLE void applyCents(double cents);
    Q_INVOKABLE void setTableCents(const QString& letter, const QString& variant, double cents);
    Q_INVOKABLE void playCurrent();
    Q_INVOKABLE void reapplyMemory();
    Q_INVOKABLE void clearMemory();

    Q_INVOKABLE void setKeySigPatternIndex(int index);
    Q_INVOKABLE void applyKeySigPattern();
    Q_INVOKABLE void clearKeySigPattern();
    Q_INVOKABLE void playKeySigPattern();

    Q_INVOKABLE QString letterFa(const QString& letter) const;
    Q_INVOKABLE QString variantFa(const QString& variant) const;

signals:
    void selectedLetterChanged();
    void selectedVariantChanged();
    void selectedOctaveChanged();
    void currentCentsChanged();
    void refFreqChanged();
    void computedFreqChanged();
    void autoMemoryChanged();
    void selectionChanged();
    void statusMessageChanged();
    void variantRowsChanged();
    void keySigPatternsChanged();
    void keySigPatternIndexChanged();

private:
    struct NoteIdentity {
        QString letter;
        QString variant;
        double baseCents = 0.0;
        int octave = 4;
        int tick = 0;
        int staffIdx = 0;
    };

    struct MemoryChange {
        int tick = 0;
        double cents = 0.0;
    };

    INotationPtr notation() const;
    engraving::Score* score() const;
    QString scoreId() const;

    void onCurrentNotationChanged();
    void refreshFromSelection();
    void refreshKeySigPattern();
    void setStatus(const QString& msg);

    NoteIdentity identityOf(const engraving::Note* note) const;
    QString memoryKey(const NoteIdentity& ident) const;
    double tableCents(const QString& letter, const QString& variant) const;
    double effectiveTarget(const engraving::Note* note) const;

    /// Assign \a variant to \a note (accidental element + cent tuning).
    /// The target is \a targetCents relative to the natural of the letter.
    void tuneNote(engraving::Note* note, const QString& variant, double targetCents);

    std::vector<engraving::Note*> selectedNotes() const;
    std::vector<engraving::Note*> collectScoreNotes() const;

    int rememberAndPropagate(const std::vector<engraving::Note*>& notes, double targetCents);
    void setMemoryChange(const QString& id, const QString& key, int tick, double cents);
    std::optional<double> resolveMemory(const QString& id, const QString& key, int tick) const;
    std::optional<int> nextChangeTick(const QString& id, const QString& key, int fromTick) const;

    void applyPersianKeySig(const QString& patternId);
    void saveCurrentKeySigPattern(const QString& patternId);

    void loadSettings();
    void saveSettings();

    static double baseCentsForVariant(const QString& variant);
    static QString letterFromTpc(int tpc);
    static int fifthsFromTpc(int tpc);
    static double round1(double v);

    QString m_selectedLetter = QStringLiteral("A");
    QString m_selectedVariant = QStringLiteral("sori");
    int m_selectedOctave = 4;
    double m_currentCents = 50.0;
    double m_refFreq = 440.0;
    bool m_autoMemory = true;
    QString m_statusMessage;
    QString m_currentKeySigPattern; //! id of the pattern applied to the current score

    QMap<QString, QMap<QString, double> > m_tuningTable;
    QMap<QString, QMap<QString, QList<MemoryChange> > > m_memory;
    QMap<QString, QString> m_keySigByScore; //! scoreId -> pattern id
};
}
